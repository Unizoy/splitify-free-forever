/// Feed types for `settings_changed` rows (phase 11, 0014 puts the setting and its new value in the data):
/// `settings_simplify_on` / `settings_simplify_off` / `settings_default_split`; other types unchanged.
String refineActivityType(String type, Map<String, Object?> data) {
  if (type != 'settings_changed') return type;
  return switch (data['setting']) {
    'simplify_debts' => simplifyActivityType(on: data['simplify_debts'] == true),
    'default_split' => 'settings_default_split',
    _ => type,
  };
}

/// The feed type of turning simplify debts on or off (also for my own unsynced change).
String simplifyActivityType({required bool on}) =>
    on ? 'settings_simplify_on' : 'settings_simplify_off';
