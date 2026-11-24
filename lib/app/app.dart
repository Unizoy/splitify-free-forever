import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/core/config/env.dart';
import 'package:splitify/features/account/application/theme_mode_controller.dart';
import 'package:splitify/features/app_lock/presentation/app_lock_gate.dart';
import 'package:splitify/features/widget/application/home_widget_sync.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

/// Build settings, set once in bootstrap.
final envProvider = Provider<Env>((ref) => throw UnimplementedError());

/// Root widget: router, localisation and the light/dark themes (B3).
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // X3: keeps the home-screen widget's values in step with balances and sync.
    ref.watch(homeWidgetSyncProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      routerConfig: ref.watch(routerProvider),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeControllerProvider),
      debugShowCheckedModeBanner: false,
      // X2: the lock screen and background cover sit above every page. Pages without their own status-bar
      // style (editor, settings pages, sheets) get dark icons in light mode and light icons in dark mode,
      // instead of keeping the white icons of the last hero page (final QA, S-254).
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: (context.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
          statusBarColor: AppPalette.clear,
        ),
        // The page colour behind every route: the shared-axis move shifts pages 24 dp, and the edge it
        // uncovers shows the page colour instead of the black window (S-288).
        child: ColoredBox(
          color: context.colors.bg,
          child: AppLockGate(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}

/// Shown instead of the app when a build setting is missing.
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppLocalizations.of(context).envErrorTitle, style: context.text.headline),
                  const SizedBox(height: AppSpacing.s2),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
