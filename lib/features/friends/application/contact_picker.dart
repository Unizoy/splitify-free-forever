import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "From contacts" (W2-X F15): the system contact picker (`ACTION_PICK`, `ContactsBridge.kt` channel
/// `splitify/contacts`). No contacts permission: Android lets the app read only the one contact the person
/// picked, and only its name is taken (no number, nothing stored).
abstract interface class ContactPicker {
  /// The picked contact's name; null when the person backed out, the contact has no name, or the picker
  /// could not open (see [ContactPickFailed]).
  Future<String?> pickName();
}

/// The picker could not open on this phone (no contacts app).
class ContactPickFailed implements Exception {
  const ContactPickFailed();
}

class ChannelContactPicker implements ContactPicker {
  const ChannelContactPicker();

  static const _channel = MethodChannel('splitify/contacts');

  @override
  Future<String?> pickName() async {
    try {
      final name = await _channel.invokeMethod<String>('pickName');
      final t = name?.trim() ?? '';
      return t.isEmpty ? null : cleanContactName(t);
    } on MissingPluginException {
      throw const ContactPickFailed();
    } on PlatformException {
      throw const ContactPickFailed();
    }
  }
}

/// A contact's display name as a member name: spaces folded, at most 50 characters (the member name limit).
String cleanContactName(String raw) {
  final folded = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = folded.runes.toList();
  return runes.length <= 50 ? folded : String.fromCharCodes(runes.take(50)).trim();
}

/// Tests replace it with a fake.
final contactPickerProvider = Provider<ContactPicker>((ref) => const ChannelContactPicker());
