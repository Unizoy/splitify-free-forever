/// A small ZIP writer for "Download my data" (D-034 WP-D, S-360): no package (the APK stays as it is),
/// deflate from `dart:io`'s raw [ZLibCodec], CRC-32, UTF-8 names, one disk, no ZIP64 (the backup of
/// a phone's groups is far below 4 GB). Entries that would not shrink are stored as they are.
library;

import 'dart:convert';
import 'dart:io' show ZLibCodec;
import 'dart:typed_data';

/// One file in the archive: a `/`-separated [path] and its bytes.
final class ZipEntry {
  const ZipEntry(this.path, this.bytes);

  /// Text file encoded as UTF-8.
  ZipEntry.text(String path, String text) : this(path, utf8.encode(text));

  final String path;
  final List<int> bytes;
}

/// `.zip` bytes holding [entries] in the given order, each dated [modified] (local time, 2-second
/// steps as ZIP stores it; before 1980 becomes 1 Jan 1980).
Uint8List buildZip(List<ZipEntry> entries, {required DateTime modified}) {
  final (time, date) = dosDateTime(modified);
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  final seen = <String>{};
  for (final e in entries) {
    if (e.path.isEmpty || e.path.startsWith('/') || e.path.contains('..') || !seen.add(e.path)) {
      throw ArgumentError.value(e.path, 'path', 'empty, absolute, ".." or repeated');
    }
    final name = utf8.encode(e.path);
    final crc = crc32(e.bytes);
    final packed = ZLibCodec(raw: true, level: 6).encode(e.bytes);
    final deflate = packed.length < e.bytes.length;
    final data = deflate ? packed : e.bytes;
    final offset = out.length;
    final header = _Le()
      ..u32(0x04034b50)
      ..u16(20)
      ..u16(_utf8Flag)
      ..u16(deflate ? 8 : 0)
      ..u16(time)
      ..u16(date)
      ..u32(crc)
      ..u32(data.length)
      ..u32(e.bytes.length)
      ..u16(name.length)
      ..u16(0);
    out
      ..add(header.bytes)
      ..add(name)
      ..add(data);
    final entry = _Le()
      ..u32(0x02014b50)
      ..u16(20)
      ..u16(20)
      ..u16(_utf8Flag)
      ..u16(deflate ? 8 : 0)
      ..u16(time)
      ..u16(date)
      ..u32(crc)
      ..u32(data.length)
      ..u32(e.bytes.length)
      ..u16(name.length)
      ..u16(0)
      ..u16(0)
      ..u16(0)
      ..u16(0)
      ..u32(0)
      ..u32(offset);
    central
      ..add(entry.bytes)
      ..add(name);
  }
  final centralOffset = out.length;
  final centralBytes = central.takeBytes();
  final end = _Le()
    ..u32(0x06054b50)
    ..u16(0)
    ..u16(0)
    ..u16(entries.length)
    ..u16(entries.length)
    ..u32(centralBytes.length)
    ..u32(centralOffset)
    ..u16(0);
  out
    ..add(centralBytes)
    ..add(end.bytes);
  return out.takeBytes();
}

/// General purpose flag bit 11: names are UTF-8.
const _utf8Flag = 0x0800;

/// MS-DOS (time, date) words of [t] as ZIP stores them.
(int, int) dosDateTime(DateTime t) {
  final d = t.year < 1980 ? DateTime(1980) : t;
  final time = (d.hour << 11) | (d.minute << 5) | (d.second ~/ 2);
  final date = ((d.year - 1980) << 9) | (d.month << 5) | d.day;
  return (time, date);
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
}, growable: false);

/// CRC-32 (ISO-HDLC, as ZIP and PNG use it) of [bytes].
int crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
}

/// Little-endian field builder.
final class _Le {
  final _b = BytesBuilder();

  void u16(int v) => _b.add([v & 0xFF, (v >> 8) & 0xFF]);

  void u32(int v) => _b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  Uint8List get bytes => _b.takeBytes();
}
