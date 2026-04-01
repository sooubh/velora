import 'package:flutter/material.dart';

import 'router.dart';
import '../core/theme/app_theme.dart';

class SwarmApp extends StatelessWidget {
  const SwarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter();

    return MaterialApp.router(
      title: 'Swarm AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router.router,
    );
  }
}
