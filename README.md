# go_router_extra_codec_generator

Automatically generates codec registries for GoRouter extra parameters with type-safe serialization and state restoration support.

<p align="center">
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Platform-Flutter-02569B?logo=flutter"
      alt="Platform" />
  </a>
  <a href="https://pub.dartlang.org/packages/go_router_extra_codec_generator">
    <img src="https://img.shields.io/pub/v/go_router_extra_codec_generator.svg"
      alt="Pub Package" />
  </a>
  <a href="https://opensource.org/licenses/MIT">
    <img src="https://img.shields.io/github/license/hantrungkien/go_router_extra_codec_generator"
      alt="License: MIT" />
  </a>
  <br>
</p><br>

## Why?

When using [GoRouter](https://pub.dev/packages/go_router) with complex `extra` objects:
- ❌ Manual factory registry management is tedious and error-prone
- ❌ State restoration requires proper serialization setup
- ❌ Type information is lost during serialization

This package:
- ✅ Auto-generates factory registries from annotations
- ✅ Creates type-safe encoder/decoder with `Codec<Object?, Object?>`
- ✅ Preserves type information for proper deserialization
- ✅ Supports state restoration out of the box

## Installation

```yaml
dependencies:
  go_router_extra_codec_annotation: ^1.1.0

dev_dependencies:
  go_router_extra_codec_generator: ^1.1.0
```

Run: `flutter pub get`

## Usage

### 1. Define Base Class and Encoder/Decoder

Create a base class for all Extra objects and implement encoder/decoder:

```dart
import 'dart:convert';
import 'package:go_router_extra_codec_annotation/annotation.dart';

// Base class for all Extra objects
abstract class BasePageExtra {
  String get nameType;
  Map<String, dynamic> toJson();
  const BasePageExtra();
}

// Encoder: Serialize objects with type information
@GoRouterExtraEncoder()
class MyExtraEncoder extends Converter<Object?, Object?> {
  final Map<String, dynamic Function(Map<String, dynamic>)> factories;
  const MyExtraEncoder(this.factories);

  @override
  Object? convert(Object? input) {
    if (input == null || input is num || input is String || input is bool) {
      return input;
    }
    try {
      final typeName = input is BasePageExtra
          ? input.nameType
          : input.runtimeType.toString();
      if (factories.containsKey(typeName)) {
        final data = input is BasePageExtra
            ? input.toJson()
            : (input as dynamic).toJson();
        print('Encoding extra of type: $typeName with data: $data');
        return <String, dynamic>{'__type': typeName, 'data': data};
      }
    } catch (_) {}
    return input;
  }
}

// Decoder: Deserialize objects using type information
@GoRouterExtraDecoder()
class MyExtraDecoder extends Converter<Object?, Object?> {
  final Map<String, dynamic Function(Map<String, dynamic>)> factories;
  const MyExtraDecoder(this.factories);

  @override
  Object? convert(Object? input) {
    if (input is Map && input.containsKey('__type')) {
      try {
        final typeName = input['__type'];
        final rawData = input['data'];
        final factory = factories[typeName];

        if (factory != null && rawData is Map) {
          final typedData = Map<String, dynamic>.from(rawData);
          return factory(typedData);
        }
      } catch (_) {}
    }
    return input;
  }
}
```

### 2. Create Extra Classes with Annotations

```dart
import 'package:go_router_extra_codec_annotation/annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'details_page.g.dart';

@GoRouterPageExtra(name: "DetailsPageExtra")
@JsonSerializable()
class DetailsPageExtra extends BasePageExtra {
  final String data;
  
  const DetailsPageExtra({required this.data});

  factory DetailsPageExtra.fromJson(Map<String, dynamic> json) =>
      _$DetailsPageExtraFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$DetailsPageExtraToJson(this);

  @override
  String get nameType => "DetailsPageExtra";
}
```

**💡 Tips:**
- Use `@GoRouterPageExtra(name: "...")` to prevent minification issues
- Extend `BasePageExtra` for consistent type handling
- Use `json_serializable` for automatic JSON methods

### 3. Run Code Generator

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates `router_extra_codec.gen.dart`:

```dart
/// Auto-generated registry for Extra classes
final Map<String, dynamic Function(Map<String, dynamic>)>
    generatedRouterExtraFactories = {
  'DetailsPageExtra': (json) => DetailsPageExtra.fromJson(json),
};

/// Codec instance with auto-generated factories
final generatedGoRouterExtraCodec =
    GoRouterExtraCodec(generatedRouterExtraFactories);
```

### 4. Configure GoRouter

```dart
final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  restorationScopeId: "root_router", // ⚠️ Required for state restoration
  extraCodec: generatedGoRouterExtraCodec, // 🎯 Use generated codec
  initialLocation: "/tab1",
  routes: [...],
);
```

**For StatefulShellRoute with state restoration:**

```dart
@TypedStatefulShellRoute<MainShellRouteData>(...)
class MainShellRouteData extends StatefulShellRouteData {
  static const String $restorationScopeId = 'mainShellRoute'; // ⚠️ Add this
  // ...
}
```

### 5. Setup MaterialApp

```dart
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: "my_app", // ⚠️ Required for state restoration
      routerConfig: router,
    );
  }
}
```

### 6. Use in Routes

```dart
// Navigate with extra
DetailsRouteData($extra: DetailsPageExtra(data: 'Test data 1')).push(context);
```

## Configuration (Optional)

Customize output location via `build.yaml`:

```yaml
targets:
  $default:
    builders:
      go_router_extra_codec_generator:
        enabled: true
        generate_for:
          include:
            - lib/page/*_page.dart
            - lib/page/router.dart
        options:
          output_filename: router_extra_codec.gen.dart
          output_folder: lib/generated/router
```

**Options:**
- `output_filename`: Name of generated file (default: `router_extra_codec.gen.dart`)
- `output_folder`: Output directory (default: `lib/generated/router`)
- `generate_for`: Specify which files to scan for annotations

## Example

See the [example](./example) folder for a complete working implementation demonstrating:
- Multiple Extra classes with `@GoRouterPageExtra` annotation
- State restoration on web (browser back/forward)
- Custom encoder/decoder implementation
- Integration with `json_serializable`
- StatefulShellRoute with tabs

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by @KienHT

---

**If this package helps you, please give it a ⭐ on [GitHub](https://github.com/hantrungkien/go_router_extra_codec_generator)!**
