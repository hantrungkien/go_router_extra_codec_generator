import 'package:flutter/material.dart';
import 'package:go_router_examples/page/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      restorationScopeId: "my_app",
      routerConfig: router,
    );
  }
}
