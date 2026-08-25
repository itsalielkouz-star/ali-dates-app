/// User & Contact Profile for Ali Dates Staff and Customers/Farmers
class UserProfile {
  final String id;
  final String phone;
  final String name;
  final bool isEmployee;
  final String companyName;
  final String passwordHash;
  final bool needsPasswordChange;
  final int? odooPartnerId;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.phone,
    required this.name,
    this.isEmployee = false,
    this.companyName = 'تمور علي',
    this.passwordHash = '1234',
    this.needsPasswordChange = true,
    this.odooPartnerId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin {
    final lower = name.toLowerCase().trim();
    return lower.contains('khaled') ||
        lower.contains('husam') ||
        lower.contains('ali elkouz') ||
        lower.contains('othman') ||
        lower.contains('خالد') ||
        lower.contains('حسام') ||
        lower.contains('علي الكوز') ||
        lower.contains('عثمان');
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isEmployee: json['is_employee'] == true,
      companyName: json['company_name']?.toString() ?? '',
      passwordHash: json['password_hash']?.toString() ?? '1234',
      needsPasswordChange: json['needs_password_change'] ??
          (json['password_hash'] == '1234'),
      odooPartnerId: json['odoo_partner_id'] is int
          ? json['odoo_partner_id']
          : int.tryParse(json['odoo_partner_id']?.toString() ?? ''),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'is_employee': isEmployee,
      'company_name': companyName,
      'password_hash': passwordHash,
      'needs_password_change': needsPasswordChange,
      'odoo_partner_id': odooPartnerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? phone,
    String? name,
    bool? isEmployee,
    String? companyName,
    String? passwordHash,
    bool? needsPasswordChange,
    int? odooPartnerId,
  }) {
    return UserProfile(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      isEmployee: isEmployee ?? this.isEmployee,
      companyName: companyName ?? this.companyName,
      passwordHash: passwordHash ?? this.passwordHash,
      needsPasswordChange: needsPasswordChange ?? this.needsPasswordChange,
      odooPartnerId: odooPartnerId ?? this.odooPartnerId,
      createdAt: createdAt,
    );
  }
}
