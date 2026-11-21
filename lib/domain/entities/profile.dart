/// The signed-in person's profile (B2). Co-members see name, photo and UPI ID.
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.avatarPath,
    this.upiId,
    this.defaultCurrency = 'INR',
  });

  /// Reads the server / cache JSON (`update_profile` result, `profiles` row).
  factory Profile.fromJson(Map<String, Object?> json) => Profile(
    id: json['id']! as String,
    displayName: json['display_name']! as String,
    avatarPath: json['avatar_path'] as String?,
    upiId: json['upi_id'] as String?,
    defaultCurrency: (json['default_currency'] as String?)?.trim() ?? 'INR',
  );

  final String id;
  final String displayName;

  /// Path in the `avatars` bucket (`<user id>/<uuid>.jpg`), or null.
  final String? avatarPath;
  final String? upiId;
  final String defaultCurrency;

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'avatar_path': avatarPath,
    'upi_id': upiId,
    'default_currency': defaultCurrency,
  };

  /// Copy with changes; pass `clearUpi` / `clearAvatar` to remove a value.
  Profile copyWith({
    String? displayName,
    String? avatarPath,
    String? upiId,
    String? defaultCurrency,
    bool clearUpi = false,
    bool clearAvatar = false,
  }) => Profile(
    id: id,
    displayName: displayName ?? this.displayName,
    avatarPath: clearAvatar ? null : avatarPath ?? this.avatarPath,
    upiId: clearUpi ? null : upiId ?? this.upiId,
    defaultCurrency: defaultCurrency ?? this.defaultCurrency,
  );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarPath == avatarPath &&
      other.upiId == upiId &&
      other.defaultCurrency == defaultCurrency;

  @override
  int get hashCode => Object.hash(id, displayName, avatarPath, upiId, defaultCurrency);
}
