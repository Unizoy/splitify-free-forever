// Phase 15 (rule 9): deleting the account is online-only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/sync/network_status.dart';
import 'package:splitify/features/account/presentation/delete_account_screen.dart';
import 'package:splitify/features/auth/application/auth_providers.dart';
import 'package:splitify/l10n/app_localizations.dart';
import 'package:splitify/ui/theme/theme.dart';

import '../../../support/fakes.dart';

class _Offline implements NetworkStatus {
  @override
  Stream<bool> watch() => Stream.value(false);

  @override
  Future<bool> isOnline() async => false;
}

void main() {
  // TC-OFF-DELETE: offline delete shows "Needs internet" and never reaches the server.
  testWidgets('offline: Delete my account shows the needs-internet text', (tester) async {
    final auth = FakeAuthRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          networkStatusProvider.overrideWithValue(_Offline()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          home: const DeleteAccountScreen(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete my account'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Needs internet. Connect and try again.'), findsOneWidget);
    expect(auth.calls, isNot(contains('delete')));
  });
}
