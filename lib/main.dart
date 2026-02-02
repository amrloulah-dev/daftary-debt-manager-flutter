import 'package:fatora/providers/debtor_provider.dart';
import 'package:fatora/providers/debts_provider.dart';
import 'package:fatora/providers/locale_provider.dart';
import 'package:fatora/providers/payment_provider.dart';
import 'package:fatora/providers/theme_provider.dart';
import 'package:fatora/screens/dashboard_page.dart';
import 'package:fatora/services/isar_service.dart';
import 'package:fatora/themes/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Ensure Isar is initialized before the app starts
  await IsarService().openDB();

  runApp(const MyAppWrapper());
}

class MyAppWrapper extends StatelessWidget {
  const MyAppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()..loadLocale()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadThemeMode()),
        ChangeNotifierProvider(create: (_) => DebtorProvider()),
        ChangeNotifierProvider(create: (_) => DebtsProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch providers for global changes (Theme & Locale)
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Daftary',
      debugShowCheckedModeBanner: false,
      
      // Theme Configuration
      themeMode: themeProvider.themeMode,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      
      // Localization Configuration
      locale: localeProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
      ],
      
      // Navigation
      home: const DashboardPage(),
      // Define other routes here if necessary, 
      // but passing objects via MaterialPageRoute is preferred for Details screens.
    );
  }
}