import 'package:fatora/firestore_services/auth_service.dart';
import 'package:fatora/providers/locale_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';

import 'package:fatora/providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          const SizedBox(height: 16),
          _buildProfileCard(context, user, theme, l10n),
          const SizedBox(height: 24),
          _buildSectionHeader(l10n.settings, theme),
          const SizedBox(height: 8),
          _buildAppearanceSetting(context, theme, l10n),
          const SizedBox(height: 8),
          _buildLanguageSetting(context, theme, l10n),
          const SizedBox(height: 32),
          _buildSignOutButton(context, theme, l10n),
        ],
      ),
    );
  }

  Widget _buildProfileCard(
      BuildContext context, User? user, ThemeData theme, AppLocalizations l10n) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundImage:
                  user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.displayName ?? 'No Name',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'No Email',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.secondary),
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.secondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAppearanceSetting(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: SwitchListTile(
        title: Text(isDarkMode ? "Dark Mode" : "Light Mode"),
        value: isDarkMode,
        onChanged: (value) {
          themeProvider.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
        },
        secondary: Icon(isDarkMode ? Icons.nightlight_round : Icons.wb_sunny),
        activeColor: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildLanguageSetting(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    final localeProvider = Provider.of<LocaleProvider>(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: ListTile(
        leading: const Icon(Icons.language),
        title: Text(l10n.language),
        trailing: DropdownButton<Locale>(
          value: localeProvider.locale,
          underline: const SizedBox(),
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: (Locale? newLocale) {
            if (newLocale != null) {
              localeProvider.setLocale(newLocale);
            }
          },
          items: [
            DropdownMenuItem(
              value: const Locale('en'),
              child: Row(
                children: [
                  Text('🇬🇧', style: theme.textTheme.bodyLarge),
                  const SizedBox(width: 8),
                  const Text('English'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: const Locale('ar'),
              child: Row(
                children: [
                  Text('🇪🇬', style: theme.textTheme.bodyLarge),
                  const SizedBox(width: 8),
                  const Text('العربية'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton(
      BuildContext context, ThemeData theme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: TextButton.icon(
        icon: const Icon(Icons.logout),
        label: const Text("Sign Out"),
        onPressed: () async {
          await AuthService().signOut();
        },
        style: TextButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}