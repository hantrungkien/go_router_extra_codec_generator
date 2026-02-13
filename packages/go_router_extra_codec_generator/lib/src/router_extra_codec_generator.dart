import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

/// Per-file builder that scans for @GoRouterPageExtra annotations
/// Works with build.yaml generate_for to process only matching files
class GoRouterExtraCodecBuilder implements Builder {
  final BuilderOptions options;

  GoRouterExtraCodecBuilder(this.options);

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.router_extra.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // Skip generated files
    final inputPath = buildStep.inputId.path;
    if (inputPath.endsWith('.g.dart') ||
        inputPath.endsWith('.gen.dart') ||
        inputPath.endsWith('.freezed.dart') ||
        inputPath.endsWith('.config.dart') ||
        inputPath.endsWith('.router_extra.dart') ||
        inputPath.contains('/generated/')) {
      return;
    }

    try {
      log.info(
        'GoRouterExtraCodecBuilder: Processing ${buildStep.inputId.path}',
      );

      final resolver = buildStep.resolver;
      if (!await resolver.isLibrary(buildStep.inputId)) return;

      final lib = await resolver.libraryFor(buildStep.inputId);
      final reader = LibraryReader(lib);

      final extraClasses = <_ExtraClassInfo>[];
      String? encoderClass;
      String? encoderImport;
      String? decoderClass;
      String? decoderImport;

      // Find @GoRouterPageExtra classes
      const extraChecker = TypeChecker.fromUrl(
        'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterPageExtra',
      );
      for (final annotated in reader.annotatedWith(extraChecker)) {
        if (annotated.element is ClassElement) {
          final classElement = annotated.element as ClassElement;
          final info = _validateExtraClass(extraChecker, classElement);
          if (info != null) {
            extraClasses.add(info);
            log.info(
              '  Found Extra: ${info.className} in ${buildStep.inputId.path}',
            );
          }
        }
      }

      if (extraClasses.isEmpty) {
        log.info('  No @GoRouterPageExtra classes found in ${buildStep.inputId.path}');
      }

      // Find @GoRouterExtraEncoder
      const encoderChecker = TypeChecker.fromUrl(
        'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterExtraEncoder',
      );
      for (final annotated in reader.annotatedWith(encoderChecker)) {
        if (annotated.element is ClassElement) {
          encoderClass = annotated.element.name;
          encoderImport = lib.identifier;
          log.info('  Found Encoder: $encoderClass');
        }
      }

      if (encoderClass == null || encoderImport == null) {
        log.info('  No Encoder found in ${buildStep.inputId.path}');
      }

      // Find @GoRouterExtraDecoder
      const decoderChecker = TypeChecker.fromUrl(
        'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterExtraDecoder',
      );
      for (final annotated in reader.annotatedWith(decoderChecker)) {
        if (annotated.element is ClassElement) {
          decoderClass = annotated.element.name;
          decoderImport = lib.identifier;
          log.info('  Found Decoder: $decoderClass');
        }
      }

      if (decoderClass == null || decoderImport == null) {
        log.info('  No Decoder found in ${buildStep.inputId.path}');
      }

      // Generate .router_extra.dart file for this input
      if (extraClasses.isNotEmpty ||
          encoderClass != null ||
          decoderClass != null) {
        final code = _generatePerFileCode(
          buildStep.inputId.path,
          extraClasses,
          encoderClass,
          encoderImport,
          decoderClass,
          decoderImport,
        );

        final outputId = buildStep.inputId.changeExtension(
          '.router_extra.dart',
        );
        await buildStep.writeAsString(outputId, code);
        log.info('Generated: ${outputId.path}');
      }
    } catch (e, stack) {
      log.warning('Error processing ${buildStep.inputId.path}: $e', e, stack);
    }
  }

  _ExtraClassInfo? _validateExtraClass(
    TypeChecker typeChecker,
    ClassElement element,
  ) {
    final className = element.name;

    if (className == null || className.isEmpty) {
      log.warning('Class element has null or empty name');
      return null;
    }

    // Validate toJson
    final hasToJson = element.methods.any((m) {
      if (m.name != 'toJson' || m.isStatic) return false;
      if (m.formalParameters.isNotEmpty) return false;
      final returnType = m.returnType.getDisplayString();
      return returnType.startsWith('Map');
    });

    if (!hasToJson) {
      log.warning('$className: missing toJson() method');
      return null;
    }

    // Validate fromJson
    final hasFromJson = element.constructors.any((c) {
      if (c.name != 'fromJson') return false;
      if (c.formalParameters.length != 1) return false;
      final paramType = c.formalParameters.first.type.getDisplayString();
      return paramType.startsWith('Map');
    });

    if (!hasFromJson) {
      log.warning('$className: missing fromJson constructor');
      return null;
    }

    final library = element.library;
    final importPath = library.identifier;

    final annotation = typeChecker.firstAnnotationOf(element);

    String customName = "";
    if (annotation != null) {
      final reader = ConstantReader(annotation);
      customName = reader.read('name').stringValue;
    }

    return _ExtraClassInfo(
      className: className,
      importPath: importPath,
      customName: customName,
    );
  }

  String _generatePerFileCode(
    String inputPath,
    List<_ExtraClassInfo> extraClasses,
    String? encoderClass,
    String? encoderImport,
    String? decoderClass,
    String? decoderImport,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from: $inputPath');
    buffer.writeln('// Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    // This file just marks that annotations were found
    // The actual aggregation will be done by a combining builder
    if (extraClasses.isNotEmpty) {
      buffer.writeln('// Extra classes found in this file:');
      for (final info in extraClasses) {
        buffer.writeln('// - ${info.className}');
      }
    }

    if (encoderClass != null) {
      buffer.writeln('// Encoder class: $encoderClass');
    }

    if (decoderClass != null) {
      buffer.writeln('// Decoder class: $decoderClass');
    }

    return buffer.toString();
  }
}

