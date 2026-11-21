import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:splitify/core/upi/upi_link.dart';
import 'package:splitify/features/friends/application/friends_providers.dart';
import 'package:splitify/features/payments/application/settle_controller.dart';
import 'package:url_launcher/url_launcher.dart';

final _log = Logger('upi');

/// Opens a `upi://pay` link in the payer's UPI app (Android shows its chooser when several apps can).
/// Returns false when no app takes it; never says whether the payment went through (rule 13).
abstract class UpiLauncher {
  Future<bool> launch(String uri);
}

/// [UpiLauncher] over `url_launcher` (the manifest `<queries>` lists scheme `upi`, research 06 §1).
class SystemUpiLauncher implements UpiLauncher {
  const SystemUpiLauncher();

  @override
  Future<bool> launch(String uri) async {
    try {
      return await launchUrl(Uri.parse(uri), mode: LaunchMode.externalNonBrowserApplication);
    } on PlatformException catch (e) {
      _log.info('no UPI app took the link (${e.code})');
      return false;
    }
  }
}

final upiLauncherProvider = Provider<UpiLauncher>((ref) => const SystemUpiLauncher());

/// The UPI ID of an account from its profile on this phone (normalised), or null when it has none or it
/// is not valid. Name-only members have no account, so no UPI ID (#26).
final upiIdProvider = StreamProvider.autoDispose.family<String?, String>(
  (ref, userId) => ref
      .watch(friendsRepositoryProvider)
      .watchProfile(userId)
      .map((p) => p?.upiId == null ? null : UpiLinkBuilder.normalizeVpa(p!.upiId!)),
);

/// "Pay via UPI" is offered only when I pay, in rupees, to someone with a UPI ID (#26, rule 13), for a new
/// payment with a valid amount.
bool canPayByUpi(SettleDraft d, String? vpa) =>
    vpa != null &&
    d.currency == UpiLinkBuilder.currency &&
    !d.isEdit &&
    d.meId != null &&
    d.from == d.meId &&
    d.to != d.meId;

/// The link for [d] (null while the amount is not valid). [note] is the `tn` text.
UpiLink? upiLinkFor(
  SettleDraft d, {
  required String vpa,
  required String name,
  required String note,
}) {
  final amount = d.amount;
  if (amount == null) return null;
  try {
    return const UpiLinkBuilder().build(
      vpa: vpa,
      name: name,
      amountMinor: amount,
      currencyCode: d.currency,
      note: note,
    );
  } on UpiLinkError {
    return null;
  }
}
