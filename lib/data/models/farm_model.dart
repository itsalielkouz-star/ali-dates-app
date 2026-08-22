/// Farm Model for Customers/Farmers (مزارع التمور)
class FarmModel {
  final String id;
  final String customerId;
  final String name;
  final String governorate; // المحافظة أو المنطقة
  final String? code; // كود المزرعة (اختياري)
  final DateTime createdAt;

  FarmModel({
    required this.id,
    required this.customerId,
    required this.name,
    required this.governorate,
    this.code,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory FarmModel.fromJson(Map<String, dynamic> json) {
    return FarmModel(
      id: json['id']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      governorate: json['governorate']?.toString() ?? 'الأغوار الجنوبية',
      code: json['code']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'name': name,
      'governorate': governorate,
      'code': code,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
