import 'package:fatora/providers/locale_provider.dart';
import 'package:fatora/providers/theme_provider.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // Theme Section
          _buildSectionHeader(context, 'Appearance'), // Could be l10n in future
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              final isDark = themeProvider.themeMode == ThemeMode.dark;
              return SwitchListTile(
                title: Text(isDark ? 'Dark Mode' : 'Light Mode'), // Add l10n later
                secondary: Icon(
                  isDark ? Icons.dark_mode : Icons.light_mode,
                  color: theme.colorScheme.primary,
                ),
                value: isDark,
                onChanged: (val) {
                  themeProvider.setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              );
            },
          ),

          const Divider(),

          // Language Section
          _buildSectionHeader(context, l10n.language),
          Consumer<LocaleProvider>(
            builder: (context, localeProvider, _) {
              final isArabic = localeProvider.locale?.languageCode == 'ar';
              return ListTile(
                title: Text(isArabic ? 'العربية' : 'English'),
                leading: const Icon(Icons.language),
                subtitle: Text(l10n.language), // "Language"
                onTap: () {
                  // Toggle language
                  final newLocale =
                      isArabic ? const Locale('en') : const Locale('ar');
                  localeProvider.setLocale(newLocale);
                },
                trailing: const Icon(Icons.chevron_right),
              );
            },
          ),
          
          const Divider(),
          
          // About / Info (Optional placeholder)
          ListTile(
            title: const Text('Version'),
            subtitle: const Text('1.0.0 (Local-First)'),
            leading: const Icon(Icons.info_outline),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}