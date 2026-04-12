enum BusinessType { accommodation, guide, restaurant, activity }

extension BusinessTypeExtension on BusinessType {
  String get label {
    return switch (this) {
      BusinessType.accommodation => 'Allotjament',
      BusinessType.guide => 'Guia',
      BusinessType.restaurant => 'Restauració',
      BusinessType.activity => 'Activitat',
    };
  }

  String get emoji {
    return switch (this) {
      BusinessType.accommodation => '🏨',
      BusinessType.guide => '🧗',
      BusinessType.restaurant => '🍽️',
      BusinessType.activity => '⛷️',
    };
  }
}

class BusinessModel {
  final String id;
  final String name;
  final BusinessType type;
  final String description;
  final String? photoUrl;
  final List<String> photos;
  final double latitude;
  final double longitude;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? comarca;
  final List<String> linkedSummitIds;
  final List<ServiceModel> services;
  final bool isPro;
  final double? rating;
  final int reviewsCount;
  final DateTime createdAt;

  BusinessModel({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    this.photoUrl,
    this.photos = const [],
    required this.latitude,
    required this.longitude,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.comarca,
    this.linkedSummitIds = const [],
    this.services = const [],
    this.isPro = false,
    this.rating,
    this.reviewsCount = 0,
    required this.createdAt,
  });

  factory BusinessModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BusinessModel(
      id: id,
      name: data['name'] ?? '',
      type: BusinessType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'accommodation'),
        orElse: () => BusinessType.accommodation,
      ),
      description: data['description'] ?? '',
      photoUrl: data['photoUrl'],
      photos: List<String>.from(data['photos'] ?? []),
      latitude: (data['latitude'] ?? 0).toDouble(),
      longitude: (data['longitude'] ?? 0).toDouble(),
      address: data['address'],
      phone: data['phone'],
      email: data['email'],
      website: data['website'],
      comarca: data['comarca'],
      linkedSummitIds: List<String>.from(data['linkedSummitIds'] ?? []),
      services: (data['services'] as List<dynamic>? ?? [])
          .map((s) => ServiceModel.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
      isPro: data['isPro'] ?? false,
      rating: data['rating']?.toDouble(),
      reviewsCount: (data['reviewsCount'] ?? 0).toInt(),
      createdAt: DateTime.parse(
          data['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'type': type.name,
      'description': description,
      'photoUrl': photoUrl,
      'photos': photos,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'comarca': comarca,
      'linkedSummitIds': linkedSummitIds,
      'services': services.map((s) => s.toMap()).toList(),
      'isPro': isPro,
      'rating': rating,
      'reviewsCount': reviewsCount,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class ServiceModel {
  final String name;
  final String? description;
  final double? price;
  final String? priceUnit;

  ServiceModel({
    required this.name,
    this.description,
    this.price,
    this.priceUnit,
  });

  factory ServiceModel.fromMap(Map<String, dynamic> data) {
    return ServiceModel(
      name: data['name'] ?? '',
      description: data['description'],
      price: data['price']?.toDouble(),
      priceUnit: data['priceUnit'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'priceUnit': priceUnit,
    };
  }
}