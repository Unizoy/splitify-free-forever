import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:splitify/domain/rules/receipt_text_parser.dart';

/// What another app shared with Splitify (D-034 A7): text (a UPI app's "Paid ₹250 to Ramesh") and/or a
/// picture copied into the app's cache.
typedef SharedPayload = ({String? text, String? imagePath});

/// Takes the shared payload of [token] (once; null when it is gone, e.g. after the app was killed).
typedef ShareReader = Future<SharedPayload?> Function(String token);

const _channel = MethodChannel('splitify/share');

/// Platform glue (MainActivity.kt turns ACTION_SEND into `splitify://expense/new?share=<token>`). Proven on
/// the device (`integration_test/d034_a_test.dart`).
Future<SharedPayload?> takeShared(String token) async {
  final m = await _channel.invokeMapMethod<String, String>('take', token);
  if (m == null) return null;
  return (text: m['text'], imagePath: m['image']);
}

final shareReaderProvider = Provider<ShareReader>((ref) => takeShared);

/// Reads shared text like a receipt: "Paid ₹250 to Ramesh Kumar via Google Pay" → ₹250, "Ramesh Kumar".
ReceiptScan parseSharedText(String text, {required int exponent, DateTime? today}) =>
    parseReceipt(text.split(RegExp(r'[\r\n]+')), exponent: exponent, today: today);
