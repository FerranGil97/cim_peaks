class SummitModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int altitude;
  final String? description;
  final String? imageUrl;
  final String? province;
  final String? massif;
  final SummitStatus status;
  final DateTime? achievedAt;
  final List<String> photos;

  SummitModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    this.description,
    this.imageUrl,
    this.province,
    this.massif,
    this.status = SummitStatus.pending,
    this.achievedAt,
    this.photos = const [],
  });

  factory SummitModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SummitModel(
      id: id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      altitude: data['altitude'] ?? 0,
      description: data['description'],
      imageUrl: data['imageUrl'],
      province: data['province'],
      massif: data['massif'],
      status: SummitStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => SummitStatus.pending,
      ),
      achievedAt: data['achievedAt'] != null
          ? DateTime.parse(data['achievedAt'])
          : null,
      photos: List<String>.from(data['photos'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'description': description,
      'imageUrl': imageUrl,
      'province': province,
      'massif': massif,
      'status': status.name,
      'achievedAt': achievedAt?.toIso8601String(),
      'photos': photos,
    };
  }

  SummitModel copyWith({
    String? name,
    double? latitude,
    double? longitude,
    int? altitude,
    String? description,
    String? imageUrl,
    String? province,
    String? massif,
    SummitStatus? status,
    DateTime? achievedAt,
    List<String>? photos,
  }) {
    return SummitModel(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      altitude: altitude ?? this.altitude,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      province: province ?? this.province,
      massif: massif ?? this.massif,
      status: status ?? this.status,
      achievedAt: achievedAt ?? this.achievedAt,
      photos: photos ?? this.photos,
    );
  }
}

enum SummitStatus { achieved, pending, saved }