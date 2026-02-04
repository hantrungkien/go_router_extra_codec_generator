import 'package:flutter/material.dart';
import 'package:go_router_examples/page/my_app.dart';

/// RUN app in release mode
/// adb shell am kill com.example.example

void main() => runApp(MyApp());

abstract class BasePageExtra {
  String get nameType;

  Map<String, dynamic> toJson();
}
