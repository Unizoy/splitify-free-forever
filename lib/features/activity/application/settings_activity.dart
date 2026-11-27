/// Feed types for `settings_changed` rows (phase 11, 0014 puts the setting and its new value in the data):
/// `settings_simplify_on` / `settings_simplify_off` / `settings_default_split`; other types unchanged.
/// `import_completed` rows (0021, phase 18) become `import_undone` ("Delete this import") or
/// `import_completed_file` (a Splitify export).
String refineActivityType(String type, Map<String, Object?> data) {
  // D-034 C4: the trip-end nudge has its own sentence.
  if (type == 'settle_nudge') return data['reason'] == 'trip_end' ? 'settle_nudge_trip_end' : type;
  if (type == 'import_completed') {
    if (data['undone'] == true) return 'import_undone';
    return data['source'] == 'splitify' ? 'import_completed_file' : type;
  }
  if (type != 'settings_changed') return type;
  return switch (data['setting']) {
    'simplify_debts' => simplifyActivityType(on: data['simplify_debts'] == true),
    'default_split' => 'settings_default_split',
    // D-034 C4 (0026): settle-up reminders turned on (weekly / monthly) or off.
    'settle_reminder' => reminderActivityType(data['settle_reminder'] as String?),
    _ => type,
  };
}

/// The feed type of a settle-up reminder setting (also for my own unsynced change).
String reminderActivityType(String? value) => switch (value) {
  'weekly' => 'settings_reminder_weekly',
  'monthly' => 'settings_reminder_monthly',
  _ => 'settings_reminder_off',
};

/// The feed type of turning simplify debts on or off (also for my own unsynced change).
String simplifyActivityType({required bool on}) =>
    on ? 'settings_simplify_on' : 'settings_simplify_off';
