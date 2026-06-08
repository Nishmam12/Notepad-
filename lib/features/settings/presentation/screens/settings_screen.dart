import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Use dark theme across the app', style: TextStyle(color: AppColors.textSecondary)),
            value: settings.darkMode,
            activeThumbColor: AppColors.accent,
            onChanged: (val) => ref.read(settingsProvider.notifier).toggleDarkMode(val),
          ),
          const Divider(),
          _buildSectionHeader('Export Defaults'),
          ListTile(
            title: const Text('Format', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Default format when exporting notebooks', style: TextStyle(color: AppColors.textSecondary)),
            trailing: DropdownButton<String>(
              value: settings.exportDefault,
              underline: const SizedBox(),
              items: ['PNG', 'PDF'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) ref.read(settingsProvider.notifier).setExportDefault(val);
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader('Developer'),
          SwitchListTile(
            title: const Text('Developer Mode', style: TextStyle(color: AppColors.textPrimary)),
            subtitle: const Text('Show performance metrics overlay', style: TextStyle(color: AppColors.textSecondary)),
            value: settings.devMode,
            activeThumbColor: AppColors.accent,
            onChanged: (val) => ref.read(settingsProvider.notifier).toggleDevMode(val),
          ),
          const Divider(),
          ListTile(
            title: const Text('About InkFlow', style: TextStyle(color: AppColors.textPrimary)),
            leading: const Icon(Icons.info_outline, color: AppColors.textSecondary),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
