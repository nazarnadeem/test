import 'package:flutter/material.dart';

/// Platform Subscription Plan Model for GCRM One Gym Franchises (Yearly Pricing).
class PlatformPlanModel {
  final String id;
  final String name;
  final String tagline;
  final double price; // Annual package price (₹ / year)
  final double? discountedPrice; // Promotional Annual price (₹ / year)
  final double? renewalPrice; // Subsequent Annual renewal price (₹ / year)
  final String billingPeriod;
  final int maxMembers;
  final int maxStaff;
  final List<String> features;
  final bool isPopular;
  final bool isActive;
  final int subscribedGymsCount;
  final Color accentColor;

  const PlatformPlanModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.price,
    this.discountedPrice,
    this.renewalPrice,
    this.billingPeriod = 'year',
    this.maxMembers = 99999,
    this.maxStaff = 99,
    required this.features,
    this.isPopular = false,
    this.isActive = true,
    this.subscribedGymsCount = 0,
    this.accentColor = const Color(0xFF00E599),
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tagline': tagline,
      'price': price,
      'discountedPrice': discountedPrice,
      'renewalPrice': renewalPrice,
      'billingPeriod': billingPeriod,
      'maxMembers': maxMembers,
      'maxStaff': maxStaff,
      'features': features,
      'isPopular': isPopular,
      'isActive': isActive,
      'subscribedGymsCount': subscribedGymsCount,
      'accentColor': accentColor.toARGB32(),
    };
  }

  factory PlatformPlanModel.fromJson(Map<String, dynamic> json) {
    return PlatformPlanModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Custom Plan',
      tagline: json['tagline'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      discountedPrice: (json['discountedPrice'] as num?)?.toDouble(),
      renewalPrice: (json['renewalPrice'] as num?)?.toDouble(),
      billingPeriod: json['billingPeriod'] as String? ?? 'year',
      maxMembers: (json['maxMembers'] as num?)?.toInt() ?? 99999,
      maxStaff: (json['maxStaff'] as num?)?.toInt() ?? 99,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isPopular: json['isPopular'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      subscribedGymsCount: (json['subscribedGymsCount'] as num?)?.toInt() ?? 0,
      accentColor: json['accentColor'] != null
          ? Color(json['accentColor'] as int)
          : const Color(0xFF00E599),
    );
  }

  PlatformPlanModel copyWith({
    String? id,
    String? name,
    String? tagline,
    double? price,
    double? discountedPrice,
    double? renewalPrice,
    String? billingPeriod,
    int? maxMembers,
    int? maxStaff,
    List<String>? features,
    bool? isPopular,
    bool? isActive,
    int? subscribedGymsCount,
    Color? accentColor,
  }) {
    return PlatformPlanModel(
      id: id ?? this.id,
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      price: price ?? this.price,
      discountedPrice: discountedPrice ?? this.discountedPrice,
      renewalPrice: renewalPrice ?? this.renewalPrice,
      billingPeriod: billingPeriod ?? this.billingPeriod,
      maxMembers: maxMembers ?? this.maxMembers,
      maxStaff: maxStaff ?? this.maxStaff,
      features: features ?? this.features,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
      subscribedGymsCount: subscribedGymsCount ?? this.subscribedGymsCount,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  /// Empty default list - plans are loaded dynamically from Firebase Firestore
  static List<PlatformPlanModel> get defaultPlans => const [];
}
