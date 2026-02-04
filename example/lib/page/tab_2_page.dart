import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'details_page.dart';

class Tab2Page extends StatelessWidget {
  const Tab2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tab 2 Page')),
      body: Center(
        child: Column(
          spacing: 12,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.push(
                '/details',
                extra: DetailsPageExtra(data: 'Test data 2'),
              ),
              child: const Text('Set extra to DetailsPageExtra'),
            ),
          ],
        ),
      ),
    );
  }
}
