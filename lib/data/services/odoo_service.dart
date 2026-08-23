import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../core/constants/api_config.dart';
import '../../core/utils/phone_utils.dart';
import '../models/user_profile.dart';

/// Odoo ERP Service for Both Employee (`hr.employee`) and Contact (`res.partner`) Modules
class OdooService {
  /// Resolves the JSON-RPC endpoint
  static Uri get odooJsonRpcUri {
    final odooBase = ApiConfig.odooUrl.isNotEmpty
        ? ApiConfig.odooUrl
        : 'https://odoo-ps-psae-ali-dates.odoo.com';
    return Uri.parse('$odooBase/jsonrpc');
  }

  /// Look up a person by phone number comparing both Odoo Employee App & Contact App
  static Future<UserProfile?> lookupContactByPhone(String rawPhone) async {
    final cleanPhone = PhoneUtils.toLocal(rawPhone);
    final baseDigits = PhoneUtils.getBaseDigits(rawPhone);

    try {
      final authUrl = odooJsonRpcUri;
      
      // 1. Authenticate with Odoo JSON-RPC
      final authPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'common',
          'method': 'authenticate',
          'args': [
            ApiConfig.odooDatabase,
            ApiConfig.odooEmail,
            ApiConfig.odooApiKey,
            {},
          ],
        },
        'id': 1,
      };

      final authResponse = await http
          .post(
            authUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(authPayload),
          )
          .timeout(const Duration(seconds: 4));

      if (authResponse.statusCode != 200) return null;

      final authJson = jsonDecode(authResponse.body);
      final uid = authJson['result'];
      if (uid is! int || uid <= 0) return null;

