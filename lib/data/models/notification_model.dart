enum NotificationType { medal, follow, like, comment }

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? activityId;
  final String? fromUserId;
  final String? fromUserName;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.activityId,
    this.fromUserId,
    this.fromUserName,
  });

  String get icon {
    return switch (type) {
      NotificationType.medal => '🏅',
      NotificationType.follow => '👤',
      NotificationType.like => '❤️',
      NotificationType.comment => '💬',
    };
  }

  factory NotificationModel.fromFirestore(
      Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      userId: data['userId'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'medal'),
        orElse: () => NotificationType.medal,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: DateTime.parse(data['createdAt']),
      activityId: data['activityId'],
      fromUserId: data['fromUserId'],
      fromUserName: data['fromUserName'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'activityId': activityId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
    };
  }
}