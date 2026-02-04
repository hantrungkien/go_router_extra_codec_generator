import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router_examples/main.dart';
import 'package:go_router_extra_codec_generator/annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'details_page.g.dart';

@GoRouterPageExtra(name: "DetailsPageExtra")
@JsonSerializable()
class DetailsPageExtra extends BasePageExtra {
  factory DetailsPageExtra.fromJson(Map<String, dynamic> json) =>
      _$DetailsPageExtraFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$DetailsPageExtraToJson(this);

  final String data;

  DetailsPageExtra({required this.data});

  @override
  String get nameType => "DetailsPageExtra";
}

class DetailsPage extends StatelessWidget {
  const DetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final extra = GoRouterState.of(context).extra as DetailsPageExtra;
    return Scaffold(
      appBar: AppBar(title: const Text('Details Page')),
      body: Center(
        child: Column(
          spacing: 12,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('TEST: ${extra.toJson()}'),
          ],
        ),
      ),
    );
  }
}
