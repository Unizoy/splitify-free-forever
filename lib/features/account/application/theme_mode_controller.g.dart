// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Light / Dark / System choice (B3), stored on the phone. System by default.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Light / Dark / System choice (B3), stored on the phone. System by default.
final class ThemeModeControllerProvider extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// Light / Dark / System choice (B3), stored on the phone. System by default.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ThemeMode>(value));
  }
}

String _$themeModeControllerHash() => r'a551fd3535df2227ebf5bc2025d66b0b238944b3';

/// Light / Dark / System choice (B3), stored on the phone. System by default.

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
