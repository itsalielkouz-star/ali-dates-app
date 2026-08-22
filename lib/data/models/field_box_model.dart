/// Field Boxes Model (صناديق الحقل - إدخال، إخراج، وتأجير)
class FieldBoxModel {
  final String id;
  final String? shipmentId;
  final String customerId;
  final String? customerName;
  final int boxCount;
  final int damagedCount; // التالف
  final int lostCount; // مفقود
  final int rentalDurationDays; // مدة الإيجار
  final double rentalPricePerBox; // إيجار الصندوق بالدينار
  final DateTime createdAt;

  FieldBoxModel({
    required this.id,
    this.shipmentId,
    required this.customerId,
    this.customerName,
    required this.boxCount,
    this.damagedCount = 0,
    this.lostCount = 0,
    this.rentalDurationDays = 0,
    this.rentalPricePerBox = 0.0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get totalRentalCost => boxCount * rentalPricePerBox;

  factory FieldBoxModel.fromJson(Map<String, dynamic> json) {
    return FieldBoxModel(
      id: json['id']?.toString() ?? '',
      shipmentId: json['shipment_id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      boxCount: int.tryParse(json['box_count']?.toString() ?? '0') ?? 0,
      damagedCount:
          int.tryParse(json['damaged_count']?.toString() ?? '0') ?? 0,
      lostCount: int.tryParse(json['lost_count']?.toString() ?? '0') ?? 0,
      rentalDurationDays:
          int.tryParse(json['rental_duration_days']?.toString() ?? '0') ?? 0,
      rentalPricePerBox:
          double.tryParse(json['rental_price_per_box']?.toString() ?? '0') ??
              0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shipment_id': shipmentId,
      'customer_id': customerId,
      'box_count': boxCount,
      'damaged_count': damagedCount,
      'lost_count': lostCount,
      'rental_duration_days': rentalDurationDays,
      'rental_price_per_box': rentalPricePerBox,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
