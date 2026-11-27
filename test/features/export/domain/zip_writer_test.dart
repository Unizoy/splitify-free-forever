// TC-D34D-01 (D-034 WP-D): the in-house ZIP writer of "Download my data".
import 'dart:convert';

import 'package:glados/glados.dart';
import 'package:splitify/features/export/domain/zip_writer.dart';

import '../zip_reader.dart';

void main() {
  final when = DateTime(2026, 11, 27, 21, 30, 15);

  group('crc32', () {
    // TC-D34D-01
    test('matches the standard check values', () {
      expect(crc32(const []), 0);
      expect(crc32(ascii.encode('123456789')), 0xCBF43926);
      expect(crc32(ascii.encode('The quick brown fox jumps over the lazy dog')), 0x414FA339);
    });
  });

  group('dosDateTime', () {
    // TC-D34D-01
    test('packs local time in 2-second steps; before 1980 is 1 Jan 1980', () {
      final (time, date) = dosDateTime(when);
      expect(time, (21 << 11) | (30 << 5) | 7);
      expect(date, (46 << 9) | (11 << 5) | 27);
      expect(dosDateTime(DateTime(1970)), (0, (0 << 9) | (1 << 5) | 1));
    });
  });

  group('buildZip', () {
    // TC-D34D-01
    test('reads back: names, bytes, order, UTF-8 flag, date', () {
      final big = 'Dinner, cab, rent; ' * 400;
      final zip = buildZip([
        ZipEntry.text('splitify-backup.json', '{"a":1}'),
        ZipEntry.text('csv/goa-trip.csv', big),
        ZipEntry.text('csv/चाय.csv', 'chai ₹20'),
        const ZipEntry('empty.txt', []),
      ], modified: when);
      final read = readZip(zip);
      expect(read.map((e) => e.name), [
        'splitify-backup.json',
        'csv/goa-trip.csv',
        'csv/चाय.csv',
        'empty.txt',
      ]);
      expect(utf8.decode(read[1].bytes), big);
      expect(read[1].method, 8, reason: 'repetitive text is deflated');
      expect(read[0].method, 0, reason: 'a tiny file would grow, so it is stored');
      expect(read[3].bytes, isEmpty);
      expect(utf8.decode(read[2].bytes), 'chai ₹20');
      for (final e in read) {
        expect(e.flags & 0x0800, 0x0800);
        expect((e.time, e.date), dosDateTime(when));
      }
      expect(zip.length, lessThan(big.length ~/ 4), reason: 'deflate works');
    });

    // TC-D34D-01
    test('an empty archive is just the end record', () {
      final zip = buildZip(const [], modified: when);
      expect(zip.length, 22);
      expect(readZip(zip), isEmpty);
    });

    // TC-D34D-01
    test('refuses empty, absolute, parent and repeated paths', () {
      for (final bad in ['', '/etc/x', '../x', 'a/../b']) {
        expect(
          () => buildZip([ZipEntry.text(bad, 'x')], modified: when),
          throwsArgumentError,
          reason: bad,
        );
      }
      expect(
        () => buildZip([ZipEntry.text('a', '1'), ZipEntry.text('a', '2')], modified: when),
        throwsArgumentError,
      );
    });
  });

  // TC-D34D-01: any bytes survive the trip.
  Glados(any.list(any.intInRange(0, 256))).test('any bytes read back unchanged', (bytes) {
    final zip = buildZip([ZipEntry('x.bin', bytes)], modified: when);
    expect(readZip(zip).single.bytes, bytes);
  });
}
