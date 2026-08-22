/// Activity Log Model for Operations Tracking (سجل العمليات والمسح والفرز والنقل)
class ActivityLogModel {
  final String id;
  final String actionType; // 'scan', 'sort_start', 'sort_finish', 'transfer', 'shift_start', 'pallet_stacked'
  final String title;
  final String details;
  final String employeeName;
  final String? employeeId;
  final String? supervisorName; // مسؤول الشفت
  final String? palletCode;
  final String? locationCode;
  final DateTime timestamp;

  ActivityLogModel({
    required this.id,
    required this.actionType,
    required this.title,
    required this.details,
    required this.employeeName,
    this.employeeId,
    this.supervisorName,
    this.palletCode,
    this.locationCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ActivityLogModel.fromJson(Map<String, dynamic> json) {
    return ActivityLogModel(
      id: json['id']?.toString() ?? '',
      actionType: json['action_type']?.toString() ?? 'scan',
      title: json['title']?.toString() ?? '',
      details: json['details']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? 'موظف غير محدد',
      employeeId: json['employee_id']?.toString(),
      supervisorName: json['supervisor_name']?.toString(),
      palletCode: json['pallet_code']?.toString(),
      locationCode: json['location_code']?.toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action_type': actionType,
      'title': title,
      'details': details,
      'employee_name': employeeName,
      'employee_id': employeeId,
      'supervisor_name': supervisorName,
      'pallet_code': palletCode,
      'location_code': locationCode,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
