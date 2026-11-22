// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Profiles extends Table with TableInfo<Profiles, LocalProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Profiles(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _avatarPathMeta = const VerificationMeta('avatarPath');
  late final GeneratedColumn<String> avatarPath = GeneratedColumn<String>(
    'avatar_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _upiIdMeta = const VerificationMeta('upiId');
  late final GeneratedColumn<String> upiId = GeneratedColumn<String>(
    'upi_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _defaultCurrencyMeta = const VerificationMeta('defaultCurrency');
  late final GeneratedColumn<String> defaultCurrency = GeneratedColumn<String>(
    'default_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'INR\'',
    defaultValue: const CustomExpression('\'INR\''),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    avatarPath,
    upiId,
    defaultCurrency,
    updatedAt,
    deletedAt,
    seq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('avatar_path')) {
      context.handle(
        _avatarPathMeta,
        avatarPath.isAcceptableOrUnknown(data['avatar_path']!, _avatarPathMeta),
      );
    }
    if (data.containsKey('upi_id')) {
      context.handle(_upiIdMeta, upiId.isAcceptableOrUnknown(data['upi_id']!, _upiIdMeta));
    }
    if (data.containsKey('default_currency')) {
      context.handle(
        _defaultCurrencyMeta,
        defaultCurrency.isAcceptableOrUnknown(data['default_currency']!, _defaultCurrencyMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalProfile(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      avatarPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}avatar_path'],
      ),
      upiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upi_id'],
      ),
      defaultCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_currency'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  Profiles createAlias(String alias) {
    return Profiles(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalProfile extends DataClass implements Insertable<LocalProfile> {
  final String id;
  final String displayName;
  final String? avatarPath;
  final String? upiId;
  final String defaultCurrency;
  final String? updatedAt;
  final String? deletedAt;
  final int seq;
  const LocalProfile({
    required this.id,
    required this.displayName,
    this.avatarPath,
    this.upiId,
    required this.defaultCurrency,
    this.updatedAt,
    this.deletedAt,
    required this.seq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || avatarPath != null) {
      map['avatar_path'] = Variable<String>(avatarPath);
    }
    if (!nullToAbsent || upiId != null) {
      map['upi_id'] = Variable<String>(upiId);
    }
    map['default_currency'] = Variable<String>(defaultCurrency);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    map['seq'] = Variable<int>(seq);
    return map;
  }

  ProfilesCompanion toCompanion(bool nullToAbsent) {
    return ProfilesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      avatarPath: avatarPath == null && nullToAbsent ? const Value.absent() : Value(avatarPath),
      upiId: upiId == null && nullToAbsent ? const Value.absent() : Value(upiId),
      defaultCurrency: Value(defaultCurrency),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      seq: Value(seq),
    );
  }

  factory LocalProfile.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalProfile(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['display_name']),
      avatarPath: serializer.fromJson<String?>(json['avatar_path']),
      upiId: serializer.fromJson<String?>(json['upi_id']),
      defaultCurrency: serializer.fromJson<String>(json['default_currency']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'display_name': serializer.toJson<String>(displayName),
      'avatar_path': serializer.toJson<String?>(avatarPath),
      'upi_id': serializer.toJson<String?>(upiId),
      'default_currency': serializer.toJson<String>(defaultCurrency),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'seq': serializer.toJson<int>(seq),
    };
  }

  LocalProfile copyWith({
    String? id,
    String? displayName,
    Value<String?> avatarPath = const Value.absent(),
    Value<String?> upiId = const Value.absent(),
    String? defaultCurrency,
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    int? seq,
  }) => LocalProfile(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    avatarPath: avatarPath.present ? avatarPath.value : this.avatarPath,
    upiId: upiId.present ? upiId.value : this.upiId,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    seq: seq ?? this.seq,
  );
  LocalProfile copyWithCompanion(ProfilesCompanion data) {
    return LocalProfile(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      avatarPath: data.avatarPath.present ? data.avatarPath.value : this.avatarPath,
      upiId: data.upiId.present ? data.upiId.value : this.upiId,
      defaultCurrency: data.defaultCurrency.present
          ? data.defaultCurrency.value
          : this.defaultCurrency,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalProfile(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('upiId: $upiId, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, displayName, avatarPath, upiId, defaultCurrency, updatedAt, deletedAt, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalProfile &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.avatarPath == this.avatarPath &&
          other.upiId == this.upiId &&
          other.defaultCurrency == this.defaultCurrency &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.seq == this.seq);
}

class ProfilesCompanion extends UpdateCompanion<LocalProfile> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String?> avatarPath;
  final Value<String?> upiId;
  final Value<String> defaultCurrency;
  final Value<String?> updatedAt;
  final Value<String?> deletedAt;
  final Value<int> seq;
  final Value<int> rowid;
  const ProfilesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.avatarPath = const Value.absent(),
    this.upiId = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProfilesCompanion.insert({
    required String id,
    required String displayName,
    this.avatarPath = const Value.absent(),
    this.upiId = const Value.absent(),
    this.defaultCurrency = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName);
  static Insertable<LocalProfile> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? avatarPath,
    Expression<String>? upiId,
    Expression<String>? defaultCurrency,
    Expression<String>? updatedAt,
    Expression<String>? deletedAt,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (avatarPath != null) 'avatar_path': avatarPath,
      if (upiId != null) 'upi_id': upiId,
      if (defaultCurrency != null) 'default_currency': defaultCurrency,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String?>? avatarPath,
    Value<String?>? upiId,
    Value<String>? defaultCurrency,
    Value<String?>? updatedAt,
    Value<String?>? deletedAt,
    Value<int>? seq,
    Value<int>? rowid,
  }) {
    return ProfilesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarPath: avatarPath ?? this.avatarPath,
      upiId: upiId ?? this.upiId,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (avatarPath.present) {
      map['avatar_path'] = Variable<String>(avatarPath.value);
    }
    if (upiId.present) {
      map['upi_id'] = Variable<String>(upiId.value);
    }
    if (defaultCurrency.present) {
      map['default_currency'] = Variable<String>(defaultCurrency.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProfilesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('avatarPath: $avatarPath, ')
          ..write('upiId: $upiId, ')
          ..write('defaultCurrency: $defaultCurrency, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Groups extends Table with TableInfo<Groups, LocalGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Groups(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'other\'',
    defaultValue: const CustomExpression('\'other\''),
  );
  static const VerificationMeta _mainCurrencyMeta = const VerificationMeta('mainCurrency');
  late final GeneratedColumn<String> mainCurrency = GeneratedColumn<String>(
    'main_currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'INR\'',
    defaultValue: const CustomExpression('\'INR\''),
  );
  static const VerificationMeta _coverKindMeta = const VerificationMeta('coverKind');
  late final GeneratedColumn<String> coverKind = GeneratedColumn<String>(
    'cover_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'generated\'',
    defaultValue: const CustomExpression('\'generated\''),
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta('coverPath');
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _simplifyDebtsMeta = const VerificationMeta('simplifyDebts');
  late final GeneratedColumn<bool> simplifyDebts = GeneratedColumn<bool>(
    'simplify_debts',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT FALSE',
    defaultValue: const CustomExpression('FALSE'),
  );
  static const VerificationMeta _defaultSplitMeta = const VerificationMeta('defaultSplit');
  late final GeneratedColumn<String> defaultSplit = GeneratedColumn<String>(
    'default_split',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _inviteCodeMeta = const VerificationMeta('inviteCode');
  late final GeneratedColumn<String> inviteCode = GeneratedColumn<String>(
    'invite_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta('archivedAt');
  late final GeneratedColumn<String> archivedAt = GeneratedColumn<String>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _directKeyMeta = const VerificationMeta('directKey');
  late final GeneratedColumn<String> directKey = GeneratedColumn<String>(
    'direct_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta('createdBy');
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta('updatedBy');
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta('deletedBy');
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta('syncState');
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\'',
    defaultValue: const CustomExpression('\'synced\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    mainCurrency,
    coverKind,
    coverPath,
    simplifyDebts,
    defaultSplit,
    inviteCode,
    archivedAt,
    directKey,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    }
    if (data.containsKey('main_currency')) {
      context.handle(
        _mainCurrencyMeta,
        mainCurrency.isAcceptableOrUnknown(data['main_currency']!, _mainCurrencyMeta),
      );
    }
    if (data.containsKey('cover_kind')) {
      context.handle(
        _coverKindMeta,
        coverKind.isAcceptableOrUnknown(data['cover_kind']!, _coverKindMeta),
      );
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('simplify_debts')) {
      context.handle(
        _simplifyDebtsMeta,
        simplifyDebts.isAcceptableOrUnknown(data['simplify_debts']!, _simplifyDebtsMeta),
      );
    }
    if (data.containsKey('default_split')) {
      context.handle(
        _defaultSplitMeta,
        defaultSplit.isAcceptableOrUnknown(data['default_split']!, _defaultSplitMeta),
      );
    }
    if (data.containsKey('invite_code')) {
      context.handle(
        _inviteCodeMeta,
        inviteCode.isAcceptableOrUnknown(data['invite_code']!, _inviteCodeMeta),
      );
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('direct_key')) {
      context.handle(
        _directKeyMeta,
        directKey.isAcceptableOrUnknown(data['direct_key']!, _directKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalGroup(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      type: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      mainCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_currency'],
      )!,
      coverKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_kind'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      simplifyDebts: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}simplify_debts'],
      )!,
      defaultSplit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_split'],
      ),
      inviteCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invite_code'],
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archived_at'],
      ),
      directKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direct_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  Groups createAlias(String alias) {
    return Groups(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalGroup extends DataClass implements Insertable<LocalGroup> {
  final String id;
  final String name;
  final String type;
  final String mainCurrency;
  final String coverKind;
  final String? coverPath;
  final bool simplifyDebts;
  final String? defaultSplit;
  final String? inviteCode;
  final String? archivedAt;
  final String? directKey;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? clientUpdatedAt;
  final String? deletedAt;
  final String? deletedBy;
  final int seq;
  final String syncState;
  const LocalGroup({
    required this.id,
    required this.name,
    required this.type,
    required this.mainCurrency,
    required this.coverKind,
    this.coverPath,
    required this.simplifyDebts,
    this.defaultSplit,
    this.inviteCode,
    this.archivedAt,
    this.directKey,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientUpdatedAt,
    this.deletedAt,
    this.deletedBy,
    required this.seq,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['main_currency'] = Variable<String>(mainCurrency);
    map['cover_kind'] = Variable<String>(coverKind);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['simplify_debts'] = Variable<bool>(simplifyDebts);
    if (!nullToAbsent || defaultSplit != null) {
      map['default_split'] = Variable<String>(defaultSplit);
    }
    if (!nullToAbsent || inviteCode != null) {
      map['invite_code'] = Variable<String>(inviteCode);
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<String>(archivedAt);
    }
    if (!nullToAbsent || directKey != null) {
      map['direct_key'] = Variable<String>(directKey);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['seq'] = Variable<int>(seq);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      mainCurrency: Value(mainCurrency),
      coverKind: Value(coverKind),
      coverPath: coverPath == null && nullToAbsent ? const Value.absent() : Value(coverPath),
      simplifyDebts: Value(simplifyDebts),
      defaultSplit: defaultSplit == null && nullToAbsent
          ? const Value.absent()
          : Value(defaultSplit),
      inviteCode: inviteCode == null && nullToAbsent ? const Value.absent() : Value(inviteCode),
      archivedAt: archivedAt == null && nullToAbsent ? const Value.absent() : Value(archivedAt),
      directKey: directKey == null && nullToAbsent ? const Value.absent() : Value(directKey),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      createdBy: createdBy == null && nullToAbsent ? const Value.absent() : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent ? const Value.absent() : Value(updatedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent ? const Value.absent() : Value(deletedBy),
      seq: Value(seq),
      syncState: Value(syncState),
    );
  }

  factory LocalGroup.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalGroup(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      mainCurrency: serializer.fromJson<String>(json['main_currency']),
      coverKind: serializer.fromJson<String>(json['cover_kind']),
      coverPath: serializer.fromJson<String?>(json['cover_path']),
      simplifyDebts: serializer.fromJson<bool>(json['simplify_debts']),
      defaultSplit: serializer.fromJson<String?>(json['default_split']),
      inviteCode: serializer.fromJson<String?>(json['invite_code']),
      archivedAt: serializer.fromJson<String?>(json['archived_at']),
      directKey: serializer.fromJson<String?>(json['direct_key']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      createdBy: serializer.fromJson<String?>(json['created_by']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      updatedBy: serializer.fromJson<String?>(json['updated_by']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      deletedBy: serializer.fromJson<String?>(json['deleted_by']),
      seq: serializer.fromJson<int>(json['seq']),
      syncState: serializer.fromJson<String>(json['sync_state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'main_currency': serializer.toJson<String>(mainCurrency),
      'cover_kind': serializer.toJson<String>(coverKind),
      'cover_path': serializer.toJson<String?>(coverPath),
      'simplify_debts': serializer.toJson<bool>(simplifyDebts),
      'default_split': serializer.toJson<String?>(defaultSplit),
      'invite_code': serializer.toJson<String?>(inviteCode),
      'archived_at': serializer.toJson<String?>(archivedAt),
      'direct_key': serializer.toJson<String?>(directKey),
      'created_at': serializer.toJson<String?>(createdAt),
      'created_by': serializer.toJson<String?>(createdBy),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'updated_by': serializer.toJson<String?>(updatedBy),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'deleted_by': serializer.toJson<String?>(deletedBy),
      'seq': serializer.toJson<int>(seq),
      'sync_state': serializer.toJson<String>(syncState),
    };
  }

  LocalGroup copyWith({
    String? id,
    String? name,
    String? type,
    String? mainCurrency,
    String? coverKind,
    Value<String?> coverPath = const Value.absent(),
    bool? simplifyDebts,
    Value<String?> defaultSplit = const Value.absent(),
    Value<String?> inviteCode = const Value.absent(),
    Value<String?> archivedAt = const Value.absent(),
    Value<String?> directKey = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> clientUpdatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    int? seq,
    String? syncState,
  }) => LocalGroup(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    mainCurrency: mainCurrency ?? this.mainCurrency,
    coverKind: coverKind ?? this.coverKind,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    simplifyDebts: simplifyDebts ?? this.simplifyDebts,
    defaultSplit: defaultSplit.present ? defaultSplit.value : this.defaultSplit,
    inviteCode: inviteCode.present ? inviteCode.value : this.inviteCode,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    directKey: directKey.present ? directKey.value : this.directKey,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    seq: seq ?? this.seq,
    syncState: syncState ?? this.syncState,
  );
  LocalGroup copyWithCompanion(GroupsCompanion data) {
    return LocalGroup(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      mainCurrency: data.mainCurrency.present ? data.mainCurrency.value : this.mainCurrency,
      coverKind: data.coverKind.present ? data.coverKind.value : this.coverKind,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      simplifyDebts: data.simplifyDebts.present ? data.simplifyDebts.value : this.simplifyDebts,
      defaultSplit: data.defaultSplit.present ? data.defaultSplit.value : this.defaultSplit,
      inviteCode: data.inviteCode.present ? data.inviteCode.value : this.inviteCode,
      archivedAt: data.archivedAt.present ? data.archivedAt.value : this.archivedAt,
      directKey: data.directKey.present ? data.directKey.value : this.directKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      seq: data.seq.present ? data.seq.value : this.seq,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalGroup(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('mainCurrency: $mainCurrency, ')
          ..write('coverKind: $coverKind, ')
          ..write('coverPath: $coverPath, ')
          ..write('simplifyDebts: $simplifyDebts, ')
          ..write('defaultSplit: $defaultSplit, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('directKey: $directKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    mainCurrency,
    coverKind,
    coverPath,
    simplifyDebts,
    defaultSplit,
    inviteCode,
    archivedAt,
    directKey,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalGroup &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.mainCurrency == this.mainCurrency &&
          other.coverKind == this.coverKind &&
          other.coverPath == this.coverPath &&
          other.simplifyDebts == this.simplifyDebts &&
          other.defaultSplit == this.defaultSplit &&
          other.inviteCode == this.inviteCode &&
          other.archivedAt == this.archivedAt &&
          other.directKey == this.directKey &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.seq == this.seq &&
          other.syncState == this.syncState);
}

class GroupsCompanion extends UpdateCompanion<LocalGroup> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String> mainCurrency;
  final Value<String> coverKind;
  final Value<String?> coverPath;
  final Value<bool> simplifyDebts;
  final Value<String?> defaultSplit;
  final Value<String?> inviteCode;
  final Value<String?> archivedAt;
  final Value<String?> directKey;
  final Value<String?> createdAt;
  final Value<String?> createdBy;
  final Value<String?> updatedAt;
  final Value<String?> updatedBy;
  final Value<String?> clientUpdatedAt;
  final Value<String?> deletedAt;
  final Value<String?> deletedBy;
  final Value<int> seq;
  final Value<String> syncState;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.mainCurrency = const Value.absent(),
    this.coverKind = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.simplifyDebts = const Value.absent(),
    this.defaultSplit = const Value.absent(),
    this.inviteCode = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.directKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    this.type = const Value.absent(),
    this.mainCurrency = const Value.absent(),
    this.coverKind = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.simplifyDebts = const Value.absent(),
    this.defaultSplit = const Value.absent(),
    this.inviteCode = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.directKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<LocalGroup> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? mainCurrency,
    Expression<String>? coverKind,
    Expression<String>? coverPath,
    Expression<bool>? simplifyDebts,
    Expression<String>? defaultSplit,
    Expression<String>? inviteCode,
    Expression<String>? archivedAt,
    Expression<String>? directKey,
    Expression<String>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? updatedAt,
    Expression<String>? updatedBy,
    Expression<String>? clientUpdatedAt,
    Expression<String>? deletedAt,
    Expression<String>? deletedBy,
    Expression<int>? seq,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (mainCurrency != null) 'main_currency': mainCurrency,
      if (coverKind != null) 'cover_kind': coverKind,
      if (coverPath != null) 'cover_path': coverPath,
      if (simplifyDebts != null) 'simplify_debts': simplifyDebts,
      if (defaultSplit != null) 'default_split': defaultSplit,
      if (inviteCode != null) 'invite_code': inviteCode,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (directKey != null) 'direct_key': directKey,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (seq != null) 'seq': seq,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String>? mainCurrency,
    Value<String>? coverKind,
    Value<String?>? coverPath,
    Value<bool>? simplifyDebts,
    Value<String?>? defaultSplit,
    Value<String?>? inviteCode,
    Value<String?>? archivedAt,
    Value<String?>? directKey,
    Value<String?>? createdAt,
    Value<String?>? createdBy,
    Value<String?>? updatedAt,
    Value<String?>? updatedBy,
    Value<String?>? clientUpdatedAt,
    Value<String?>? deletedAt,
    Value<String?>? deletedBy,
    Value<int>? seq,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      mainCurrency: mainCurrency ?? this.mainCurrency,
      coverKind: coverKind ?? this.coverKind,
      coverPath: coverPath ?? this.coverPath,
      simplifyDebts: simplifyDebts ?? this.simplifyDebts,
      defaultSplit: defaultSplit ?? this.defaultSplit,
      inviteCode: inviteCode ?? this.inviteCode,
      archivedAt: archivedAt ?? this.archivedAt,
      directKey: directKey ?? this.directKey,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      seq: seq ?? this.seq,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (mainCurrency.present) {
      map['main_currency'] = Variable<String>(mainCurrency.value);
    }
    if (coverKind.present) {
      map['cover_kind'] = Variable<String>(coverKind.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (simplifyDebts.present) {
      map['simplify_debts'] = Variable<bool>(simplifyDebts.value);
    }
    if (defaultSplit.present) {
      map['default_split'] = Variable<String>(defaultSplit.value);
    }
    if (inviteCode.present) {
      map['invite_code'] = Variable<String>(inviteCode.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<String>(archivedAt.value);
    }
    if (directKey.present) {
      map['direct_key'] = Variable<String>(directKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('mainCurrency: $mainCurrency, ')
          ..write('coverKind: $coverKind, ')
          ..write('coverPath: $coverPath, ')
          ..write('simplifyDebts: $simplifyDebts, ')
          ..write('defaultSplit: $defaultSplit, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('directKey: $directKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class GroupMembers extends Table with TableInfo<GroupMembers, LocalMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  GroupMembers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta('displayName');
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'member\'',
    defaultValue: const CustomExpression('\'member\''),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'active\'',
    defaultValue: const CustomExpression('\'active\''),
  );
  static const VerificationMeta _claimedAtMeta = const VerificationMeta('claimedAt');
  late final GeneratedColumn<String> claimedAt = GeneratedColumn<String>(
    'claimed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _tintMeta = const VerificationMeta('tint');
  late final GeneratedColumn<int> tint = GeneratedColumn<int>(
    'tint',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta('createdBy');
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta('updatedBy');
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta('deletedBy');
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta('syncState');
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\'',
    defaultValue: const CustomExpression('\'synced\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    userId,
    displayName,
    position,
    role,
    status,
    claimedAt,
    tint,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta, userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(data['display_name']!, _displayNameMeta),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(_roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('claimed_at')) {
      context.handle(
        _claimedAtMeta,
        claimedAt.isAcceptableOrUnknown(data['claimed_at']!, _claimedAtMeta),
      );
    }
    if (data.containsKey('tint')) {
      context.handle(_tintMeta, tint.isAcceptableOrUnknown(data['tint']!, _tintMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMember(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      role: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      claimedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}claimed_at'],
      ),
      tint: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}tint']),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  GroupMembers createAlias(String alias) {
    return GroupMembers(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalMember extends DataClass implements Insertable<LocalMember> {
  final String id;
  final String groupId;
  final String? userId;
  final String displayName;
  final int position;
  final String role;
  final String status;
  final String? claimedAt;
  final int? tint;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? clientUpdatedAt;
  final String? deletedAt;
  final String? deletedBy;
  final int seq;
  final String syncState;
  const LocalMember({
    required this.id,
    required this.groupId,
    this.userId,
    required this.displayName,
    required this.position,
    required this.role,
    required this.status,
    this.claimedAt,
    this.tint,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientUpdatedAt,
    this.deletedAt,
    this.deletedBy,
    required this.seq,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['display_name'] = Variable<String>(displayName);
    map['position'] = Variable<int>(position);
    map['role'] = Variable<String>(role);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || claimedAt != null) {
      map['claimed_at'] = Variable<String>(claimedAt);
    }
    if (!nullToAbsent || tint != null) {
      map['tint'] = Variable<int>(tint);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['seq'] = Variable<int>(seq);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      id: Value(id),
      groupId: Value(groupId),
      userId: userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      displayName: Value(displayName),
      position: Value(position),
      role: Value(role),
      status: Value(status),
      claimedAt: claimedAt == null && nullToAbsent ? const Value.absent() : Value(claimedAt),
      tint: tint == null && nullToAbsent ? const Value.absent() : Value(tint),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      createdBy: createdBy == null && nullToAbsent ? const Value.absent() : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent ? const Value.absent() : Value(updatedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent ? const Value.absent() : Value(deletedBy),
      seq: Value(seq),
      syncState: Value(syncState),
    );
  }

  factory LocalMember.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMember(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      userId: serializer.fromJson<String?>(json['user_id']),
      displayName: serializer.fromJson<String>(json['display_name']),
      position: serializer.fromJson<int>(json['position']),
      role: serializer.fromJson<String>(json['role']),
      status: serializer.fromJson<String>(json['status']),
      claimedAt: serializer.fromJson<String?>(json['claimed_at']),
      tint: serializer.fromJson<int?>(json['tint']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      createdBy: serializer.fromJson<String?>(json['created_by']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      updatedBy: serializer.fromJson<String?>(json['updated_by']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      deletedBy: serializer.fromJson<String?>(json['deleted_by']),
      seq: serializer.fromJson<int>(json['seq']),
      syncState: serializer.fromJson<String>(json['sync_state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'group_id': serializer.toJson<String>(groupId),
      'user_id': serializer.toJson<String?>(userId),
      'display_name': serializer.toJson<String>(displayName),
      'position': serializer.toJson<int>(position),
      'role': serializer.toJson<String>(role),
      'status': serializer.toJson<String>(status),
      'claimed_at': serializer.toJson<String?>(claimedAt),
      'tint': serializer.toJson<int?>(tint),
      'created_at': serializer.toJson<String?>(createdAt),
      'created_by': serializer.toJson<String?>(createdBy),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'updated_by': serializer.toJson<String?>(updatedBy),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'deleted_by': serializer.toJson<String?>(deletedBy),
      'seq': serializer.toJson<int>(seq),
      'sync_state': serializer.toJson<String>(syncState),
    };
  }

  LocalMember copyWith({
    String? id,
    String? groupId,
    Value<String?> userId = const Value.absent(),
    String? displayName,
    int? position,
    String? role,
    String? status,
    Value<String?> claimedAt = const Value.absent(),
    Value<int?> tint = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> clientUpdatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    int? seq,
    String? syncState,
  }) => LocalMember(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    userId: userId.present ? userId.value : this.userId,
    displayName: displayName ?? this.displayName,
    position: position ?? this.position,
    role: role ?? this.role,
    status: status ?? this.status,
    claimedAt: claimedAt.present ? claimedAt.value : this.claimedAt,
    tint: tint.present ? tint.value : this.tint,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    seq: seq ?? this.seq,
    syncState: syncState ?? this.syncState,
  );
  LocalMember copyWithCompanion(GroupMembersCompanion data) {
    return LocalMember(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      userId: data.userId.present ? data.userId.value : this.userId,
      displayName: data.displayName.present ? data.displayName.value : this.displayName,
      position: data.position.present ? data.position.value : this.position,
      role: data.role.present ? data.role.value : this.role,
      status: data.status.present ? data.status.value : this.status,
      claimedAt: data.claimedAt.present ? data.claimedAt.value : this.claimedAt,
      tint: data.tint.present ? data.tint.value : this.tint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      seq: data.seq.present ? data.seq.value : this.seq,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMember(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('position: $position, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('tint: $tint, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    userId,
    displayName,
    position,
    role,
    status,
    claimedAt,
    tint,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMember &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.userId == this.userId &&
          other.displayName == this.displayName &&
          other.position == this.position &&
          other.role == this.role &&
          other.status == this.status &&
          other.claimedAt == this.claimedAt &&
          other.tint == this.tint &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.seq == this.seq &&
          other.syncState == this.syncState);
}

class GroupMembersCompanion extends UpdateCompanion<LocalMember> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> userId;
  final Value<String> displayName;
  final Value<int> position;
  final Value<String> role;
  final Value<String> status;
  final Value<String?> claimedAt;
  final Value<int?> tint;
  final Value<String?> createdAt;
  final Value<String?> createdBy;
  final Value<String?> updatedAt;
  final Value<String?> updatedBy;
  final Value<String?> clientUpdatedAt;
  final Value<String?> deletedAt;
  final Value<String?> deletedBy;
  final Value<int> seq;
  final Value<String> syncState;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.userId = const Value.absent(),
    this.displayName = const Value.absent(),
    this.position = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.tint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String id,
    required String groupId,
    this.userId = const Value.absent(),
    required String displayName,
    this.position = const Value.absent(),
    this.role = const Value.absent(),
    this.status = const Value.absent(),
    this.claimedAt = const Value.absent(),
    this.tint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       displayName = Value(displayName);
  static Insertable<LocalMember> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? userId,
    Expression<String>? displayName,
    Expression<int>? position,
    Expression<String>? role,
    Expression<String>? status,
    Expression<String>? claimedAt,
    Expression<int>? tint,
    Expression<String>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? updatedAt,
    Expression<String>? updatedBy,
    Expression<String>? clientUpdatedAt,
    Expression<String>? deletedAt,
    Expression<String>? deletedBy,
    Expression<int>? seq,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (userId != null) 'user_id': userId,
      if (displayName != null) 'display_name': displayName,
      if (position != null) 'position': position,
      if (role != null) 'role': role,
      if (status != null) 'status': status,
      if (claimedAt != null) 'claimed_at': claimedAt,
      if (tint != null) 'tint': tint,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (seq != null) 'seq': seq,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String?>? userId,
    Value<String>? displayName,
    Value<int>? position,
    Value<String>? role,
    Value<String>? status,
    Value<String?>? claimedAt,
    Value<int?>? tint,
    Value<String?>? createdAt,
    Value<String?>? createdBy,
    Value<String?>? updatedAt,
    Value<String?>? updatedBy,
    Value<String?>? clientUpdatedAt,
    Value<String?>? deletedAt,
    Value<String?>? deletedBy,
    Value<int>? seq,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      position: position ?? this.position,
      role: role ?? this.role,
      status: status ?? this.status,
      claimedAt: claimedAt ?? this.claimedAt,
      tint: tint ?? this.tint,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      seq: seq ?? this.seq,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (claimedAt.present) {
      map['claimed_at'] = Variable<String>(claimedAt.value);
    }
    if (tint.present) {
      map['tint'] = Variable<int>(tint.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('userId: $userId, ')
          ..write('displayName: $displayName, ')
          ..write('position: $position, ')
          ..write('role: $role, ')
          ..write('status: $status, ')
          ..write('claimedAt: $claimedAt, ')
          ..write('tint: $tint, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Expenses extends Table with TableInfo<Expenses, LocalExpense> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Expenses(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'expense\'',
    defaultValue: const CustomExpression('\'expense\''),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta('category');
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'other.general\'',
    defaultValue: const CustomExpression('\'other.general\''),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payersMeta = const VerificationMeta('payers');
  late final GeneratedColumn<String> payers = GeneratedColumn<String>(
    'payers',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _sharesMeta = const VerificationMeta('shares');
  late final GeneratedColumn<String> shares = GeneratedColumn<String>(
    'shares',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _splitKindMeta = const VerificationMeta('splitKind');
  late final GeneratedColumn<String> splitKind = GeneratedColumn<String>(
    'split_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'equal\'',
    defaultValue: const CustomExpression('\'equal\''),
  );
  static const VerificationMeta _splitValuesMeta = const VerificationMeta('splitValues');
  late final GeneratedColumn<String> splitValues = GeneratedColumn<String>(
    'split_values',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxRateMeta = const VerificationMeta('fxRate');
  late final GeneratedColumn<String> fxRate = GeneratedColumn<String>(
    'fx_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxRateDateMeta = const VerificationMeta('fxRateDate');
  late final GeneratedColumn<String> fxRateDate = GeneratedColumn<String>(
    'fx_rate_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxSourceMeta = const VerificationMeta('fxSource');
  late final GeneratedColumn<String> fxSource = GeneratedColumn<String>(
    'fx_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxCurrencyMeta = const VerificationMeta('fxCurrency');
  late final GeneratedColumn<String> fxCurrency = GeneratedColumn<String>(
    'fx_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxTotalMeta = const VerificationMeta('fxTotal');
  late final GeneratedColumn<int> fxTotal = GeneratedColumn<int>(
    'fx_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxPayersMeta = const VerificationMeta('fxPayers');
  late final GeneratedColumn<String> fxPayers = GeneratedColumn<String>(
    'fx_payers',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxSharesMeta = const VerificationMeta('fxShares');
  late final GeneratedColumn<String> fxShares = GeneratedColumn<String>(
    'fx_shares',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _receiptPathMeta = const VerificationMeta('receiptPath');
  late final GeneratedColumn<String> receiptPath = GeneratedColumn<String>(
    'receipt_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _recurringIdMeta = const VerificationMeta('recurringId');
  late final GeneratedColumn<String> recurringId = GeneratedColumn<String>(
    'recurring_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'app\'',
    defaultValue: const CustomExpression('\'app\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta('createdBy');
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta('updatedBy');
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta('deletedBy');
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta('syncState');
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\'',
    defaultValue: const CustomExpression('\'synced\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    kind,
    description,
    notes,
    category,
    date,
    currency,
    total,
    payers,
    shares,
    splitKind,
    splitValues,
    fxRate,
    fxRateDate,
    fxSource,
    fxCurrency,
    fxTotal,
    fxPayers,
    fxShares,
    receiptPath,
    recurringId,
    source,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalExpense> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['description']!, _descriptionMeta),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('total')) {
      context.handle(_totalMeta, total.isAcceptableOrUnknown(data['total']!, _totalMeta));
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('payers')) {
      context.handle(_payersMeta, payers.isAcceptableOrUnknown(data['payers']!, _payersMeta));
    } else if (isInserting) {
      context.missing(_payersMeta);
    }
    if (data.containsKey('shares')) {
      context.handle(_sharesMeta, shares.isAcceptableOrUnknown(data['shares']!, _sharesMeta));
    } else if (isInserting) {
      context.missing(_sharesMeta);
    }
    if (data.containsKey('split_kind')) {
      context.handle(
        _splitKindMeta,
        splitKind.isAcceptableOrUnknown(data['split_kind']!, _splitKindMeta),
      );
    }
    if (data.containsKey('split_values')) {
      context.handle(
        _splitValuesMeta,
        splitValues.isAcceptableOrUnknown(data['split_values']!, _splitValuesMeta),
      );
    }
    if (data.containsKey('fx_rate')) {
      context.handle(_fxRateMeta, fxRate.isAcceptableOrUnknown(data['fx_rate']!, _fxRateMeta));
    }
    if (data.containsKey('fx_rate_date')) {
      context.handle(
        _fxRateDateMeta,
        fxRateDate.isAcceptableOrUnknown(data['fx_rate_date']!, _fxRateDateMeta),
      );
    }
    if (data.containsKey('fx_source')) {
      context.handle(
        _fxSourceMeta,
        fxSource.isAcceptableOrUnknown(data['fx_source']!, _fxSourceMeta),
      );
    }
    if (data.containsKey('fx_currency')) {
      context.handle(
        _fxCurrencyMeta,
        fxCurrency.isAcceptableOrUnknown(data['fx_currency']!, _fxCurrencyMeta),
      );
    }
    if (data.containsKey('fx_total')) {
      context.handle(_fxTotalMeta, fxTotal.isAcceptableOrUnknown(data['fx_total']!, _fxTotalMeta));
    }
    if (data.containsKey('fx_payers')) {
      context.handle(
        _fxPayersMeta,
        fxPayers.isAcceptableOrUnknown(data['fx_payers']!, _fxPayersMeta),
      );
    }
    if (data.containsKey('fx_shares')) {
      context.handle(
        _fxSharesMeta,
        fxShares.isAcceptableOrUnknown(data['fx_shares']!, _fxSharesMeta),
      );
    }
    if (data.containsKey('receipt_path')) {
      context.handle(
        _receiptPathMeta,
        receiptPath.isAcceptableOrUnknown(data['receipt_path']!, _receiptPathMeta),
      );
    }
    if (data.containsKey('recurring_id')) {
      context.handle(
        _recurringIdMeta,
        recurringId.isAcceptableOrUnknown(data['recurring_id']!, _recurringIdMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalExpense map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalExpense(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      total: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}total'])!,
      payers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payers'],
      )!,
      shares: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shares'],
      )!,
      splitKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}split_kind'],
      )!,
      splitValues: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}split_values'],
      ),
      fxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_rate'],
      ),
      fxRateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_rate_date'],
      ),
      fxSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_source'],
      ),
      fxCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_currency'],
      ),
      fxTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fx_total'],
      ),
      fxPayers: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_payers'],
      ),
      fxShares: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_shares'],
      ),
      receiptPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}receipt_path'],
      ),
      recurringId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recurring_id'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  Expenses createAlias(String alias) {
    return Expenses(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalExpense extends DataClass implements Insertable<LocalExpense> {
  final String id;
  final String groupId;
  final String kind;
  final String description;
  final String? notes;
  final String category;
  final String date;
  final String currency;
  final int total;
  final String payers;
  final String shares;
  final String splitKind;
  final String? splitValues;
  final String? fxRate;
  final String? fxRateDate;
  final String? fxSource;
  final String? fxCurrency;
  final int? fxTotal;
  final String? fxPayers;
  final String? fxShares;
  final String? receiptPath;
  final String? recurringId;
  final String source;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? clientUpdatedAt;
  final String? deletedAt;
  final String? deletedBy;
  final int seq;
  final String syncState;
  const LocalExpense({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.description,
    this.notes,
    required this.category,
    required this.date,
    required this.currency,
    required this.total,
    required this.payers,
    required this.shares,
    required this.splitKind,
    this.splitValues,
    this.fxRate,
    this.fxRateDate,
    this.fxSource,
    this.fxCurrency,
    this.fxTotal,
    this.fxPayers,
    this.fxShares,
    this.receiptPath,
    this.recurringId,
    required this.source,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientUpdatedAt,
    this.deletedAt,
    this.deletedBy,
    required this.seq,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['kind'] = Variable<String>(kind);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['category'] = Variable<String>(category);
    map['date'] = Variable<String>(date);
    map['currency'] = Variable<String>(currency);
    map['total'] = Variable<int>(total);
    map['payers'] = Variable<String>(payers);
    map['shares'] = Variable<String>(shares);
    map['split_kind'] = Variable<String>(splitKind);
    if (!nullToAbsent || splitValues != null) {
      map['split_values'] = Variable<String>(splitValues);
    }
    if (!nullToAbsent || fxRate != null) {
      map['fx_rate'] = Variable<String>(fxRate);
    }
    if (!nullToAbsent || fxRateDate != null) {
      map['fx_rate_date'] = Variable<String>(fxRateDate);
    }
    if (!nullToAbsent || fxSource != null) {
      map['fx_source'] = Variable<String>(fxSource);
    }
    if (!nullToAbsent || fxCurrency != null) {
      map['fx_currency'] = Variable<String>(fxCurrency);
    }
    if (!nullToAbsent || fxTotal != null) {
      map['fx_total'] = Variable<int>(fxTotal);
    }
    if (!nullToAbsent || fxPayers != null) {
      map['fx_payers'] = Variable<String>(fxPayers);
    }
    if (!nullToAbsent || fxShares != null) {
      map['fx_shares'] = Variable<String>(fxShares);
    }
    if (!nullToAbsent || receiptPath != null) {
      map['receipt_path'] = Variable<String>(receiptPath);
    }
    if (!nullToAbsent || recurringId != null) {
      map['recurring_id'] = Variable<String>(recurringId);
    }
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['seq'] = Variable<int>(seq);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      groupId: Value(groupId),
      kind: Value(kind),
      description: Value(description),
      notes: notes == null && nullToAbsent ? const Value.absent() : Value(notes),
      category: Value(category),
      date: Value(date),
      currency: Value(currency),
      total: Value(total),
      payers: Value(payers),
      shares: Value(shares),
      splitKind: Value(splitKind),
      splitValues: splitValues == null && nullToAbsent ? const Value.absent() : Value(splitValues),
      fxRate: fxRate == null && nullToAbsent ? const Value.absent() : Value(fxRate),
      fxRateDate: fxRateDate == null && nullToAbsent ? const Value.absent() : Value(fxRateDate),
      fxSource: fxSource == null && nullToAbsent ? const Value.absent() : Value(fxSource),
      fxCurrency: fxCurrency == null && nullToAbsent ? const Value.absent() : Value(fxCurrency),
      fxTotal: fxTotal == null && nullToAbsent ? const Value.absent() : Value(fxTotal),
      fxPayers: fxPayers == null && nullToAbsent ? const Value.absent() : Value(fxPayers),
      fxShares: fxShares == null && nullToAbsent ? const Value.absent() : Value(fxShares),
      receiptPath: receiptPath == null && nullToAbsent ? const Value.absent() : Value(receiptPath),
      recurringId: recurringId == null && nullToAbsent ? const Value.absent() : Value(recurringId),
      source: Value(source),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      createdBy: createdBy == null && nullToAbsent ? const Value.absent() : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent ? const Value.absent() : Value(updatedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent ? const Value.absent() : Value(deletedBy),
      seq: Value(seq),
      syncState: Value(syncState),
    );
  }

  factory LocalExpense.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalExpense(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      kind: serializer.fromJson<String>(json['kind']),
      description: serializer.fromJson<String>(json['description']),
      notes: serializer.fromJson<String?>(json['notes']),
      category: serializer.fromJson<String>(json['category']),
      date: serializer.fromJson<String>(json['date']),
      currency: serializer.fromJson<String>(json['currency']),
      total: serializer.fromJson<int>(json['total']),
      payers: serializer.fromJson<String>(json['payers']),
      shares: serializer.fromJson<String>(json['shares']),
      splitKind: serializer.fromJson<String>(json['split_kind']),
      splitValues: serializer.fromJson<String?>(json['split_values']),
      fxRate: serializer.fromJson<String?>(json['fx_rate']),
      fxRateDate: serializer.fromJson<String?>(json['fx_rate_date']),
      fxSource: serializer.fromJson<String?>(json['fx_source']),
      fxCurrency: serializer.fromJson<String?>(json['fx_currency']),
      fxTotal: serializer.fromJson<int?>(json['fx_total']),
      fxPayers: serializer.fromJson<String?>(json['fx_payers']),
      fxShares: serializer.fromJson<String?>(json['fx_shares']),
      receiptPath: serializer.fromJson<String?>(json['receipt_path']),
      recurringId: serializer.fromJson<String?>(json['recurring_id']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      createdBy: serializer.fromJson<String?>(json['created_by']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      updatedBy: serializer.fromJson<String?>(json['updated_by']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      deletedBy: serializer.fromJson<String?>(json['deleted_by']),
      seq: serializer.fromJson<int>(json['seq']),
      syncState: serializer.fromJson<String>(json['sync_state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'group_id': serializer.toJson<String>(groupId),
      'kind': serializer.toJson<String>(kind),
      'description': serializer.toJson<String>(description),
      'notes': serializer.toJson<String?>(notes),
      'category': serializer.toJson<String>(category),
      'date': serializer.toJson<String>(date),
      'currency': serializer.toJson<String>(currency),
      'total': serializer.toJson<int>(total),
      'payers': serializer.toJson<String>(payers),
      'shares': serializer.toJson<String>(shares),
      'split_kind': serializer.toJson<String>(splitKind),
      'split_values': serializer.toJson<String?>(splitValues),
      'fx_rate': serializer.toJson<String?>(fxRate),
      'fx_rate_date': serializer.toJson<String?>(fxRateDate),
      'fx_source': serializer.toJson<String?>(fxSource),
      'fx_currency': serializer.toJson<String?>(fxCurrency),
      'fx_total': serializer.toJson<int?>(fxTotal),
      'fx_payers': serializer.toJson<String?>(fxPayers),
      'fx_shares': serializer.toJson<String?>(fxShares),
      'receipt_path': serializer.toJson<String?>(receiptPath),
      'recurring_id': serializer.toJson<String?>(recurringId),
      'source': serializer.toJson<String>(source),
      'created_at': serializer.toJson<String?>(createdAt),
      'created_by': serializer.toJson<String?>(createdBy),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'updated_by': serializer.toJson<String?>(updatedBy),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'deleted_by': serializer.toJson<String?>(deletedBy),
      'seq': serializer.toJson<int>(seq),
      'sync_state': serializer.toJson<String>(syncState),
    };
  }

  LocalExpense copyWith({
    String? id,
    String? groupId,
    String? kind,
    String? description,
    Value<String?> notes = const Value.absent(),
    String? category,
    String? date,
    String? currency,
    int? total,
    String? payers,
    String? shares,
    String? splitKind,
    Value<String?> splitValues = const Value.absent(),
    Value<String?> fxRate = const Value.absent(),
    Value<String?> fxRateDate = const Value.absent(),
    Value<String?> fxSource = const Value.absent(),
    Value<String?> fxCurrency = const Value.absent(),
    Value<int?> fxTotal = const Value.absent(),
    Value<String?> fxPayers = const Value.absent(),
    Value<String?> fxShares = const Value.absent(),
    Value<String?> receiptPath = const Value.absent(),
    Value<String?> recurringId = const Value.absent(),
    String? source,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> clientUpdatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    int? seq,
    String? syncState,
  }) => LocalExpense(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    kind: kind ?? this.kind,
    description: description ?? this.description,
    notes: notes.present ? notes.value : this.notes,
    category: category ?? this.category,
    date: date ?? this.date,
    currency: currency ?? this.currency,
    total: total ?? this.total,
    payers: payers ?? this.payers,
    shares: shares ?? this.shares,
    splitKind: splitKind ?? this.splitKind,
    splitValues: splitValues.present ? splitValues.value : this.splitValues,
    fxRate: fxRate.present ? fxRate.value : this.fxRate,
    fxRateDate: fxRateDate.present ? fxRateDate.value : this.fxRateDate,
    fxSource: fxSource.present ? fxSource.value : this.fxSource,
    fxCurrency: fxCurrency.present ? fxCurrency.value : this.fxCurrency,
    fxTotal: fxTotal.present ? fxTotal.value : this.fxTotal,
    fxPayers: fxPayers.present ? fxPayers.value : this.fxPayers,
    fxShares: fxShares.present ? fxShares.value : this.fxShares,
    receiptPath: receiptPath.present ? receiptPath.value : this.receiptPath,
    recurringId: recurringId.present ? recurringId.value : this.recurringId,
    source: source ?? this.source,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    seq: seq ?? this.seq,
    syncState: syncState ?? this.syncState,
  );
  LocalExpense copyWithCompanion(ExpensesCompanion data) {
    return LocalExpense(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      kind: data.kind.present ? data.kind.value : this.kind,
      description: data.description.present ? data.description.value : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      category: data.category.present ? data.category.value : this.category,
      date: data.date.present ? data.date.value : this.date,
      currency: data.currency.present ? data.currency.value : this.currency,
      total: data.total.present ? data.total.value : this.total,
      payers: data.payers.present ? data.payers.value : this.payers,
      shares: data.shares.present ? data.shares.value : this.shares,
      splitKind: data.splitKind.present ? data.splitKind.value : this.splitKind,
      splitValues: data.splitValues.present ? data.splitValues.value : this.splitValues,
      fxRate: data.fxRate.present ? data.fxRate.value : this.fxRate,
      fxRateDate: data.fxRateDate.present ? data.fxRateDate.value : this.fxRateDate,
      fxSource: data.fxSource.present ? data.fxSource.value : this.fxSource,
      fxCurrency: data.fxCurrency.present ? data.fxCurrency.value : this.fxCurrency,
      fxTotal: data.fxTotal.present ? data.fxTotal.value : this.fxTotal,
      fxPayers: data.fxPayers.present ? data.fxPayers.value : this.fxPayers,
      fxShares: data.fxShares.present ? data.fxShares.value : this.fxShares,
      receiptPath: data.receiptPath.present ? data.receiptPath.value : this.receiptPath,
      recurringId: data.recurringId.present ? data.recurringId.value : this.recurringId,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      seq: data.seq.present ? data.seq.value : this.seq,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalExpense(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('currency: $currency, ')
          ..write('total: $total, ')
          ..write('payers: $payers, ')
          ..write('shares: $shares, ')
          ..write('splitKind: $splitKind, ')
          ..write('splitValues: $splitValues, ')
          ..write('fxRate: $fxRate, ')
          ..write('fxRateDate: $fxRateDate, ')
          ..write('fxSource: $fxSource, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxTotal: $fxTotal, ')
          ..write('fxPayers: $fxPayers, ')
          ..write('fxShares: $fxShares, ')
          ..write('receiptPath: $receiptPath, ')
          ..write('recurringId: $recurringId, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    groupId,
    kind,
    description,
    notes,
    category,
    date,
    currency,
    total,
    payers,
    shares,
    splitKind,
    splitValues,
    fxRate,
    fxRateDate,
    fxSource,
    fxCurrency,
    fxTotal,
    fxPayers,
    fxShares,
    receiptPath,
    recurringId,
    source,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalExpense &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.kind == this.kind &&
          other.description == this.description &&
          other.notes == this.notes &&
          other.category == this.category &&
          other.date == this.date &&
          other.currency == this.currency &&
          other.total == this.total &&
          other.payers == this.payers &&
          other.shares == this.shares &&
          other.splitKind == this.splitKind &&
          other.splitValues == this.splitValues &&
          other.fxRate == this.fxRate &&
          other.fxRateDate == this.fxRateDate &&
          other.fxSource == this.fxSource &&
          other.fxCurrency == this.fxCurrency &&
          other.fxTotal == this.fxTotal &&
          other.fxPayers == this.fxPayers &&
          other.fxShares == this.fxShares &&
          other.receiptPath == this.receiptPath &&
          other.recurringId == this.recurringId &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.seq == this.seq &&
          other.syncState == this.syncState);
}

class ExpensesCompanion extends UpdateCompanion<LocalExpense> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> kind;
  final Value<String> description;
  final Value<String?> notes;
  final Value<String> category;
  final Value<String> date;
  final Value<String> currency;
  final Value<int> total;
  final Value<String> payers;
  final Value<String> shares;
  final Value<String> splitKind;
  final Value<String?> splitValues;
  final Value<String?> fxRate;
  final Value<String?> fxRateDate;
  final Value<String?> fxSource;
  final Value<String?> fxCurrency;
  final Value<int?> fxTotal;
  final Value<String?> fxPayers;
  final Value<String?> fxShares;
  final Value<String?> receiptPath;
  final Value<String?> recurringId;
  final Value<String> source;
  final Value<String?> createdAt;
  final Value<String?> createdBy;
  final Value<String?> updatedAt;
  final Value<String?> updatedBy;
  final Value<String?> clientUpdatedAt;
  final Value<String?> deletedAt;
  final Value<String?> deletedBy;
  final Value<int> seq;
  final Value<String> syncState;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.kind = const Value.absent(),
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.category = const Value.absent(),
    this.date = const Value.absent(),
    this.currency = const Value.absent(),
    this.total = const Value.absent(),
    this.payers = const Value.absent(),
    this.shares = const Value.absent(),
    this.splitKind = const Value.absent(),
    this.splitValues = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.fxRateDate = const Value.absent(),
    this.fxSource = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxTotal = const Value.absent(),
    this.fxPayers = const Value.absent(),
    this.fxShares = const Value.absent(),
    this.receiptPath = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required String groupId,
    this.kind = const Value.absent(),
    required String description,
    this.notes = const Value.absent(),
    this.category = const Value.absent(),
    required String date,
    required String currency,
    required int total,
    required String payers,
    required String shares,
    this.splitKind = const Value.absent(),
    this.splitValues = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.fxRateDate = const Value.absent(),
    this.fxSource = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxTotal = const Value.absent(),
    this.fxPayers = const Value.absent(),
    this.fxShares = const Value.absent(),
    this.receiptPath = const Value.absent(),
    this.recurringId = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       description = Value(description),
       date = Value(date),
       currency = Value(currency),
       total = Value(total),
       payers = Value(payers),
       shares = Value(shares);
  static Insertable<LocalExpense> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? kind,
    Expression<String>? description,
    Expression<String>? notes,
    Expression<String>? category,
    Expression<String>? date,
    Expression<String>? currency,
    Expression<int>? total,
    Expression<String>? payers,
    Expression<String>? shares,
    Expression<String>? splitKind,
    Expression<String>? splitValues,
    Expression<String>? fxRate,
    Expression<String>? fxRateDate,
    Expression<String>? fxSource,
    Expression<String>? fxCurrency,
    Expression<int>? fxTotal,
    Expression<String>? fxPayers,
    Expression<String>? fxShares,
    Expression<String>? receiptPath,
    Expression<String>? recurringId,
    Expression<String>? source,
    Expression<String>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? updatedAt,
    Expression<String>? updatedBy,
    Expression<String>? clientUpdatedAt,
    Expression<String>? deletedAt,
    Expression<String>? deletedBy,
    Expression<int>? seq,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (kind != null) 'kind': kind,
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (category != null) 'category': category,
      if (date != null) 'date': date,
      if (currency != null) 'currency': currency,
      if (total != null) 'total': total,
      if (payers != null) 'payers': payers,
      if (shares != null) 'shares': shares,
      if (splitKind != null) 'split_kind': splitKind,
      if (splitValues != null) 'split_values': splitValues,
      if (fxRate != null) 'fx_rate': fxRate,
      if (fxRateDate != null) 'fx_rate_date': fxRateDate,
      if (fxSource != null) 'fx_source': fxSource,
      if (fxCurrency != null) 'fx_currency': fxCurrency,
      if (fxTotal != null) 'fx_total': fxTotal,
      if (fxPayers != null) 'fx_payers': fxPayers,
      if (fxShares != null) 'fx_shares': fxShares,
      if (receiptPath != null) 'receipt_path': receiptPath,
      if (recurringId != null) 'recurring_id': recurringId,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (seq != null) 'seq': seq,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? kind,
    Value<String>? description,
    Value<String?>? notes,
    Value<String>? category,
    Value<String>? date,
    Value<String>? currency,
    Value<int>? total,
    Value<String>? payers,
    Value<String>? shares,
    Value<String>? splitKind,
    Value<String?>? splitValues,
    Value<String?>? fxRate,
    Value<String?>? fxRateDate,
    Value<String?>? fxSource,
    Value<String?>? fxCurrency,
    Value<int?>? fxTotal,
    Value<String?>? fxPayers,
    Value<String?>? fxShares,
    Value<String?>? receiptPath,
    Value<String?>? recurringId,
    Value<String>? source,
    Value<String?>? createdAt,
    Value<String?>? createdBy,
    Value<String?>? updatedAt,
    Value<String?>? updatedBy,
    Value<String?>? clientUpdatedAt,
    Value<String?>? deletedAt,
    Value<String?>? deletedBy,
    Value<int>? seq,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      kind: kind ?? this.kind,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      date: date ?? this.date,
      currency: currency ?? this.currency,
      total: total ?? this.total,
      payers: payers ?? this.payers,
      shares: shares ?? this.shares,
      splitKind: splitKind ?? this.splitKind,
      splitValues: splitValues ?? this.splitValues,
      fxRate: fxRate ?? this.fxRate,
      fxRateDate: fxRateDate ?? this.fxRateDate,
      fxSource: fxSource ?? this.fxSource,
      fxCurrency: fxCurrency ?? this.fxCurrency,
      fxTotal: fxTotal ?? this.fxTotal,
      fxPayers: fxPayers ?? this.fxPayers,
      fxShares: fxShares ?? this.fxShares,
      receiptPath: receiptPath ?? this.receiptPath,
      recurringId: recurringId ?? this.recurringId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      seq: seq ?? this.seq,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (payers.present) {
      map['payers'] = Variable<String>(payers.value);
    }
    if (shares.present) {
      map['shares'] = Variable<String>(shares.value);
    }
    if (splitKind.present) {
      map['split_kind'] = Variable<String>(splitKind.value);
    }
    if (splitValues.present) {
      map['split_values'] = Variable<String>(splitValues.value);
    }
    if (fxRate.present) {
      map['fx_rate'] = Variable<String>(fxRate.value);
    }
    if (fxRateDate.present) {
      map['fx_rate_date'] = Variable<String>(fxRateDate.value);
    }
    if (fxSource.present) {
      map['fx_source'] = Variable<String>(fxSource.value);
    }
    if (fxCurrency.present) {
      map['fx_currency'] = Variable<String>(fxCurrency.value);
    }
    if (fxTotal.present) {
      map['fx_total'] = Variable<int>(fxTotal.value);
    }
    if (fxPayers.present) {
      map['fx_payers'] = Variable<String>(fxPayers.value);
    }
    if (fxShares.present) {
      map['fx_shares'] = Variable<String>(fxShares.value);
    }
    if (receiptPath.present) {
      map['receipt_path'] = Variable<String>(receiptPath.value);
    }
    if (recurringId.present) {
      map['recurring_id'] = Variable<String>(recurringId.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('kind: $kind, ')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('category: $category, ')
          ..write('date: $date, ')
          ..write('currency: $currency, ')
          ..write('total: $total, ')
          ..write('payers: $payers, ')
          ..write('shares: $shares, ')
          ..write('splitKind: $splitKind, ')
          ..write('splitValues: $splitValues, ')
          ..write('fxRate: $fxRate, ')
          ..write('fxRateDate: $fxRateDate, ')
          ..write('fxSource: $fxSource, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxTotal: $fxTotal, ')
          ..write('fxPayers: $fxPayers, ')
          ..write('fxShares: $fxShares, ')
          ..write('receiptPath: $receiptPath, ')
          ..write('recurringId: $recurringId, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Payments extends Table with TableInfo<Payments, LocalPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Payments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fromMemberMeta = const VerificationMeta('fromMember');
  late final GeneratedColumn<String> fromMember = GeneratedColumn<String>(
    'from_member',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _toMemberMeta = const VerificationMeta('toMember');
  late final GeneratedColumn<String> toMember = GeneratedColumn<String>(
    'to_member',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  late final GeneratedColumn<int> amount = GeneratedColumn<int>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _methodMeta = const VerificationMeta('method');
  late final GeneratedColumn<String> method = GeneratedColumn<String>(
    'method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'cash\'',
    defaultValue: const CustomExpression('\'cash\''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxRateMeta = const VerificationMeta('fxRate');
  late final GeneratedColumn<String> fxRate = GeneratedColumn<String>(
    'fx_rate',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxRateDateMeta = const VerificationMeta('fxRateDate');
  late final GeneratedColumn<String> fxRateDate = GeneratedColumn<String>(
    'fx_rate_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxSourceMeta = const VerificationMeta('fxSource');
  late final GeneratedColumn<String> fxSource = GeneratedColumn<String>(
    'fx_source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxCurrencyMeta = const VerificationMeta('fxCurrency');
  late final GeneratedColumn<String> fxCurrency = GeneratedColumn<String>(
    'fx_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxAmountMeta = const VerificationMeta('fxAmount');
  late final GeneratedColumn<int> fxAmount = GeneratedColumn<int>(
    'fx_amount',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta('createdBy');
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta('updatedBy');
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta('deletedBy');
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta('syncState');
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\'',
    defaultValue: const CustomExpression('\'synced\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    fromMember,
    toMember,
    amount,
    currency,
    date,
    method,
    note,
    fxRate,
    fxRateDate,
    fxSource,
    fxCurrency,
    fxAmount,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('from_member')) {
      context.handle(
        _fromMemberMeta,
        fromMember.isAcceptableOrUnknown(data['from_member']!, _fromMemberMeta),
      );
    } else if (isInserting) {
      context.missing(_fromMemberMeta);
    }
    if (data.containsKey('to_member')) {
      context.handle(
        _toMemberMeta,
        toMember.isAcceptableOrUnknown(data['to_member']!, _toMemberMeta),
      );
    } else if (isInserting) {
      context.missing(_toMemberMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(_amountMeta, amount.isAcceptableOrUnknown(data['amount']!, _amountMeta));
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('date')) {
      context.handle(_dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('method')) {
      context.handle(_methodMeta, method.isAcceptableOrUnknown(data['method']!, _methodMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('fx_rate')) {
      context.handle(_fxRateMeta, fxRate.isAcceptableOrUnknown(data['fx_rate']!, _fxRateMeta));
    }
    if (data.containsKey('fx_rate_date')) {
      context.handle(
        _fxRateDateMeta,
        fxRateDate.isAcceptableOrUnknown(data['fx_rate_date']!, _fxRateDateMeta),
      );
    }
    if (data.containsKey('fx_source')) {
      context.handle(
        _fxSourceMeta,
        fxSource.isAcceptableOrUnknown(data['fx_source']!, _fxSourceMeta),
      );
    }
    if (data.containsKey('fx_currency')) {
      context.handle(
        _fxCurrencyMeta,
        fxCurrency.isAcceptableOrUnknown(data['fx_currency']!, _fxCurrencyMeta),
      );
    }
    if (data.containsKey('fx_amount')) {
      context.handle(
        _fxAmountMeta,
        fxAmount.isAcceptableOrUnknown(data['fx_amount']!, _fxAmountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPayment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      fromMember: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_member'],
      )!,
      toMember: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_member'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      date: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      method: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}method'],
      )!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      fxRate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_rate'],
      ),
      fxRateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_rate_date'],
      ),
      fxSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_source'],
      ),
      fxCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_currency'],
      ),
      fxAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fx_amount'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  Payments createAlias(String alias) {
    return Payments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalPayment extends DataClass implements Insertable<LocalPayment> {
  final String id;
  final String groupId;
  final String fromMember;
  final String toMember;
  final int amount;
  final String currency;
  final String date;
  final String method;
  final String? note;
  final String? fxRate;
  final String? fxRateDate;
  final String? fxSource;
  final String? fxCurrency;
  final int? fxAmount;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? clientUpdatedAt;
  final String? deletedAt;
  final String? deletedBy;
  final int seq;
  final String syncState;
  const LocalPayment({
    required this.id,
    required this.groupId,
    required this.fromMember,
    required this.toMember,
    required this.amount,
    required this.currency,
    required this.date,
    required this.method,
    this.note,
    this.fxRate,
    this.fxRateDate,
    this.fxSource,
    this.fxCurrency,
    this.fxAmount,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientUpdatedAt,
    this.deletedAt,
    this.deletedBy,
    required this.seq,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['from_member'] = Variable<String>(fromMember);
    map['to_member'] = Variable<String>(toMember);
    map['amount'] = Variable<int>(amount);
    map['currency'] = Variable<String>(currency);
    map['date'] = Variable<String>(date);
    map['method'] = Variable<String>(method);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || fxRate != null) {
      map['fx_rate'] = Variable<String>(fxRate);
    }
    if (!nullToAbsent || fxRateDate != null) {
      map['fx_rate_date'] = Variable<String>(fxRateDate);
    }
    if (!nullToAbsent || fxSource != null) {
      map['fx_source'] = Variable<String>(fxSource);
    }
    if (!nullToAbsent || fxCurrency != null) {
      map['fx_currency'] = Variable<String>(fxCurrency);
    }
    if (!nullToAbsent || fxAmount != null) {
      map['fx_amount'] = Variable<int>(fxAmount);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['seq'] = Variable<int>(seq);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  PaymentsCompanion toCompanion(bool nullToAbsent) {
    return PaymentsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      fromMember: Value(fromMember),
      toMember: Value(toMember),
      amount: Value(amount),
      currency: Value(currency),
      date: Value(date),
      method: Value(method),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      fxRate: fxRate == null && nullToAbsent ? const Value.absent() : Value(fxRate),
      fxRateDate: fxRateDate == null && nullToAbsent ? const Value.absent() : Value(fxRateDate),
      fxSource: fxSource == null && nullToAbsent ? const Value.absent() : Value(fxSource),
      fxCurrency: fxCurrency == null && nullToAbsent ? const Value.absent() : Value(fxCurrency),
      fxAmount: fxAmount == null && nullToAbsent ? const Value.absent() : Value(fxAmount),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      createdBy: createdBy == null && nullToAbsent ? const Value.absent() : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent ? const Value.absent() : Value(updatedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent ? const Value.absent() : Value(deletedBy),
      seq: Value(seq),
      syncState: Value(syncState),
    );
  }

  factory LocalPayment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPayment(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      fromMember: serializer.fromJson<String>(json['from_member']),
      toMember: serializer.fromJson<String>(json['to_member']),
      amount: serializer.fromJson<int>(json['amount']),
      currency: serializer.fromJson<String>(json['currency']),
      date: serializer.fromJson<String>(json['date']),
      method: serializer.fromJson<String>(json['method']),
      note: serializer.fromJson<String?>(json['note']),
      fxRate: serializer.fromJson<String?>(json['fx_rate']),
      fxRateDate: serializer.fromJson<String?>(json['fx_rate_date']),
      fxSource: serializer.fromJson<String?>(json['fx_source']),
      fxCurrency: serializer.fromJson<String?>(json['fx_currency']),
      fxAmount: serializer.fromJson<int?>(json['fx_amount']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      createdBy: serializer.fromJson<String?>(json['created_by']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      updatedBy: serializer.fromJson<String?>(json['updated_by']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      deletedBy: serializer.fromJson<String?>(json['deleted_by']),
      seq: serializer.fromJson<int>(json['seq']),
      syncState: serializer.fromJson<String>(json['sync_state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'group_id': serializer.toJson<String>(groupId),
      'from_member': serializer.toJson<String>(fromMember),
      'to_member': serializer.toJson<String>(toMember),
      'amount': serializer.toJson<int>(amount),
      'currency': serializer.toJson<String>(currency),
      'date': serializer.toJson<String>(date),
      'method': serializer.toJson<String>(method),
      'note': serializer.toJson<String?>(note),
      'fx_rate': serializer.toJson<String?>(fxRate),
      'fx_rate_date': serializer.toJson<String?>(fxRateDate),
      'fx_source': serializer.toJson<String?>(fxSource),
      'fx_currency': serializer.toJson<String?>(fxCurrency),
      'fx_amount': serializer.toJson<int?>(fxAmount),
      'created_at': serializer.toJson<String?>(createdAt),
      'created_by': serializer.toJson<String?>(createdBy),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'updated_by': serializer.toJson<String?>(updatedBy),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'deleted_by': serializer.toJson<String?>(deletedBy),
      'seq': serializer.toJson<int>(seq),
      'sync_state': serializer.toJson<String>(syncState),
    };
  }

  LocalPayment copyWith({
    String? id,
    String? groupId,
    String? fromMember,
    String? toMember,
    int? amount,
    String? currency,
    String? date,
    String? method,
    Value<String?> note = const Value.absent(),
    Value<String?> fxRate = const Value.absent(),
    Value<String?> fxRateDate = const Value.absent(),
    Value<String?> fxSource = const Value.absent(),
    Value<String?> fxCurrency = const Value.absent(),
    Value<int?> fxAmount = const Value.absent(),
    Value<String?> createdAt = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> clientUpdatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    int? seq,
    String? syncState,
  }) => LocalPayment(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    fromMember: fromMember ?? this.fromMember,
    toMember: toMember ?? this.toMember,
    amount: amount ?? this.amount,
    currency: currency ?? this.currency,
    date: date ?? this.date,
    method: method ?? this.method,
    note: note.present ? note.value : this.note,
    fxRate: fxRate.present ? fxRate.value : this.fxRate,
    fxRateDate: fxRateDate.present ? fxRateDate.value : this.fxRateDate,
    fxSource: fxSource.present ? fxSource.value : this.fxSource,
    fxCurrency: fxCurrency.present ? fxCurrency.value : this.fxCurrency,
    fxAmount: fxAmount.present ? fxAmount.value : this.fxAmount,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    seq: seq ?? this.seq,
    syncState: syncState ?? this.syncState,
  );
  LocalPayment copyWithCompanion(PaymentsCompanion data) {
    return LocalPayment(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      fromMember: data.fromMember.present ? data.fromMember.value : this.fromMember,
      toMember: data.toMember.present ? data.toMember.value : this.toMember,
      amount: data.amount.present ? data.amount.value : this.amount,
      currency: data.currency.present ? data.currency.value : this.currency,
      date: data.date.present ? data.date.value : this.date,
      method: data.method.present ? data.method.value : this.method,
      note: data.note.present ? data.note.value : this.note,
      fxRate: data.fxRate.present ? data.fxRate.value : this.fxRate,
      fxRateDate: data.fxRateDate.present ? data.fxRateDate.value : this.fxRateDate,
      fxSource: data.fxSource.present ? data.fxSource.value : this.fxSource,
      fxCurrency: data.fxCurrency.present ? data.fxCurrency.value : this.fxCurrency,
      fxAmount: data.fxAmount.present ? data.fxAmount.value : this.fxAmount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      seq: data.seq.present ? data.seq.value : this.seq,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPayment(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('fromMember: $fromMember, ')
          ..write('toMember: $toMember, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('method: $method, ')
          ..write('note: $note, ')
          ..write('fxRate: $fxRate, ')
          ..write('fxRateDate: $fxRateDate, ')
          ..write('fxSource: $fxSource, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxAmount: $fxAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    groupId,
    fromMember,
    toMember,
    amount,
    currency,
    date,
    method,
    note,
    fxRate,
    fxRateDate,
    fxSource,
    fxCurrency,
    fxAmount,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPayment &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.fromMember == this.fromMember &&
          other.toMember == this.toMember &&
          other.amount == this.amount &&
          other.currency == this.currency &&
          other.date == this.date &&
          other.method == this.method &&
          other.note == this.note &&
          other.fxRate == this.fxRate &&
          other.fxRateDate == this.fxRateDate &&
          other.fxSource == this.fxSource &&
          other.fxCurrency == this.fxCurrency &&
          other.fxAmount == this.fxAmount &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.seq == this.seq &&
          other.syncState == this.syncState);
}

class PaymentsCompanion extends UpdateCompanion<LocalPayment> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> fromMember;
  final Value<String> toMember;
  final Value<int> amount;
  final Value<String> currency;
  final Value<String> date;
  final Value<String> method;
  final Value<String?> note;
  final Value<String?> fxRate;
  final Value<String?> fxRateDate;
  final Value<String?> fxSource;
  final Value<String?> fxCurrency;
  final Value<int?> fxAmount;
  final Value<String?> createdAt;
  final Value<String?> createdBy;
  final Value<String?> updatedAt;
  final Value<String?> updatedBy;
  final Value<String?> clientUpdatedAt;
  final Value<String?> deletedAt;
  final Value<String?> deletedBy;
  final Value<int> seq;
  final Value<String> syncState;
  final Value<int> rowid;
  const PaymentsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.fromMember = const Value.absent(),
    this.toMember = const Value.absent(),
    this.amount = const Value.absent(),
    this.currency = const Value.absent(),
    this.date = const Value.absent(),
    this.method = const Value.absent(),
    this.note = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.fxRateDate = const Value.absent(),
    this.fxSource = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxAmount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentsCompanion.insert({
    required String id,
    required String groupId,
    required String fromMember,
    required String toMember,
    required int amount,
    required String currency,
    required String date,
    this.method = const Value.absent(),
    this.note = const Value.absent(),
    this.fxRate = const Value.absent(),
    this.fxRateDate = const Value.absent(),
    this.fxSource = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxAmount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       fromMember = Value(fromMember),
       toMember = Value(toMember),
       amount = Value(amount),
       currency = Value(currency),
       date = Value(date);
  static Insertable<LocalPayment> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? fromMember,
    Expression<String>? toMember,
    Expression<int>? amount,
    Expression<String>? currency,
    Expression<String>? date,
    Expression<String>? method,
    Expression<String>? note,
    Expression<String>? fxRate,
    Expression<String>? fxRateDate,
    Expression<String>? fxSource,
    Expression<String>? fxCurrency,
    Expression<int>? fxAmount,
    Expression<String>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? updatedAt,
    Expression<String>? updatedBy,
    Expression<String>? clientUpdatedAt,
    Expression<String>? deletedAt,
    Expression<String>? deletedBy,
    Expression<int>? seq,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (fromMember != null) 'from_member': fromMember,
      if (toMember != null) 'to_member': toMember,
      if (amount != null) 'amount': amount,
      if (currency != null) 'currency': currency,
      if (date != null) 'date': date,
      if (method != null) 'method': method,
      if (note != null) 'note': note,
      if (fxRate != null) 'fx_rate': fxRate,
      if (fxRateDate != null) 'fx_rate_date': fxRateDate,
      if (fxSource != null) 'fx_source': fxSource,
      if (fxCurrency != null) 'fx_currency': fxCurrency,
      if (fxAmount != null) 'fx_amount': fxAmount,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (seq != null) 'seq': seq,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? fromMember,
    Value<String>? toMember,
    Value<int>? amount,
    Value<String>? currency,
    Value<String>? date,
    Value<String>? method,
    Value<String?>? note,
    Value<String?>? fxRate,
    Value<String?>? fxRateDate,
    Value<String?>? fxSource,
    Value<String?>? fxCurrency,
    Value<int?>? fxAmount,
    Value<String?>? createdAt,
    Value<String?>? createdBy,
    Value<String?>? updatedAt,
    Value<String?>? updatedBy,
    Value<String?>? clientUpdatedAt,
    Value<String?>? deletedAt,
    Value<String?>? deletedBy,
    Value<int>? seq,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return PaymentsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      fromMember: fromMember ?? this.fromMember,
      toMember: toMember ?? this.toMember,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      method: method ?? this.method,
      note: note ?? this.note,
      fxRate: fxRate ?? this.fxRate,
      fxRateDate: fxRateDate ?? this.fxRateDate,
      fxSource: fxSource ?? this.fxSource,
      fxCurrency: fxCurrency ?? this.fxCurrency,
      fxAmount: fxAmount ?? this.fxAmount,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      seq: seq ?? this.seq,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (fromMember.present) {
      map['from_member'] = Variable<String>(fromMember.value);
    }
    if (toMember.present) {
      map['to_member'] = Variable<String>(toMember.value);
    }
    if (amount.present) {
      map['amount'] = Variable<int>(amount.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (method.present) {
      map['method'] = Variable<String>(method.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (fxRate.present) {
      map['fx_rate'] = Variable<String>(fxRate.value);
    }
    if (fxRateDate.present) {
      map['fx_rate_date'] = Variable<String>(fxRateDate.value);
    }
    if (fxSource.present) {
      map['fx_source'] = Variable<String>(fxSource.value);
    }
    if (fxCurrency.present) {
      map['fx_currency'] = Variable<String>(fxCurrency.value);
    }
    if (fxAmount.present) {
      map['fx_amount'] = Variable<int>(fxAmount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('fromMember: $fromMember, ')
          ..write('toMember: $toMember, ')
          ..write('amount: $amount, ')
          ..write('currency: $currency, ')
          ..write('date: $date, ')
          ..write('method: $method, ')
          ..write('note: $note, ')
          ..write('fxRate: $fxRate, ')
          ..write('fxRateDate: $fxRateDate, ')
          ..write('fxSource: $fxSource, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxAmount: $fxAmount, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Comments extends Table with TableInfo<Comments, LocalComment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Comments(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta('targetType');
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta('targetId');
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdByMeta = const VerificationMeta('createdBy');
  late final GeneratedColumn<String> createdBy = GeneratedColumn<String>(
    'created_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _updatedByMeta = const VerificationMeta('updatedBy');
  late final GeneratedColumn<String> updatedBy = GeneratedColumn<String>(
    'updated_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta('deletedAt');
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deletedByMeta = const VerificationMeta('deletedBy');
  late final GeneratedColumn<String> deletedBy = GeneratedColumn<String>(
    'deleted_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta('syncState');
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'synced\'',
    defaultValue: const CustomExpression('\'synced\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    targetType,
    targetId,
    body,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'comments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalComment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_targetTypeMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_targetIdMeta);
    }
    if (data.containsKey('body')) {
      context.handle(_bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('created_by')) {
      context.handle(
        _createdByMeta,
        createdBy.isAcceptableOrUnknown(data['created_by']!, _createdByMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('updated_by')) {
      context.handle(
        _updatedByMeta,
        updatedBy.isAcceptableOrUnknown(data['updated_by']!, _updatedByMeta),
      );
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('deleted_by')) {
      context.handle(
        _deletedByMeta,
        deletedBy.isAcceptableOrUnknown(data['deleted_by']!, _deletedByMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalComment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalComment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      )!,
      body: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      createdBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
      updatedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by'],
      ),
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
      deletedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_by'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  Comments createAlias(String alias) {
    return Comments(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalComment extends DataClass implements Insertable<LocalComment> {
  final String id;
  final String groupId;
  final String targetType;
  final String targetId;
  final String body;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;
  final String? clientUpdatedAt;
  final String? deletedAt;
  final String? deletedBy;
  final int seq;
  final String syncState;
  const LocalComment({
    required this.id,
    required this.groupId,
    required this.targetType,
    required this.targetId,
    required this.body,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
    this.clientUpdatedAt,
    this.deletedAt,
    this.deletedBy,
    required this.seq,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['target_type'] = Variable<String>(targetType);
    map['target_id'] = Variable<String>(targetId);
    map['body'] = Variable<String>(body);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || createdBy != null) {
      map['created_by'] = Variable<String>(createdBy);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    if (!nullToAbsent || updatedBy != null) {
      map['updated_by'] = Variable<String>(updatedBy);
    }
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    if (!nullToAbsent || deletedBy != null) {
      map['deleted_by'] = Variable<String>(deletedBy);
    }
    map['seq'] = Variable<int>(seq);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  CommentsCompanion toCompanion(bool nullToAbsent) {
    return CommentsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      targetType: Value(targetType),
      targetId: Value(targetId),
      body: Value(body),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      createdBy: createdBy == null && nullToAbsent ? const Value.absent() : Value(createdBy),
      updatedAt: updatedAt == null && nullToAbsent ? const Value.absent() : Value(updatedAt),
      updatedBy: updatedBy == null && nullToAbsent ? const Value.absent() : Value(updatedBy),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      deletedAt: deletedAt == null && nullToAbsent ? const Value.absent() : Value(deletedAt),
      deletedBy: deletedBy == null && nullToAbsent ? const Value.absent() : Value(deletedBy),
      seq: Value(seq),
      syncState: Value(syncState),
    );
  }

  factory LocalComment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalComment(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      targetType: serializer.fromJson<String>(json['target_type']),
      targetId: serializer.fromJson<String>(json['target_id']),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      createdBy: serializer.fromJson<String?>(json['created_by']),
      updatedAt: serializer.fromJson<String?>(json['updated_at']),
      updatedBy: serializer.fromJson<String?>(json['updated_by']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
      deletedBy: serializer.fromJson<String?>(json['deleted_by']),
      seq: serializer.fromJson<int>(json['seq']),
      syncState: serializer.fromJson<String>(json['sync_state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'group_id': serializer.toJson<String>(groupId),
      'target_type': serializer.toJson<String>(targetType),
      'target_id': serializer.toJson<String>(targetId),
      'body': serializer.toJson<String>(body),
      'created_at': serializer.toJson<String?>(createdAt),
      'created_by': serializer.toJson<String?>(createdBy),
      'updated_at': serializer.toJson<String?>(updatedAt),
      'updated_by': serializer.toJson<String?>(updatedBy),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
      'deleted_by': serializer.toJson<String?>(deletedBy),
      'seq': serializer.toJson<int>(seq),
      'sync_state': serializer.toJson<String>(syncState),
    };
  }

  LocalComment copyWith({
    String? id,
    String? groupId,
    String? targetType,
    String? targetId,
    String? body,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> createdBy = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
    Value<String?> updatedBy = const Value.absent(),
    Value<String?> clientUpdatedAt = const Value.absent(),
    Value<String?> deletedAt = const Value.absent(),
    Value<String?> deletedBy = const Value.absent(),
    int? seq,
    String? syncState,
  }) => LocalComment(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    targetType: targetType ?? this.targetType,
    targetId: targetId ?? this.targetId,
    body: body ?? this.body,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    createdBy: createdBy.present ? createdBy.value : this.createdBy,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    updatedBy: updatedBy.present ? updatedBy.value : this.updatedBy,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    deletedBy: deletedBy.present ? deletedBy.value : this.deletedBy,
    seq: seq ?? this.seq,
    syncState: syncState ?? this.syncState,
  );
  LocalComment copyWithCompanion(CommentsCompanion data) {
    return LocalComment(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      targetType: data.targetType.present ? data.targetType.value : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdBy: data.createdBy.present ? data.createdBy.value : this.createdBy,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      updatedBy: data.updatedBy.present ? data.updatedBy.value : this.updatedBy,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      deletedBy: data.deletedBy.present ? data.deletedBy.value : this.deletedBy,
      seq: data.seq.present ? data.seq.value : this.seq,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalComment(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    targetType,
    targetId,
    body,
    createdAt,
    createdBy,
    updatedAt,
    updatedBy,
    clientUpdatedAt,
    deletedAt,
    deletedBy,
    seq,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalComment &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.body == this.body &&
          other.createdAt == this.createdAt &&
          other.createdBy == this.createdBy &&
          other.updatedAt == this.updatedAt &&
          other.updatedBy == this.updatedBy &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deletedAt == this.deletedAt &&
          other.deletedBy == this.deletedBy &&
          other.seq == this.seq &&
          other.syncState == this.syncState);
}

class CommentsCompanion extends UpdateCompanion<LocalComment> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String> targetType;
  final Value<String> targetId;
  final Value<String> body;
  final Value<String?> createdAt;
  final Value<String?> createdBy;
  final Value<String?> updatedAt;
  final Value<String?> updatedBy;
  final Value<String?> clientUpdatedAt;
  final Value<String?> deletedAt;
  final Value<String?> deletedBy;
  final Value<int> seq;
  final Value<String> syncState;
  final Value<int> rowid;
  const CommentsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CommentsCompanion.insert({
    required String id,
    required String groupId,
    required String targetType,
    required String targetId,
    required String body,
    this.createdAt = const Value.absent(),
    this.createdBy = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.updatedBy = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.deletedBy = const Value.absent(),
    this.seq = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       targetType = Value(targetType),
       targetId = Value(targetId),
       body = Value(body);
  static Insertable<LocalComment> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? body,
    Expression<String>? createdAt,
    Expression<String>? createdBy,
    Expression<String>? updatedAt,
    Expression<String>? updatedBy,
    Expression<String>? clientUpdatedAt,
    Expression<String>? deletedAt,
    Expression<String>? deletedBy,
    Expression<int>? seq,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (deletedBy != null) 'deleted_by': deletedBy,
      if (seq != null) 'seq': seq,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CommentsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String>? targetType,
    Value<String>? targetId,
    Value<String>? body,
    Value<String?>? createdAt,
    Value<String?>? createdBy,
    Value<String?>? updatedAt,
    Value<String?>? updatedBy,
    Value<String?>? clientUpdatedAt,
    Value<String?>? deletedAt,
    Value<String?>? deletedBy,
    Value<int>? seq,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return CommentsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      seq: seq ?? this.seq,
      syncState: syncState ?? this.syncState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (createdBy.present) {
      map['created_by'] = Variable<String>(createdBy.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (updatedBy.present) {
      map['updated_by'] = Variable<String>(updatedBy.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (deletedBy.present) {
      map['deleted_by'] = Variable<String>(deletedBy.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CommentsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdBy: $createdBy, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('updatedBy: $updatedBy, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('deletedBy: $deletedBy, ')
          ..write('seq: $seq, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Activity extends Table with TableInfo<Activity, LocalActivity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Activity(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _actorUserIdMeta = const VerificationMeta('actorUserId');
  late final GeneratedColumn<String> actorUserId = GeneratedColumn<String>(
    'actor_user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _actorMemberIdMeta = const VerificationMeta('actorMemberId');
  late final GeneratedColumn<String> actorMemberId = GeneratedColumn<String>(
    'actor_member_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _targetTypeMeta = const VerificationMeta('targetType');
  late final GeneratedColumn<String> targetType = GeneratedColumn<String>(
    'target_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta('targetId');
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'{}\'',
    defaultValue: const CustomExpression('\'{}\''),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    actorUserId,
    actorMemberId,
    type,
    targetType,
    targetId,
    data,
    createdAt,
    seq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalActivity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('actor_user_id')) {
      context.handle(
        _actorUserIdMeta,
        actorUserId.isAcceptableOrUnknown(data['actor_user_id']!, _actorUserIdMeta),
      );
    }
    if (data.containsKey('actor_member_id')) {
      context.handle(
        _actorMemberIdMeta,
        actorMemberId.isAcceptableOrUnknown(data['actor_member_id']!, _actorMemberIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(_typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_type')) {
      context.handle(
        _targetTypeMeta,
        targetType.isAcceptableOrUnknown(data['target_type']!, _targetTypeMeta),
      );
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(_dataMeta, this.data.isAcceptableOrUnknown(data['data']!, _dataMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalActivity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalActivity(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      actorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_user_id'],
      ),
      actorMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_member_id'],
      ),
      type: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      targetType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_type'],
      ),
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      data: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}data'])!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  Activity createAlias(String alias) {
    return Activity(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalActivity extends DataClass implements Insertable<LocalActivity> {
  final String id;
  final String groupId;
  final String? actorUserId;
  final String? actorMemberId;
  final String type;
  final String? targetType;
  final String? targetId;
  final String data;
  final String? createdAt;
  final int seq;
  const LocalActivity({
    required this.id,
    required this.groupId,
    this.actorUserId,
    this.actorMemberId,
    required this.type,
    this.targetType,
    this.targetId,
    required this.data,
    this.createdAt,
    required this.seq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    if (!nullToAbsent || actorUserId != null) {
      map['actor_user_id'] = Variable<String>(actorUserId);
    }
    if (!nullToAbsent || actorMemberId != null) {
      map['actor_member_id'] = Variable<String>(actorMemberId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || targetType != null) {
      map['target_type'] = Variable<String>(targetType);
    }
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    map['data'] = Variable<String>(data);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    map['seq'] = Variable<int>(seq);
    return map;
  }

  ActivityCompanion toCompanion(bool nullToAbsent) {
    return ActivityCompanion(
      id: Value(id),
      groupId: Value(groupId),
      actorUserId: actorUserId == null && nullToAbsent ? const Value.absent() : Value(actorUserId),
      actorMemberId: actorMemberId == null && nullToAbsent
          ? const Value.absent()
          : Value(actorMemberId),
      type: Value(type),
      targetType: targetType == null && nullToAbsent ? const Value.absent() : Value(targetType),
      targetId: targetId == null && nullToAbsent ? const Value.absent() : Value(targetId),
      data: Value(data),
      createdAt: createdAt == null && nullToAbsent ? const Value.absent() : Value(createdAt),
      seq: Value(seq),
    );
  }

  factory LocalActivity.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalActivity(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      actorUserId: serializer.fromJson<String?>(json['actor_user_id']),
      actorMemberId: serializer.fromJson<String?>(json['actor_member_id']),
      type: serializer.fromJson<String>(json['type']),
      targetType: serializer.fromJson<String?>(json['target_type']),
      targetId: serializer.fromJson<String?>(json['target_id']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<String?>(json['created_at']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'group_id': serializer.toJson<String>(groupId),
      'actor_user_id': serializer.toJson<String?>(actorUserId),
      'actor_member_id': serializer.toJson<String?>(actorMemberId),
      'type': serializer.toJson<String>(type),
      'target_type': serializer.toJson<String?>(targetType),
      'target_id': serializer.toJson<String?>(targetId),
      'data': serializer.toJson<String>(data),
      'created_at': serializer.toJson<String?>(createdAt),
      'seq': serializer.toJson<int>(seq),
    };
  }

  LocalActivity copyWith({
    String? id,
    String? groupId,
    Value<String?> actorUserId = const Value.absent(),
    Value<String?> actorMemberId = const Value.absent(),
    String? type,
    Value<String?> targetType = const Value.absent(),
    Value<String?> targetId = const Value.absent(),
    String? data,
    Value<String?> createdAt = const Value.absent(),
    int? seq,
  }) => LocalActivity(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    actorUserId: actorUserId.present ? actorUserId.value : this.actorUserId,
    actorMemberId: actorMemberId.present ? actorMemberId.value : this.actorMemberId,
    type: type ?? this.type,
    targetType: targetType.present ? targetType.value : this.targetType,
    targetId: targetId.present ? targetId.value : this.targetId,
    data: data ?? this.data,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    seq: seq ?? this.seq,
  );
  LocalActivity copyWithCompanion(ActivityCompanion data) {
    return LocalActivity(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      actorUserId: data.actorUserId.present ? data.actorUserId.value : this.actorUserId,
      actorMemberId: data.actorMemberId.present ? data.actorMemberId.value : this.actorMemberId,
      type: data.type.present ? data.type.value : this.type,
      targetType: data.targetType.present ? data.targetType.value : this.targetType,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalActivity(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('type: $type, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    actorUserId,
    actorMemberId,
    type,
    targetType,
    targetId,
    data,
    createdAt,
    seq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalActivity &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.actorUserId == this.actorUserId &&
          other.actorMemberId == this.actorMemberId &&
          other.type == this.type &&
          other.targetType == this.targetType &&
          other.targetId == this.targetId &&
          other.data == this.data &&
          other.createdAt == this.createdAt &&
          other.seq == this.seq);
}

class ActivityCompanion extends UpdateCompanion<LocalActivity> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<String?> actorUserId;
  final Value<String?> actorMemberId;
  final Value<String> type;
  final Value<String?> targetType;
  final Value<String?> targetId;
  final Value<String> data;
  final Value<String?> createdAt;
  final Value<int> seq;
  final Value<int> rowid;
  const ActivityCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.actorUserId = const Value.absent(),
    this.actorMemberId = const Value.absent(),
    this.type = const Value.absent(),
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ActivityCompanion.insert({
    required String id,
    required String groupId,
    this.actorUserId = const Value.absent(),
    this.actorMemberId = const Value.absent(),
    required String type,
    this.targetType = const Value.absent(),
    this.targetId = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       type = Value(type);
  static Insertable<LocalActivity> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<String>? actorUserId,
    Expression<String>? actorMemberId,
    Expression<String>? type,
    Expression<String>? targetType,
    Expression<String>? targetId,
    Expression<String>? data,
    Expression<String>? createdAt,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (actorUserId != null) 'actor_user_id': actorUserId,
      if (actorMemberId != null) 'actor_member_id': actorMemberId,
      if (type != null) 'type': type,
      if (targetType != null) 'target_type': targetType,
      if (targetId != null) 'target_id': targetId,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ActivityCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<String?>? actorUserId,
    Value<String?>? actorMemberId,
    Value<String>? type,
    Value<String?>? targetType,
    Value<String?>? targetId,
    Value<String>? data,
    Value<String?>? createdAt,
    Value<int>? seq,
    Value<int>? rowid,
  }) {
    return ActivityCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      actorUserId: actorUserId ?? this.actorUserId,
      actorMemberId: actorMemberId ?? this.actorMemberId,
      type: type ?? this.type,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (actorUserId.present) {
      map['actor_user_id'] = Variable<String>(actorUserId.value);
    }
    if (actorMemberId.present) {
      map['actor_member_id'] = Variable<String>(actorMemberId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetType.present) {
      map['target_type'] = Variable<String>(targetType.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('actorUserId: $actorUserId, ')
          ..write('actorMemberId: $actorMemberId, ')
          ..write('type: $type, ')
          ..write('targetType: $targetType, ')
          ..write('targetId: $targetId, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ExpenseParts extends Table with TableInfo<ExpenseParts, ExpensePart> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ExpenseParts(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _expenseIdMeta = const VerificationMeta('expenseId');
  late final GeneratedColumn<String> expenseId = GeneratedColumn<String>(
    'expense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _memberIdMeta = const VerificationMeta('memberId');
  late final GeneratedColumn<String> memberId = GeneratedColumn<String>(
    'member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta('currency');
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  late final GeneratedColumn<int> paid = GeneratedColumn<int>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _owedMeta = const VerificationMeta('owed');
  late final GeneratedColumn<int> owed = GeneratedColumn<int>(
    'owed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _fxCurrencyMeta = const VerificationMeta('fxCurrency');
  late final GeneratedColumn<String> fxCurrency = GeneratedColumn<String>(
    'fx_currency',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxPaidMeta = const VerificationMeta('fxPaid');
  late final GeneratedColumn<int> fxPaid = GeneratedColumn<int>(
    'fx_paid',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _fxOwedMeta = const VerificationMeta('fxOwed');
  late final GeneratedColumn<int> fxOwed = GeneratedColumn<int>(
    'fx_owed',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    expenseId,
    groupId,
    memberId,
    currency,
    paid,
    owed,
    fxCurrency,
    fxPaid,
    fxOwed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpensePart> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('expense_id')) {
      context.handle(
        _expenseIdMeta,
        expenseId.isAcceptableOrUnknown(data['expense_id']!, _expenseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_expenseIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('member_id')) {
      context.handle(
        _memberIdMeta,
        memberId.isAcceptableOrUnknown(data['member_id']!, _memberIdMeta),
      );
    } else if (isInserting) {
      context.missing(_memberIdMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(_paidMeta, paid.isAcceptableOrUnknown(data['paid']!, _paidMeta));
    }
    if (data.containsKey('owed')) {
      context.handle(_owedMeta, owed.isAcceptableOrUnknown(data['owed']!, _owedMeta));
    }
    if (data.containsKey('fx_currency')) {
      context.handle(
        _fxCurrencyMeta,
        fxCurrency.isAcceptableOrUnknown(data['fx_currency']!, _fxCurrencyMeta),
      );
    }
    if (data.containsKey('fx_paid')) {
      context.handle(_fxPaidMeta, fxPaid.isAcceptableOrUnknown(data['fx_paid']!, _fxPaidMeta));
    }
    if (data.containsKey('fx_owed')) {
      context.handle(_fxOwedMeta, fxOwed.isAcceptableOrUnknown(data['fx_owed']!, _fxOwedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {expenseId, memberId};
  @override
  ExpensePart map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpensePart(
      expenseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}expense_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      memberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_id'],
      )!,
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      paid: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}paid'])!,
      owed: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}owed'])!,
      fxCurrency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fx_currency'],
      ),
      fxPaid: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fx_paid'],
      ),
      fxOwed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fx_owed'],
      ),
    );
  }

  @override
  ExpenseParts createAlias(String alias) {
    return ExpenseParts(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const ['PRIMARY KEY(expense_id, member_id)'];
  @override
  bool get dontWriteConstraints => true;
}

class ExpensePart extends DataClass implements Insertable<ExpensePart> {
  final String expenseId;
  final String groupId;
  final String memberId;
  final String currency;
  final int paid;
  final int owed;
  final String? fxCurrency;
  final int? fxPaid;
  final int? fxOwed;
  const ExpensePart({
    required this.expenseId,
    required this.groupId,
    required this.memberId,
    required this.currency,
    required this.paid,
    required this.owed,
    this.fxCurrency,
    this.fxPaid,
    this.fxOwed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['expense_id'] = Variable<String>(expenseId);
    map['group_id'] = Variable<String>(groupId);
    map['member_id'] = Variable<String>(memberId);
    map['currency'] = Variable<String>(currency);
    map['paid'] = Variable<int>(paid);
    map['owed'] = Variable<int>(owed);
    if (!nullToAbsent || fxCurrency != null) {
      map['fx_currency'] = Variable<String>(fxCurrency);
    }
    if (!nullToAbsent || fxPaid != null) {
      map['fx_paid'] = Variable<int>(fxPaid);
    }
    if (!nullToAbsent || fxOwed != null) {
      map['fx_owed'] = Variable<int>(fxOwed);
    }
    return map;
  }

  ExpensePartsCompanion toCompanion(bool nullToAbsent) {
    return ExpensePartsCompanion(
      expenseId: Value(expenseId),
      groupId: Value(groupId),
      memberId: Value(memberId),
      currency: Value(currency),
      paid: Value(paid),
      owed: Value(owed),
      fxCurrency: fxCurrency == null && nullToAbsent ? const Value.absent() : Value(fxCurrency),
      fxPaid: fxPaid == null && nullToAbsent ? const Value.absent() : Value(fxPaid),
      fxOwed: fxOwed == null && nullToAbsent ? const Value.absent() : Value(fxOwed),
    );
  }

  factory ExpensePart.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpensePart(
      expenseId: serializer.fromJson<String>(json['expense_id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      memberId: serializer.fromJson<String>(json['member_id']),
      currency: serializer.fromJson<String>(json['currency']),
      paid: serializer.fromJson<int>(json['paid']),
      owed: serializer.fromJson<int>(json['owed']),
      fxCurrency: serializer.fromJson<String?>(json['fx_currency']),
      fxPaid: serializer.fromJson<int?>(json['fx_paid']),
      fxOwed: serializer.fromJson<int?>(json['fx_owed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'expense_id': serializer.toJson<String>(expenseId),
      'group_id': serializer.toJson<String>(groupId),
      'member_id': serializer.toJson<String>(memberId),
      'currency': serializer.toJson<String>(currency),
      'paid': serializer.toJson<int>(paid),
      'owed': serializer.toJson<int>(owed),
      'fx_currency': serializer.toJson<String?>(fxCurrency),
      'fx_paid': serializer.toJson<int?>(fxPaid),
      'fx_owed': serializer.toJson<int?>(fxOwed),
    };
  }

  ExpensePart copyWith({
    String? expenseId,
    String? groupId,
    String? memberId,
    String? currency,
    int? paid,
    int? owed,
    Value<String?> fxCurrency = const Value.absent(),
    Value<int?> fxPaid = const Value.absent(),
    Value<int?> fxOwed = const Value.absent(),
  }) => ExpensePart(
    expenseId: expenseId ?? this.expenseId,
    groupId: groupId ?? this.groupId,
    memberId: memberId ?? this.memberId,
    currency: currency ?? this.currency,
    paid: paid ?? this.paid,
    owed: owed ?? this.owed,
    fxCurrency: fxCurrency.present ? fxCurrency.value : this.fxCurrency,
    fxPaid: fxPaid.present ? fxPaid.value : this.fxPaid,
    fxOwed: fxOwed.present ? fxOwed.value : this.fxOwed,
  );
  ExpensePart copyWithCompanion(ExpensePartsCompanion data) {
    return ExpensePart(
      expenseId: data.expenseId.present ? data.expenseId.value : this.expenseId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      memberId: data.memberId.present ? data.memberId.value : this.memberId,
      currency: data.currency.present ? data.currency.value : this.currency,
      paid: data.paid.present ? data.paid.value : this.paid,
      owed: data.owed.present ? data.owed.value : this.owed,
      fxCurrency: data.fxCurrency.present ? data.fxCurrency.value : this.fxCurrency,
      fxPaid: data.fxPaid.present ? data.fxPaid.value : this.fxPaid,
      fxOwed: data.fxOwed.present ? data.fxOwed.value : this.fxOwed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpensePart(')
          ..write('expenseId: $expenseId, ')
          ..write('groupId: $groupId, ')
          ..write('memberId: $memberId, ')
          ..write('currency: $currency, ')
          ..write('paid: $paid, ')
          ..write('owed: $owed, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxPaid: $fxPaid, ')
          ..write('fxOwed: $fxOwed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(expenseId, groupId, memberId, currency, paid, owed, fxCurrency, fxPaid, fxOwed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpensePart &&
          other.expenseId == this.expenseId &&
          other.groupId == this.groupId &&
          other.memberId == this.memberId &&
          other.currency == this.currency &&
          other.paid == this.paid &&
          other.owed == this.owed &&
          other.fxCurrency == this.fxCurrency &&
          other.fxPaid == this.fxPaid &&
          other.fxOwed == this.fxOwed);
}

class ExpensePartsCompanion extends UpdateCompanion<ExpensePart> {
  final Value<String> expenseId;
  final Value<String> groupId;
  final Value<String> memberId;
  final Value<String> currency;
  final Value<int> paid;
  final Value<int> owed;
  final Value<String?> fxCurrency;
  final Value<int?> fxPaid;
  final Value<int?> fxOwed;
  final Value<int> rowid;
  const ExpensePartsCompanion({
    this.expenseId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.memberId = const Value.absent(),
    this.currency = const Value.absent(),
    this.paid = const Value.absent(),
    this.owed = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxPaid = const Value.absent(),
    this.fxOwed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensePartsCompanion.insert({
    required String expenseId,
    required String groupId,
    required String memberId,
    required String currency,
    this.paid = const Value.absent(),
    this.owed = const Value.absent(),
    this.fxCurrency = const Value.absent(),
    this.fxPaid = const Value.absent(),
    this.fxOwed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : expenseId = Value(expenseId),
       groupId = Value(groupId),
       memberId = Value(memberId),
       currency = Value(currency);
  static Insertable<ExpensePart> custom({
    Expression<String>? expenseId,
    Expression<String>? groupId,
    Expression<String>? memberId,
    Expression<String>? currency,
    Expression<int>? paid,
    Expression<int>? owed,
    Expression<String>? fxCurrency,
    Expression<int>? fxPaid,
    Expression<int>? fxOwed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (expenseId != null) 'expense_id': expenseId,
      if (groupId != null) 'group_id': groupId,
      if (memberId != null) 'member_id': memberId,
      if (currency != null) 'currency': currency,
      if (paid != null) 'paid': paid,
      if (owed != null) 'owed': owed,
      if (fxCurrency != null) 'fx_currency': fxCurrency,
      if (fxPaid != null) 'fx_paid': fxPaid,
      if (fxOwed != null) 'fx_owed': fxOwed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensePartsCompanion copyWith({
    Value<String>? expenseId,
    Value<String>? groupId,
    Value<String>? memberId,
    Value<String>? currency,
    Value<int>? paid,
    Value<int>? owed,
    Value<String?>? fxCurrency,
    Value<int?>? fxPaid,
    Value<int?>? fxOwed,
    Value<int>? rowid,
  }) {
    return ExpensePartsCompanion(
      expenseId: expenseId ?? this.expenseId,
      groupId: groupId ?? this.groupId,
      memberId: memberId ?? this.memberId,
      currency: currency ?? this.currency,
      paid: paid ?? this.paid,
      owed: owed ?? this.owed,
      fxCurrency: fxCurrency ?? this.fxCurrency,
      fxPaid: fxPaid ?? this.fxPaid,
      fxOwed: fxOwed ?? this.fxOwed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (expenseId.present) {
      map['expense_id'] = Variable<String>(expenseId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (memberId.present) {
      map['member_id'] = Variable<String>(memberId.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (paid.present) {
      map['paid'] = Variable<int>(paid.value);
    }
    if (owed.present) {
      map['owed'] = Variable<int>(owed.value);
    }
    if (fxCurrency.present) {
      map['fx_currency'] = Variable<String>(fxCurrency.value);
    }
    if (fxPaid.present) {
      map['fx_paid'] = Variable<int>(fxPaid.value);
    }
    if (fxOwed.present) {
      map['fx_owed'] = Variable<int>(fxOwed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensePartsCompanion(')
          ..write('expenseId: $expenseId, ')
          ..write('groupId: $groupId, ')
          ..write('memberId: $memberId, ')
          ..write('currency: $currency, ')
          ..write('paid: $paid, ')
          ..write('owed: $owed, ')
          ..write('fxCurrency: $fxCurrency, ')
          ..write('fxPaid: $fxPaid, ')
          ..write('fxOwed: $fxOwed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Outbox extends Table with TableInfo<Outbox, OutboxItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY AUTOINCREMENT',
  );
  static const VerificationMeta _mutationIdMeta = const VerificationMeta('mutationId');
  late final GeneratedColumn<String> mutationId = GeneratedColumn<String>(
    'mutation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta('attempts');
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta('lastError');
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT \'queued\'',
    defaultValue: const CustomExpression('\'queued\''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    seq,
    mutationId,
    entity,
    op,
    recordId,
    groupId,
    payload,
    clientUpdatedAt,
    createdAt,
    attempts,
    lastError,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    if (data.containsKey('mutation_id')) {
      context.handle(
        _mutationIdMeta,
        mutationId.isAcceptableOrUnknown(data['mutation_id']!, _mutationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mutationIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(_entityMeta, entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_clientUpdatedAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta, status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {seq};
  @override
  OutboxItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxItem(
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
      mutationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mutation_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      op: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}op'])!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class OutboxItem extends DataClass implements Insertable<OutboxItem> {
  final int seq;
  final String mutationId;
  final String entity;
  final String op;
  final String recordId;
  final String groupId;
  final String payload;
  final String clientUpdatedAt;
  final String createdAt;
  final int attempts;
  final String? lastError;
  final String status;
  const OutboxItem({
    required this.seq,
    required this.mutationId,
    required this.entity,
    required this.op,
    required this.recordId,
    required this.groupId,
    required this.payload,
    required this.clientUpdatedAt,
    required this.createdAt,
    required this.attempts,
    this.lastError,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['seq'] = Variable<int>(seq);
    map['mutation_id'] = Variable<String>(mutationId);
    map['entity'] = Variable<String>(entity);
    map['op'] = Variable<String>(op);
    map['record_id'] = Variable<String>(recordId);
    map['group_id'] = Variable<String>(groupId);
    map['payload'] = Variable<String>(payload);
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['created_at'] = Variable<String>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['status'] = Variable<String>(status);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      seq: Value(seq),
      mutationId: Value(mutationId),
      entity: Value(entity),
      op: Value(op),
      recordId: Value(recordId),
      groupId: Value(groupId),
      payload: Value(payload),
      clientUpdatedAt: Value(clientUpdatedAt),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent ? const Value.absent() : Value(lastError),
      status: Value(status),
    );
  }

  factory OutboxItem.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxItem(
      seq: serializer.fromJson<int>(json['seq']),
      mutationId: serializer.fromJson<String>(json['mutation_id']),
      entity: serializer.fromJson<String>(json['entity']),
      op: serializer.fromJson<String>(json['op']),
      recordId: serializer.fromJson<String>(json['record_id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      payload: serializer.fromJson<String>(json['payload']),
      clientUpdatedAt: serializer.fromJson<String>(json['client_updated_at']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['last_error']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'seq': serializer.toJson<int>(seq),
      'mutation_id': serializer.toJson<String>(mutationId),
      'entity': serializer.toJson<String>(entity),
      'op': serializer.toJson<String>(op),
      'record_id': serializer.toJson<String>(recordId),
      'group_id': serializer.toJson<String>(groupId),
      'payload': serializer.toJson<String>(payload),
      'client_updated_at': serializer.toJson<String>(clientUpdatedAt),
      'created_at': serializer.toJson<String>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
      'last_error': serializer.toJson<String?>(lastError),
      'status': serializer.toJson<String>(status),
    };
  }

  OutboxItem copyWith({
    int? seq,
    String? mutationId,
    String? entity,
    String? op,
    String? recordId,
    String? groupId,
    String? payload,
    String? clientUpdatedAt,
    String? createdAt,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    String? status,
  }) => OutboxItem(
    seq: seq ?? this.seq,
    mutationId: mutationId ?? this.mutationId,
    entity: entity ?? this.entity,
    op: op ?? this.op,
    recordId: recordId ?? this.recordId,
    groupId: groupId ?? this.groupId,
    payload: payload ?? this.payload,
    clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    status: status ?? this.status,
  );
  OutboxItem copyWithCompanion(OutboxCompanion data) {
    return OutboxItem(
      seq: data.seq.present ? data.seq.value : this.seq,
      mutationId: data.mutationId.present ? data.mutationId.value : this.mutationId,
      entity: data.entity.present ? data.entity.value : this.entity,
      op: data.op.present ? data.op.value : this.op,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      payload: data.payload.present ? data.payload.value : this.payload,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxItem(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('recordId: $recordId, ')
          ..write('groupId: $groupId, ')
          ..write('payload: $payload, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    seq,
    mutationId,
    entity,
    op,
    recordId,
    groupId,
    payload,
    clientUpdatedAt,
    createdAt,
    attempts,
    lastError,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxItem &&
          other.seq == this.seq &&
          other.mutationId == this.mutationId &&
          other.entity == this.entity &&
          other.op == this.op &&
          other.recordId == this.recordId &&
          other.groupId == this.groupId &&
          other.payload == this.payload &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.status == this.status);
}

class OutboxCompanion extends UpdateCompanion<OutboxItem> {
  final Value<int> seq;
  final Value<String> mutationId;
  final Value<String> entity;
  final Value<String> op;
  final Value<String> recordId;
  final Value<String> groupId;
  final Value<String> payload;
  final Value<String> clientUpdatedAt;
  final Value<String> createdAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<String> status;
  const OutboxCompanion({
    this.seq = const Value.absent(),
    this.mutationId = const Value.absent(),
    this.entity = const Value.absent(),
    this.op = const Value.absent(),
    this.recordId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.payload = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
  });
  OutboxCompanion.insert({
    this.seq = const Value.absent(),
    required String mutationId,
    required String entity,
    required String op,
    required String recordId,
    required String groupId,
    required String payload,
    required String clientUpdatedAt,
    required String createdAt,
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.status = const Value.absent(),
  }) : mutationId = Value(mutationId),
       entity = Value(entity),
       op = Value(op),
       recordId = Value(recordId),
       groupId = Value(groupId),
       payload = Value(payload),
       clientUpdatedAt = Value(clientUpdatedAt),
       createdAt = Value(createdAt);
  static Insertable<OutboxItem> custom({
    Expression<int>? seq,
    Expression<String>? mutationId,
    Expression<String>? entity,
    Expression<String>? op,
    Expression<String>? recordId,
    Expression<String>? groupId,
    Expression<String>? payload,
    Expression<String>? clientUpdatedAt,
    Expression<String>? createdAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (seq != null) 'seq': seq,
      if (mutationId != null) 'mutation_id': mutationId,
      if (entity != null) 'entity': entity,
      if (op != null) 'op': op,
      if (recordId != null) 'record_id': recordId,
      if (groupId != null) 'group_id': groupId,
      if (payload != null) 'payload': payload,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (status != null) 'status': status,
    });
  }

  OutboxCompanion copyWith({
    Value<int>? seq,
    Value<String>? mutationId,
    Value<String>? entity,
    Value<String>? op,
    Value<String>? recordId,
    Value<String>? groupId,
    Value<String>? payload,
    Value<String>? clientUpdatedAt,
    Value<String>? createdAt,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<String>? status,
  }) {
    return OutboxCompanion(
      seq: seq ?? this.seq,
      mutationId: mutationId ?? this.mutationId,
      entity: entity ?? this.entity,
      op: op ?? this.op,
      recordId: recordId ?? this.recordId,
      groupId: groupId ?? this.groupId,
      payload: payload ?? this.payload,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (mutationId.present) {
      map['mutation_id'] = Variable<String>(mutationId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('seq: $seq, ')
          ..write('mutationId: $mutationId, ')
          ..write('entity: $entity, ')
          ..write('op: $op, ')
          ..write('recordId: $recordId, ')
          ..write('groupId: $groupId, ')
          ..write('payload: $payload, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class SyncCursors extends Table with TableInfo<SyncCursors, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncCursors(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [scope, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('scope')) {
      context.handle(_scopeMeta, scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta));
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {scope};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  SyncCursors createAlias(String alias) {
    return SyncCursors(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  final String scope;
  final int seq;
  const SyncCursor({required this.scope, required this.seq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['scope'] = Variable<String>(scope);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(scope: Value(scope), seq: Value(seq));
  }

  factory SyncCursor.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      scope: serializer.fromJson<String>(json['scope']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'scope': serializer.toJson<String>(scope),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncCursor copyWith({String? scope, int? seq}) =>
      SyncCursor(scope: scope ?? this.scope, seq: seq ?? this.seq);
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      scope: data.scope.present ? data.scope.value : this.scope,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('scope: $scope, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(scope, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor && other.scope == this.scope && other.seq == this.seq);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> scope;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.scope = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String scope,
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : scope = Value(scope);
  static Insertable<SyncCursor> custom({
    Expression<String>? scope,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (scope != null) 'scope': scope,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({Value<String>? scope, Value<int>? seq, Value<int>? rowid}) {
    return SyncCursorsCompanion(
      scope: scope ?? this.scope,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('scope: $scope, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncMeta extends Table with TableInfo<SyncMeta, SyncMetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncMeta(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetaEntry(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  SyncMeta createAlias(String alias) {
    return SyncMeta(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class SyncMetaEntry extends DataClass implements Insertable<SyncMetaEntry> {
  final String key;
  final String value;
  const SyncMetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetaCompanion toCompanion(bool nullToAbsent) {
    return SyncMetaCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetaEntry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetaEntry copyWith({String? key, String? value}) =>
      SyncMetaEntry(key: key ?? this.key, value: value ?? this.value);
  SyncMetaEntry copyWithCompanion(SyncMetaCompanion data) {
    return SyncMetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetaEntry && other.key == this.key && other.value == this.value);
}

class SyncMetaCompanion extends UpdateCompanion<SyncMetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetaCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return SyncMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PendingUploads extends Table with TableInfo<PendingUploads, PendingUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PendingUploads(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _bucketMeta = const VerificationMeta('bucket');
  late final GeneratedColumn<String> bucket = GeneratedColumn<String>(
    'bucket',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta('localPath');
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _remotePathMeta = const VerificationMeta('remotePath');
  late final GeneratedColumn<String> remotePath = GeneratedColumn<String>(
    'remote_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta('attempts');
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, bucket, localPath, remotePath, recordId, attempts];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingUpload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('bucket')) {
      context.handle(_bucketMeta, bucket.isAcceptableOrUnknown(data['bucket']!, _bucketMeta));
    } else if (isInserting) {
      context.missing(_bucketMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('remote_path')) {
      context.handle(
        _remotePathMeta,
        remotePath.isAcceptableOrUnknown(data['remote_path']!, _remotePathMeta),
      );
    } else if (isInserting) {
      context.missing(_remotePathMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUpload(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      bucket: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      remotePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_path'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
    );
  }

  @override
  PendingUploads createAlias(String alias) {
    return PendingUploads(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class PendingUpload extends DataClass implements Insertable<PendingUpload> {
  final String id;
  final String bucket;
  final String localPath;
  final String remotePath;
  final String recordId;
  final int attempts;
  const PendingUpload({
    required this.id,
    required this.bucket,
    required this.localPath,
    required this.remotePath,
    required this.recordId,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['bucket'] = Variable<String>(bucket);
    map['local_path'] = Variable<String>(localPath);
    map['remote_path'] = Variable<String>(remotePath);
    map['record_id'] = Variable<String>(recordId);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      id: Value(id),
      bucket: Value(bucket),
      localPath: Value(localPath),
      remotePath: Value(remotePath),
      recordId: Value(recordId),
      attempts: Value(attempts),
    );
  }

  factory PendingUpload.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUpload(
      id: serializer.fromJson<String>(json['id']),
      bucket: serializer.fromJson<String>(json['bucket']),
      localPath: serializer.fromJson<String>(json['local_path']),
      remotePath: serializer.fromJson<String>(json['remote_path']),
      recordId: serializer.fromJson<String>(json['record_id']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'bucket': serializer.toJson<String>(bucket),
      'local_path': serializer.toJson<String>(localPath),
      'remote_path': serializer.toJson<String>(remotePath),
      'record_id': serializer.toJson<String>(recordId),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  PendingUpload copyWith({
    String? id,
    String? bucket,
    String? localPath,
    String? remotePath,
    String? recordId,
    int? attempts,
  }) => PendingUpload(
    id: id ?? this.id,
    bucket: bucket ?? this.bucket,
    localPath: localPath ?? this.localPath,
    remotePath: remotePath ?? this.remotePath,
    recordId: recordId ?? this.recordId,
    attempts: attempts ?? this.attempts,
  );
  PendingUpload copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUpload(
      id: data.id.present ? data.id.value : this.id,
      bucket: data.bucket.present ? data.bucket.value : this.bucket,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      remotePath: data.remotePath.present ? data.remotePath.value : this.remotePath,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUpload(')
          ..write('id: $id, ')
          ..write('bucket: $bucket, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('recordId: $recordId, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, bucket, localPath, remotePath, recordId, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUpload &&
          other.id == this.id &&
          other.bucket == this.bucket &&
          other.localPath == this.localPath &&
          other.remotePath == this.remotePath &&
          other.recordId == this.recordId &&
          other.attempts == this.attempts);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUpload> {
  final Value<String> id;
  final Value<String> bucket;
  final Value<String> localPath;
  final Value<String> remotePath;
  final Value<String> recordId;
  final Value<int> attempts;
  final Value<int> rowid;
  const PendingUploadsCompanion({
    this.id = const Value.absent(),
    this.bucket = const Value.absent(),
    this.localPath = const Value.absent(),
    this.remotePath = const Value.absent(),
    this.recordId = const Value.absent(),
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    required String id,
    required String bucket,
    required String localPath,
    required String remotePath,
    required String recordId,
    this.attempts = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       bucket = Value(bucket),
       localPath = Value(localPath),
       remotePath = Value(remotePath),
       recordId = Value(recordId);
  static Insertable<PendingUpload> custom({
    Expression<String>? id,
    Expression<String>? bucket,
    Expression<String>? localPath,
    Expression<String>? remotePath,
    Expression<String>? recordId,
    Expression<int>? attempts,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (bucket != null) 'bucket': bucket,
      if (localPath != null) 'local_path': localPath,
      if (remotePath != null) 'remote_path': remotePath,
      if (recordId != null) 'record_id': recordId,
      if (attempts != null) 'attempts': attempts,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadsCompanion copyWith({
    Value<String>? id,
    Value<String>? bucket,
    Value<String>? localPath,
    Value<String>? remotePath,
    Value<String>? recordId,
    Value<int>? attempts,
    Value<int>? rowid,
  }) {
    return PendingUploadsCompanion(
      id: id ?? this.id,
      bucket: bucket ?? this.bucket,
      localPath: localPath ?? this.localPath,
      remotePath: remotePath ?? this.remotePath,
      recordId: recordId ?? this.recordId,
      attempts: attempts ?? this.attempts,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (bucket.present) {
      map['bucket'] = Variable<String>(bucket.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (remotePath.present) {
      map['remote_path'] = Variable<String>(remotePath.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('id: $id, ')
          ..write('bucket: $bucket, ')
          ..write('localPath: $localPath, ')
          ..write('remotePath: $remotePath, ')
          ..write('recordId: $recordId, ')
          ..write('attempts: $attempts, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class RecordVersions extends Table with TableInfo<RecordVersions, LocalVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  RecordVersions(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _tableName$Meta = const VerificationMeta('tableName\$');
  late final GeneratedColumn<String> tableName$ = GeneratedColumn<String>(
    'table_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta('groupId');
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _opMeta = const VerificationMeta('op');
  late final GeneratedColumn<String> op = GeneratedColumn<String>(
    'op',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _snapshotMeta = const VerificationMeta('snapshot');
  late final GeneratedColumn<String> snapshot = GeneratedColumn<String>(
    'snapshot',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _changedByMeta = const VerificationMeta('changedBy');
  late final GeneratedColumn<String> changedBy = GeneratedColumn<String>(
    'changed_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta('changedAt');
  late final GeneratedColumn<String> changedAt = GeneratedColumn<String>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _clientUpdatedAtMeta = const VerificationMeta('clientUpdatedAt');
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
    'client_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tableName$,
    recordId,
    groupId,
    op,
    snapshot,
    changedBy,
    changedAt,
    clientUpdatedAt,
    seq,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'record_versions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalVersion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('table_name')) {
      context.handle(
        _tableName$Meta,
        tableName$.isAcceptableOrUnknown(data['table_name']!, _tableName$Meta),
      );
    } else if (isInserting) {
      context.missing(_tableName$Meta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(_groupIdMeta, groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta));
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('op')) {
      context.handle(_opMeta, op.isAcceptableOrUnknown(data['op']!, _opMeta));
    } else if (isInserting) {
      context.missing(_opMeta);
    }
    if (data.containsKey('snapshot')) {
      context.handle(
        _snapshotMeta,
        snapshot.isAcceptableOrUnknown(data['snapshot']!, _snapshotMeta),
      );
    } else if (isInserting) {
      context.missing(_snapshotMeta);
    }
    if (data.containsKey('changed_by')) {
      context.handle(
        _changedByMeta,
        changedBy.isAcceptableOrUnknown(data['changed_by']!, _changedByMeta),
      );
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    if (data.containsKey('client_updated_at')) {
      context.handle(
        _clientUpdatedAtMeta,
        clientUpdatedAt.isAcceptableOrUnknown(data['client_updated_at']!, _clientUpdatedAtMeta),
      );
    }
    if (data.containsKey('seq')) {
      context.handle(_seqMeta, seq.isAcceptableOrUnknown(data['seq']!, _seqMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalVersion(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      tableName$: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_name'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      op: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}op'])!,
      snapshot: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot'],
      )!,
      changedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_by'],
      ),
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}changed_at'],
      )!,
      clientUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_updated_at'],
      ),
      seq: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}seq'])!,
    );
  }

  @override
  RecordVersions createAlias(String alias) {
    return RecordVersions(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class LocalVersion extends DataClass implements Insertable<LocalVersion> {
  final int id;
  final String tableName$;
  final String recordId;
  final String groupId;
  final String op;
  final String snapshot;
  final String? changedBy;
  final String changedAt;
  final String? clientUpdatedAt;
  final int seq;
  const LocalVersion({
    required this.id,
    required this.tableName$,
    required this.recordId,
    required this.groupId,
    required this.op,
    required this.snapshot,
    this.changedBy,
    required this.changedAt,
    this.clientUpdatedAt,
    required this.seq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['table_name'] = Variable<String>(tableName$);
    map['record_id'] = Variable<String>(recordId);
    map['group_id'] = Variable<String>(groupId);
    map['op'] = Variable<String>(op);
    map['snapshot'] = Variable<String>(snapshot);
    if (!nullToAbsent || changedBy != null) {
      map['changed_by'] = Variable<String>(changedBy);
    }
    map['changed_at'] = Variable<String>(changedAt);
    if (!nullToAbsent || clientUpdatedAt != null) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    }
    map['seq'] = Variable<int>(seq);
    return map;
  }

  RecordVersionsCompanion toCompanion(bool nullToAbsent) {
    return RecordVersionsCompanion(
      id: Value(id),
      tableName$: Value(tableName$),
      recordId: Value(recordId),
      groupId: Value(groupId),
      op: Value(op),
      snapshot: Value(snapshot),
      changedBy: changedBy == null && nullToAbsent ? const Value.absent() : Value(changedBy),
      changedAt: Value(changedAt),
      clientUpdatedAt: clientUpdatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(clientUpdatedAt),
      seq: Value(seq),
    );
  }

  factory LocalVersion.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalVersion(
      id: serializer.fromJson<int>(json['id']),
      tableName$: serializer.fromJson<String>(json['table_name']),
      recordId: serializer.fromJson<String>(json['record_id']),
      groupId: serializer.fromJson<String>(json['group_id']),
      op: serializer.fromJson<String>(json['op']),
      snapshot: serializer.fromJson<String>(json['snapshot']),
      changedBy: serializer.fromJson<String?>(json['changed_by']),
      changedAt: serializer.fromJson<String>(json['changed_at']),
      clientUpdatedAt: serializer.fromJson<String?>(json['client_updated_at']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'table_name': serializer.toJson<String>(tableName$),
      'record_id': serializer.toJson<String>(recordId),
      'group_id': serializer.toJson<String>(groupId),
      'op': serializer.toJson<String>(op),
      'snapshot': serializer.toJson<String>(snapshot),
      'changed_by': serializer.toJson<String?>(changedBy),
      'changed_at': serializer.toJson<String>(changedAt),
      'client_updated_at': serializer.toJson<String?>(clientUpdatedAt),
      'seq': serializer.toJson<int>(seq),
    };
  }

  LocalVersion copyWith({
    int? id,
    String? tableName$,
    String? recordId,
    String? groupId,
    String? op,
    String? snapshot,
    Value<String?> changedBy = const Value.absent(),
    String? changedAt,
    Value<String?> clientUpdatedAt = const Value.absent(),
    int? seq,
  }) => LocalVersion(
    id: id ?? this.id,
    tableName$: tableName$ ?? this.tableName$,
    recordId: recordId ?? this.recordId,
    groupId: groupId ?? this.groupId,
    op: op ?? this.op,
    snapshot: snapshot ?? this.snapshot,
    changedBy: changedBy.present ? changedBy.value : this.changedBy,
    changedAt: changedAt ?? this.changedAt,
    clientUpdatedAt: clientUpdatedAt.present ? clientUpdatedAt.value : this.clientUpdatedAt,
    seq: seq ?? this.seq,
  );
  LocalVersion copyWithCompanion(RecordVersionsCompanion data) {
    return LocalVersion(
      id: data.id.present ? data.id.value : this.id,
      tableName$: data.tableName$.present ? data.tableName$.value : this.tableName$,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      op: data.op.present ? data.op.value : this.op,
      snapshot: data.snapshot.present ? data.snapshot.value : this.snapshot,
      changedBy: data.changedBy.present ? data.changedBy.value : this.changedBy,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalVersion(')
          ..write('id: $id, ')
          ..write('tableName\$: ${tableName$}, ')
          ..write('recordId: $recordId, ')
          ..write('groupId: $groupId, ')
          ..write('op: $op, ')
          ..write('snapshot: $snapshot, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableName$,
    recordId,
    groupId,
    op,
    snapshot,
    changedBy,
    changedAt,
    clientUpdatedAt,
    seq,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalVersion &&
          other.id == this.id &&
          other.tableName$ == this.tableName$ &&
          other.recordId == this.recordId &&
          other.groupId == this.groupId &&
          other.op == this.op &&
          other.snapshot == this.snapshot &&
          other.changedBy == this.changedBy &&
          other.changedAt == this.changedAt &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.seq == this.seq);
}

class RecordVersionsCompanion extends UpdateCompanion<LocalVersion> {
  final Value<int> id;
  final Value<String> tableName$;
  final Value<String> recordId;
  final Value<String> groupId;
  final Value<String> op;
  final Value<String> snapshot;
  final Value<String?> changedBy;
  final Value<String> changedAt;
  final Value<String?> clientUpdatedAt;
  final Value<int> seq;
  const RecordVersionsCompanion({
    this.id = const Value.absent(),
    this.tableName$ = const Value.absent(),
    this.recordId = const Value.absent(),
    this.groupId = const Value.absent(),
    this.op = const Value.absent(),
    this.snapshot = const Value.absent(),
    this.changedBy = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.clientUpdatedAt = const Value.absent(),
    this.seq = const Value.absent(),
  });
  RecordVersionsCompanion.insert({
    this.id = const Value.absent(),
    required String tableName$,
    required String recordId,
    required String groupId,
    required String op,
    required String snapshot,
    this.changedBy = const Value.absent(),
    required String changedAt,
    this.clientUpdatedAt = const Value.absent(),
    this.seq = const Value.absent(),
  }) : tableName$ = Value(tableName$),
       recordId = Value(recordId),
       groupId = Value(groupId),
       op = Value(op),
       snapshot = Value(snapshot),
       changedAt = Value(changedAt);
  static Insertable<LocalVersion> custom({
    Expression<int>? id,
    Expression<String>? tableName$,
    Expression<String>? recordId,
    Expression<String>? groupId,
    Expression<String>? op,
    Expression<String>? snapshot,
    Expression<String>? changedBy,
    Expression<String>? changedAt,
    Expression<String>? clientUpdatedAt,
    Expression<int>? seq,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableName$ != null) 'table_name': tableName$,
      if (recordId != null) 'record_id': recordId,
      if (groupId != null) 'group_id': groupId,
      if (op != null) 'op': op,
      if (snapshot != null) 'snapshot': snapshot,
      if (changedBy != null) 'changed_by': changedBy,
      if (changedAt != null) 'changed_at': changedAt,
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (seq != null) 'seq': seq,
    });
  }

  RecordVersionsCompanion copyWith({
    Value<int>? id,
    Value<String>? tableName$,
    Value<String>? recordId,
    Value<String>? groupId,
    Value<String>? op,
    Value<String>? snapshot,
    Value<String?>? changedBy,
    Value<String>? changedAt,
    Value<String?>? clientUpdatedAt,
    Value<int>? seq,
  }) {
    return RecordVersionsCompanion(
      id: id ?? this.id,
      tableName$: tableName$ ?? this.tableName$,
      recordId: recordId ?? this.recordId,
      groupId: groupId ?? this.groupId,
      op: op ?? this.op,
      snapshot: snapshot ?? this.snapshot,
      changedBy: changedBy ?? this.changedBy,
      changedAt: changedAt ?? this.changedAt,
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      seq: seq ?? this.seq,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tableName$.present) {
      map['table_name'] = Variable<String>(tableName$.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>(op.value);
    }
    if (snapshot.present) {
      map['snapshot'] = Variable<String>(snapshot.value);
    }
    if (changedBy.present) {
      map['changed_by'] = Variable<String>(changedBy.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<String>(changedAt.value);
    }
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordVersionsCompanion(')
          ..write('id: $id, ')
          ..write('tableName\$: ${tableName$}, ')
          ..write('recordId: $recordId, ')
          ..write('groupId: $groupId, ')
          ..write('op: $op, ')
          ..write('snapshot: $snapshot, ')
          ..write('changedBy: $changedBy, ')
          ..write('changedAt: $changedAt, ')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }
}

class ExpenseSearch extends Table
    with
        TableInfo<ExpenseSearch, ExpenseSearchData>,
        VirtualTableInfo<ExpenseSearch, ExpenseSearchData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ExpenseSearch(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _descriptionMeta = const VerificationMeta('description');
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _memberNamesMeta = const VerificationMeta('memberNames');
  late final GeneratedColumn<String> memberNames = GeneratedColumn<String>(
    'member_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  static const VerificationMeta _amountTextMeta = const VerificationMeta('amountText');
  late final GeneratedColumn<String> amountText = GeneratedColumn<String>(
    'amount_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [description, notes, memberNames, amountText];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expense_search';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseSearchData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(data['description']!, _descriptionMeta),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(_notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('member_names')) {
      context.handle(
        _memberNamesMeta,
        memberNames.isAcceptableOrUnknown(data['member_names']!, _memberNamesMeta),
      );
    } else if (isInserting) {
      context.missing(_memberNamesMeta);
    }
    if (data.containsKey('amount_text')) {
      context.handle(
        _amountTextMeta,
        amountText.isAcceptableOrUnknown(data['amount_text']!, _amountTextMeta),
      );
    } else if (isInserting) {
      context.missing(_amountTextMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => const {};
  @override
  ExpenseSearchData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseSearchData(
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      memberNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}member_names'],
      )!,
      amountText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}amount_text'],
      )!,
    );
  }

  @override
  ExpenseSearch createAlias(String alias) {
    return ExpenseSearch(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
  @override
  String get moduleAndArgs => 'fts5(description, notes, member_names, amount_text)';
}

class ExpenseSearchData extends DataClass implements Insertable<ExpenseSearchData> {
  final String description;
  final String notes;
  final String memberNames;
  final String amountText;
  const ExpenseSearchData({
    required this.description,
    required this.notes,
    required this.memberNames,
    required this.amountText,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['description'] = Variable<String>(description);
    map['notes'] = Variable<String>(notes);
    map['member_names'] = Variable<String>(memberNames);
    map['amount_text'] = Variable<String>(amountText);
    return map;
  }

  ExpenseSearchCompanion toCompanion(bool nullToAbsent) {
    return ExpenseSearchCompanion(
      description: Value(description),
      notes: Value(notes),
      memberNames: Value(memberNames),
      amountText: Value(amountText),
    );
  }

  factory ExpenseSearchData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseSearchData(
      description: serializer.fromJson<String>(json['description']),
      notes: serializer.fromJson<String>(json['notes']),
      memberNames: serializer.fromJson<String>(json['member_names']),
      amountText: serializer.fromJson<String>(json['amount_text']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'description': serializer.toJson<String>(description),
      'notes': serializer.toJson<String>(notes),
      'member_names': serializer.toJson<String>(memberNames),
      'amount_text': serializer.toJson<String>(amountText),
    };
  }

  ExpenseSearchData copyWith({
    String? description,
    String? notes,
    String? memberNames,
    String? amountText,
  }) => ExpenseSearchData(
    description: description ?? this.description,
    notes: notes ?? this.notes,
    memberNames: memberNames ?? this.memberNames,
    amountText: amountText ?? this.amountText,
  );
  ExpenseSearchData copyWithCompanion(ExpenseSearchCompanion data) {
    return ExpenseSearchData(
      description: data.description.present ? data.description.value : this.description,
      notes: data.notes.present ? data.notes.value : this.notes,
      memberNames: data.memberNames.present ? data.memberNames.value : this.memberNames,
      amountText: data.amountText.present ? data.amountText.value : this.amountText,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseSearchData(')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('memberNames: $memberNames, ')
          ..write('amountText: $amountText')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(description, notes, memberNames, amountText);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseSearchData &&
          other.description == this.description &&
          other.notes == this.notes &&
          other.memberNames == this.memberNames &&
          other.amountText == this.amountText);
}

class ExpenseSearchCompanion extends UpdateCompanion<ExpenseSearchData> {
  final Value<String> description;
  final Value<String> notes;
  final Value<String> memberNames;
  final Value<String> amountText;
  final Value<int> rowid;
  const ExpenseSearchCompanion({
    this.description = const Value.absent(),
    this.notes = const Value.absent(),
    this.memberNames = const Value.absent(),
    this.amountText = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpenseSearchCompanion.insert({
    required String description,
    required String notes,
    required String memberNames,
    required String amountText,
    this.rowid = const Value.absent(),
  }) : description = Value(description),
       notes = Value(notes),
       memberNames = Value(memberNames),
       amountText = Value(amountText);
  static Insertable<ExpenseSearchData> custom({
    Expression<String>? description,
    Expression<String>? notes,
    Expression<String>? memberNames,
    Expression<String>? amountText,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (description != null) 'description': description,
      if (notes != null) 'notes': notes,
      if (memberNames != null) 'member_names': memberNames,
      if (amountText != null) 'amount_text': amountText,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpenseSearchCompanion copyWith({
    Value<String>? description,
    Value<String>? notes,
    Value<String>? memberNames,
    Value<String>? amountText,
    Value<int>? rowid,
  }) {
    return ExpenseSearchCompanion(
      description: description ?? this.description,
      notes: notes ?? this.notes,
      memberNames: memberNames ?? this.memberNames,
      amountText: amountText ?? this.amountText,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (memberNames.present) {
      map['member_names'] = Variable<String>(memberNames.value);
    }
    if (amountText.present) {
      map['amount_text'] = Variable<String>(amountText.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseSearchCompanion(')
          ..write('description: $description, ')
          ..write('notes: $notes, ')
          ..write('memberNames: $memberNames, ')
          ..write('amountText: $amountText, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Profiles profiles = Profiles(this);
  late final Groups groups = Groups(this);
  late final GroupMembers groupMembers = GroupMembers(this);
  late final Index groupMembersGroup = Index(
    'group_members_group',
    'CREATE INDEX group_members_group ON group_members (group_id)',
  );
  late final Expenses expenses = Expenses(this);
  late final Index expensesGroupDate = Index(
    'expenses_group_date',
    'CREATE INDEX expenses_group_date ON expenses (group_id, date)',
  );
  late final Payments payments = Payments(this);
  late final Index paymentsGroup = Index(
    'payments_group',
    'CREATE INDEX payments_group ON payments (group_id)',
  );
  late final Comments comments = Comments(this);
  late final Index commentsTarget = Index(
    'comments_target',
    'CREATE INDEX comments_target ON comments (target_id)',
  );
  late final Activity activity = Activity(this);
  late final Index activityGroupSeq = Index(
    'activity_group_seq',
    'CREATE INDEX activity_group_seq ON activity (group_id, seq)',
  );
  late final ExpenseParts expenseParts = ExpenseParts(this);
  late final Index expensePartsGroup = Index(
    'expense_parts_group',
    'CREATE INDEX expense_parts_group ON expense_parts (group_id, currency)',
  );
  late final Outbox outbox = Outbox(this);
  late final Index outboxRecord = Index(
    'outbox_record',
    'CREATE INDEX outbox_record ON outbox (record_id)',
  );
  late final SyncCursors syncCursors = SyncCursors(this);
  late final SyncMeta syncMeta = SyncMeta(this);
  late final PendingUploads pendingUploads = PendingUploads(this);
  late final RecordVersions recordVersions = RecordVersions(this);
  late final Index recordVersionsRecord = Index(
    'record_versions_record',
    'CREATE INDEX record_versions_record ON record_versions (record_id, seq)',
  );
  late final ExpenseSearch expenseSearch = ExpenseSearch(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    profiles,
    groups,
    groupMembers,
    groupMembersGroup,
    expenses,
    expensesGroupDate,
    payments,
    paymentsGroup,
    comments,
    commentsTarget,
    activity,
    activityGroupSeq,
    expenseParts,
    expensePartsGroup,
    outbox,
    outboxRecord,
    syncCursors,
    syncMeta,
    pendingUploads,
    recordVersions,
    recordVersionsRecord,
    expenseSearch,
  ];
  @override
  DriftDatabaseOptions get options => const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $ProfilesCreateCompanionBuilder = ProfilesCompanion Function({
  required String id,
  required String displayName,
  Value<String?> avatarPath,
  Value<String?> upiId,
  Value<String> defaultCurrency,
  Value<String?> updatedAt,
  Value<String?> deletedAt,
  Value<int> seq,
  Value<int> rowid,
});
typedef $ProfilesUpdateCompanionBuilder = ProfilesCompanion Function({
  Value<String> id,
  Value<String> displayName,
  Value<String?> avatarPath,
  Value<String?> upiId,
  Value<String> defaultCurrency,
  Value<String?> updatedAt,
  Value<String?> deletedAt,
  Value<int> seq,
  Value<int> rowid,
});

class $ProfilesFilterComposer extends Composer<_$AppDatabase, Profiles> {
  $ProfilesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarPath =>
      $composableBuilder(column: $table.avatarPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get upiId =>
      $composableBuilder(column: $table.upiId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $ProfilesOrderingComposer extends Composer<_$AppDatabase, Profiles> {
  $ProfilesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarPath =>
      $composableBuilder(column: $table.avatarPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get upiId =>
      $composableBuilder(column: $table.upiId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get defaultCurrency => $composableBuilder(
    column: $table.defaultCurrency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $ProfilesAnnotationComposer extends Composer<_$AppDatabase, Profiles> {
  $ProfilesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<String> get avatarPath =>
      $composableBuilder(column: $table.avatarPath, builder: (column) => column);

  GeneratedColumn<String> get upiId =>
      $composableBuilder(column: $table.upiId, builder: (column) => column);

  GeneratedColumn<String> get defaultCurrency =>
      $composableBuilder(column: $table.defaultCurrency, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $ProfilesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Profiles,
          LocalProfile,
          $ProfilesFilterComposer,
          $ProfilesOrderingComposer,
          $ProfilesAnnotationComposer,
          $ProfilesCreateCompanionBuilder,
          $ProfilesUpdateCompanionBuilder,
          (LocalProfile, BaseReferences<_$AppDatabase, Profiles, LocalProfile>),
          LocalProfile,
          PrefetchHooks Function()
        > {
  $ProfilesTableManager(_$AppDatabase db, Profiles table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ProfilesFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ProfilesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ProfilesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> upiId = const Value.absent(),
                Value<String> defaultCurrency = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion(
                id: id,
                displayName: displayName,
                avatarPath: avatarPath,
                upiId: upiId,
                defaultCurrency: defaultCurrency,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                seq: seq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                Value<String?> avatarPath = const Value.absent(),
                Value<String?> upiId = const Value.absent(),
                Value<String> defaultCurrency = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProfilesCompanion.insert(
                id: id,
                displayName: displayName,
                avatarPath: avatarPath,
                upiId: upiId,
                defaultCurrency: defaultCurrency,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                seq: seq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Profiles, LocalProfile>(table),
                  BaseReferences<_$AppDatabase, Profiles, LocalProfile>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ProfilesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Profiles,
      LocalProfile,
      $ProfilesFilterComposer,
      $ProfilesOrderingComposer,
      $ProfilesAnnotationComposer,
      $ProfilesCreateCompanionBuilder,
      $ProfilesUpdateCompanionBuilder,
      (LocalProfile, BaseReferences<_$AppDatabase, Profiles, LocalProfile>),
      LocalProfile,
      PrefetchHooks Function()
    >;
typedef $GroupsCreateCompanionBuilder = GroupsCompanion Function({
  required String id,
  required String name,
  Value<String> type,
  Value<String> mainCurrency,
  Value<String> coverKind,
  Value<String?> coverPath,
  Value<bool> simplifyDebts,
  Value<String?> defaultSplit,
  Value<String?> inviteCode,
  Value<String?> archivedAt,
  Value<String?> directKey,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});
typedef $GroupsUpdateCompanionBuilder = GroupsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> type,
  Value<String> mainCurrency,
  Value<String> coverKind,
  Value<String?> coverPath,
  Value<bool> simplifyDebts,
  Value<String?> defaultSplit,
  Value<String?> inviteCode,
  Value<String?> archivedAt,
  Value<String?> directKey,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});

class $GroupsFilterComposer extends Composer<_$AppDatabase, Groups> {
  $GroupsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mainCurrency =>
      $composableBuilder(column: $table.mainCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverKind =>
      $composableBuilder(column: $table.coverKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get simplifyDebts =>
      $composableBuilder(column: $table.simplifyDebts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get defaultSplit =>
      $composableBuilder(column: $table.defaultSplit, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviteCode =>
      $composableBuilder(column: $table.inviteCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get directKey =>
      $composableBuilder(column: $table.directKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnFilters(column));
}

class $GroupsOrderingComposer extends Composer<_$AppDatabase, Groups> {
  $GroupsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mainCurrency =>
      $composableBuilder(column: $table.mainCurrency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverKind =>
      $composableBuilder(column: $table.coverKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get simplifyDebts => $composableBuilder(
    column: $table.simplifyDebts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultSplit =>
      $composableBuilder(column: $table.defaultSplit, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviteCode =>
      $composableBuilder(column: $table.inviteCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get directKey =>
      $composableBuilder(column: $table.directKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));
}

class $GroupsAnnotationComposer extends Composer<_$AppDatabase, Groups> {
  $GroupsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get mainCurrency =>
      $composableBuilder(column: $table.mainCurrency, builder: (column) => column);

  GeneratedColumn<String> get coverKind =>
      $composableBuilder(column: $table.coverKind, builder: (column) => column);

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<bool> get simplifyDebts =>
      $composableBuilder(column: $table.simplifyDebts, builder: (column) => column);

  GeneratedColumn<String> get defaultSplit =>
      $composableBuilder(column: $table.defaultSplit, builder: (column) => column);

  GeneratedColumn<String> get inviteCode =>
      $composableBuilder(column: $table.inviteCode, builder: (column) => column);

  GeneratedColumn<String> get archivedAt =>
      $composableBuilder(column: $table.archivedAt, builder: (column) => column);

  GeneratedColumn<String> get directKey =>
      $composableBuilder(column: $table.directKey, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $GroupsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Groups,
          LocalGroup,
          $GroupsFilterComposer,
          $GroupsOrderingComposer,
          $GroupsAnnotationComposer,
          $GroupsCreateCompanionBuilder,
          $GroupsUpdateCompanionBuilder,
          (LocalGroup, BaseReferences<_$AppDatabase, Groups, LocalGroup>),
          LocalGroup,
          PrefetchHooks Function()
        > {
  $GroupsTableManager(_$AppDatabase db, Groups table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $GroupsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $GroupsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $GroupsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> mainCurrency = const Value.absent(),
                Value<String> coverKind = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<bool> simplifyDebts = const Value.absent(),
                Value<String?> defaultSplit = const Value.absent(),
                Value<String?> inviteCode = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String?> directKey = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                type: type,
                mainCurrency: mainCurrency,
                coverKind: coverKind,
                coverPath: coverPath,
                simplifyDebts: simplifyDebts,
                defaultSplit: defaultSplit,
                inviteCode: inviteCode,
                archivedAt: archivedAt,
                directKey: directKey,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> type = const Value.absent(),
                Value<String> mainCurrency = const Value.absent(),
                Value<String> coverKind = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<bool> simplifyDebts = const Value.absent(),
                Value<String?> defaultSplit = const Value.absent(),
                Value<String?> inviteCode = const Value.absent(),
                Value<String?> archivedAt = const Value.absent(),
                Value<String?> directKey = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                type: type,
                mainCurrency: mainCurrency,
                coverKind: coverKind,
                coverPath: coverPath,
                simplifyDebts: simplifyDebts,
                defaultSplit: defaultSplit,
                inviteCode: inviteCode,
                archivedAt: archivedAt,
                directKey: directKey,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Groups, LocalGroup>(table),
                  BaseReferences<_$AppDatabase, Groups, LocalGroup>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $GroupsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Groups,
      LocalGroup,
      $GroupsFilterComposer,
      $GroupsOrderingComposer,
      $GroupsAnnotationComposer,
      $GroupsCreateCompanionBuilder,
      $GroupsUpdateCompanionBuilder,
      (LocalGroup, BaseReferences<_$AppDatabase, Groups, LocalGroup>),
      LocalGroup,
      PrefetchHooks Function()
    >;
typedef $GroupMembersCreateCompanionBuilder = GroupMembersCompanion Function({
  required String id,
  required String groupId,
  Value<String?> userId,
  required String displayName,
  Value<int> position,
  Value<String> role,
  Value<String> status,
  Value<String?> claimedAt,
  Value<int?> tint,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});
typedef $GroupMembersUpdateCompanionBuilder = GroupMembersCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> userId,
  Value<String> displayName,
  Value<int> position,
  Value<String> role,
  Value<String> status,
  Value<String?> claimedAt,
  Value<int?> tint,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});

class $GroupMembersFilterComposer extends Composer<_$AppDatabase, GroupMembers> {
  $GroupMembersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get tint =>
      $composableBuilder(column: $table.tint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnFilters(column));
}

class $GroupMembersOrderingComposer extends Composer<_$AppDatabase, GroupMembers> {
  $GroupMembersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get tint =>
      $composableBuilder(column: $table.tint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));
}

class $GroupMembersAnnotationComposer extends Composer<_$AppDatabase, GroupMembers> {
  $GroupMembersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get displayName =>
      $composableBuilder(column: $table.displayName, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get claimedAt =>
      $composableBuilder(column: $table.claimedAt, builder: (column) => column);

  GeneratedColumn<int> get tint =>
      $composableBuilder(column: $table.tint, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $GroupMembersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          GroupMembers,
          LocalMember,
          $GroupMembersFilterComposer,
          $GroupMembersOrderingComposer,
          $GroupMembersAnnotationComposer,
          $GroupMembersCreateCompanionBuilder,
          $GroupMembersUpdateCompanionBuilder,
          (LocalMember, BaseReferences<_$AppDatabase, GroupMembers, LocalMember>),
          LocalMember,
          PrefetchHooks Function()
        > {
  $GroupMembersTableManager(_$AppDatabase db, GroupMembers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $GroupMembersFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $GroupMembersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $GroupMembersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> claimedAt = const Value.absent(),
                Value<int?> tint = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                id: id,
                groupId: groupId,
                userId: userId,
                displayName: displayName,
                position: position,
                role: role,
                status: status,
                claimedAt: claimedAt,
                tint: tint,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String?> userId = const Value.absent(),
                required String displayName,
                Value<int> position = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> claimedAt = const Value.absent(),
                Value<int?> tint = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                id: id,
                groupId: groupId,
                userId: userId,
                displayName: displayName,
                position: position,
                role: role,
                status: status,
                claimedAt: claimedAt,
                tint: tint,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<GroupMembers, LocalMember>(table),
                  BaseReferences<_$AppDatabase, GroupMembers, LocalMember>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $GroupMembersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      GroupMembers,
      LocalMember,
      $GroupMembersFilterComposer,
      $GroupMembersOrderingComposer,
      $GroupMembersAnnotationComposer,
      $GroupMembersCreateCompanionBuilder,
      $GroupMembersUpdateCompanionBuilder,
      (LocalMember, BaseReferences<_$AppDatabase, GroupMembers, LocalMember>),
      LocalMember,
      PrefetchHooks Function()
    >;
typedef $ExpensesCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required String groupId,
  Value<String> kind,
  required String description,
  Value<String?> notes,
  Value<String> category,
  required String date,
  required String currency,
  required int total,
  required String payers,
  required String shares,
  Value<String> splitKind,
  Value<String?> splitValues,
  Value<String?> fxRate,
  Value<String?> fxRateDate,
  Value<String?> fxSource,
  Value<String?> fxCurrency,
  Value<int?> fxTotal,
  Value<String?> fxPayers,
  Value<String?> fxShares,
  Value<String?> receiptPath,
  Value<String?> recurringId,
  Value<String> source,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});
typedef $ExpensesUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> kind,
  Value<String> description,
  Value<String?> notes,
  Value<String> category,
  Value<String> date,
  Value<String> currency,
  Value<int> total,
  Value<String> payers,
  Value<String> shares,
  Value<String> splitKind,
  Value<String?> splitValues,
  Value<String?> fxRate,
  Value<String?> fxRateDate,
  Value<String?> fxSource,
  Value<String?> fxCurrency,
  Value<int?> fxTotal,
  Value<String?> fxPayers,
  Value<String?> fxShares,
  Value<String?> receiptPath,
  Value<String?> recurringId,
  Value<String> source,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});

class $ExpensesFilterComposer extends Composer<_$AppDatabase, Expenses> {
  $ExpensesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payers =>
      $composableBuilder(column: $table.payers, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get splitKind =>
      $composableBuilder(column: $table.splitKind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get splitValues =>
      $composableBuilder(column: $table.splitValues, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fxTotal =>
      $composableBuilder(column: $table.fxTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxPayers =>
      $composableBuilder(column: $table.fxPayers, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxShares =>
      $composableBuilder(column: $table.fxShares, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get receiptPath =>
      $composableBuilder(column: $table.receiptPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recurringId =>
      $composableBuilder(column: $table.recurringId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnFilters(column));
}

class $ExpensesOrderingComposer extends Composer<_$AppDatabase, Expenses> {
  $ExpensesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payers =>
      $composableBuilder(column: $table.payers, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get splitKind =>
      $composableBuilder(column: $table.splitKind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get splitValues =>
      $composableBuilder(column: $table.splitValues, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fxTotal =>
      $composableBuilder(column: $table.fxTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxPayers =>
      $composableBuilder(column: $table.fxPayers, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxShares =>
      $composableBuilder(column: $table.fxShares, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get receiptPath =>
      $composableBuilder(column: $table.receiptPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recurringId =>
      $composableBuilder(column: $table.recurringId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));
}

class $ExpensesAnnotationComposer extends Composer<_$AppDatabase, Expenses> {
  $ExpensesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get payers =>
      $composableBuilder(column: $table.payers, builder: (column) => column);

  GeneratedColumn<String> get shares =>
      $composableBuilder(column: $table.shares, builder: (column) => column);

  GeneratedColumn<String> get splitKind =>
      $composableBuilder(column: $table.splitKind, builder: (column) => column);

  GeneratedColumn<String> get splitValues =>
      $composableBuilder(column: $table.splitValues, builder: (column) => column);

  GeneratedColumn<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => column);

  GeneratedColumn<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => column);

  GeneratedColumn<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => column);

  GeneratedColumn<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => column);

  GeneratedColumn<int> get fxTotal =>
      $composableBuilder(column: $table.fxTotal, builder: (column) => column);

  GeneratedColumn<String> get fxPayers =>
      $composableBuilder(column: $table.fxPayers, builder: (column) => column);

  GeneratedColumn<String> get fxShares =>
      $composableBuilder(column: $table.fxShares, builder: (column) => column);

  GeneratedColumn<String> get receiptPath =>
      $composableBuilder(column: $table.receiptPath, builder: (column) => column);

  GeneratedColumn<String> get recurringId =>
      $composableBuilder(column: $table.recurringId, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $ExpensesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Expenses,
          LocalExpense,
          $ExpensesFilterComposer,
          $ExpensesOrderingComposer,
          $ExpensesAnnotationComposer,
          $ExpensesCreateCompanionBuilder,
          $ExpensesUpdateCompanionBuilder,
          (LocalExpense, BaseReferences<_$AppDatabase, Expenses, LocalExpense>),
          LocalExpense,
          PrefetchHooks Function()
        > {
  $ExpensesTableManager(_$AppDatabase db, Expenses table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ExpensesFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ExpensesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ExpensesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> payers = const Value.absent(),
                Value<String> shares = const Value.absent(),
                Value<String> splitKind = const Value.absent(),
                Value<String?> splitValues = const Value.absent(),
                Value<String?> fxRate = const Value.absent(),
                Value<String?> fxRateDate = const Value.absent(),
                Value<String?> fxSource = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxTotal = const Value.absent(),
                Value<String?> fxPayers = const Value.absent(),
                Value<String?> fxShares = const Value.absent(),
                Value<String?> receiptPath = const Value.absent(),
                Value<String?> recurringId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                groupId: groupId,
                kind: kind,
                description: description,
                notes: notes,
                category: category,
                date: date,
                currency: currency,
                total: total,
                payers: payers,
                shares: shares,
                splitKind: splitKind,
                splitValues: splitValues,
                fxRate: fxRate,
                fxRateDate: fxRateDate,
                fxSource: fxSource,
                fxCurrency: fxCurrency,
                fxTotal: fxTotal,
                fxPayers: fxPayers,
                fxShares: fxShares,
                receiptPath: receiptPath,
                recurringId: recurringId,
                source: source,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String> kind = const Value.absent(),
                required String description,
                Value<String?> notes = const Value.absent(),
                Value<String> category = const Value.absent(),
                required String date,
                required String currency,
                required int total,
                required String payers,
                required String shares,
                Value<String> splitKind = const Value.absent(),
                Value<String?> splitValues = const Value.absent(),
                Value<String?> fxRate = const Value.absent(),
                Value<String?> fxRateDate = const Value.absent(),
                Value<String?> fxSource = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxTotal = const Value.absent(),
                Value<String?> fxPayers = const Value.absent(),
                Value<String?> fxShares = const Value.absent(),
                Value<String?> receiptPath = const Value.absent(),
                Value<String?> recurringId = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                groupId: groupId,
                kind: kind,
                description: description,
                notes: notes,
                category: category,
                date: date,
                currency: currency,
                total: total,
                payers: payers,
                shares: shares,
                splitKind: splitKind,
                splitValues: splitValues,
                fxRate: fxRate,
                fxRateDate: fxRateDate,
                fxSource: fxSource,
                fxCurrency: fxCurrency,
                fxTotal: fxTotal,
                fxPayers: fxPayers,
                fxShares: fxShares,
                receiptPath: receiptPath,
                recurringId: recurringId,
                source: source,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Expenses, LocalExpense>(table),
                  BaseReferences<_$AppDatabase, Expenses, LocalExpense>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ExpensesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Expenses,
      LocalExpense,
      $ExpensesFilterComposer,
      $ExpensesOrderingComposer,
      $ExpensesAnnotationComposer,
      $ExpensesCreateCompanionBuilder,
      $ExpensesUpdateCompanionBuilder,
      (LocalExpense, BaseReferences<_$AppDatabase, Expenses, LocalExpense>),
      LocalExpense,
      PrefetchHooks Function()
    >;
typedef $PaymentsCreateCompanionBuilder = PaymentsCompanion Function({
  required String id,
  required String groupId,
  required String fromMember,
  required String toMember,
  required int amount,
  required String currency,
  required String date,
  Value<String> method,
  Value<String?> note,
  Value<String?> fxRate,
  Value<String?> fxRateDate,
  Value<String?> fxSource,
  Value<String?> fxCurrency,
  Value<int?> fxAmount,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});
typedef $PaymentsUpdateCompanionBuilder = PaymentsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> fromMember,
  Value<String> toMember,
  Value<int> amount,
  Value<String> currency,
  Value<String> date,
  Value<String> method,
  Value<String?> note,
  Value<String?> fxRate,
  Value<String?> fxRateDate,
  Value<String?> fxSource,
  Value<String?> fxCurrency,
  Value<int?> fxAmount,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});

class $PaymentsFilterComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromMember =>
      $composableBuilder(column: $table.fromMember, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toMember =>
      $composableBuilder(column: $table.toMember, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fxAmount =>
      $composableBuilder(column: $table.fxAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnFilters(column));
}

class $PaymentsOrderingComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromMember =>
      $composableBuilder(column: $table.fromMember, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toMember =>
      $composableBuilder(column: $table.toMember, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fxAmount =>
      $composableBuilder(column: $table.fxAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));
}

class $PaymentsAnnotationComposer extends Composer<_$AppDatabase, Payments> {
  $PaymentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get fromMember =>
      $composableBuilder(column: $table.fromMember, builder: (column) => column);

  GeneratedColumn<String> get toMember =>
      $composableBuilder(column: $table.toMember, builder: (column) => column);

  GeneratedColumn<int> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get method =>
      $composableBuilder(column: $table.method, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get fxRate =>
      $composableBuilder(column: $table.fxRate, builder: (column) => column);

  GeneratedColumn<String> get fxRateDate =>
      $composableBuilder(column: $table.fxRateDate, builder: (column) => column);

  GeneratedColumn<String> get fxSource =>
      $composableBuilder(column: $table.fxSource, builder: (column) => column);

  GeneratedColumn<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => column);

  GeneratedColumn<int> get fxAmount =>
      $composableBuilder(column: $table.fxAmount, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $PaymentsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Payments,
          LocalPayment,
          $PaymentsFilterComposer,
          $PaymentsOrderingComposer,
          $PaymentsAnnotationComposer,
          $PaymentsCreateCompanionBuilder,
          $PaymentsUpdateCompanionBuilder,
          (LocalPayment, BaseReferences<_$AppDatabase, Payments, LocalPayment>),
          LocalPayment,
          PrefetchHooks Function()
        > {
  $PaymentsTableManager(_$AppDatabase db, Payments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $PaymentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $PaymentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $PaymentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> fromMember = const Value.absent(),
                Value<String> toMember = const Value.absent(),
                Value<int> amount = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> method = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> fxRate = const Value.absent(),
                Value<String?> fxRateDate = const Value.absent(),
                Value<String?> fxSource = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxAmount = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion(
                id: id,
                groupId: groupId,
                fromMember: fromMember,
                toMember: toMember,
                amount: amount,
                currency: currency,
                date: date,
                method: method,
                note: note,
                fxRate: fxRate,
                fxRateDate: fxRateDate,
                fxSource: fxSource,
                fxCurrency: fxCurrency,
                fxAmount: fxAmount,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String fromMember,
                required String toMember,
                required int amount,
                required String currency,
                required String date,
                Value<String> method = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> fxRate = const Value.absent(),
                Value<String?> fxRateDate = const Value.absent(),
                Value<String?> fxSource = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxAmount = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentsCompanion.insert(
                id: id,
                groupId: groupId,
                fromMember: fromMember,
                toMember: toMember,
                amount: amount,
                currency: currency,
                date: date,
                method: method,
                note: note,
                fxRate: fxRate,
                fxRateDate: fxRateDate,
                fxSource: fxSource,
                fxCurrency: fxCurrency,
                fxAmount: fxAmount,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Payments, LocalPayment>(table),
                  BaseReferences<_$AppDatabase, Payments, LocalPayment>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PaymentsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Payments,
      LocalPayment,
      $PaymentsFilterComposer,
      $PaymentsOrderingComposer,
      $PaymentsAnnotationComposer,
      $PaymentsCreateCompanionBuilder,
      $PaymentsUpdateCompanionBuilder,
      (LocalPayment, BaseReferences<_$AppDatabase, Payments, LocalPayment>),
      LocalPayment,
      PrefetchHooks Function()
    >;
typedef $CommentsCreateCompanionBuilder = CommentsCompanion Function({
  required String id,
  required String groupId,
  required String targetType,
  required String targetId,
  required String body,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});
typedef $CommentsUpdateCompanionBuilder = CommentsCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String> targetType,
  Value<String> targetId,
  Value<String> body,
  Value<String?> createdAt,
  Value<String?> createdBy,
  Value<String?> updatedAt,
  Value<String?> updatedBy,
  Value<String?> clientUpdatedAt,
  Value<String?> deletedAt,
  Value<String?> deletedBy,
  Value<int> seq,
  Value<String> syncState,
  Value<int> rowid,
});

class $CommentsFilterComposer extends Composer<_$AppDatabase, Comments> {
  $CommentsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnFilters(column));
}

class $CommentsOrderingComposer extends Composer<_$AppDatabase, Comments> {
  $CommentsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));
}

class $CommentsAnnotationComposer extends Composer<_$AppDatabase, Comments> {
  $CommentsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdBy =>
      $composableBuilder(column: $table.createdBy, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get updatedBy =>
      $composableBuilder(column: $table.updatedBy, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get deletedBy =>
      $composableBuilder(column: $table.deletedBy, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $CommentsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Comments,
          LocalComment,
          $CommentsFilterComposer,
          $CommentsOrderingComposer,
          $CommentsAnnotationComposer,
          $CommentsCreateCompanionBuilder,
          $CommentsUpdateCompanionBuilder,
          (LocalComment, BaseReferences<_$AppDatabase, Comments, LocalComment>),
          LocalComment,
          PrefetchHooks Function()
        > {
  $CommentsTableManager(_$AppDatabase db, Comments table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $CommentsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $CommentsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $CommentsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> targetType = const Value.absent(),
                Value<String> targetId = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommentsCompanion(
                id: id,
                groupId: groupId,
                targetType: targetType,
                targetId: targetId,
                body: body,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required String targetType,
                required String targetId,
                required String body,
                Value<String?> createdAt = const Value.absent(),
                Value<String?> createdBy = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<String?> updatedBy = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<String?> deletedBy = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CommentsCompanion.insert(
                id: id,
                groupId: groupId,
                targetType: targetType,
                targetId: targetId,
                body: body,
                createdAt: createdAt,
                createdBy: createdBy,
                updatedAt: updatedAt,
                updatedBy: updatedBy,
                clientUpdatedAt: clientUpdatedAt,
                deletedAt: deletedAt,
                deletedBy: deletedBy,
                seq: seq,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Comments, LocalComment>(table),
                  BaseReferences<_$AppDatabase, Comments, LocalComment>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $CommentsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Comments,
      LocalComment,
      $CommentsFilterComposer,
      $CommentsOrderingComposer,
      $CommentsAnnotationComposer,
      $CommentsCreateCompanionBuilder,
      $CommentsUpdateCompanionBuilder,
      (LocalComment, BaseReferences<_$AppDatabase, Comments, LocalComment>),
      LocalComment,
      PrefetchHooks Function()
    >;
typedef $ActivityCreateCompanionBuilder = ActivityCompanion Function({
  required String id,
  required String groupId,
  Value<String?> actorUserId,
  Value<String?> actorMemberId,
  required String type,
  Value<String?> targetType,
  Value<String?> targetId,
  Value<String> data,
  Value<String?> createdAt,
  Value<int> seq,
  Value<int> rowid,
});
typedef $ActivityUpdateCompanionBuilder = ActivityCompanion Function({
  Value<String> id,
  Value<String> groupId,
  Value<String?> actorUserId,
  Value<String?> actorMemberId,
  Value<String> type,
  Value<String?> targetType,
  Value<String?> targetId,
  Value<String> data,
  Value<String?> createdAt,
  Value<int> seq,
  Value<int> rowid,
});

class $ActivityFilterComposer extends Composer<_$AppDatabase, Activity> {
  $ActivityFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorUserId =>
      $composableBuilder(column: $table.actorUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actorMemberId =>
      $composableBuilder(column: $table.actorMemberId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $ActivityOrderingComposer extends Composer<_$AppDatabase, Activity> {
  $ActivityOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorUserId =>
      $composableBuilder(column: $table.actorUserId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actorMemberId => $composableBuilder(
    column: $table.actorMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $ActivityAnnotationComposer extends Composer<_$AppDatabase, Activity> {
  $ActivityAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get actorUserId =>
      $composableBuilder(column: $table.actorUserId, builder: (column) => column);

  GeneratedColumn<String> get actorMemberId =>
      $composableBuilder(column: $table.actorMemberId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get targetType =>
      $composableBuilder(column: $table.targetType, builder: (column) => column);

  GeneratedColumn<String> get targetId =>
      $composableBuilder(column: $table.targetId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $ActivityTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Activity,
          LocalActivity,
          $ActivityFilterComposer,
          $ActivityOrderingComposer,
          $ActivityAnnotationComposer,
          $ActivityCreateCompanionBuilder,
          $ActivityUpdateCompanionBuilder,
          (LocalActivity, BaseReferences<_$AppDatabase, Activity, LocalActivity>),
          LocalActivity,
          PrefetchHooks Function()
        > {
  $ActivityTableManager(_$AppDatabase db, Activity table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ActivityFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ActivityOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $ActivityAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String?> actorUserId = const Value.absent(),
                Value<String?> actorMemberId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityCompanion(
                id: id,
                groupId: groupId,
                actorUserId: actorUserId,
                actorMemberId: actorMemberId,
                type: type,
                targetType: targetType,
                targetId: targetId,
                data: data,
                createdAt: createdAt,
                seq: seq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                Value<String?> actorUserId = const Value.absent(),
                Value<String?> actorMemberId = const Value.absent(),
                required String type,
                Value<String?> targetType = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ActivityCompanion.insert(
                id: id,
                groupId: groupId,
                actorUserId: actorUserId,
                actorMemberId: actorMemberId,
                type: type,
                targetType: targetType,
                targetId: targetId,
                data: data,
                createdAt: createdAt,
                seq: seq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Activity, LocalActivity>(table),
                  BaseReferences<_$AppDatabase, Activity, LocalActivity>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ActivityProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Activity,
      LocalActivity,
      $ActivityFilterComposer,
      $ActivityOrderingComposer,
      $ActivityAnnotationComposer,
      $ActivityCreateCompanionBuilder,
      $ActivityUpdateCompanionBuilder,
      (LocalActivity, BaseReferences<_$AppDatabase, Activity, LocalActivity>),
      LocalActivity,
      PrefetchHooks Function()
    >;
typedef $ExpensePartsCreateCompanionBuilder = ExpensePartsCompanion Function({
  required String expenseId,
  required String groupId,
  required String memberId,
  required String currency,
  Value<int> paid,
  Value<int> owed,
  Value<String?> fxCurrency,
  Value<int?> fxPaid,
  Value<int?> fxOwed,
  Value<int> rowid,
});
typedef $ExpensePartsUpdateCompanionBuilder = ExpensePartsCompanion Function({
  Value<String> expenseId,
  Value<String> groupId,
  Value<String> memberId,
  Value<String> currency,
  Value<int> paid,
  Value<int> owed,
  Value<String?> fxCurrency,
  Value<int?> fxPaid,
  Value<int?> fxOwed,
  Value<int> rowid,
});

class $ExpensePartsFilterComposer extends Composer<_$AppDatabase, ExpenseParts> {
  $ExpensePartsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get expenseId =>
      $composableBuilder(column: $table.expenseId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get owed =>
      $composableBuilder(column: $table.owed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fxPaid =>
      $composableBuilder(column: $table.fxPaid, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fxOwed =>
      $composableBuilder(column: $table.fxOwed, builder: (column) => ColumnFilters(column));
}

class $ExpensePartsOrderingComposer extends Composer<_$AppDatabase, ExpenseParts> {
  $ExpensePartsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get expenseId =>
      $composableBuilder(column: $table.expenseId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get owed =>
      $composableBuilder(column: $table.owed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fxPaid =>
      $composableBuilder(column: $table.fxPaid, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fxOwed =>
      $composableBuilder(column: $table.fxOwed, builder: (column) => ColumnOrderings(column));
}

class $ExpensePartsAnnotationComposer extends Composer<_$AppDatabase, ExpenseParts> {
  $ExpensePartsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get expenseId =>
      $composableBuilder(column: $table.expenseId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get memberId =>
      $composableBuilder(column: $table.memberId, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<int> get owed =>
      $composableBuilder(column: $table.owed, builder: (column) => column);

  GeneratedColumn<String> get fxCurrency =>
      $composableBuilder(column: $table.fxCurrency, builder: (column) => column);

  GeneratedColumn<int> get fxPaid =>
      $composableBuilder(column: $table.fxPaid, builder: (column) => column);

  GeneratedColumn<int> get fxOwed =>
      $composableBuilder(column: $table.fxOwed, builder: (column) => column);
}

class $ExpensePartsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ExpenseParts,
          ExpensePart,
          $ExpensePartsFilterComposer,
          $ExpensePartsOrderingComposer,
          $ExpensePartsAnnotationComposer,
          $ExpensePartsCreateCompanionBuilder,
          $ExpensePartsUpdateCompanionBuilder,
          (ExpensePart, BaseReferences<_$AppDatabase, ExpenseParts, ExpensePart>),
          ExpensePart,
          PrefetchHooks Function()
        > {
  $ExpensePartsTableManager(_$AppDatabase db, ExpenseParts table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ExpensePartsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ExpensePartsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ExpensePartsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> expenseId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> memberId = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<int> paid = const Value.absent(),
                Value<int> owed = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxPaid = const Value.absent(),
                Value<int?> fxOwed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensePartsCompanion(
                expenseId: expenseId,
                groupId: groupId,
                memberId: memberId,
                currency: currency,
                paid: paid,
                owed: owed,
                fxCurrency: fxCurrency,
                fxPaid: fxPaid,
                fxOwed: fxOwed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String expenseId,
                required String groupId,
                required String memberId,
                required String currency,
                Value<int> paid = const Value.absent(),
                Value<int> owed = const Value.absent(),
                Value<String?> fxCurrency = const Value.absent(),
                Value<int?> fxPaid = const Value.absent(),
                Value<int?> fxOwed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensePartsCompanion.insert(
                expenseId: expenseId,
                groupId: groupId,
                memberId: memberId,
                currency: currency,
                paid: paid,
                owed: owed,
                fxCurrency: fxCurrency,
                fxPaid: fxPaid,
                fxOwed: fxOwed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ExpenseParts, ExpensePart>(table),
                  BaseReferences<_$AppDatabase, ExpenseParts, ExpensePart>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ExpensePartsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ExpenseParts,
      ExpensePart,
      $ExpensePartsFilterComposer,
      $ExpensePartsOrderingComposer,
      $ExpensePartsAnnotationComposer,
      $ExpensePartsCreateCompanionBuilder,
      $ExpensePartsUpdateCompanionBuilder,
      (ExpensePart, BaseReferences<_$AppDatabase, ExpenseParts, ExpensePart>),
      ExpensePart,
      PrefetchHooks Function()
    >;
typedef $OutboxCreateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  required String mutationId,
  required String entity,
  required String op,
  required String recordId,
  required String groupId,
  required String payload,
  required String clientUpdatedAt,
  required String createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String> status,
});
typedef $OutboxUpdateCompanionBuilder = OutboxCompanion Function({
  Value<int> seq,
  Value<String> mutationId,
  Value<String> entity,
  Value<String> op,
  Value<String> recordId,
  Value<String> groupId,
  Value<String> payload,
  Value<String> clientUpdatedAt,
  Value<String> createdAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<String> status,
});

class $OutboxFilterComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mutationId =>
      $composableBuilder(column: $table.mutationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnFilters(column));
}

class $OutboxOrderingComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mutationId =>
      $composableBuilder(column: $table.mutationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $OutboxAnnotationComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<String> get mutationId =>
      $composableBuilder(column: $table.mutationId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $OutboxTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Outbox,
          OutboxItem,
          $OutboxFilterComposer,
          $OutboxOrderingComposer,
          $OutboxAnnotationComposer,
          $OutboxCreateCompanionBuilder,
          $OutboxUpdateCompanionBuilder,
          (OutboxItem, BaseReferences<_$AppDatabase, Outbox, OutboxItem>),
          OutboxItem,
          PrefetchHooks Function()
        > {
  $OutboxTableManager(_$AppDatabase db, Outbox table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $OutboxFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $OutboxOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $OutboxAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                Value<String> mutationId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> clientUpdatedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => OutboxCompanion(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                recordId: recordId,
                groupId: groupId,
                payload: payload,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> seq = const Value.absent(),
                required String mutationId,
                required String entity,
                required String op,
                required String recordId,
                required String groupId,
                required String payload,
                required String clientUpdatedAt,
                required String createdAt,
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => OutboxCompanion.insert(
                seq: seq,
                mutationId: mutationId,
                entity: entity,
                op: op,
                recordId: recordId,
                groupId: groupId,
                payload: payload,
                clientUpdatedAt: clientUpdatedAt,
                createdAt: createdAt,
                attempts: attempts,
                lastError: lastError,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Outbox, OutboxItem>(table),
                  BaseReferences<_$AppDatabase, Outbox, OutboxItem>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $OutboxProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Outbox,
      OutboxItem,
      $OutboxFilterComposer,
      $OutboxOrderingComposer,
      $OutboxAnnotationComposer,
      $OutboxCreateCompanionBuilder,
      $OutboxUpdateCompanionBuilder,
      (OutboxItem, BaseReferences<_$AppDatabase, Outbox, OutboxItem>),
      OutboxItem,
      PrefetchHooks Function()
    >;
typedef $SyncCursorsCreateCompanionBuilder = SyncCursorsCompanion Function({
  required String scope,
  Value<int> seq,
  Value<int> rowid,
});
typedef $SyncCursorsUpdateCompanionBuilder = SyncCursorsCompanion Function({
  Value<String> scope,
  Value<int> seq,
  Value<int> rowid,
});

class $SyncCursorsFilterComposer extends Composer<_$AppDatabase, SyncCursors> {
  $SyncCursorsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $SyncCursorsOrderingComposer extends Composer<_$AppDatabase, SyncCursors> {
  $SyncCursorsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $SyncCursorsAnnotationComposer extends Composer<_$AppDatabase, SyncCursors> {
  $SyncCursorsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $SyncCursorsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SyncCursors,
          SyncCursor,
          $SyncCursorsFilterComposer,
          $SyncCursorsOrderingComposer,
          $SyncCursorsAnnotationComposer,
          $SyncCursorsCreateCompanionBuilder,
          $SyncCursorsUpdateCompanionBuilder,
          (SyncCursor, BaseReferences<_$AppDatabase, SyncCursors, SyncCursor>),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $SyncCursorsTableManager(_$AppDatabase db, SyncCursors table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SyncCursorsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SyncCursorsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SyncCursorsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> scope = const Value.absent(),
            Value<int> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion(scope: scope, seq: seq, rowid: rowid),
          createCompanionCallback: ({
            required String scope,
            Value<int> seq = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncCursorsCompanion.insert(scope: scope, seq: seq, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncCursors, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, SyncCursors, SyncCursor>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SyncCursorsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SyncCursors,
      SyncCursor,
      $SyncCursorsFilterComposer,
      $SyncCursorsOrderingComposer,
      $SyncCursorsAnnotationComposer,
      $SyncCursorsCreateCompanionBuilder,
      $SyncCursorsUpdateCompanionBuilder,
      (SyncCursor, BaseReferences<_$AppDatabase, SyncCursors, SyncCursor>),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $SyncMetaCreateCompanionBuilder = SyncMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $SyncMetaUpdateCompanionBuilder = SyncMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $SyncMetaFilterComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $SyncMetaOrderingComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $SyncMetaAnnotationComposer extends Composer<_$AppDatabase, SyncMeta> {
  $SyncMetaAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $SyncMetaTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SyncMeta,
          SyncMetaEntry,
          $SyncMetaFilterComposer,
          $SyncMetaOrderingComposer,
          $SyncMetaAnnotationComposer,
          $SyncMetaCreateCompanionBuilder,
          $SyncMetaUpdateCompanionBuilder,
          (SyncMetaEntry, BaseReferences<_$AppDatabase, SyncMeta, SyncMetaEntry>),
          SyncMetaEntry,
          PrefetchHooks Function()
        > {
  $SyncMetaTableManager(_$AppDatabase db, SyncMeta table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $SyncMetaFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $SyncMetaOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $SyncMetaAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncMetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncMeta, SyncMetaEntry>(table),
                  BaseReferences<_$AppDatabase, SyncMeta, SyncMetaEntry>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $SyncMetaProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SyncMeta,
      SyncMetaEntry,
      $SyncMetaFilterComposer,
      $SyncMetaOrderingComposer,
      $SyncMetaAnnotationComposer,
      $SyncMetaCreateCompanionBuilder,
      $SyncMetaUpdateCompanionBuilder,
      (SyncMetaEntry, BaseReferences<_$AppDatabase, SyncMeta, SyncMetaEntry>),
      SyncMetaEntry,
      PrefetchHooks Function()
    >;
typedef $PendingUploadsCreateCompanionBuilder = PendingUploadsCompanion Function({
  required String id,
  required String bucket,
  required String localPath,
  required String remotePath,
  required String recordId,
  Value<int> attempts,
  Value<int> rowid,
});
typedef $PendingUploadsUpdateCompanionBuilder = PendingUploadsCompanion Function({
  Value<String> id,
  Value<String> bucket,
  Value<String> localPath,
  Value<String> remotePath,
  Value<String> recordId,
  Value<int> attempts,
  Value<int> rowid,
});

class $PendingUploadsFilterComposer extends Composer<_$AppDatabase, PendingUploads> {
  $PendingUploadsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remotePath =>
      $composableBuilder(column: $table.remotePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnFilters(column));
}

class $PendingUploadsOrderingComposer extends Composer<_$AppDatabase, PendingUploads> {
  $PendingUploadsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remotePath =>
      $composableBuilder(column: $table.remotePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => ColumnOrderings(column));
}

class $PendingUploadsAnnotationComposer extends Composer<_$AppDatabase, PendingUploads> {
  $PendingUploadsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get bucket =>
      $composableBuilder(column: $table.bucket, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get remotePath =>
      $composableBuilder(column: $table.remotePath, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $PendingUploadsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          PendingUploads,
          PendingUpload,
          $PendingUploadsFilterComposer,
          $PendingUploadsOrderingComposer,
          $PendingUploadsAnnotationComposer,
          $PendingUploadsCreateCompanionBuilder,
          $PendingUploadsUpdateCompanionBuilder,
          (PendingUpload, BaseReferences<_$AppDatabase, PendingUploads, PendingUpload>),
          PendingUpload,
          PrefetchHooks Function()
        > {
  $PendingUploadsTableManager(_$AppDatabase db, PendingUploads table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $PendingUploadsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $PendingUploadsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PendingUploadsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> bucket = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<String> remotePath = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion(
                id: id,
                bucket: bucket,
                localPath: localPath,
                remotePath: remotePath,
                recordId: recordId,
                attempts: attempts,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String bucket,
                required String localPath,
                required String remotePath,
                required String recordId,
                Value<int> attempts = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingUploadsCompanion.insert(
                id: id,
                bucket: bucket,
                localPath: localPath,
                remotePath: remotePath,
                recordId: recordId,
                attempts: attempts,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PendingUploads, PendingUpload>(table),
                  BaseReferences<_$AppDatabase, PendingUploads, PendingUpload>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $PendingUploadsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      PendingUploads,
      PendingUpload,
      $PendingUploadsFilterComposer,
      $PendingUploadsOrderingComposer,
      $PendingUploadsAnnotationComposer,
      $PendingUploadsCreateCompanionBuilder,
      $PendingUploadsUpdateCompanionBuilder,
      (PendingUpload, BaseReferences<_$AppDatabase, PendingUploads, PendingUpload>),
      PendingUpload,
      PrefetchHooks Function()
    >;
typedef $RecordVersionsCreateCompanionBuilder = RecordVersionsCompanion Function({
  Value<int> id,
  required String tableName$,
  required String recordId,
  required String groupId,
  required String op,
  required String snapshot,
  Value<String?> changedBy,
  required String changedAt,
  Value<String?> clientUpdatedAt,
  Value<int> seq,
});
typedef $RecordVersionsUpdateCompanionBuilder = RecordVersionsCompanion Function({
  Value<int> id,
  Value<String> tableName$,
  Value<String> recordId,
  Value<String> groupId,
  Value<String> op,
  Value<String> snapshot,
  Value<String?> changedBy,
  Value<String> changedAt,
  Value<String?> clientUpdatedAt,
  Value<int> seq,
});

class $RecordVersionsFilterComposer extends Composer<_$AppDatabase, RecordVersions> {
  $RecordVersionsFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tableName$ =>
      $composableBuilder(column: $table.tableName$, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnFilters(column));
}

class $RecordVersionsOrderingComposer extends Composer<_$AppDatabase, RecordVersions> {
  $RecordVersionsOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tableName$ =>
      $composableBuilder(column: $table.tableName$, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
    column: $table.clientUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => ColumnOrderings(column));
}

class $RecordVersionsAnnotationComposer extends Composer<_$AppDatabase, RecordVersions> {
  $RecordVersionsAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableName$ =>
      $composableBuilder(column: $table.tableName$, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get snapshot =>
      $composableBuilder(column: $table.snapshot, builder: (column) => column);

  GeneratedColumn<String> get changedBy =>
      $composableBuilder(column: $table.changedBy, builder: (column) => column);

  GeneratedColumn<String> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);

  GeneratedColumn<String> get clientUpdatedAt =>
      $composableBuilder(column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $RecordVersionsTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          RecordVersions,
          LocalVersion,
          $RecordVersionsFilterComposer,
          $RecordVersionsOrderingComposer,
          $RecordVersionsAnnotationComposer,
          $RecordVersionsCreateCompanionBuilder,
          $RecordVersionsUpdateCompanionBuilder,
          (LocalVersion, BaseReferences<_$AppDatabase, RecordVersions, LocalVersion>),
          LocalVersion,
          PrefetchHooks Function()
        > {
  $RecordVersionsTableManager(_$AppDatabase db, RecordVersions table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $RecordVersionsFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $RecordVersionsOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $RecordVersionsAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tableName$ = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<String> op = const Value.absent(),
                Value<String> snapshot = const Value.absent(),
                Value<String?> changedBy = const Value.absent(),
                Value<String> changedAt = const Value.absent(),
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
              }) => RecordVersionsCompanion(
                id: id,
                tableName$: tableName$,
                recordId: recordId,
                groupId: groupId,
                op: op,
                snapshot: snapshot,
                changedBy: changedBy,
                changedAt: changedAt,
                clientUpdatedAt: clientUpdatedAt,
                seq: seq,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tableName$,
                required String recordId,
                required String groupId,
                required String op,
                required String snapshot,
                Value<String?> changedBy = const Value.absent(),
                required String changedAt,
                Value<String?> clientUpdatedAt = const Value.absent(),
                Value<int> seq = const Value.absent(),
              }) => RecordVersionsCompanion.insert(
                id: id,
                tableName$: tableName$,
                recordId: recordId,
                groupId: groupId,
                op: op,
                snapshot: snapshot,
                changedBy: changedBy,
                changedAt: changedAt,
                clientUpdatedAt: clientUpdatedAt,
                seq: seq,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<RecordVersions, LocalVersion>(table),
                  BaseReferences<_$AppDatabase, RecordVersions, LocalVersion>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $RecordVersionsProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      RecordVersions,
      LocalVersion,
      $RecordVersionsFilterComposer,
      $RecordVersionsOrderingComposer,
      $RecordVersionsAnnotationComposer,
      $RecordVersionsCreateCompanionBuilder,
      $RecordVersionsUpdateCompanionBuilder,
      (LocalVersion, BaseReferences<_$AppDatabase, RecordVersions, LocalVersion>),
      LocalVersion,
      PrefetchHooks Function()
    >;
typedef $ExpenseSearchCreateCompanionBuilder = ExpenseSearchCompanion Function({
  required String description,
  required String notes,
  required String memberNames,
  required String amountText,
  Value<int> rowid,
});
typedef $ExpenseSearchUpdateCompanionBuilder = ExpenseSearchCompanion Function({
  Value<String> description,
  Value<String> notes,
  Value<String> memberNames,
  Value<String> amountText,
  Value<int> rowid,
});

class $ExpenseSearchFilterComposer extends Composer<_$AppDatabase, ExpenseSearch> {
  $ExpenseSearchFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get memberNames =>
      $composableBuilder(column: $table.memberNames, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get amountText =>
      $composableBuilder(column: $table.amountText, builder: (column) => ColumnFilters(column));
}

class $ExpenseSearchOrderingComposer extends Composer<_$AppDatabase, ExpenseSearch> {
  $ExpenseSearchOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get memberNames =>
      $composableBuilder(column: $table.memberNames, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get amountText =>
      $composableBuilder(column: $table.amountText, builder: (column) => ColumnOrderings(column));
}

class $ExpenseSearchAnnotationComposer extends Composer<_$AppDatabase, ExpenseSearch> {
  $ExpenseSearchAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get description =>
      $composableBuilder(column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get memberNames =>
      $composableBuilder(column: $table.memberNames, builder: (column) => column);

  GeneratedColumn<String> get amountText =>
      $composableBuilder(column: $table.amountText, builder: (column) => column);
}

class $ExpenseSearchTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ExpenseSearch,
          ExpenseSearchData,
          $ExpenseSearchFilterComposer,
          $ExpenseSearchOrderingComposer,
          $ExpenseSearchAnnotationComposer,
          $ExpenseSearchCreateCompanionBuilder,
          $ExpenseSearchUpdateCompanionBuilder,
          (ExpenseSearchData, BaseReferences<_$AppDatabase, ExpenseSearch, ExpenseSearchData>),
          ExpenseSearchData,
          PrefetchHooks Function()
        > {
  $ExpenseSearchTableManager(_$AppDatabase db, ExpenseSearch table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $ExpenseSearchFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $ExpenseSearchOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ExpenseSearchAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> description = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<String> memberNames = const Value.absent(),
                Value<String> amountText = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpenseSearchCompanion(
                description: description,
                notes: notes,
                memberNames: memberNames,
                amountText: amountText,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String description,
                required String notes,
                required String memberNames,
                required String amountText,
                Value<int> rowid = const Value.absent(),
              }) => ExpenseSearchCompanion.insert(
                description: description,
                notes: notes,
                memberNames: memberNames,
                amountText: amountText,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ExpenseSearch, ExpenseSearchData>(table),
                  BaseReferences<_$AppDatabase, ExpenseSearch, ExpenseSearchData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $ExpenseSearchProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ExpenseSearch,
      ExpenseSearchData,
      $ExpenseSearchFilterComposer,
      $ExpenseSearchOrderingComposer,
      $ExpenseSearchAnnotationComposer,
      $ExpenseSearchCreateCompanionBuilder,
      $ExpenseSearchUpdateCompanionBuilder,
      (ExpenseSearchData, BaseReferences<_$AppDatabase, ExpenseSearch, ExpenseSearchData>),
      ExpenseSearchData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $ProfilesTableManager get profiles => $ProfilesTableManager(_db, _db.profiles);
  $GroupsTableManager get groups => $GroupsTableManager(_db, _db.groups);
  $GroupMembersTableManager get groupMembers => $GroupMembersTableManager(_db, _db.groupMembers);
  $ExpensesTableManager get expenses => $ExpensesTableManager(_db, _db.expenses);
  $PaymentsTableManager get payments => $PaymentsTableManager(_db, _db.payments);
  $CommentsTableManager get comments => $CommentsTableManager(_db, _db.comments);
  $ActivityTableManager get activity => $ActivityTableManager(_db, _db.activity);
  $ExpensePartsTableManager get expenseParts => $ExpensePartsTableManager(_db, _db.expenseParts);
  $OutboxTableManager get outbox => $OutboxTableManager(_db, _db.outbox);
  $SyncCursorsTableManager get syncCursors => $SyncCursorsTableManager(_db, _db.syncCursors);
  $SyncMetaTableManager get syncMeta => $SyncMetaTableManager(_db, _db.syncMeta);
  $PendingUploadsTableManager get pendingUploads =>
      $PendingUploadsTableManager(_db, _db.pendingUploads);
  $RecordVersionsTableManager get recordVersions =>
      $RecordVersionsTableManager(_db, _db.recordVersions);
  $ExpenseSearchTableManager get expenseSearch =>
      $ExpenseSearchTableManager(_db, _db.expenseSearch);
}
