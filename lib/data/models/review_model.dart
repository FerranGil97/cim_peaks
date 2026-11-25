class ReviewModel {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final double rating;
  final String? comment;
  final DateTime createdAt;

  ReviewModel({
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory ReviewModel.fromFirestore(Map<String, dynamic> data) {
    return ReviewModel(
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Usuari',
      userPhotoUrl: data['userPhotoUrl'],
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'],
      createdAt: DateTime.parse(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}