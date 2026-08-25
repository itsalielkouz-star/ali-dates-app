/// Output Pallet item produced from Sorting Machine (مخرجات الفرز)
class SortingOutputItem {
  final String id;
  final String? batchId;
  final String palletCode;
  final String category; // بريميوم, ديلايت, كلاسيك, سوفت بريميوم, احمر أ, احمر ب, بون بون, مفروز أولي...
  final String size; // سوبر جمبو, جمبو, لارج, ميديوم, سمول, سمول بيبي, مشكل
  final int boxCount; 
  final double weight; // Net weight of dates only
  final bool isCardboard; // هل الصناديق كرتون؟ (للفرز الأولي)
  final double boxTareWeight; // وزن الصندوق الفارغ (default 5kg if cardboard or user specified)
  final double palletTareWeight; // وزن الطبلية الفارغة
  final double grossWeight; // الوزن الإجمالي القائم
  final bool isFull; // علامة اكتمال الطبلية (صح/ممتلئة)

  SortingOutputItem({
    required this.id,
    this.batchId,
    required this.palletCode,
    required this.category,
    required this.size,
    required this.boxCount,
    double? weight,
    this.isCardboard = false,
    this.boxTareWeight = 0.95,
    this.palletTareWeight = 25.0,
    double? grossWeight,
    this.isFull = false,
  })  : weight = weight ?? (isCardboard ? (boxCount * 5.0) : (boxCount * 5.0)),
        grossWeight = grossWeight ?? ((weight ?? (boxCount * 5.0)) + (boxCount * (isCardboard ? 0.5 : 0.95)) + (palletTareWeight));

  SortingOutputItem copyWith({
    String? id,
    String? batchId,
    String? palletCode,
    String? category,
    String? size,
    int? boxCount,
    double? weight,
    bool? isCardboard,
    double? boxTareWeight,
    double? palletTareWeight,
    double? grossWeight,
    bool? isFull,
  }) {
    return SortingOutputItem(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      palletCode: palletCode ?? this.palletCode,
      category: category ?? this.category,
      size: size ?? this.size,
      boxCount: boxCount ?? this.boxCount,
      weight: weight ?? this.weight,
      isCardboard: isCardboard ?? this.isCardboard,
      boxTareWeight: boxTareWeight ?? this.boxTareWeight,
      palletTareWeight: palletTareWeight ?? this.palletTareWeight,
      grossWeight: grossWeight ?? this.grossWeight,
      isFull: isFull ?? this.isFull,
    );
  }

  factory SortingOutputItem.fromJson(Map<String, dynamic> json) {
    final boxes = int.tryParse(json['box_count']?.toString() ?? '0') ?? 0;
    return SortingOutputItem(
      id: json['id']?.toString() ?? '',
      batchId: json['batch_id']?.toString(),
      palletCode: json['pallet_code']?.toString() ?? '',
      category: json['category']?.toString() ?? 'بريميوم',
      size: json['size']?.toString() ?? 'جمبو',
      boxCount: boxes,
      weight: json['weight'] != null
          ? double.tryParse(json['weight'].toString()) ?? (boxes * 5.0)
          : (boxes * 5.0),
      isCardboard: json['is_cardboard'] == true || json['is_cardboard'] == 'true',
      boxTareWeight: double.tryParse(json['box_tare_weight']?.toString() ?? '5.0') ?? 5.0,
      palletTareWeight: double.tryParse(json['pallet_tare_weight']?.toString() ?? '25.0') ?? 25.0,
      grossWeight: double.tryParse(json['gross_weight']?.toString() ?? '0.0'),
      isFull: json['is_full'] == true || json['is_full'] == 'true',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'pallet_code': palletCode,
      'category': category,
      'size': size,
      'box_count': boxCount,
      'weight': weight,
      'is_cardboard': isCardboard,
      'box_tare_weight': boxTareWeight,
      'pallet_tare_weight': palletTareWeight,
      'gross_weight': grossWeight,
      'is_full': isFull,
    };
  }
}

/// Sorting Batch Model (دفعات الفرز الأولي والآلي - تدعم عدة طبالي مدخلة وطبالي مخرجة Many-to-Many)
class SortingBatchModel {
  final String id;
  final int? batchNumber;
  final String sourcePalletId; // Primary / first pallet ID
  final String? sourcePalletCode; // Primary / first pallet code
  final List<String> sourcePalletIds; // All source input pallet IDs (Many-to-Many)
  final List<String> sourcePalletCodes; // All source input pallet codes
  final String? sourcePalletLocation;
  final String customerId;
  final String? customerName;
  final String? farmId;
  final String? farmName;
  final String sortingType; // 'presort' (أولي) vs 'autosort' (آلي)
  final DateTime? scheduledDate;
  final double inputWeight;
  final double outputWeight;
  final double wasteWeight; // التالف / الفاقد
  final Map<String, double>? wasteDetails; // تفصيل أصناف الفرز الأولي
  final List<SortingOutputItem> outputPallets;
  final String status; // 'in_progress' (جاري الفرز), 'completed', 'cancelled'
  final DateTime createdAt;
  final DateTime? completedAt;

