// A strict little ZIP reader for the backup tests (D-034 WP-D): walks the central directory, checks
// every local header against it, inflates (raw deflate) or copies, and checks sizes and CRC-32.
import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

import 'package:splitify/features/export/domain/zip_writer.dart' show crc32;

/// One entry as read back.
typedef ZipRead = ({String name, List<int> bytes, int method, int flags, int time, int date});

int _u16(Uint8List b, int o) => b[o] | (b[o + 1] << 8);
int _u32(Uint8List b, int o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24);

/// Every entry of [zip] in central-directory order; throws [StateError] on anything malformed.
List<ZipRead> readZip(Uint8List zip) {
  final eocd = zip.length - 22;
  if (eocd < 0 || _u32(zip, eocd) != 0x06054b50) throw StateError('no end record');
  final count = _u16(zip, eocd + 10);
  if (_u16(zip, eocd + 8) != count) throw StateError('disk counts differ');
  final size = _u32(zip, eocd + 12);
  var at = _u32(zip, eocd + 16);
  if (at + size != eocd) throw StateError('central directory does not end at the end record');
  final out = <ZipRead>[];
  for (var i = 0; i < count; i++) {
    if (_u32(zip, at) != 0x02014b50) throw StateError('bad central header $i');
    final flags = _u16(zip, at + 8);
    final method = _u16(zip, at + 10);
    final time = _u16(zip, at + 12);
    final date = _u16(zip, at + 14);
    final crc = _u32(zip, at + 16);
    final packed = _u32(zip, at + 20);
    final plain = _u32(zip, at + 24);
    final nameLen = _u16(zip, at + 28);
    final extra = _u16(zip, at + 30);
    final comment = _u16(zip, at + 32);
    final local = _u32(zip, at + 42);
    final name = utf8.decode(zip.sublist(at + 46, at + 46 + nameLen));
    at += 46 + nameLen + extra + comment;

    if (_u32(zip, local) != 0x04034b50) throw StateError('bad local header for $name');
    if (_u16(zip, local + 6) != flags || _u16(zip, local + 8) != method) {
      throw StateError('local header differs for $name');
    }
    if (_u32(zip, local + 14) != crc || _u32(zip, local + 18) != packed) {
      throw StateError('local sizes differ for $name');
    }
    final localName = _u16(zip, local + 26);
    final localExtra = _u16(zip, local + 28);
    final start = local + 30 + localName + localExtra;
    final data = zip.sublist(start, start + packed);
    final bytes = switch (method) {
      0 => data,
      8 => ZLibCodec(raw: true).decode(data),
      _ => throw StateError('method $method'),
    };
    if (bytes.length != plain) throw StateError('size of $name');
    if (crc32(bytes) != crc) throw StateError('crc of $name');
    out.add((name: name, bytes: bytes, method: method, flags: flags, time: time, date: date));
  }
  return out;
}

/// Entry texts by name (UTF-8).
Map<String, String> zipTexts(Uint8List zip) => {
  for (final e in readZip(zip)) e.name: utf8.decode(e.bytes),
};
