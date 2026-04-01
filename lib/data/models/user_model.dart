class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final int totalSummits;
  final int level;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.totalSummits = 0,
    this.level = 1,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      totalSummits: data['totalSummits'] ?? 0,
      level: data['level'] ?? 1,
      createdAt: DateTime.parse(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'totalSummits': totalSummits,
      'level': level,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}