  SortingBatchModel({
    required this.id,
    this.batchNumber,
    required this.sourcePalletId,
    this.sourcePalletCode,
    List<String>? sourcePalletIds,
    List<String>? sourcePalletCodes,
    this.sourcePalletLocation,
    required this.customerId,
    this.customerName,
    this.farmId,
    this.farmName,
    required this.sortingType,
    this.scheduledDate,
    required this.inputWeight,
    this.outputWeight = 0.0,
    this.wasteWeight = 0.0,
    this.wasteDetails,
    this.outputPallets = const [],
    this.status = 'in_progress',
    DateTime? createdAt,
    this.completedAt,
  })  : sourcePalletIds = sourcePalletIds ?? [sourcePalletId],
        sourcePalletCodes = sourcePalletCodes ?? (sourcePalletCode != null ? [sourcePalletCode] : []),
        createdAt = createdAt ?? DateTime.now();

  bool get isOngoing => status == 'in_progress';

  bool get isPlanned {
    if (scheduledDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sched = DateTime(scheduledDate!.year, scheduledDate!.month, scheduledDate!.day);
    return sched.isAfter(today);
  }

  SortingBatchModel copyWith({
    String? id,
    int? batchNumber,
    String? sourcePalletId,
    String? sourcePalletCode,
    List<String>? sourcePalletIds,
    List<String>? sourcePalletCodes,
    String? sourcePalletLocation,
    String? customerId,
    String? customerName,
    String? farmId,
    String? farmName,
    String? sortingType,
    DateTime? scheduledDate,
    double? inputWeight,
    double? outputWeight,
    double? wasteWeight,
    Map<String, double>? wasteDetails,
    List<SortingOutputItem>? outputPallets,
    String? status,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return SortingBatchModel(
      id: id ?? this.id,
      batchNumber: batchNumber ?? this.batchNumber,
      sourcePalletId: sourcePalletId ?? this.sourcePalletId,
      sourcePalletCode: sourcePalletCode ?? this.sourcePalletCode,
      sourcePalletIds: sourcePalletIds ?? this.sourcePalletIds,
      sourcePalletCodes: sourcePalletCodes ?? this.sourcePalletCodes,
      sourcePalletLocation: sourcePalletLocation ?? this.sourcePalletLocation,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      farmId: farmId ?? this.farmId,
      farmName: farmName ?? this.farmName,
      sortingType: sortingType ?? this.sortingType,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      inputWeight: inputWeight ?? this.inputWeight,
      outputWeight: outputWeight ?? this.outputWeight,
      wasteWeight: wasteWeight ?? this.wasteWeight,
      wasteDetails: wasteDetails ?? this.wasteDetails,
      outputPallets: outputPallets ?? this.outputPallets,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory SortingBatchModel.fromJson(Map<String, dynamic> json) {
    List<SortingOutputItem> outputs = [];
    if (json['output_pallets'] != null && json['output_pallets'] is List) {
      outputs = (json['output_pallets'] as List)
          .map((e) => SortingOutputItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    Map<String, double>? wasteMap;
    if (json['waste_details'] != null && json['waste_details'] is Map) {
      wasteMap = (json['waste_details'] as Map).map(
        (key, value) => MapEntry(
          key.toString(),
          double.tryParse(value?.toString() ?? '0') ?? 0.0,
        ),
      );
    }

    final sId = json['source_pallet_id']?.toString() ?? '';
    final sCode = json['source_pallet_code']?.toString();

    List<String> sIds = [];
    if (json['source_pallet_ids'] != null && json['source_pallet_ids'] is List) {
      sIds = (json['source_pallet_ids'] as List).map((e) => e.toString()).toList();
    } else if (sId.isNotEmpty) {
      sIds = [sId];
    }

    List<String> sCodes = [];
    if (json['source_pallet_codes'] != null && json['source_pallet_codes'] is List) {
      sCodes = (json['source_pallet_codes'] as List).map((e) => e.toString()).toList();
    } else if (sCode != null && sCode.isNotEmpty) {
      sCodes = [sCode];
    }

    return SortingBatchModel(
      id: json['id']?.toString() ?? '',
      batchNumber: json['batch_number'] is int
          ? json['batch_number']
          : int.tryParse(json['batch_number']?.toString() ?? ''),
      sourcePalletId: sId,
      sourcePalletCode: sCode,
      sourcePalletIds: sIds,
      sourcePalletCodes: sCodes,
      sourcePalletLocation: json['source_pallet_location']?.toString(),
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString(),
      farmId: json['farm_id']?.toString(),
      farmName: json['farm_name']?.toString(),
      sortingType: json['sorting_type']?.toString() ?? 'autosort',
      scheduledDate: json['scheduled_date'] != null
          ? DateTime.tryParse(json['scheduled_date'].toString())
          : null,
      inputWeight:
          double.tryParse(json['input_weight']?.toString() ?? '0') ?? 0.0,
      outputWeight:
          double.tryParse(json['output_weight']?.toString() ?? '0') ?? 0.0,
      wasteWeight:
          double.tryParse(json['waste_weight']?.toString() ?? '0') ?? 0.0,
      wasteDetails: wasteMap,
      outputPallets: outputs,
      status: json['status']?.toString() ?? 'in_progress',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source_pallet_id': sourcePalletId,
      'source_pallet_code': sourcePalletCode,
      'source_pallet_ids': sourcePalletIds,
      'source_pallet_codes': sourcePalletCodes,
      'source_pallet_location': sourcePalletLocation,
      'customer_id': customerId,
      'farm_id': farmId,
      'sorting_type': sortingType,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'input_weight': inputWeight,
      'output_weight': outputWeight,
      'waste_weight': wasteWeight,
      'waste_details': wasteDetails,
      'output_pallets': outputPallets.map((e) => e.toJson()).toList(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}
