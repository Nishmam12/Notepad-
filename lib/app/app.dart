// Root application widget — applies theme and sets up routing.

import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class InkFlowApp extends StatelessWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'InkFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