      // 2. CHECK 1: Odoo Employee App (`hr.employee`)
      // If found here, the person is 100% an internal worker/employee of Ali Dates
      final empSearchPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'object',
          'method': 'execute_kw',
          'args': [
            ApiConfig.odooDatabase,
            uid,
            ApiConfig.odooApiKey,
            'hr.employee',
            'search_read',
            [
              [
                '|',
                ['work_phone', 'ilike', baseDigits],
                ['mobile_phone', 'ilike', baseDigits],
              ]
            ],
            {
              'fields': [
                'id',
                'name',
                'work_phone',
                'mobile_phone',
                'work_email',
                'job_title',
                'department_id',
              ],
              'limit': 1,
            },
          ],
        },
        'id': 2,
      };

      final empResponse = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(empSearchPayload),
      );

      if (empResponse.statusCode == 200) {
        final empJson = jsonDecode(empResponse.body);
        final List empResults = empJson['result'] ?? [];

        if (empResults.isNotEmpty) {
          final emp = empResults.first;
          final empName = emp['name']?.toString().trim() ?? 'موظف تمور علي';
          final jobTitle = emp['job_title']?.toString() ?? 'كادر تمور علي';

          debugPrint('[OdooService] Match in hr.employee (Worker): $empName ($jobTitle)');

          return UserProfile(
            id: 'odoo_emp_${emp['id']}',
            phone: cleanPhone,
            name: empName,
            isEmployee: true,
            companyName: 'تمور علي',
            odooPartnerId: emp['id'] as int?,
          );
        }
      }

      // 3. CHECK 2: Odoo Contacts App (`res.partner`)
      // If found here and not in hr.employee, the person is a Customer / Farmer
      final partnerSearchPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'object',
          'method': 'execute_kw',
          'args': [
            ApiConfig.odooDatabase,
            uid,
            ApiConfig.odooApiKey,
            'res.partner',
            'search_read',
              [
                [
                  ['phone', 'ilike', baseDigits],
                ]
              ],
              {
                'fields': [
                  'id',
                  'name',
                  'phone',
                  'email',
                  'company_type',
                  'is_company',
                ],
                'limit': 1,
              },
          ],
        },
        'id': 3,
      };

      final partnerResponse = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(partnerSearchPayload),
      );

      if (partnerResponse.statusCode == 200) {
        final partnerJson = jsonDecode(partnerResponse.body);
        final List partnerResults = partnerJson['result'] ?? [];

        if (partnerResults.isNotEmpty) {
          final partner = partnerResults.first;
          final custName = partner['name']?.toString().trim() ?? 'عميل تمور علي';

          debugPrint('[OdooService] Match in res.partner (Customer): $custName');

          return UserProfile(
            id: 'odoo_cust_${partner['id']}',
            phone: cleanPhone,
            name: custName,
            isEmployee: false,
            companyName: custName,
            odooPartnerId: partner['id'] as int?,
          );
        }
      }
    } catch (e) {
      debugPrint('[OdooService] Direct lookup note: $e');
    }

    return null;
  }

  /// Sync all employees and contacts from Odoo ERP
  static Future<List<UserProfile>> fetchOdooContacts() async {
    final List<UserProfile> synced = [];

    try {
      final authUrl = odooJsonRpcUri;
      final authPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'common',
          'method': 'authenticate',
          'args': [
            ApiConfig.odooDatabase,
            ApiConfig.odooEmail,
            ApiConfig.odooApiKey,
            {},
          ],
        },
        'id': 1,
      };

      final authResponse = await http
          .post(
            authUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(authPayload),
          )
          .timeout(const Duration(seconds: 4));

      if (authResponse.statusCode == 200) {
        final authJson = jsonDecode(authResponse.body);
        final uid = authJson['result'];

        if (uid is int && uid > 0) {
          // 1. Fetch from hr.employee (Employees)
          try {
            final empPayload = {
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'service': 'object',
                'method': 'execute_kw',
                'args': [
                  ApiConfig.odooDatabase,
                  uid,
                  ApiConfig.odooApiKey,
                  'hr.employee',
                  'search_read',
                  [
                    [
                      ['active', '=', true]
                    ]
                  ],
                  {
                    'fields': ['id', 'name', 'work_phone', 'mobile_phone', 'work_email', 'job_title'],
                    'limit': 500,
                  },
                ],
              },
              'id': 2,
            };

            final empRes = await http.post(authUrl, headers: {'Content-Type': 'application/json'}, body: jsonEncode(empPayload));
            if (empRes.statusCode == 200) {
              final empJson = jsonDecode(empRes.body);
              final List empList = empJson['result'] ?? [];
              for (final e in empList) {
                final phone = (e['work_phone'] ?? e['mobile_phone'] ?? '').toString().trim();
                if (phone.isNotEmpty) {
                  final empUuid = const Uuid().v5(Uuid.NAMESPACE_URL, 'odoo_emp_${e['id']}');
                  synced.add(UserProfile(
                    id: empUuid,
                    phone: PhoneUtils.toLocal(phone),
                    name: e['name']?.toString() ?? 'موظف تمور علي',
                    isEmployee: true,
                    companyName: 'تمور علي',
                    odooPartnerId: e['id'] as int?,
                  ));
                }
              }
            }
          } catch (_) {}

          // 2. Fetch from res.partner (Customers/Growers)
          try {
            final partnerPayload = {
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'service': 'object',
                'method': 'execute_kw',
                'args': [
                  ApiConfig.odooDatabase,
                  uid,
                  ApiConfig.odooApiKey,
                  'res.partner',
                  'search_read',
                  [
                    [
                      ['active', '=', true]
                    ]
                  ],
                  {
                    'fields': ['id', 'name', 'phone', 'email', 'is_company'],
                    'limit': 1000,
                  },
                ],
              },
              'id': 3,
            };

            final partnerRes = await http.post(authUrl, headers: {'Content-Type': 'application/json'}, body: jsonEncode(partnerPayload));
            if (partnerRes.statusCode == 200) {
              final partnerJson = jsonDecode(partnerRes.body);
              final List partnerList = partnerJson['result'] ?? [];
              for (final p in partnerList) {
                if (p['name'] == 'Ali Dates') continue;
                final rawPhone = (p['phone'] ?? '').toString().trim();
                final phone = rawPhone.isNotEmpty
                    ? PhoneUtils.toLocal(rawPhone)
                    : 'odoo_no_phone_${p['id']}';

                // Avoid overwriting if already marked as employee
                if (!synced.any((s) => s.phone == phone && s.isEmployee)) {
                  // Generate valid deterministic UUID for Supabase uuid column
                  final deterministicUuid = const Uuid().v5(Uuid.NAMESPACE_URL, 'odoo_partner_${p['id']}');
                  synced.add(UserProfile(
                    id: deterministicUuid,
                    phone: phone,
                    name: p['name']?.toString() ?? 'عميل',
                    isEmployee: false,
                    companyName: p['name']?.toString() ?? 'عميل',
                    odooPartnerId: p['id'] as int?,
                  ));
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[OdooService] Sync note: $e');
    }

    return synced;
  }

  /// Create a new partner / customer directly in Odoo ERP
  static Future<int?> createPartnerInOdoo({
    required String name,
    required String phone,
    bool isCompany = false,
  }) async {
    try {
      final authUrl = odooJsonRpcUri;
      final authPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'common',
          'method': 'authenticate',
          'args': [
            ApiConfig.odooDatabase,
            ApiConfig.odooEmail,
            ApiConfig.odooApiKey,
            {},
          ],
        },
        'id': 1,
      };

      final authRes = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(authPayload),
      ).timeout(const Duration(seconds: 4));

      if (authRes.statusCode != 200) return null;
      final authJson = jsonDecode(authRes.body);
      final uid = authJson['result'];
      if (uid is! int || uid <= 0) return null;

      final createPayload = {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': {
          'service': 'object',
          'method': 'execute_kw',
          'args': [
            ApiConfig.odooDatabase,
            uid,
            ApiConfig.odooApiKey,
            'res.partner',
            'create',
            [
              {
                'name': name.trim(),
                'phone': phone.trim(),
                'is_company': isCompany,
              }
            ],
          ],
        },
        'id': 2,
      };

      final createRes = await http.post(
        authUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(createPayload),
      ).timeout(const Duration(seconds: 5));

      if (createRes.statusCode == 200) {
        final createJson = jsonDecode(createRes.body);
        final createdId = createJson['result'];
        if (createdId is int && createdId > 0) {
          debugPrint('[OdooService] Created partner in Odoo: $name (ID: $createdId)');
          return createdId;
        }
      }
    } catch (e) {
      debugPrint('[OdooService] Partner creation note: $e');
    }
    return null;
  }
}
