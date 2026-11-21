import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New client-generated id (UUID v7, time-ordered).
String newId() => _uuid.v7();
