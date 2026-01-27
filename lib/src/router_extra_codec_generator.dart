import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';

class GoRouterExtraCodecBuilder implements Builder {
  final BuilderOptions options;
  final List<Glob> _includeGlobs;
  final List<Glob> _excludeGlobs;
  final String _outputFilename;
  final String _outputFolder;
  final String _codecClassName;

  GoRouterExtraCodecBuilder(this.options)
    : _includeGlobs = _parseGlobPatterns(
        options.config['generate_for']?['include'] as List?,
        defaultPattern: ['lib/*.dart', 'lib/**/*.dart'],
      ),
      _excludeGlobs = _parseGlobPatterns(
        options.config['generate_for']?['exclude'] as List?,
      ),
      _outputFilename =
          options.config['output_filename'] as String? ??
          'router_extra_converter.dart',
      _outputFolder =
          options.config['output_folder'] as String? ?? 'lib/generated/router',
      _codecClassName =
          options.config['codec_class_name'] as String? ?? 'GoRouterExtraCodec';

  static List<Glob> _parseGlobPatterns(
    List<dynamic>? patterns, {
    List<String> defaultPattern = const [],
  }) {
    if (patterns == null || patterns.isEmpty) {
      if (defaultPattern.isNotEmpty) {
        return defaultPattern.map((p) => Glob(p)).toList();
      }
      return [];
    }
    return patterns.map((p) => Glob(p.toString())).toList();
  }

  @override
  Map<String, List<String>> get buildExtensions => const {
    'lib/\$lib\$': ['lib/generated/router/router_extra_converter.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    try {
      // This builder runs on the $lib$ pseudo-input
      if (buildStep.inputId.path != 'lib/\$lib\$') {
        return;
      }

      log.info('GoRouterExtraCodecBuilder: Starting scan...');

      final resolver = buildStep.resolver;
      final extraClasses = <_ExtraClassInfo>[];
      String? encoderClass;
      String? encoderImport;
      String? decoderClass;
      String? decoderImport;

      // Scan all matching files
      for (final includeGlob in _includeGlobs) {
        await for (final input in buildStep.findAssets(includeGlob)) {
          if (input.path.endsWith('.g.dart') ||
              input.path.endsWith('.freezed.dart') ||
              input.path.endsWith('.gen.dart') ||
              input.path.contains('/generated/')) {
            continue;
          }

          if (_shouldExclude(input.path)) {
            continue;
          }

          try {
            if (!await resolver.isLibrary(input)) continue;

            final lib = await resolver.libraryFor(input);
            final reader = LibraryReader(lib);

            // Find @GoRouterPageExtra classes
            const extraChecker = TypeChecker.fromUrl(
              'package:go_router_extra_codec_generator/src/router_extra_annotation.dart#GoRouterPageExtra',
            );
            for (final annotated in reader.annotatedWith(extraChecker)) {
              if (annotated.element is ClassElement) {
                final classElement = annotated.element as ClassElement;
                final info = _validateExtraClass(extraChecker, classElement);
                if (info != null) {
                  extraClasses.add(info);
                  log.info('  Found Extra: ${info.className}');
                }
              }
            }

            // Find @GoRouterExtraEncoder
            const encoderChecker = TypeChecker.fromUrl(
              'package:go_router_extra_codec_generator/src/router_extra_annotation.dart#GoRouterExtraEncoder',
            );
            for (final annotated in reader.annotatedWith(encoderChecker)) {
              if (annotated.element is ClassElement) {
                encoderClass = annotated.element.name;
                encoderImport = lib.identifier;
                log.info('  Found Encoder: $encoderClass');
              }
            }

            // Find @GoRouterExtraDecoder
            const decoderChecker = TypeChecker.fromUrl(
              'package:go_router_extra_codec_generator/src/router_extra_annotation.dart#GoRouterExtraDecoder',
            );
            for (final annotated in reader.annotatedWith(decoderChecker)) {
              if (annotated.element is ClassElement) {
                decoderClass = annotated.element.name;
                decoderImport = lib.identifier;
                log.info('  Found Decoder: $decoderClass');
              }
            }
          } catch (e, stack) {
            log.warning('Error processing ${input.path}: $e', e, stack);
          }
        }
      }

      if (extraClasses.isEmpty) {
        log.warning('No @GoRouterPageExtra classes found');
        return;
      }

      log.info('Found ${extraClasses.length} Extra classes');

      // Generate output
      final code = _generateCode(
        extraClasses,
        encoderClass,
        encoderImport,
        decoderClass,
        decoderImport,
        _codecClassName,
      );

      // Write to output file
      final outputPath = '$_outputFolder/$_outputFilename';
      final outputId = AssetId(buildStep.inputId.package, outputPath);

      await buildStep.writeAsString(outputId, code);
      log.info(
        'Generated: $outputPath with ${extraClasses.length} Extra classes',
      );
    } catch (e, stack) {
      log.severe('GoRouterExtraCodecBuilder error: $e', e, stack);
    }
  }

  bool _shouldExclude(String path) {
    for (final excludeGlob in _excludeGlobs) {
      if (excludeGlob.matches(path)) {
        return true;
      }
    }
    return false;
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

  String _generateCode(
    List<_ExtraClassInfo> extraClasses,
    String? encoderClass,
    String? encoderImport,
    String? decoderClass,
    String? decoderImport,
    String codecClassName,
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
    buffer.writeln('// Author: @KienHT');
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
    if (encoderImport != null &&
        encoderImport.isNotEmpty &&
        !imports.contains(encoderImport)) {
      buffer.writeln("import '$encoderImport';");
    }
    if (decoderImport != null &&
        decoderImport.isNotEmpty &&
        decoderImport != encoderImport &&
        !imports.contains(decoderImport)) {
      buffer.writeln("import '$decoderImport';");
    }
    buffer.writeln();

    // Generate Codec class
    buffer.writeln('/// Auto-generated router extra codec');
    buffer.writeln('class $codecClassName extends Codec<Object?, Object?> {');
    buffer.writeln(
      '  final Map<String, dynamic Function(Map<String, dynamic>)> _factories;',
    );
    buffer.writeln();
    buffer.writeln('  const $codecClassName(this._factories);');
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
      'final generated$codecClassName = '
      '$codecClassName(generatedRouterExtraFactories);',
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
