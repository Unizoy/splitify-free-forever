import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/features/currency/application/currency_providers.dart';

/// Keeps the exchange-rate cache refreshing after syncs while the signed-in shell is shown (05 §6).
class FxRatesKeeper extends ConsumerWidget {
  const FxRatesKeeper({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(fxAutoRefreshProvider);
    return child;
  }
}
