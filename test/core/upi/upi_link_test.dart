// UPI link builder vectors (CLAUDE.md rule 13, planning/08-feature-specs.md #26).
//
// TC-26-01  link builder encoding/rounding (every vector in upi_vectors.json)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/core/upi/upi_link.dart';

const _fixture = 'test/fixtures/upi_vectors.json';

typedef _Json = Map<String, dynamic>;

const _builder = UpiLinkBuilder();

_Json _evaluate(_Json input) {
  try {
    final link = _builder.build(
      vpa: input['vpa'] as String,
      name: input['name'] as String,
      amountMinor: input['amount_minor'] as int,
      currencyCode: input['currency'] as String,
      note: input['note'] as String,
    );
    return {
      'uri': link.uri,
      'vpa': link.vpa,
      'name': link.name,
      'amount': link.amount,
      'note': link.note,
    };
  } on UpiLinkError catch (e) {
    return {'error': e.code};
  }
}

void main() {
  final doc = jsonDecode(File(_fixture).readAsStringSync()) as _Json;
  final vectors = (doc['vectors'] as List).cast<_Json>();

  group('upi vectors', () {
    test('fixture covers every error code', () {
      final errors = {for (final v in vectors) (v['expect'] as _Json)['error']}..remove(null);
      expect(errors, {
        'UPI_CURRENCY_NOT_INR',
        'AMOUNT_NOT_POSITIVE',
        'AMOUNT_TOO_LARGE',
        'UPI_INVALID_VPA',
      });
    });

    for (final vector in vectors) {
      test('${vector['id']} matches the vector', () {
        expect(_evaluate(vector['input'] as _Json), vector['expect']);
      });
    }

    test('every built link parses back to its cleaned parts', () {
      for (final vector in vectors) {
        final expected = vector['expect'] as _Json;
        if (expected.containsKey('error')) continue;
        final uri = Uri.parse(expected['uri'] as String);
        expect(uri.scheme, 'upi', reason: vector['id'] as String);
        expect(uri.host, 'pay');
        final params = uri.queryParameters;
        expect(params['pa'], expected['vpa']);
        expect(params['pn'], expected['name']);
        expect(params['am'], expected['amount']);
        expect(params['cu'], 'INR');
        final note = expected['note'] as String;
        expect(params['tn'], note.isEmpty ? isNull : note);
        expect(note.length, lessThanOrEqualTo(UpiLinkBuilder.noteMaxLength));
      }
    });
  });

  group('UpiLinkBuilder', () {
    test('toString of a link is its URI', () {
      final link = _builder.build(
        vpa: 'rahul@okicici',
        name: 'Rahul',
        amountMinor: 100,
        currencyCode: 'INR',
      );
      expect(link.toString(), 'upi://pay?pa=rahul@okicici&pn=Rahul&am=1.00&cu=INR');
      expect(link.note, isEmpty);
    });

    test('normalizeVpa trims, lower-cases the handle and rejects bad IDs', () {
      expect(UpiLinkBuilder.normalizeVpa(' Rahul@OKICICI '), 'Rahul@okicici');
      expect(UpiLinkBuilder.normalizeVpa('rahul@'), isNull);
    });

    test('encode keeps unreserved characters and encodes UTF-8 bytes', () {
      expect(UpiLinkBuilder.encode('aZ09-._~'), 'aZ09-._~');
      expect(UpiLinkBuilder.encode(' +&'), '%20%2B%26');
      expect(UpiLinkBuilder.encode('₹'), '%E2%82%B9');
    });

    test('cleanText drops non-ASCII and collapses whitespace', () {
      expect(UpiLinkBuilder.cleanText('  Goa\t🏖️  trip\n'), 'Goa trip');
    });
  });

  group('UpiLinkError', () {
    test('codes, data and toString are stable', () {
      expect(const UpiCurrencyNotInr('USD').data, {'currency': 'USD'});
      expect(
        const UpiCurrencyNotInr('USD').toString(),
        'UpiLinkError(UPI_CURRENCY_NOT_INR, {currency: USD})',
      );
      expect(const UpiInvalidVpa().data, isEmpty);
      expect(const UpiInvalidVpa().toString(), 'UpiLinkError(UPI_INVALID_VPA)');
      expect(const UpiAmountNotPositive().code, 'AMOUNT_NOT_POSITIVE');
      expect(const UpiAmountTooLarge().code, 'AMOUNT_TOO_LARGE');
    });
  });
}
