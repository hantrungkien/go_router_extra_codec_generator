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

part 'router.g.dart';

GlobalKey<NavigatorState> _key(String debugLabel) {
  return GlobalKey<NavigatorState>(debugLabel: debugLabel);
}

final rootNavigatorKey = _key('RootNavigator');
final tab1NavigatorKey = _key('Tab1Navigator');
final tab2NavigatorKey = _key('Tab2Navigator');

@TypedStatefulShellRoute<MainShellRouteData>(
  branches: <TypedStatefulShellBranch<StatefulShellBranchData>>[
    TypedStatefulShellBranch<Tab1BranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<Tab1RouteData>(path: '/tab1'),
      ],
    ),
    TypedStatefulShellBranch<Tab2BranchData>(
      routes: <TypedRoute<RouteData>>[
        TypedGoRoute<Tab2RouteData>(path: '/tab2'),
      ],
    ),
  ],
)
class MainShellRouteData extends StatefulShellRouteData {
  const MainShellRouteData();

  static final GlobalKey<NavigatorState> $parentNavigatorKey = rootNavigatorKey;
  static const String $restorationScopeId = 'mainShellRoute';

  @override
  Widget builder(
    BuildContext context,
    GoRouterState state,
    StatefulNavigationShell navigationShell,
  ) {
    return MainPage(navigationShell: navigationShell);
  }
}

class Tab1BranchData extends StatefulShellBranchData {
  const Tab1BranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = tab1NavigatorKey;
  static final List<NavigatorObserver> $observers = const [];
}

class Tab1RouteData extends GoRouteData with $Tab1RouteData {
  const Tab1RouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage(
      key: state.pageKey,
      name: 'Tab1',
      child: const Tab1Page(),
    );
  }
}

class Tab2BranchData extends StatefulShellBranchData {
  const Tab2BranchData();

  static final GlobalKey<NavigatorState> $navigatorKey = tab2NavigatorKey;
  static final List<NavigatorObserver> $observers = const [];
}

class Tab2RouteData extends GoRouteData with $Tab2RouteData {
  const Tab2RouteData();

  @override
  Page<void> buildPage(BuildContext context, GoRouterState state) {
    return NoTransitionPage(
      key: state.pageKey,
      name: 'Tab2',
      child: const Tab2Page(),
    );
  }
}

@TypedGoRoute<DetailsRouteData>(path: '/details')
class DetailsRouteData extends GoRouteData with $DetailsRouteData {
  const DetailsRouteData({required this.$extra});

  final DetailsPageExtra $extra;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const DetailsPage();
  }
}

final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  restorationScopeId: "root_router",
  extraCodec: generatedGoRouterExtraCodec,
  initialLocation: "/tab1",
  routes: $appRoutes,
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
        return <String, dynamic>{'__type': typeName, 'data': data};
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
