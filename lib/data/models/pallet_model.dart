import '../../core/constants/app_constants.dart';

/// Pallet Model for Dates Warehouse & Tracking (طبالي التمور)
class PalletModel {
  final String id;
  final String palletCode; // QR code or unique reference
  final String? shipmentId;
  final String customerId;
  final String? customerName;
  final String? farmId;
  final String? farmName;
  final double emptyPalletWeight;
  final double emptyBoxWeight;
  final int boxCount;
  final double grossWeight;
  final double netWeight;
  final String locationType;
  final String? freezerRow;
  final int? freezerCol;
  final int? freezerLayer;
  final String? locationCode; // e.g. A11, O63
  final String status;
  final bool isPresorted;
  final String? category;
  final String? size;
  final String? pairedPalletId; // ID of pallet stacked together in the same slot
  final String? pairedPalletCode; // Code of pallet stacked together
  final bool isStackedTop; // True if this pallet is sitting on top of another in the slot
  final DateTime createdAt;

  PalletModel({
    required this.id,
    required this.palletCode,
    this.shipmentId,
    required this.customerId,
    this.customerName,
    this.farmId,
    this.farmName,
    this.emptyPalletWeight = AppConstants.defaultEmptyPalletWeight,
    this.emptyBoxWeight = AppConstants.defaultEmptyBoxWeight,
    this.boxCount = AppConstants.defaultBoxCount,
    required this.grossWeight,
    double? netWeight,
    this.locationType = AppConstants.locPreFridge,
    this.freezerRow,
    this.freezerCol,
    this.freezerLayer,
    this.locationCode,
    this.status = 'received',
    this.isPresorted = false,
    this.category,
    this.size,
    this.pairedPalletId,
    this.pairedPalletCode,
    this.isStackedTop = false,
    DateTime? createdAt,
  })  : netWeight = netWeight ??
            calculateTareWeight(
              gross: grossWeight,
              palletEmpty: emptyPalletWeight,
              boxEmpty: emptyBoxWeight,
              boxes: boxCount,
            ),
        createdAt = createdAt ?? DateTime.now();

  /// Tare calculation formula:
  /// Net Weight = Gross Weight - (Empty Pallet Weight + (Empty Box Weight * Box Count))
  static double calculateTareWeight({
    required double gross,
    required double palletEmpty,
    required double boxEmpty,
    required int boxes,
  }) {
    final tare = gross - (palletEmpty + (boxEmpty * boxes));
    return tare > 0 ? double.parse(tare.toStringAsFixed(2)) : 0.0;
  }

  factory PalletModel.fromJson(Map<String, dynamic> json) {
    final gross = double.tryParse(json['gross_weight']?.toString() ?? '0') ?? 0.0;
    final palletEmpty =
        double.tryParse(json['empty_pallet_weight']?.toString() ?? '16.0') ?? 16.0;
    final boxEmpty =
        double.tryParse(json['empty_box_weight']?.toString() ?? '0.95') ?? 0.95;
    final boxes = int.tryParse(json['box_count']?.toString() ?? '200') ?? 200;
    final net = json['net_weight'] != null
        ? double.tryParse(json['net_weight'].toString()) ?? 0.0
        : calculateTareWeight(
            gross: gross,
            palletEmpty: palletEmpty,
            boxEmpty: boxEmpty,
            boxes: boxes,
          );

    return PalletModel(
      id: json['id']?.toString() ?? '',
      palletCode: json['pallet_code']?.toString() ?? '',
      shipmentId: json['shipment_id']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      farmId: json['farm_id']?.toString(),
      farmName: json['farm_name']?.toString(),
      emptyPalletWeight: palletEmpty,
      emptyBoxWeight: boxEmpty,
      boxCount: boxes,
      grossWeight: gross,
      netWeight: net,
      locationType: json['location_type']?.toString() ?? AppConstants.locPreFridge,
      freezerRow: json['freezer_row']?.toString(),
      freezerCol: json['freezer_col'] is int
          ? json['freezer_col']
          : int.tryParse(json['freezer_col']?.toString() ?? ''),
      freezerLayer: json['freezer_layer'] is int
          ? json['freezer_layer']
          : int.tryParse(json['freezer_layer']?.toString() ?? ''),
      locationCode: json['location_code']?.toString(),
      status: json['status']?.toString() ?? 'received',
      isPresorted: json['is_presorted'] == true,
      category: json['category']?.toString(),
      size: json['size']?.toString(),
      pairedPalletId: json['paired_pallet_id']?.toString(),
      pairedPalletCode: json['paired_pallet_code']?.toString(),
      isStackedTop: json['is_stacked_top'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pallet_code': palletCode,
      'shipment_id': shipmentId,
      'customer_id': customerId,
      'farm_id': farmId,
      'empty_pallet_weight': emptyPalletWeight,
      'empty_box_weight': emptyBoxWeight,
      'box_count': boxCount,
      'gross_weight': grossWeight,
      'net_weight': netWeight,
      'location_type': locationType,
      'freezer_row': freezerRow,
      'freezer_col': freezerCol,
      'freezer_layer': freezerLayer,
      'location_code': locationCode,
      'status': status,
      'is_presorted': isPresorted,
      'category': category,
      'size': size,
      'paired_pallet_id': pairedPalletId,
      'paired_pallet_code': pairedPalletCode,
      'is_stacked_top': isStackedTop,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PalletModel copyWith({
    String? locationType,
    String? freezerRow,
    int? freezerCol,
    int? freezerLayer,
    String? locationCode,
    String? status,
    bool? isPresorted,
    String? category,
    String? size,
    String? pairedPalletId,
    String? pairedPalletCode,
    bool? isStackedTop,
    bool clearPairing = false,
  }) {
    return PalletModel(
      id: id,
      palletCode: palletCode,
      shipmentId: shipmentId,
      customerId: customerId,
      customerName: customerName,
      farmId: farmId,
      farmName: farmName,
      emptyPalletWeight: emptyPalletWeight,
      emptyBoxWeight: emptyBoxWeight,
      boxCount: boxCount,
      grossWeight: grossWeight,
      netWeight: netWeight,
      locationType: locationType ?? this.locationType,
      freezerRow: freezerRow ?? this.freezerRow,
      freezerCol: freezerCol ?? this.freezerCol,
      freezerLayer: freezerLayer ?? this.freezerLayer,
      locationCode: locationCode ?? this.locationCode,
      status: status ?? this.status,
      isPresorted: isPresorted ?? this.isPresorted,
      category: category ?? this.category,
      size: size ?? this.size,
      pairedPalletId: clearPairing ? null : (pairedPalletId ?? this.pairedPalletId),
      pairedPalletCode: clearPairing ? null : (pairedPalletCode ?? this.pairedPalletCode),
      isStackedTop: clearPairing ? false : (isStackedTop ?? this.isStackedTop),
      createdAt: createdAt,
    );
  }

  String get qrData => palletCode;

  String get displayLocation {
    if (locationCode != null && locationCode!.isNotEmpty) {
      final locName = AppConstants.locationNamesAr[locationType] ?? locationType;
      return '$locName - موقع ($locationCode)';
    }
    return AppConstants.locationNamesAr[locationType] ?? locationType;
  }

  /// Returns true if the owner during receiving was Ali Dates (تمور علي / Ali Elkouz / Khaled Ali Elkouz)
  bool get isOwnedByAliDates {
    final cName = (customerName ?? '').toLowerCase();
    return cName.contains('ali dates') ||
        cName.contains('تمور علي') ||
        cName.contains('ali elkouz') ||
        cName.contains('elkouz') ||
        cName.contains('الكوز');
  }
}
