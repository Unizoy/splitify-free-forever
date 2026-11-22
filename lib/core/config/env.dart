/// Thrown when a required build-time setting is missing.
class EnvException implements Exception {
  const EnvException(this.missingKeys);

  final List<String> missingKeys;

  String get message =>
      'Missing build settings: ${missingKeys.join(', ')}. '
      'Run with --dart-define-from-file=secrets/env.dev.json '
      '(copy secrets/env.example.json first).';

  @override
  String toString() => 'EnvException: $message';
}

/// Build-time configuration, read from `--dart-define-from-file`.
class Env {
  const Env._({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.googleWebClientId,
    required this.devLogin,
    required this.e2ePassword,
    required this.emailOtpLength,
  });

  /// Reads the compiled-in values and fails fast when one is missing.
  factory Env.load() => Env.fromValues(
    supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
    googleWebClientId: const String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
    devLogin: const String.fromEnvironment('DEV_LOGIN'),
    e2ePassword: const String.fromEnvironment('E2E_PASSWORD'),
    emailOtpLength: const String.fromEnvironment('EMAIL_OTP_LENGTH'),
  );

  /// Validates raw values (also used by tests).
  factory Env.fromValues({
    required String supabaseUrl,
    required String supabasePublishableKey,
    required String googleWebClientId,
    required String devLogin,
    required String e2ePassword,
    String emailOtpLength = '',
  }) {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];
    if (missing.isNotEmpty) throw EnvException(missing);
    return Env._(
      supabaseUrl: supabaseUrl,
      supabasePublishableKey: supabasePublishableKey,
      googleWebClientId: googleWebClientId,
      devLogin: devLogin == 'true',
      e2ePassword: e2ePassword,
      emailOtpLength: parseOtpLength(emailOtpLength),
    );
  }

  /// Supabase's default "Email OTP Length" (dashboard: Auth → Providers → Email).
  static const defaultEmailOtpLength = 6;

  /// `EMAIL_OTP_LENGTH` must match the project's "Email OTP Length" (Supabase allows 6 to 10); anything else
  /// (missing, not a number, out of range) means the default 6 (S-232).
  static int parseOtpLength(String raw) {
    final n = int.tryParse(raw.trim());
    return n != null && n >= 6 && n <= 10 ? n : defaultEmailOtpLength;
  }

  /// Digits in the email sign-in code: the code screen shows this many boxes.
  final int emailOtpLength;

  final String supabaseUrl;
  final String supabasePublishableKey;

  /// Google OAuth web client id; empty or a template placeholder means Google
  /// sign-in is not set up yet (D-020: the button shows "Coming soon").
  final String googleWebClientId;

  /// True when a real Google web client id was compiled in.
  bool get hasGoogle => isConfiguredValue(googleWebClientId);

  /// True when [devLogin] is on and this is not a release build (TC-B1-08).
  bool devLoginAvailable({required bool releaseMode}) => devLogin && !releaseMode;

  /// True only in dev builds (password login for tests).
  final bool devLogin;

  /// Tests only.
  final String e2ePassword;
}

/// False for empty values and the `your-...` placeholders of `secrets/env.example.json`.
bool isConfiguredValue(String value) => value.isNotEmpty && !value.contains('your-');
