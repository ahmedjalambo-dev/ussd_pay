import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/generated/app_localizations.dart';
import 'providers/app_providers.dart';
import 'screens/root_screen.dart';
import 'theme/app_theme.dart';
import 'tour/coach_mark_overlay.dart';
import 'widgets/payment_decision_listener.dart';

class UssdPayApp extends ConsumerWidget {
  const UssdPayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Above the Navigator, so the tour can follow the user across routes.
      builder: (context, child) => TourOverlay(child: child!),
      home: const PaymentDecisionListener(child: RootScreen()),
    );
  }
}
