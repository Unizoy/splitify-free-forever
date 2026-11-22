/// Where a captured payment came from (X4): a UPI/bank app notification, a bank SMS shown by the SMS app, or the
/// UPI app's screen (smart capture).
enum CaptureSource {
  notification,
  sms,
  screen;

  static CaptureSource? fromWire(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return null;
  }
}

/// A payment the phone caught and the user has not added yet (phase 18b, S-224). Parsed fields only — the alert's
/// text is never kept. [amount] is in paise (rule 1) and always INR.
class PaymentCapture {
  const PaymentCapture({
    required this.id,
    required this.amount,
    required this.appPackage,
    required this.appName,
    required this.source,
    required this.capturedAt,
    this.currency = 'INR',
    this.payee,
    this.note,
    this.ref,
  });

  final String id;
  final int amount;
  final String currency;
  final String? payee;
  final String? note;
  final String? ref;
  final String appPackage;
  final String appName;
  final CaptureSource source;
  final DateTime capturedAt;

  @override
  bool operator ==(Object other) =>
      other is PaymentCapture &&
      other.id == id &&
      other.amount == amount &&
      other.currency == currency &&
      other.payee == payee &&
      other.note == note &&
      other.ref == ref &&
      other.appPackage == appPackage &&
      other.appName == appName &&
      other.source == source &&
      other.capturedAt == capturedAt;

  @override
  int get hashCode =>
      Object.hash(id, amount, currency, payee, note, ref, appPackage, appName, source, capturedAt);
}

/// The feature's switches (Account → Payment bubble). Everything is off until the user opts in (X4); when on,
/// notifications + bubble are the default sources.
class CaptureSettings {
  const CaptureSettings({
    this.enabled = false,
    this.notifications = true,
    this.smart = false,
    this.bubble = true,
    this.duringPayment = false,
    this.apps = const {},
    this.theme = 'system',
  });

  final bool enabled;
  final bool notifications;
  final bool smart;
  final bool bubble;
  final bool duringPayment;

  /// Per-app switches the user changed (package → on); the others follow [CaptureApp.defaultOn].
  final Map<String, bool> apps;

  /// The app's theme mode name, so the native bubble matches it.
  final String theme;

  bool appOn(CaptureApp app) => apps[app.package] ?? app.defaultOn;

  CaptureSettings copyWith({
    bool? enabled,
    bool? notifications,
    bool? smart,
    bool? bubble,
    bool? duringPayment,
    Map<String, bool>? apps,
    String? theme,
  }) => CaptureSettings(
    enabled: enabled ?? this.enabled,
    notifications: notifications ?? this.notifications,
    smart: smart ?? this.smart,
    bubble: bubble ?? this.bubble,
    duringPayment: duringPayment ?? this.duringPayment,
    apps: apps ?? this.apps,
    theme: theme ?? this.theme,
  );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'notifications': notifications,
    'smart': smart,
    'bubble': bubble,
    'during_payment': duringPayment,
    'apps': apps,
    'theme': theme,
  };

  static CaptureSettings fromJson(Map<Object?, Object?>? j) {
    if (j == null) return const CaptureSettings();
    final apps = j['apps'];
    return CaptureSettings(
      enabled: j['enabled'] == true,
      notifications: j['notifications'] != false,
      smart: j['smart'] == true,
      bubble: j['bubble'] != false,
      duringPayment: j['during_payment'] == true,
      apps: apps is Map
          ? {
              for (final e in apps.entries)
                if (e.key is String && e.value is bool) e.key as String: e.value as bool,
            }
          : const {},
      theme: j['theme'] is String ? j['theme']! as String : 'system',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CaptureSettings &&
      other.enabled == enabled &&
      other.notifications == notifications &&
      other.smart == smart &&
      other.bubble == bubble &&
      other.duringPayment == duringPayment &&
      other.theme == theme &&
      other.apps.length == apps.length &&
      other.apps.entries.every((e) => apps[e.key] == e.value);

  @override
  int get hashCode =>
      Object.hash(enabled, notifications, smart, bubble, duringPayment, theme, apps.length);
}

/// One allow-listed app from the recipes (for the per-app switches).
class CaptureApp {
  const CaptureApp({
    required this.package,
    required this.name,
    required this.kind,
    this.defaultOn = true,
    this.installed = false,
  });

  final String package;
  final String name;

  /// `upi`, `sms` or `bank`.
  final String kind;
  final bool defaultOn;
  final bool installed;
}

/// Which Android access a source needs.
enum CaptureAccess { notifications, overlay, accessibility, postNotifications }

/// Live permission state of each access (read again on every resume).
class CapturePermissions {
  const CapturePermissions({
    this.notifications = false,
    this.overlay = false,
    this.accessibility = false,
    this.postNotifications = false,
    this.supported = false,
    this.sdk = 0,
    this.listening = false,
    this.smartConnected = false,
  });

  final bool notifications;
  final bool overlay;
  final bool accessibility;
  final bool postNotifications;

  /// False when the platform has no capture services (not Android, tests).
  final bool supported;
  final int sdk;

  /// Android has actually bound the listener / the accessibility service (not just allowed them).
  final bool listening;
  final bool smartConnected;

  bool granted(CaptureAccess a) => switch (a) {
    CaptureAccess.notifications => notifications,
    CaptureAccess.overlay => overlay,
    CaptureAccess.accessibility => accessibility,
    CaptureAccess.postNotifications => postNotifications,
  };
}
