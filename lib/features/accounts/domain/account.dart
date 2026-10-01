/// نموذج حساب الطالب في الجهاز.
///
/// يمثل طالباً واحداً مسجّلاً على نفس الجهاز (حد أقصى 10 حسابات).
/// التوكن (wstoken) لا يُخزَّن هنا بل في مخزن آمن منفصل (SecureTokenStore).
class Account {
  const Account({
    required this.id,
    required this.serverUrl,
    required this.username,
    required this.displayName,
    this.moodleUserId,
    this.avatarUrl,
    this.isDemo = false,
    required this.colorIndex,
    required this.sortOrder,
    required this.createdAt,
    this.lastSyncedAt,
  });

  final String id;
  final String serverUrl;
  final String username;
  final int? moodleUserId;
  final String displayName;
  final String? avatarUrl;
  final bool isDemo;
  final int colorIndex;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime? lastSyncedAt;

  /// أول حرفين من الاسم لعرضهما داخل دائرة الحساب.
  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) {
      final word = parts.first;
      return word.substring(0, word.length.clamp(0, 2));
    }
    return '${_firstLetter(parts.first)}${_firstLetter(parts.last)}';
  }

  /// أول حرف من كلمة، مع تجاهل «ال» التعريف (العلي ← ع).
  static String _firstLetter(String word) {
    var w = word;
    if (w.length > 2 && w.startsWith('ال')) w = w.substring(2);
    return w[0];
  }

  Account copyWith({
    String? serverUrl,
    String? username,
    String? displayName,
    int? moodleUserId,
    String? avatarUrl,
    bool? isDemo,
    int? colorIndex,
    int? sortOrder,
    DateTime? lastSyncedAt,
    bool clearLastSync = false,
  }) {
    return Account(
      id: id,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      moodleUserId: moodleUserId ?? this.moodleUserId,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isDemo: isDemo ?? this.isDemo,
      colorIndex: colorIndex ?? this.colorIndex,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      lastSyncedAt: clearLastSync
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'serverUrl': serverUrl,
        'username': username,
        'moodleUserId': moodleUserId,
        'displayName': displayName,
        'avatarUrl': avatarUrl,
        'isDemo': isDemo,
        'colorIndex': colorIndex,
        'sortOrder': sortOrder,
        'createdAt': createdAt.toIso8601String(),
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        serverUrl: map['serverUrl'] as String,
        username: map['username'] as String,
        moodleUserId: map['moodleUserId'] as int?,
        displayName: map['displayName'] as String,
        avatarUrl: map['avatarUrl'] as String?,
        isDemo: map['isDemo'] as bool? ?? false,
        colorIndex: map['colorIndex'] as int? ?? 0,
        sortOrder: map['sortOrder'] as int? ?? 0,
        createdAt: DateTime.parse(map['createdAt'] as String),
        lastSyncedAt: map['lastSyncedAt'] == null
            ? null
            : DateTime.parse(map['lastSyncedAt'] as String),
      );
}
