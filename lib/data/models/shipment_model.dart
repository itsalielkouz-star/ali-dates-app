/// Shipment Model (معلومات الشحنة، المركبة، السائق والاستلام/التسليم)
class ShipmentModel {
  final String id;
  final int? shipmentNumber;
  final String direction; // 'inbound' (استلام) vs 'outbound' (تسليم)
  final String cargoType; // 'dates' (تمور) vs 'boxes' (صناديق حقل)
  final String customerId;
  final String? customerName;
  final String? farmId;
  final String? farmName;
  final String driverName; // اسم السائق
  final String agentName; // اسم وكيل العميل أو المشرف
  final String plateNumber; // رقم المركبة
  final String? truckPhotoUrl; // صورة المركبة
  final String? licensePhotoUrl; // صورة الرخصة
  final bool isPresorted; // مفروز أولي (checkbox)
  final String? boxContractType; // تحديد ملكية الصناديق: 'sorting' (عقد فرز), 'marketing' (عقد تسويق), 'purchase' (عقد شراء)
  final String status;
  final DateTime createdAt;

  static const String contractSorting = 'من عقد فرز';
  static const String contractMarketing = 'من عقد تسويق';
  static const String contractPurchase = 'من عقد شراء';

  ShipmentModel({
    required this.id,
    this.shipmentNumber,
    required this.direction,
    required this.cargoType,
    required this.customerId,
    this.customerName,
    this.farmId,
    this.farmName,
    required this.driverName,
    required this.agentName,
    required this.plateNumber,
    this.truckPhotoUrl,
    this.licensePhotoUrl,
    this.isPresorted = false,
    this.boxContractType,
    this.status = 'completed',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ShipmentModel.fromJson(Map<String, dynamic> json) {
    return ShipmentModel(
      id: json['id']?.toString() ?? '',
      shipmentNumber: json['shipment_number'] is int
          ? json['shipment_number']
          : int.tryParse(json['shipment_number']?.toString() ?? ''),
      direction: json['direction']?.toString() ?? 'inbound',
      cargoType: json['cargo_type']?.toString() ?? 'dates',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      farmId: json['farm_id']?.toString(),
      farmName: json['farm_name']?.toString(),
      driverName: json['driver_name']?.toString() ?? '',
      agentName: json['agent_name']?.toString() ?? '',
      plateNumber: json['plate_number']?.toString() ?? '',
      truckPhotoUrl: json['truck_photo_url']?.toString(),
      licensePhotoUrl: json['license_photo_url']?.toString(),
      isPresorted: json['is_presorted'] == true,
      boxContractType: json['box_contract_type']?.toString(),
      status: json['status']?.toString() ?? 'completed',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'direction': direction,
      'cargo_type': cargoType,
      'customer_id': customerId,
      'farm_id': farmId,
      'driver_name': driverName,
      'agent_name': agentName,
      'plate_number': plateNumber,
      'truck_photo_url': truckPhotoUrl,
      'license_photo_url': licensePhotoUrl,
      'is_presorted': isPresorted,
      'box_contract_type': boxContractType,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
