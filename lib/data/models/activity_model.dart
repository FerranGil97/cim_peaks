import 'package:cloud_firestore/cloud_firestore.dart';
enum SportType { walking, running, skiing, snowshoes, cycling, climbing }

extension SportTypeExtension on SportType {
  String get label {
    return switch (this) {
      SportType.walking => 'Caminant',
      SportType.running => 'Corrent',
      SportType.skiing => 'Esquiant',
      SportType.snowshoes => 'Raquetes',
      SportType.cycling => 'Bicicleta',
      SportType.climbing => 'Escalant',
    };
  }

  String get emoji {
    return switch (this) {
      SportType.walking => '🥾',
      SportType.running => '🏃',
      SportType.skiing => '⛷️',
      SportType.snowshoes => '🎿',
      SportType.cycling => '🚵',
      SportType.climbing => '🧗',
    };
  }
}

class ActivityModel {
  final String id;
  final String userId;
  final String userName;
  final String summitId;
  final String summitName;
  final int altitude;
  final String? title;
  final String? photoUrl;
  final String? description;
  final SportType? sport;
  final List<String> likes;
  final int commentsCount;
  final DateTime createdAt;
  final List<Map<String, String>> taggedUsers;
  final String? userPhotoUrl;

  ActivityModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.summitId,
    required this.summitName,
    required this.altitude,
    this.title,
    this.photoUrl,
    this.description,
    this.sport,
    this.likes = const [],
    this.commentsCount = 0,
    required this.createdAt,
    this.taggedUsers = const [],
    this.userPhotoUrl,
  });

  bool isLikedBy(String userId) => likes.contains(userId);
  int get likesCount => likes.length;

  factory ActivityModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Gestionar tant String ISO com Timestamp de Firestore
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value).toLocal();
      if (value is Timestamp) return value.toDate().toLocal();
      return DateTime.now();
    }

    return ActivityModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Usuari',
      summitId: data['summitId'] ?? '',
      summitName: data['summitName'] ?? '',
      altitude: (data['altitude'] ?? 0).toInt(),
      title: data['title'],
      photoUrl: data['photoUrl'],
      description: data['description'],
      sport: data['sport'] != null
          ? SportType.values.firstWhere(
              (e) => e.name == data['sport'],
              orElse: () => SportType.walking,
            )
          : null,
      likes: List<String>.from(data['likes'] ?? []),
      commentsCount: (data['commentsCount'] ?? 0).toInt(),
      createdAt: parseDate(data['createdAt']),
      taggedUsers: (data['taggedUsers'] as List<dynamic>? ?? [])
        .map((t) => Map<String, String>.from(t as Map))
        .toList(),
      userPhotoUrl: data['userPhotoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'summitId': summitId,
      'summitName': summitName,
      'altitude': altitude,
      'title': title,
      'photoUrl': photoUrl,
      'description': description,
      'sport': sport?.name,
      'likes': likes,
      'commentsCount': commentsCount,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'taggedUsers': taggedUsers,
      'userPhotoUrl': userPhotoUrl,
    };
  }
}

class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CommentModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Usuari',
      text: data['text'] ?? '',
      createdAt: DateTime.parse(data['createdAt']).toLocal(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'text': text,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }
}