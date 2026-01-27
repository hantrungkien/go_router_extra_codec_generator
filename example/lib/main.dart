// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router_extra_codec_generator/annotation.dart';
import 'package:json_annotation/json_annotation.dart';

import 'generated/router/router_extra_converter.dart';

part 'main.g.dart';

/// This sample app demonstrates how to provide a codec for complex extra data.
void main() => runApp(const MyApp());

/// The router configuration.
final GoRouter _router = GoRouter(
  restorationScopeId: "root_router",
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) =>
          const HomeScreen(),
    ),
  ],
  extraCodec: generatedGoRouterExtraCodec,
);

/// The main app.
class MyApp extends StatelessWidget {
  /// Constructs a [MyApp]
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: "my_app",
      routerConfig: _router,
    );
  }
}

/// The home screen.
class HomeScreen extends StatelessWidget {
  /// Constructs a [HomeScreen].
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "If running in web, use the browser's backward and forward button to test extra codec after setting extra several times.",
            ),
            Text(
              'The extra for this page is: ${GoRouterState.of(context).extra}',
            ),
            ElevatedButton(
              onPressed: () =>
                  context.go('/', extra: Complex1PageExtra(data: 'data 1')),
              child: const Text('Set extra to Complex1PageExtra'),
            ),
            ElevatedButton(
              onPressed: () =>
                  context.go('/', extra: Complex2PageExtra(data: 'data 2')),
              child: const Text('Set extra to Complex2PageExtra'),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class BasePageExtra {
  String get nameType;
  Map<String, dynamic> toJson();
}

@GoRouterPageExtra(name: "Complex1PageExtra")
@JsonSerializable()
class Complex1PageExtra extends BasePageExtra {
  factory Complex1PageExtra.fromJson(Map<String, dynamic> json) =>
      _$Complex1PageExtraFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$Complex1PageExtraToJson(this);

  final String data;

  Complex1PageExtra({required this.data});

  @override
  String get nameType => "Complex1PageExtra";
}

@GoRouterPageExtra(name: "Complex2PageExtra")
@JsonSerializable()
class Complex2PageExtra extends BasePageExtra {
  factory Complex2PageExtra.fromJson(Map<String, dynamic> json) =>
      _$Complex2PageExtraFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$Complex2PageExtraToJson(this);

  final String data;

  Complex2PageExtra({required this.data});

  @override
  String get nameType => "Complex2PageExtra";
}

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
        return {'__type': typeName, 'data': data};
      }
    } catch (_) {}
    return input;
  }
}

@GoRouterExtraDecoder()
class MyExtraDecoder extends Converter<Object?, Object?> {
  final Map<String, dynamic Function(Map<String, dynamic>)> factories;

  const MyExtraDecoder(this.factories);

  @override
  Object? convert(Object? input) {
    if (input is Map<String, dynamic> && input.containsKey('__type')) {
      try {
        final typeName = input['__type'];
        final data = input['data'];
        final factory = factories[typeName];

        if (factory != null) {
          return factory(data as Map<String, dynamic>);
        }
      } catch (_) {}
    }
    return input;
  }
}
