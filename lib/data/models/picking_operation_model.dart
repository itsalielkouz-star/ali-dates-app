import 'dart:convert';

/// Model representing a single Load dispatched from the farm to Ali Dates facility
class HarvestLoadModel {
  final String id;
  final int loadNumber;
  final int crateCount;
  final DateTime departureTime;
  final String? vehicleInfo;
  final String? driverName;
  final String destination;
  final List<String> photoUrls;

  HarvestLoadModel({
    required this.id,
    required this.loadNumber,
    required this.crateCount,
    DateTime? departureTime,
    this.vehicleInfo,
    this.driverName,
    this.destination = 'مركز فرز تمور علي',
    this.photoUrls = const [],
  }) : departureTime = departureTime ?? DateTime.now();

  factory HarvestLoadModel.fromJson(Map<String, dynamic> json) {
    return HarvestLoadModel(
      id: json['id']?.toString() ?? '',
      loadNumber: json['load_number'] is int
          ? json['load_number']
          : int.tryParse(json['load_number']?.toString() ?? '1') ?? 1,
      crateCount: json['crate_count'] is int
          ? json['crate_count']
          : int.tryParse(json['crate_count']?.toString() ?? '0') ?? 0,
      departureTime: json['departure_time'] != null
          ? DateTime.tryParse(json['departure_time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      vehicleInfo: json['vehicle_info']?.toString(),
      driverName: json['driver_name']?.toString(),
      destination: json['destination']?.toString() ?? 'مركز فرز تمور علي',
      photoUrls: json['photo_urls'] != null
          ? List<String>.from(json['photo_urls'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'load_number': loadNumber,
      'crate_count': crateCount,
      'departure_time': departureTime.toIso8601String(),
      'vehicle_info': vehicleInfo,
      'driver_name': driverName,
      'destination': destination,
      'photo_urls': photoUrls,
    };
  }
}

/// Photographic evidence during field harvesting
class HarvestPhotoModel {
  final String id;
  final String title;
  final String? base64Data;
  final DateTime timestamp;

  HarvestPhotoModel({
    required this.id,
    required this.title,
    this.base64Data,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory HarvestPhotoModel.fromJson(Map<String, dynamic> json) {
    return HarvestPhotoModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      base64Data: json['base64_data']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'base64_data': base64Data,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Extra field expenses (e.g. transportation, meals, tractor hire)
class ExpenseItemModel {
  final String id;
  final String title;
  final double amount;
  final String category;
  final String? notes;

  ExpenseItemModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.notes,
  });

  factory ExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return ExpenseItemModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      category: json['category']?.toString() ?? 'نقل',
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'category': category,
      'notes': notes,
    };
  }
}

/// Crate Reconciliation details at the end of the operation
class CrateReconciliationModel {
  final int sentToFarm;
  final int filledReturned;
  final int emptyReturned;
  final int damaged;
  final int missing;
  final String? discrepancyNotes;

  CrateReconciliationModel({
    this.sentToFarm = 0,
    this.filledReturned = 0,
    this.emptyReturned = 0,
    this.damaged = 0,
    this.missing = 0,
    this.discrepancyNotes,
  });

  int get totalAccounted => filledReturned + emptyReturned + damaged;
  int get calculatedMissing => sentToFarm - totalAccounted;
  bool get hasDiscrepancy => calculatedMissing != 0 || damaged > 0;

  factory CrateReconciliationModel.fromJson(Map<String, dynamic> json) {
    return CrateReconciliationModel(
      sentToFarm: json['sent_to_farm'] ?? 0,
      filledReturned: json['filled_returned'] ?? 0,
      emptyReturned: json['empty_returned'] ?? 0,
      damaged: json['damaged'] ?? 0,
      missing: json['missing'] ?? 0,
      discrepancyNotes: json['discrepancy_notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sent_to_farm': sentToFarm,
      'filled_returned': filledReturned,
      'empty_returned': emptyReturned,
      'damaged': damaged,
      'missing': missing,
      'discrepancy_notes': discrepancyNotes,
    };
  }
}

/// Core Picking & Harvesting Operation Model (عملية القطاف والحصاد الميداني)
class PickingOperationModel {
  final String id;
  final String code; // e.g. HARV-2026-001
  final String customerId;
  final String customerName;
  final String farmId;
  final String farmName;
  final String landName;
  final String? landCode;

  // Planned Quantities (Estimates - Never Overwritten)
  final int plannedWorkers;
  final int plannedCrates;
  final double plannedEstimatedKg;
  final DateTime plannedDate;

  // Ali Dates Harvesting Supervisor (Ali Dates Employee)
  final String supervisorName;
  final String? supervisorId;

  // Labor Team Leader (One of the Daily Workers coordinating labor & payment distribution)
  final String laborTeamLeaderName;
  final String? laborTeamLeaderPhone;

  // Actual Field Execution
  final int actualWorkers;
  final double dailyWorkerRate; // JOD per day per worker
  final List<String> workerNames;

  // Operational Lifecycle Timestamps
  final DateTime? departedFacilityTime;
  final DateTime? arrivedAtFarmTime;
  final DateTime? harvestingStartTime;
  final DateTime? harvestingEndTime;
  final DateTime? leftFarmTime;
  final DateTime? returnedFacilityTime;

  // Lifecycle Status:
  // 'planned', 'crates_dispatched', 'team_dispatched', 'at_farm',
  // 'harvesting_in_progress', 'loads_dispatched', 'harvesting_completed',
  // 'in_transit', 'returned_to_facility', 'weighed', 'settled'
  final String status;

  // Loads & Photos & Expenses
  final List<HarvestLoadModel> loads;
  final List<HarvestPhotoModel> photos;
  final List<ExpenseItemModel> expenses;

  // Facility Weighing & Receiving
  final double? actualGrossWeight;
  final double? actualTareWeight;
  final double? actualNetWeight;

  // Crates Reconciliation
  final CrateReconciliationModel crateReconciliation;

  // Settlement & Notes
  final bool isLaborPaid;
  final bool isSettled;
  final String? notes;
  final DateTime createdAt;

  // Location Tracking & Live Coordinates
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final double? currentLatitude;
  final double? currentLongitude;
  final String? startLocationName;
  final String? endLocationName;

  PickingOperationModel({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    required this.farmId,
    required this.farmName,
    required this.landName,
    this.landCode,
    this.plannedWorkers = 20,
    this.plannedCrates = 150,
    this.plannedEstimatedKg = 1000.0,
    DateTime? plannedDate,
    required this.supervisorName,
    this.supervisorId,
    required this.laborTeamLeaderName,
    this.laborTeamLeaderPhone,
    this.actualWorkers = 20,
    this.dailyWorkerRate = 15.0,
    this.workerNames = const [],
    this.departedFacilityTime,
    this.arrivedAtFarmTime,
    this.harvestingStartTime,
    this.harvestingEndTime,
    this.leftFarmTime,
    this.returnedFacilityTime,
    this.status = 'planned',
    this.loads = const [],
    this.photos = const [],
    this.expenses = const [],
    this.actualGrossWeight,
    this.actualTareWeight,
    this.actualNetWeight,
    CrateReconciliationModel? crateReconciliation,
    this.isLaborPaid = false,
    this.isSettled = false,
    this.notes,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.currentLatitude,
    this.currentLongitude,
    this.startLocationName,
    this.endLocationName,
    DateTime? createdAt,
  })  : plannedDate = plannedDate ?? DateTime.now(),
        crateReconciliation = crateReconciliation ?? CrateReconciliationModel(),
        createdAt = createdAt ?? DateTime.now();

  // --- Computed Financial & Time Properties ---
  double get totalLaborCost => actualWorkers * dailyWorkerRate;
  double get totalExpensesCost => expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get totalPickingCost => totalLaborCost + totalExpensesCost;
  int get totalHarvestedCrates => loads.fold(0, (sum, l) => sum + l.crateCount);

  /// Calculated time taken for actual harvesting
  Duration? get harvestingDuration {
    if (harvestingStartTime == null) return null;
    final end = harvestingEndTime ?? DateTime.now();
    return end.difference(harvestingStartTime!);
  }

  /// Formatted duration string (e.g. "4 ساعات و 25 دقيقة")
  String get formattedDuration {
    final d = harvestingDuration;
    if (d == null) return 'غير محدد';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    if (hours > 0) {
      return '$hours ساعة و $minutes دقيقة';
    }
    return '$minutes دقيقة';
  }

  // Status Arabic Display
  String get statusAr {
    switch (status) {
      case 'planned':
        return 'مجدولة (قيد التجهيز)';
      case 'crates_dispatched':
        return 'تم إرسال الصناديق للحقل';
      case 'team_dispatched':
        return 'الفريق في الطريق للمزرعة';
      case 'at_farm':
        return 'تم الوصول للمزرعة';
      case 'harvesting_in_progress':
        return 'جاري القطاف والحصاد 🌴';
      case 'loads_dispatched':
        return 'تم تسيير شحنات للمصنع 🚚';
      case 'harvesting_completed':
        return 'تم إنهاء القطاف في الحقل';
      case 'in_transit':
        return 'الفريق في طريق العودة';
      case 'returned_to_facility':
        return 'وصلت المحصول للمصنع (بانتظار الوزن)';
      case 'weighed':
        return 'تم الوزن واستلام المحصول ⚖️';
      case 'settled':
        return 'مكتملة ومقفلة مالياً ✅';
      default:
        return 'مجدولة';
    }
  }

  factory PickingOperationModel.fromJson(Map<String, dynamic> json) {
    return PickingOperationModel(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      farmId: json['farm_id']?.toString() ?? '',
      farmName: json['farm_name']?.toString() ?? '',
      landName: json['land_name']?.toString() ?? '',
      landCode: json['land_code']?.toString(),
      plannedWorkers: json['planned_workers'] ?? 20,
      plannedCrates: json['planned_crates'] ?? 150,
      plannedEstimatedKg: (json['planned_estimated_kg'] is num)
          ? (json['planned_estimated_kg'] as num).toDouble()
          : 1000.0,
      plannedDate: json['planned_date'] != null
          ? DateTime.tryParse(json['planned_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      supervisorName: json['supervisor_name']?.toString() ?? 'مشرف تمور علي',
      supervisorId: json['supervisor_id']?.toString(),
      laborTeamLeaderName: json['labor_team_leader_name']?.toString() ?? 'عامل رئيس العمال',
      laborTeamLeaderPhone: json['labor_team_leader_phone']?.toString(),
      actualWorkers: json['actual_workers'] ?? 20,
      dailyWorkerRate: (json['daily_worker_rate'] is num)
          ? (json['daily_worker_rate'] as num).toDouble()
          : 15.0,
      workerNames: json['worker_names'] != null
          ? List<String>.from(json['worker_names'])
          : [],
      departedFacilityTime: json['departed_facility_time'] != null
          ? DateTime.tryParse(json['departed_facility_time'].toString())
          : null,
      arrivedAtFarmTime: json['arrived_at_farm_time'] != null
          ? DateTime.tryParse(json['arrived_at_farm_time'].toString())
          : null,
      harvestingStartTime: json['harvesting_start_time'] != null
          ? DateTime.tryParse(json['harvesting_start_time'].toString())
          : null,
      harvestingEndTime: json['harvesting_end_time'] != null
          ? DateTime.tryParse(json['harvesting_end_time'].toString())
          : null,
      leftFarmTime: json['left_farm_time'] != null
          ? DateTime.tryParse(json['left_farm_time'].toString())
          : null,
      returnedFacilityTime: json['returned_facility_time'] != null
          ? DateTime.tryParse(json['returned_facility_time'].toString())
          : null,
      status: json['status']?.toString() ?? 'planned',
      loads: json['loads'] != null
          ? (json['loads'] as List).map((l) => HarvestLoadModel.fromJson(l)).toList()
          : [],
      photos: json['photos'] != null
          ? (json['photos'] as List).map((p) => HarvestPhotoModel.fromJson(p)).toList()
          : [],
      expenses: json['expenses'] != null
          ? (json['expenses'] as List).map((e) => ExpenseItemModel.fromJson(e)).toList()
          : [],
      actualGrossWeight: (json['actual_gross_weight'] is num)
          ? (json['actual_gross_weight'] as num).toDouble()
          : null,
      actualTareWeight: (json['actual_tare_weight'] is num)
          ? (json['actual_tare_weight'] as num).toDouble()
          : null,
      actualNetWeight: (json['actual_net_weight'] is num)
          ? (json['actual_net_weight'] as num).toDouble()
          : null,
      crateReconciliation: json['crate_reconciliation'] != null
          ? CrateReconciliationModel.fromJson(json['crate_reconciliation'])
          : CrateReconciliationModel(),
      isLaborPaid: json['is_labor_paid'] == true,
      isSettled: json['is_settled'] == true,
      notes: json['notes']?.toString(),
      startLatitude: (json['start_latitude'] is num) ? (json['start_latitude'] as num).toDouble() : null,
      startLongitude: (json['start_longitude'] is num) ? (json['start_longitude'] as num).toDouble() : null,
      endLatitude: (json['end_latitude'] is num) ? (json['end_latitude'] as num).toDouble() : null,
      endLongitude: (json['end_longitude'] is num) ? (json['end_longitude'] as num).toDouble() : null,
      currentLatitude: (json['current_latitude'] is num) ? (json['current_latitude'] as num).toDouble() : null,
      currentLongitude: (json['current_longitude'] is num) ? (json['current_longitude'] as num).toDouble() : null,
      startLocationName: json['start_location_name']?.toString(),
      endLocationName: json['end_location_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'customer_id': customerId,
      'customer_name': customerName,
      'farm_id': farmId,
      'farm_name': farmName,
      'land_name': landName,
      'land_code': landCode,
      'planned_workers': plannedWorkers,
      'planned_crates': plannedCrates,
      'planned_estimated_kg': plannedEstimatedKg,
      'planned_date': plannedDate.toIso8601String(),
      'supervisor_name': supervisorName,
      'supervisor_id': supervisorId,
      'labor_team_leader_name': laborTeamLeaderName,
      'labor_team_leader_phone': laborTeamLeaderPhone,
      'actual_workers': actualWorkers,
      'daily_worker_rate': dailyWorkerRate,
      'worker_names': workerNames,
      'departed_facility_time': departedFacilityTime?.toIso8601String(),
      'arrived_at_farm_time': arrivedAtFarmTime?.toIso8601String(),
      'harvesting_start_time': harvestingStartTime?.toIso8601String(),
      'harvesting_end_time': harvestingEndTime?.toIso8601String(),
      'left_farm_time': leftFarmTime?.toIso8601String(),
      'returned_facility_time': returnedFacilityTime?.toIso8601String(),
      'status': status,
      'loads': loads.map((l) => l.toJson()).toList(),
      'photos': photos.map((p) => p.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'actual_gross_weight': actualGrossWeight,
      'actual_tare_weight': actualTareWeight,
      'actual_net_weight': actualNetWeight,
      'crate_reconciliation': crateReconciliation.toJson(),
      'is_labor_paid': isLaborPaid,
      'is_settled': isSettled,
      'notes': notes,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'end_latitude': endLatitude,
      'end_longitude': endLongitude,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'start_location_name': startLocationName,
      'end_location_name': endLocationName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PickingOperationModel copyWith({
    String? id,
    String? code,
    String? customerId,
    String? customerName,
    String? farmId,
    String? farmName,
    String? landName,
    String? landCode,
    int? plannedWorkers,
    int? plannedCrates,
    double? plannedEstimatedKg,
    DateTime? plannedDate,
    String? supervisorName,
    String? supervisorId,
    String? laborTeamLeaderName,
    String? laborTeamLeaderPhone,
    int? actualWorkers,
    double? dailyWorkerRate,
    List<String>? workerNames,
    DateTime? departedFacilityTime,
    DateTime? arrivedAtFarmTime,
    DateTime? harvestingStartTime,
    DateTime? harvestingEndTime,
    DateTime? leftFarmTime,
    DateTime? returnedFacilityTime,
    String? status,
    List<HarvestLoadModel>? loads,
    List<HarvestPhotoModel>? photos,
    List<ExpenseItemModel>? expenses,
    double? actualGrossWeight,
    double? actualTareWeight,
    double? actualNetWeight,
    CrateReconciliationModel? crateReconciliation,
    bool? isLaborPaid,
    bool? isSettled,
    String? notes,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    double? currentLatitude,
    double? currentLongitude,
    String? startLocationName,
    String? endLocationName,
  }) {
    return PickingOperationModel(
      id: id ?? this.id,
      code: code ?? this.code,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      farmId: farmId ?? this.farmId,
      farmName: farmName ?? this.farmName,
      landName: landName ?? this.landName,
      landCode: landCode ?? this.landCode,
      plannedWorkers: plannedWorkers ?? this.plannedWorkers,
      plannedCrates: plannedCrates ?? this.plannedCrates,
      plannedEstimatedKg: plannedEstimatedKg ?? this.plannedEstimatedKg,
      plannedDate: plannedDate ?? this.plannedDate,
      supervisorName: supervisorName ?? this.supervisorName,
      supervisorId: supervisorId ?? this.supervisorId,
      laborTeamLeaderName: laborTeamLeaderName ?? this.laborTeamLeaderName,
      laborTeamLeaderPhone: laborTeamLeaderPhone ?? this.laborTeamLeaderPhone,
      actualWorkers: actualWorkers ?? this.actualWorkers,
      dailyWorkerRate: dailyWorkerRate ?? this.dailyWorkerRate,
      workerNames: workerNames ?? this.workerNames,
      departedFacilityTime: departedFacilityTime ?? this.departedFacilityTime,
      arrivedAtFarmTime: arrivedAtFarmTime ?? this.arrivedAtFarmTime,
      harvestingStartTime: harvestingStartTime ?? this.harvestingStartTime,
      harvestingEndTime: harvestingEndTime ?? this.harvestingEndTime,
      leftFarmTime: leftFarmTime ?? this.leftFarmTime,
      returnedFacilityTime: returnedFacilityTime ?? this.returnedFacilityTime,
      status: status ?? this.status,
      loads: loads ?? this.loads,
      photos: photos ?? this.photos,
      expenses: expenses ?? this.expenses,
      actualGrossWeight: actualGrossWeight ?? this.actualGrossWeight,
      actualTareWeight: actualTareWeight ?? this.actualTareWeight,
      actualNetWeight: actualNetWeight ?? this.actualNetWeight,
      crateReconciliation: crateReconciliation ?? this.crateReconciliation,
      isLaborPaid: isLaborPaid ?? this.isLaborPaid,
      isSettled: isSettled ?? this.isSettled,
      notes: notes ?? this.notes,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      startLocationName: startLocationName ?? this.startLocationName,
      endLocationName: endLocationName ?? this.endLocationName,
      createdAt: createdAt,
    );
  }
}
