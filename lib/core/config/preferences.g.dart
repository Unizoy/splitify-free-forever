// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preferences.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Local key-value settings (theme mode, small UI choices). Loaded once in
/// bootstrap before `runApp` and injected with an override.

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

/// Local key-value settings (theme mode, small UI choices). Loaded once in
/// bootstrap before `runApp` and injected with an override.

final class SharedPreferencesProvider
    extends $FunctionalProvider<SharedPreferences, SharedPreferences, SharedPreferences>
    with $Provider<SharedPreferences> {
  /// Local key-value settings (theme mode, small UI choices). Loaded once in
  /// bootstrap before `runApp` and injected with an override.
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $ProviderElement<SharedPreferences> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SharedPreferences create(Ref ref) {
    return sharedPreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SharedPreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SharedPreferences>(value),
    );
  }
}

String _$sharedPreferencesHash() => r'4eded8c0cab442bd3072f812a31231b714a65946';
