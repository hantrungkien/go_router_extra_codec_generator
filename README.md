# go_router_extra_codec_generator

A code generator for Flutter that automatically creates codec registries for GoRouter extra parameters, solving serialization/deserialization and state restoration challenges.

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

## 🔍 Keywords
`flutter`, `go_router`, `codec`, `serialization`, `state restoration`, `code generation`

## 🎯 Problem

When working with Flutter's [GoRouter](https://pub.dev/packages/go_router), developers face several challenges:

### 1. **Complex Extra Serialization**
Passing complex objects between screens requires custom serialization/deserialization logic through the `extraCodec` parameter.

### 2. **State Restoration**
Restoring navigation state when the app returns from background to foreground requires:
- Adding `restorationScopeId` to `GoRouter`, `ShellRoute`, and `MaterialApp.router`
- Properly serializable extra parameters
- Manual factory registration

### 3. **Manual Registry Management**
In projects with many Extra classes, manually maintaining the factory registry becomes tedious and error-prone:

```dart
// Manually maintaining this is time-consuming!
final Map<String, dynamic Function(Map<String, dynamic>)> factories = {
  'Complex1PageExtra': (json) => Complex1PageExtra.fromJson(json),
  'Complex2PageExtra': (json) => Complex2PageExtra.fromJson(json),
  'Complex3PageExtra': (json) => Complex3PageExtra.fromJson(json),
  // ... dozens more
};
```

## ✨ Solution

This package automatically generates the factory registry using build_runner and annotations:

```dart
@GoRouterPageExtra(name: "Complex1PageExtra")
class Complex1PageExtra extends BasePageExtra {
  // Your class implementation
}
```

The generator will:
- ✅ Automatically create `generatedRouterExtraFactories` registry
- ✅ Generate a `GoRouterExtraCodec` class extending `Codec<Object?, Object?>`
- ✅ Wire up your custom encoder/decoder classes
- ✅ Keep everything in sync as you add/remove Extra classes

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  go_router: ^14.0.0
  json_annotation: ^4.9.0
  go_router_extra_codec_generator: ^1.0.0

dev_dependencies:
  build_runner: ^2.4.0
  json_serializable: ^6.8.0
```

Then run:
```bash
flutter pub get
```

## 🚀 Usage

### Step 1: Implement Your Encoder and Decoder

Following [GoRouter's official guidance](https://pub.dev/documentation/go_router/latest/topics/Configuration-topic.html#configuring-the-code-for-serializing-extra), create encoder and decoder classes:

```dart
@GoRouterExtraEncoder()
class MyExtraEncoder extends Converter<Object?, Object?> {
  final Map<String, dynamic Function(Map<String, dynamic>)> factories;
  const MyExtraEncoder(this.factories);

  @override
  Object? convert(Object? input) {
    // Handle primitives
    if (input == null || input is num || input is String || input is bool) {
      return input;
    }
    // Serialize complex objects with type information
    final typeName = (input as BasePageExtra).nameType;
    if (factories.containsKey(typeName)) {
      return {'__type': typeName, 'data': input.toJson()};
    }
    return input;
  }
}

@GoRouterExtraDecoder()
class MyExtraDecoder extends Converter<Object?, Object?> {
  final Map<String, dynamic Function(Map<String, dynamic>)> factories;
  const MyExtraDecoder(this.factories);

  @override
  Object? convert(Object? input) {
    // Deserialize objects using registered factories
    if (input is Map<String, dynamic> && input.containsKey('__type')) {
      final factory = factories[input['__type']];
      return factory?.call(input['data'] as Map<String, dynamic>);
    }
    return input;
  }
}
```

> 💡 See the [complete example](./example/lib/main.dart) for the full implementation.

### Step 2: Annotate Your Extra Classes

Mark classes with `@GoRouterPageExtra` for automatic registration:

```dart
import 'package:go_router_extra_codec_generator/annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'main.g.dart';

abstract class BasePageExtra {
  String get nameType;
  Map<String, dynamic> toJson();
}

@GoRouterPageExtra(name: "Complex1PageExtra")
@JsonSerializable()
class Complex1PageExtra extends BasePageExtra {
  final String data;
  
  Complex1PageExtra({required this.data});

  factory Complex1PageExtra.fromJson(Map<String, dynamic> json) =>
      _$Complex1PageExtraFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$Complex1PageExtraToJson(this);

  @override
  String get nameType => "Complex1PageExtra";
}

// Add more Extra classes as needed...
```

**💡 Tips:**
- Providing a `name` prevents minification issues in release builds
- Extend from a base class with `nameType` getter for consistent type identification
- Use `json_serializable` for automatic JSON serialization

### Step 3: Run Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This generates `router_extra_converter.dart` with:

```dart
/// Auto-generated registry for Extra classes
final Map<String, dynamic Function(Map<String, dynamic>)> generatedRouterExtraFactories = {
  'Complex1PageExtra': (json) => Complex1PageExtra.fromJson(json),
  'Complex2PageExtra': (json) => Complex2PageExtra.fromJson(json),
};

/// Codec instance with auto-generated factories
final generatedGoRouterExtraCodec = GoRouterExtraCodec(generatedRouterExtraFactories);
```

### Step 4: Configure GoRouter

```dart
final GoRouter _router = GoRouter(
  restorationScopeId: "root_router", // Required for state restoration
  extraCodec: generatedGoRouterExtraCodec, // Use generated codec
  routes: [...],
);

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: "my_app", // Required for state restoration
      routerConfig: _router,
    );
  }
}
```

**⚠️ State Restoration:**
Add `restorationScopeId` to `MaterialApp.router`, `GoRouter`, and `ShellRoute` for proper state restoration when returning from background.

### Step 5: Use It!

```dart
// Navigate with complex extras
context.go('/', extra: Complex1PageExtra(data: 'Hello'));

// Access extras
final extra = GoRouterState.of(context).extra;
if (extra is Complex1PageExtra) {
  print(extra.data);
}
```

##  Configuration (Optional)

Customize output location via `build.yaml`:

```yaml
targets:
  $default:
    builders:
      go_router_extra_codec_generator:builder:
        options:
          output_dir: "lib/generated/router"
```

## 💡 Example

See the [example](./example) folder for a complete working implementation demonstrating:
- Multiple Extra classes
- State restoration on web (browser back/forward)
- Custom encoder/decoder implementation
- Integration with `json_serializable`

Run the example:
```bash
cd example
flutter run -d chrome
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT - see the [LICENSE](LICENSE) file for details.

## 👤 Author

Created by @KienHT

---

**If this package helps you, please give it a ⭐ on [GitHub](https://github.com/hantrungkien/go_router_extra_codec_generator)!**
