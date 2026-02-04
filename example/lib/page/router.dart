import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router_examples/generated/router/router_extra_converter.dart';
import 'package:go_router_examples/main.dart';
import 'package:go_router_examples/page/details_page.dart';
import 'package:go_router_examples/page/main_page.dart';
import 'package:go_router_examples/page/tab_1_page.dart';
import 'package:go_router_examples/page/tab_2_page.dart';
import 'package:go_router_extra_codec_generator/annotation.dart';

GlobalKey<NavigatorState> _key(String debugLabel) {
  return GlobalKey<NavigatorState>(debugLabel: debugLabel);
}

final rootNavigatorKey = _key('RootNavigator');
final tab1NavigatorKey = _key('Tab1Navigator');
final tab2NavigatorKey = _key('Tab2Navigator');

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
  restorationScopeId: "root_router",
  extraCodec: generatedGoRouterExtraCodec,
  initialLocation: "/tab1",
  routes: <RouteBase>[
    StatefulShellRoute.indexedStack(
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state, navigationShell) {
        return MainPage(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          navigatorKey: tab1NavigatorKey,
          routes: [
            GoRoute(
              name: "Tab1",
              path: "/tab1",
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                name: state.name,
                child: const Tab1Page(),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          navigatorKey: tab2NavigatorKey,
          routes: [
            GoRoute(
              name: "Tab2",
              path: "/tab2",
              pageBuilder: (context, state) => NoTransitionPage(
                key: state.pageKey,
                name: state.name,
                child: const Tab2Page(),
              ),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      name: "Details",
      path: '/details',
      builder: (context, state) => const DetailsPage(),
    ),
  ],
);

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
