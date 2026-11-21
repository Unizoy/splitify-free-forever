import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/data/data_providers.dart';
import 'package:splitify/data/remote/fx_rates_remote.dart';
import 'package:splitify/data/repositories/fx_rates_repository.dart';
import 'package:splitify/features/currency/domain/fx_service.dart';

/// Server exchange rates (phase 14). Bootstrap overrides it with `RemoteServices.fxRates`; without settings
/// and in widget tests every call fails like being offline.
final fxRatesRemoteProvider = Provider<FxRatesRemote>((ref) => const UnconfiguredFxRatesRemote());

/// The phone's exchange-rate cache (offline conversions, 05 §6).
final fxRatesRepositoryProvider = Provider<FxRatesRepository>(
  (ref) => FxRatesRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(fxRatesRemoteProvider),
    ref.watch(clockProvider),
  ),
);

/// Rate lookup over the cache (S-093..S-095).
final fxServiceProvider = Provider<FxService>(
  (ref) => FxService(ref.watch(fxRatesRepositoryProvider)),
);
