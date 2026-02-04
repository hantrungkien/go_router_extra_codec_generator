import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router_examples/page/details_page.dart';

class Tab1Page extends StatelessWidget {
  const Tab1Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tab 1 Page')),
      body: Center(
        child: Column(
          spacing: 12,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.push(
                '/details',
                extra: DetailsPageExtra(data: 'Test data 1'),
              ),
              child: const Text('Set extra to DetailsPageExtra'),
            ),
          ],
        ),
      ),
    );
  }
}
