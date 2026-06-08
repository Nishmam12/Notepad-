// Root application widget — applies theme and sets up routing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/app_theme.dart';
import '../core/providers/settings_provider.dart';
import 'router.dart';

class InkFlowApp extends ConsumerWidget {
  const InkFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp.router(
      title: 'InkFlow',
      debugShowCheckedModeBanner: false,
      showPerformanceOverlay: settings.devMode,
      theme: settings.darkMode ? AppTheme.darkTheme : AppTheme.darkTheme, // We'll always use dark theme for now as requested by previous constraints, or expand later.
      routerConfig: appRouter,
    );
  }
}