/// Combining builder that aggregates all .router_extra.dart files
/// and generates the final router_extra_codec.gen.dart
class GoRouterExtraCodecCombiningBuilder implements Builder {
  final BuilderOptions options;
  final String _outputFilename;
  final String _outputFolder;

  GoRouterExtraCodecCombiningBuilder(this.options)
    : _outputFilename =
          options.config['output_filename'] as String? ??
          'router_extra_codec.gen.dart',
      _outputFolder =
          options.config['output_folder'] as String? ?? 'lib/generated/router';

  @override
  Map<String, List<String>> get buildExtensions {
    return {
      r'lib/$lib$': ['$_outputFolder/$_outputFilename'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    // This builder runs on the $lib$ pseudo-input
    if (buildStep.inputId.path != r'lib/$lib$') {
      return;
    }

    try {
      log.info('GoRouterExtraCodecCombiningBuilder: Starting aggregation...');

      final resolver = buildStep.resolver;
      final extraClasses = <_ExtraClassInfo>[];
      String? encoderClass;
      String? encoderImport;
      String? decoderClass;
      String? decoderImport;

      // Collect source files from .router_extra.dart files in cache
      final sourceFiles = <String>{};
      // Use glob that matches both source and generated cache locations
      final routerExtraGlob = Glob('**.router_extra.dart');
      await for (final routerExtraFile in buildStep.findAssets(
        routerExtraGlob,
      )) {
        // Get corresponding source file by removing .router_extra.dart
        final sourcePath = routerExtraFile.path.replaceAll(
          '.router_extra.dart',
          '.dart',
        );
        sourceFiles.add(sourcePath);
      }

      log.info(
        'Found ${sourceFiles.length} source files from .router_extra.dart files',
      );

      // Scan only the source files that have .router_extra.dart
      for (final sourcePath in sourceFiles) {
        final input = AssetId(buildStep.inputId.package, sourcePath);

        try {
          if (!await resolver.isLibrary(input)) continue;

          final lib = await resolver.libraryFor(input);
          final reader = LibraryReader(lib);

          // Find @GoRouterPageExtra classes
          const extraChecker = TypeChecker.fromUrl(
            'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterPageExtra',
          );
          for (final annotated in reader.annotatedWith(extraChecker)) {
            if (annotated.element is ClassElement) {
              final classElement = annotated.element as ClassElement;
              final info = _validateExtraClass(extraChecker, classElement);
              if (info != null) {
                extraClasses.add(info);
              }
            }
          }

          if (extraClasses.isEmpty) {
            log.warning('No @GoRouterPageExtra classes found');
          }

          // Find @GoRouterExtraEncoder
          const encoderChecker = TypeChecker.fromUrl(
            'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterExtraEncoder',
          );
          for (final annotated in reader.annotatedWith(encoderChecker)) {
            if (annotated.element is ClassElement) {
              encoderClass = annotated.element.name;
              encoderImport = lib.identifier;
            }
          }

          if (encoderClass == null || encoderImport == null) {
            log.info('  No Encoder found in ${buildStep.inputId.path}');
          }

          // Find @GoRouterExtraDecoder
          const decoderChecker = TypeChecker.fromUrl(
            'package:go_router_extra_codec_annotation/src/router_extra_annotation.dart#GoRouterExtraDecoder',
          );
          for (final annotated in reader.annotatedWith(decoderChecker)) {
            if (annotated.element is ClassElement) {
              decoderClass = annotated.element.name;
              decoderImport = lib.identifier;
            }
          }

          if (decoderClass == null || decoderImport == null) {
            log.info('  No Decoder found in ${buildStep.inputId.path}');
          }
        } catch (e, stack) {
          log.warning('Error processing $sourcePath: $e', e, stack);
        }
      }

      if (extraClasses.isEmpty) {
        log.warning('No @GoRouterPageExtra classes found');
      }

      log.info(
        'Found ${extraClasses.length} Extra classes, generating $_outputFilename...',
      );

      // Generate output
      final code = _generateCode(
        extraClasses,
        encoderClass,
        encoderImport,
        decoderClass,
        decoderImport,
      );

      // Write to output file
      final outputPath = '$_outputFolder/$_outputFilename';
      final outputId = AssetId(buildStep.inputId.package, outputPath);

      await buildStep.writeAsString(outputId, code);
      log.info(
        'Generated: $outputPath with ${extraClasses.length} Extra classes',
      );
    } catch (e, stack) {
      log.severe('GoRouterExtraCodecCombiningBuilder error: $e', e, stack);
    }
  }

  _ExtraClassInfo? _validateExtraClass(
    TypeChecker typeChecker,
    ClassElement element,
  ) {
    final className = element.name;

    if (className == null || className.isEmpty) {
      return null;
    }

    // Validate toJson
    final hasToJson = element.methods.any((m) {
      if (m.name != 'toJson' || m.isStatic) return false;
      if (m.formalParameters.isNotEmpty) return false;
      final returnType = m.returnType.getDisplayString();
      return returnType.startsWith('Map');
    });

    if (!hasToJson) {
      return null;
    }

    // Validate fromJson
    final hasFromJson = element.constructors.any((c) {
      if (c.name != 'fromJson') return false;
      if (c.formalParameters.length != 1) return false;
      final paramType = c.formalParameters.first.type.getDisplayString();
      return paramType.startsWith('Map');
    });

    if (!hasFromJson) {
      return null;
    }

    final library = element.library;
    final importPath = library.identifier;

    final annotation = typeChecker.firstAnnotationOf(element);

    String customName = "";
    if (annotation != null) {
      final reader = ConstantReader(annotation);
      customName = reader.read('name').stringValue;
    }

    return _ExtraClassInfo(
      className: className,
      importPath: importPath,
      customName: customName,
    );
  }

  String _generateCode(
    List<_ExtraClassInfo> extraClasses,
    String? encoderClass,
    String? encoderImport,
    String? decoderClass,
    String? decoderImport,
  ) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      '// **************************************************************************',
    );
    buffer.writeln('// GoRouterExtraCodecGenerator');
    buffer.writeln(
      '// **************************************************************************',
    );
    buffer.writeln();
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('// Author: @Klever');
    buffer.writeln();

    // Imports
    buffer.writeln("import 'dart:convert';");
    buffer.writeln();

    // Import Extra classes
    final sortedClasses = extraClasses.toList()
      ..sort((a, b) => a.className.compareTo(b.className));

    final imports = sortedClasses.map((e) => e.importPath).toSet().toList()
      ..sort();

    for (final import in imports) {
      buffer.writeln("import '$import';");
    }
    buffer.writeln();

    // Import encoder/decoder if found
    if (encoderImport != null && encoderImport.isNotEmpty) {
      buffer.writeln("import '$encoderImport';");
    }
    if (decoderImport != null &&
        decoderImport.isNotEmpty &&
        decoderImport != encoderImport) {
      buffer.writeln("import '$decoderImport';");
    }
    buffer.writeln();

    // Generate GoRouterExtraCodec class
    buffer.writeln('/// Auto-generated router extra codec');
    buffer.writeln(
      'class GoRouterExtraCodec extends Codec<Object?, Object?> {',
    );
    buffer.writeln(
      '  final Map<String, dynamic Function(Map<String, dynamic>)> _factories;',
    );
    buffer.writeln();
    buffer.writeln('  const GoRouterExtraCodec(this._factories);');
    buffer.writeln();
    buffer.writeln('  @override');

    if (encoderClass != null) {
      buffer.writeln(
        '  Converter<Object?, Object?> get encoder => $encoderClass(_factories);',
      );
    } else {
      buffer.writeln(
        '  Converter<Object?, Object?> get encoder => const _DefaultEncoder();',
      );
    }

    buffer.writeln();
    buffer.writeln('  @override');

    if (decoderClass != null) {
      buffer.writeln(
        '  Converter<Object?, Object?> get decoder => $decoderClass(_factories);',
      );
    } else {
      buffer.writeln(
        '  Converter<Object?, Object?> get decoder => const _DefaultDecoder();',
      );
    }

    buffer.writeln('}');
    buffer.writeln();

    // Generate factories map
    buffer.writeln('/// Auto-generated registry for Extra classes');
    buffer.writeln('/// ${extraClasses.length} classes registered:');
    for (final info in sortedClasses) {
      buffer.writeln('/// - ${info.className}');
    }
    buffer.writeln(
      'final Map<String, dynamic Function(Map<String, dynamic>)> '
      'generatedRouterExtraFactories = {',
    );

    for (final info in sortedClasses) {
      buffer.writeln(
        "  '${info.keyName}': (json) => ${info.className}.fromJson(json),",
      );
    }

    buffer.writeln('};');
    buffer.writeln();

    // Generate codec instance
    buffer.writeln('/// Codec instance with auto-generated factories');
    buffer.writeln(
      'final generatedGoRouterExtraCodec = '
      'GoRouterExtraCodec(generatedRouterExtraFactories);',
    );
    buffer.writeln();

    // Add default encoder/decoder if custom ones not found
    if (encoderClass == null) {
      buffer.writeln(
        'class _DefaultEncoder extends Converter<Object?, Object?> {',
      );
      buffer.writeln('  const _DefaultEncoder();');
      buffer.writeln('  @override');
      buffer.writeln('  Object? convert(Object? input) => input;');
      buffer.writeln('}');
      buffer.writeln();
    }

    if (decoderClass == null) {
      buffer.writeln(
        'class _DefaultDecoder extends Converter<Object?, Object?> {',
      );
      buffer.writeln('  const _DefaultDecoder();');
      buffer.writeln('  @override');
      buffer.writeln('  Object? convert(Object? input) => input;');
      buffer.writeln('}');
    }

    return buffer.toString();
  }
}

class _ExtraClassInfo {
  final String className;
  final String importPath;
  final String customName;

  String get keyName => customName.isNotEmpty ? customName : className;

  const _ExtraClassInfo({
    required this.className,
    required this.importPath,
    required this.customName,
  });
}
