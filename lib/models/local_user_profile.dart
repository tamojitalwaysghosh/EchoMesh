class LocalUserProfile {
  const LocalUserProfile({
    required this.username,
    required this.meshId,
    this.avatarPath,
    this.emergencyInfo = '',
  });

  final String username;
  /// Stable id embedded in BLE wire payloads (not the Bluetooth MAC).
  final String meshId;
  final String? avatarPath;
  final String emergencyInfo;

  Map<String, dynamic> toJson() => {
        'username': username,
        'meshId': meshId,
        'avatarPath': avatarPath,
        'emergencyInfo': emergencyInfo,
      };

  factory LocalUserProfile.fromJson(Map<String, dynamic> j) {
    return LocalUserProfile(
      username: j['username'] as String? ?? 'Operator',
      meshId: j['meshId'] as String? ?? '',
      avatarPath: j['avatarPath'] as String?,
      emergencyInfo: j['emergencyInfo'] as String? ?? '',
    );
  }

  LocalUserProfile copyWith({
    String? username,
    String? meshId,
    String? avatarPath,
    String? emergencyInfo,
  }) {
    return LocalUserProfile(
      username: username ?? this.username,
      meshId: meshId ?? this.meshId,
      avatarPath: avatarPath ?? this.avatarPath,
      emergencyInfo: emergencyInfo ?? this.emergencyInfo,
    );
  }
}
