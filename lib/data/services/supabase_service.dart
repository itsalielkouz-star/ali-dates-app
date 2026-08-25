import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/api_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/notification_service.dart';
import '../models/user_profile.dart';
import '../models/farm_model.dart';
import '../models/shipment_model.dart';
import '../models/pallet_model.dart';
import '../models/field_box_model.dart';
import '../models/sorting_batch_model.dart';
import '../models/document_model.dart';
import '../models/activity_log_model.dart';
import '../models/picking_operation_model.dart';
import 'storage_service.dart';
import 'odoo_service.dart';
import '../../core/utils/phone_utils.dart';

/// Result object for login authentication and identity discovery
class LoginResult {
  final UserProfile user;
  final bool isFirstTime;
  final String sourceDescription;

  LoginResult({
    required this.user,
    required this.isFirstTime,
    required this.sourceDescription,
  });
}

/// Central Supabase & Business Logic Service for Ali Dates
class SupabaseService extends ChangeNotifier {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _supabase;
  SupabaseClient? get client => _supabase;

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  // In-memory active datasets with offline resilience
  List<UserProfile> _profiles = [];
  List<FarmModel> _farms = [];
  List<ShipmentModel> _shipments = [];
  List<PalletModel> _pallets = [];
  List<SortingBatchModel> _sortingBatches = [];
  List<DocumentModel> _documents = [];
  List<FieldBoxModel> _fieldBoxRecords = [];
  List<ActivityLogModel> _activityLogs = [];
  List<PickingOperationModel> _pickingOperations = [];
  String _shiftSupervisor = 'خالد الكوز (المشرف العام)';

  List<ActivityLogModel> get activityLogs => List.unmodifiable(_activityLogs);
  List<PickingOperationModel> get pickingOperations => List.unmodifiable(_pickingOperations);
  String get shiftSupervisor => _shiftSupervisor;

  // Executive Dashboard State
  Map<String, int> _freezerCapacities = {
    'pre_fridge': 60,
    'first_fridge': 90,
    'main_freezer_1': 270,
    'main_freezer_2': 270,
    'small_freezer': 120,
  };
  int _totalCompanyBoxes = 100000;

  bool _isSyncingOdoo = false;
  bool get isSyncingOdoo => _isSyncingOdoo;

  DateTime? _lastOdooSyncTime;
  DateTime? get lastOdooSyncTime => _lastOdooSyncTime;

  Timer? _odooSyncTimer;

  List<UserProfile> get profiles => _profiles;
  List<FarmModel> get farms => _farms;
  List<ShipmentModel> get shipments => _shipments;
  List<PalletModel> get pallets => _pallets;
  List<SortingBatchModel> get sortingBatches => _sortingBatches;
  List<DocumentModel> get documents => _documents;
  List<FieldBoxModel> get fieldBoxRecords => _fieldBoxRecords;
  Map<String, int> get freezerCapacities => _freezerCapacities;
  int get totalCompanyBoxes => _totalCompanyBoxes;

  /// Returns true if there are active ongoing sorting processes
  bool get hasOngoingSorting =>
      _sortingBatches.any((b) => b.status == 'in_progress');

  int get ongoingSortingCount =>
      _sortingBatches.where((b) => b.status == 'in_progress').length;

  /// Update freezer capacities dynamically
  Future<void> updateFreezerCapacity(String locationKey, int newCapacity) async {
    _freezerCapacities[locationKey] = newCapacity;
    await StorageService.saveFreezerCapacities(_freezerCapacities);
    notifyListeners();
  }

  /// Update total company stock of plastic field boxes
  Future<void> updateTotalCompanyBoxes(int newTotal) async {
    _totalCompanyBoxes = newTotal;
    await StorageService.saveTotalCompanyBoxes(_totalCompanyBoxes);
    notifyListeners();
  }

  /// Calculates number of boxes currently held by a specific customer
  int getBoxesHeldByCustomer(String customerId) {
    int totalGiven = 0;
    int totalReturned = 0;

    // From shipments
    for (final s in _shipments.where((s) => s.customerId == customerId)) {
      if (s.direction == 'outbound' && s.cargoType == 'boxes') {
        // Outbound boxes given to customer
        totalGiven += _fieldBoxRecords
            .where((r) => r.shipmentId == s.id)
            .fold<int>(0, (sum, r) => sum + r.boxCount);
      } else if (s.direction == 'inbound' && s.cargoType == 'boxes') {
        // Inbound boxes returned by customer
        totalReturned += _fieldBoxRecords
            .where((r) => r.shipmentId == s.id)
            .fold<int>(0, (sum, r) => sum + r.boxCount);
      }
    }

    // Also include pallet boxes in warehouse for this customer
    final palletBoxes = _pallets
        .where((p) =>
            p.customerId == customerId &&
            p.status != 'delivered' &&
            p.status != 'consumed')
        .fold<int>(0, (sum, p) => sum + p.boxCount);

    final netBoxes = (totalGiven - totalReturned);
    return netBoxes > 0 ? (netBoxes + palletBoxes) : palletBoxes;
  }

  /// Calculates total boxes currently distributed across all customers
  int get totalBoxesWithCustomers {
    final customerIds = _profiles.where((p) => !p.isEmployee).map((p) => p.id).toSet();
    int sum = 0;
    for (final cId in customerIds) {
      sum += getBoxesHeldByCustomer(cId);
    }
    return sum;
  }

  /// Calculates available boxes in factory warehouse (Total stock - distributed)
  int get availableBoxesInFactory {
    final available = _totalCompanyBoxes - totalBoxesWithCustomers;
    return available >= 0 ? available : 0;
  }

  /// Initialize Supabase client and load state
  Future<void> initialize() async {
    // Load cached session & data immediately for instant app rendering
    _currentUser = StorageService.getCurrentUser();
    _loadSeedOrCacheData();

    // Initialize Supabase in the background without blocking initial app start
    unawaited(() async {
      try {
        await Supabase.initialize(
          url: ApiConfig.supabaseUrl,
          anonKey: ApiConfig.supabasePublishableKey,
        );
        _supabase = Supabase.instance.client;
      } catch (e) {
        debugPrint('Supabase init warning: $e');
      }

      // Background async sync with Odoo and Supabase
      syncAllData();
    }());

    // Start auto-sync interval with Odoo every 2 minutes
    _odooSyncTimer?.cancel();
    _odooSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      syncWithOdoo();
    });
  }

  void _loadSeedOrCacheData() {
    _profiles = StorageService.getCachedProfiles();

    // Ensure official management and executive staff exist in memory
    final defaultStaff = [
      UserProfile(
        id: 'admin_khaled_elkouz',
        phone: '0798997449',
        name: 'خالد الكوز',
        isEmployee: true,
        companyName: 'تمور علي',
        passwordHash: '1234',
        needsPasswordChange: false,
      ),
      UserProfile(
        id: 'admin_husam_elkouz',
        phone: '72033020',
        name: 'حسام الكوز',
        isEmployee: true,
        companyName: 'تمور علي',
        passwordHash: '1234',
        needsPasswordChange: false,
      ),
      UserProfile(
        id: 'admin_ali_elkouz',
        phone: '0795457988',
        name: 'علي الشريف',
        isEmployee: true,
        companyName: 'تمور علي',
        passwordHash: '1234',
        needsPasswordChange: false,
      ),
      UserProfile(
        id: 'admin_othman_adarbeh',
        phone: '0796611533',
        name: 'عثمان ابراهيم عداربة',
        isEmployee: true,
        companyName: 'تمور علي',
        passwordHash: '1234',
        needsPasswordChange: false,
      ),
    ];

    for (var staff in defaultStaff) {
      final exists = _profiles.any((p) => PhoneUtils.areEqual(p.phone, staff.phone));
      if (!exists) {
        _profiles.insert(0, staff);
      }
    }

    _farms = [];
    _pallets = StorageService.getCachedPallets();
    _sortingBatches = StorageService.getCachedSortingBatches();
    _documents = StorageService.getCachedDocuments();
    _freezerCapacities = StorageService.getFreezerCapacities();
    _totalCompanyBoxes = StorageService.getTotalCompanyBoxes();
    _shiftSupervisor = StorageService.getShiftSupervisor();

    final cachedLogs = StorageService.getCachedActivityLogs();
    _activityLogs = cachedLogs.map((e) => ActivityLogModel.fromJson(e)).toList();

    final cachedPicking = StorageService.getCachedPickingOperations();
    _pickingOperations = cachedPicking.map((e) => PickingOperationModel.fromJson(e)).toList();
  }

  /// Update / Start Shift with Supervisor
  Future<void> setShiftSupervisor(String supervisorName) async {
    _shiftSupervisor = supervisorName;
    await StorageService.saveShiftSupervisor(supervisorName);
    
    // Log Shift Start
    await logAction(
      actionType: 'shift_start',
      title: 'بدء وردية جديدة',
      details: 'تم بدء وردية العمل بإشراف مسؤول الشفت: $supervisorName',
      supervisorName: supervisorName,
    );
    notifyListeners();
  }

  /// Centralized Activity Logging for Scans, Sorting, and Pallet Transfers
  Future<void> logAction({
    required String actionType,
    required String title,
    required String details,
    String? employeeName,
    String? employeeId,
    String? supervisorName,
    String? palletCode,
    String? locationCode,
  }) async {
    final empName = employeeName ??
        _currentUser?.name ??
        'موظف تمور علي (${_currentUser?.phone ?? "مجهول"})';

    final log = ActivityLogModel(
      id: const Uuid().v4(),
      actionType: actionType,
      title: title,
      details: details,
      employeeName: empName,
      employeeId: employeeId ?? _currentUser?.id,
      supervisorName: supervisorName ?? _shiftSupervisor,
      palletCode: palletCode,
      locationCode: locationCode,
      timestamp: DateTime.now(),
    );

    _activityLogs.insert(0, log);
    if (_activityLogs.length > 300) {
      _activityLogs = _activityLogs.sublist(0, 300);
    }
    await StorageService.cacheActivityLogs(_activityLogs);
    notifyListeners();
  }

  /// Live Two-Way Synchronization with Odoo ERP (`hr.employee` & `res.partner`)
  Future<void> syncWithOdoo({bool force = false}) async {
    if (_isSyncingOdoo && !force) return;
    _isSyncingOdoo = true;
    notifyListeners();

    try {
      final odooContacts = await OdooService.fetchOdooContacts();
      if (odooContacts.isNotEmpty) {
        int newOrUpdated = 0;
        for (var contact in odooContacts) {
          final existingIdx = _profiles.indexWhere((p) => p.phone == contact.phone);
          if (existingIdx >= 0) {
            // Update name or role if changed in Odoo
            if (_profiles[existingIdx].name != contact.name ||
                _profiles[existingIdx].isEmployee != contact.isEmployee) {
              _profiles[existingIdx] = _profiles[existingIdx].copyWith(
                name: contact.name,
                isEmployee: contact.isEmployee,
                companyName: contact.isEmployee ? 'تمور علي' : contact.name,
              );
              newOrUpdated++;
            }
          } else {
            _profiles.add(contact);
            newOrUpdated++;
          }

          // Also upsert directly to Supabase
          if (_supabase != null) {
            try {
              await _supabase!.from('profiles').upsert(contact.toJson());
            } catch (_) {}
          }
        }

        await StorageService.cacheProfiles(_profiles);
        _lastOdooSyncTime = DateTime.now();
        debugPrint('[SupabaseService] Odoo Sync complete: ${odooContacts.length} contacts checked, $newOrUpdated updated.');
      }
    } catch (e) {
      debugPrint('[SupabaseService] Odoo Sync note: $e');
    } finally {
      _isSyncingOdoo = false;
      notifyListeners();
    }
  }

  /// Sync with Supabase & Odoo
  Future<void> syncAllData() async {
    try {
      // 1. Sync Odoo Contacts & Employees
      await syncWithOdoo(force: true);

      // 2. Fetch Supabase Data if available
      if (_supabase != null) {
        final profilesRes = await _supabase!.from('profiles').select();
        if (profilesRes.isNotEmpty) {
          _profiles = profilesRes.map((e) => UserProfile.fromJson(e)).toList();
          await StorageService.cacheProfiles(_profiles);
        }

        final farmsRes = await _supabase!.from('farms').select();
        if (farmsRes.isNotEmpty) {
          _farms = farmsRes.map((e) => FarmModel.fromJson(e)).toList();
        }

        final palletsRes = await _supabase!.from('pallets').select();
        if (palletsRes.isNotEmpty) {
          _pallets = palletsRes.map((e) => PalletModel.fromJson(e)).toList();
          await StorageService.cachePallets(_pallets);
        }

        final batchesRes = await _supabase!.from('sorting_batches').select();
        if (batchesRes.isNotEmpty) {
          _sortingBatches =
              batchesRes.map((e) => SortingBatchModel.fromJson(e)).toList();
          await StorageService.cacheSortingBatches(_sortingBatches);
        }

        final docsRes = await _supabase!.from('documents').select();
        if (docsRes.isNotEmpty) {
          _documents = docsRes.map((e) => DocumentModel.fromJson(e)).toList();
          await StorageService.cacheDocuments(_documents);
        }
      }
    } catch (e) {
      debugPrint('Sync completed with local fallback: $e');
    }
    notifyListeners();
  }

  // --- Auth & Profile Methods ---

  /// Login with phone (supports all formats: +962, 00962, 079, spaces, etc.)
  /// Automatically recognizes name & employee vs customer role from Odoo/Database
  Future<LoginResult?> login(String rawPhone, String password) async {
    final cleanPhone = PhoneUtils.toLocal(rawPhone);
    final searchVariants = PhoneUtils.generateSearchVariants(rawPhone);

    UserProfile? user;
    bool isFirstTime = false;
    String sourceDesc = 'قاعدة البيانات المعتمدة';

    // 1. Live lookup from Odoo ERP (Employee App `hr.employee` vs Contact App `res.partner`)
    try {
      final odooContact = await OdooService.lookupContactByPhone(rawPhone);
      if (odooContact != null) {
        user = odooContact;
        sourceDesc = odooContact.isEmployee
            ? 'سجلات نظام Odoo للموظفين (Employee App)'
            : 'سجلات نظام Odoo للعملاء والجهات (Contacts App)';

        if (_supabase != null) {
          try {
            await _supabase!.from('profiles').upsert(user.toJson());
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Odoo live lookup note: $e');
    }

    // 2. Query Supabase profiles table across all phone variants
    if (user == null && _supabase != null) {
      try {
        for (final pVariant in searchVariants) {
          final res = await _supabase!
              .from('profiles')
              .select()
              .eq('phone', pVariant)
              .maybeSingle();

          if (res != null) {
            user = UserProfile.fromJson(res);
            sourceDesc = 'الملف المسجل في قاعدة البيانات';
            break;
          }
        }
      } catch (e) {
        debugPrint('Supabase login check note: $e');
      }
    }

    // 3. Fallback to local memory / cache or create new user
    if (user == null) {
      final localIndex = _profiles.indexWhere(
        (p) => searchVariants.any((v) => PhoneUtils.areEqual(p.phone, v)),
      );

      if (localIndex != -1) {
        user = _profiles[localIndex];
      } else {
        // Completely new first-time login
        isFirstTime = true;
        final isKhaled = cleanPhone.contains('0798997449') || rawPhone.contains('798997449') || cleanPhone.contains('798997449');
        final isHusam = cleanPhone.contains('72033020') || rawPhone.contains('72033020') || cleanPhone.contains('33454144') || rawPhone.contains('33454144');
        final isAli = cleanPhone.contains('0795457988') || rawPhone.contains('795457988');
        final isOthman = cleanPhone.contains('0796611533') || rawPhone.contains('796611533');
        final isEmp = isKhaled || isHusam || isAli || isOthman;

        String assignedName = 'عميل تمور علي (${PhoneUtils.toDisplay(cleanPhone)})';
        if (isKhaled) assignedName = 'خالد الكوز';
        if (isHusam) assignedName = 'حسام الكوز';
        if (isAli) assignedName = 'علي الشريف';
        if (isOthman) assignedName = 'عثمان ابراهيم عداربة';

        user = UserProfile(
          id: const Uuid().v4(),
          phone: cleanPhone,
          name: assignedName,
          isEmployee: isEmp,
          companyName: isEmp ? 'تمور علي' : 'مزرعة جديدة',
          passwordHash: password.isNotEmpty ? password : '1234',
          needsPasswordChange: password == '1234' || password.isEmpty,
        );
        _profiles.add(user);
        sourceDesc = (isKhaled || isHusam || isAli || isOthman)
            ? 'حساب الإدارة المعتمد ($assignedName)'
            : (isEmp ? 'حساب كادر تمور علي' : 'تسجيل مستخدم جديد لأول مرة');

        if (_supabase != null) {
          try {
            await _supabase!.from('profiles').upsert(user.toJson());
          } catch (_) {}
        }
      }
    }

    // Verify Password:
    // 1. If the user set a custom password (needsPasswordChange == false), they MUST provide their exact password.
    //    The default '1234' is completely blocked and invalid once activated!
    // 2. If it's the very first time (needsPasswordChange == true or passwordHash == '1234'),
    //    the default initial code '1234' or empty password triggers the one-time activation.
    final bool isCorrectPassword = user.passwordHash == password;
    final bool isInitialOneTimeLogin = user.needsPasswordChange && (password == '1234' || password.isEmpty);

    if (isCorrectPassword || isInitialOneTimeLogin) {
      _currentUser = user;
      await StorageService.saveCurrentUser(user);
      await StorageService.cacheProfiles(_profiles);
      notifyListeners();
      return LoginResult(
        user: user,
        isFirstTime: isFirstTime,
        sourceDescription: sourceDesc,
      );
    }
    return null;
  }

  /// Change Password
  Future<bool> changePassword(String userId, String newPassword) async {
    final index = _profiles.indexWhere((p) => p.id == userId);
    if (index != -1) {
      final updated = _profiles[index].copyWith(
        passwordHash: newPassword,
        needsPasswordChange: false,
      );
      _profiles[index] = updated;
      _currentUser = updated;
      await StorageService.saveCurrentUser(updated);
      await StorageService.cacheProfiles(_profiles);

      if (_supabase != null) {
        try {
          await _supabase!.from('profiles').upsert(updated.toJson());
        } catch (_) {}
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update user profile name and sync to Supabase
  Future<bool> updateProfileName(String userId, String newName) async {
    final index = _profiles.indexWhere((p) => p.id == userId);
    if (index != -1) {
      final updated = _profiles[index].copyWith(name: newName.trim());
      _profiles[index] = updated;
      if (_currentUser?.id == userId) {
        _currentUser = updated;
        await StorageService.saveCurrentUser(updated);
      }
      await StorageService.cacheProfiles(_profiles);

      if (_supabase != null) {
        try {
          await _supabase!.from('profiles').update({'name': newName.trim()}).eq('id', userId);
        } catch (_) {}
      }

      notifyListeners();
      return true;
    }
    return false;
  }

  /// Update full user profile (name, isEmployee role, company) and sync to Supabase
  Future<UserProfile?> updateUserProfile({
    required String userId,
    required String name,
    required bool isEmployee,
    String? companyName,
  }) async {
    final index = _profiles.indexWhere((p) => p.id == userId);
    if (index != -1) {
      final updated = _profiles[index].copyWith(
        name: name.trim(),
        isEmployee: isEmployee,
        companyName: companyName ?? (isEmployee ? 'تمور علي' : name.trim()),
      );
      _profiles[index] = updated;
      if (_currentUser?.id == userId) {
        _currentUser = updated;
        await StorageService.saveCurrentUser(updated);
      }
      await StorageService.cacheProfiles(_profiles);

      if (_supabase != null) {
        try {
          await _supabase!.from('profiles').update({
            'name': name.trim(),
            'is_employee': isEmployee,
            'company_name': updated.companyName,
          }).eq('id', userId);
        } catch (_) {}
      }

      notifyListeners();
      return updated;
    }
    return null;
  }

  void logout() {
    _currentUser = null;
    StorageService.clearUser();
    notifyListeners();
  }

  // --- Customer & Farm Operations ---

  /// Activity score calculation for a customer based on pallets, shipments, batches, docs, and picking operations
  int getCustomerActivityScore(String customerId) {
    int score = 0;
    score += _pallets.where((p) => p.customerId == customerId).length * 3;
    score += _shipments.where((s) => s.customerId == customerId).length * 3;
    score += _sortingBatches.where((b) => b.customerId == customerId).length * 2;
    score += _pickingOperations.where((o) => o.customerId == customerId).length * 4;
    score += _documents.where((d) => d.customerId == customerId).length;
    score += _activityLogs.where((l) => l.employeeId == customerId || l.palletCode?.isNotEmpty == true).length;
    return score;
  }

  List<UserProfile> getCustomerContacts() {
    final list = _profiles.where((p) => !p.isEmployee).toList();

    // Priority Sort everywhere:
    // 1. Jordanian Numbers First (079, 078, 077, +962)
    // 2. Highest Activity on Top (Most pallets, shipments, harvesting ops, and transactions)
    // 3. Other valid international numbers with activity
    // 4. Alphabetical by Name
    list.sort((a, b) {
      final aIsJo = PhoneUtils.isJordanian(a.phone);
      final bIsJo = PhoneUtils.isJordanian(b.phone);

      if (aIsJo && !bIsJo) return -1;
      if (!aIsJo && bIsJo) return 1;

      final aScore = getCustomerActivityScore(a.id);
      final bScore = getCustomerActivityScore(b.id);
      if (aScore != bScore) {
        return bScore.compareTo(aScore); // Most active on top
      }

      final aHasPhone = !a.phone.startsWith('odoo_no_phone_');
      final bHasPhone = !b.phone.startsWith('odoo_no_phone_');
      if (aHasPhone && !bHasPhone) return -1;
      if (!aHasPhone && bHasPhone) return 1;

      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return list;
  }

  /// Add a new Customer contact with name and phone, saving to Odoo ERP, Supabase & local state
  Future<UserProfile> addNewCustomerContact({
    required String name,
    required String phone,
    String? companyName,
  }) async {
    final cleanPhone = PhoneUtils.toLocal(phone);
    UserProfile newContact = UserProfile(
      id: const Uuid().v4(),
      phone: cleanPhone,
      name: name.trim(),
      isEmployee: false,
      companyName: companyName?.trim().isNotEmpty == true ? companyName!.trim() : name.trim(),
      passwordHash: '1234',
      needsPasswordChange: false,
    );

    _profiles.insert(0, newContact);
    await StorageService.cacheProfiles(_profiles);

    // Save to Supabase
    if (_supabase != null) {
      try {
        await _supabase!.from('profiles').upsert(newContact.toJson());
      } catch (_) {}
    }

    // Automatically create in Odoo ERP in the background
    OdooService.createPartnerInOdoo(name: name, phone: phone).then((odooId) async {
      if (odooId != null && odooId > 0) {
        newContact = newContact.copyWith(odooPartnerId: odooId);
        final idx = _profiles.indexWhere((p) => p.id == newContact.id);
        if (idx >= 0) _profiles[idx] = newContact;
        await StorageService.cacheProfiles(_profiles);
        if (_supabase != null) {
          try {
            await _supabase!.from('profiles').upsert(newContact.toJson());
          } catch (_) {}
        }
        notifyListeners();
      }
    });

    notifyListeners();
    return newContact;
  }

  List<FarmModel> getFarmsForCustomer(String customerId) {
    return _farms.where((f) => f.customerId == customerId).toList();
  }

  Future<FarmModel> addNewFarm({
    required String customerId,
    required String name,
    required String governorate,
    String? code,
  }) async {
    final newFarm = FarmModel(
      id: const Uuid().v4(),
      customerId: customerId,
      name: name,
      governorate: governorate,
      code: code,
    );
    _farms.add(newFarm);

    if (_supabase != null) {
      try {
        await _supabase!.from('farms').insert(newFarm.toJson());
      } catch (_) {}
    }

    notifyListeners();
    return newFarm;
  }

  // --- Receiving & Shipments Operations ---

  Future<ShipmentModel> recordInboundShipment({
    required String cargoType,
    required String customerId,
    String? customerName,
    String? farmId,
    String? farmName,
    required String driverName,
    required String agentName,
    required String plateNumber,
    String? truckPhotoUrl,
    String? licensePhotoUrl,
    required bool isPresorted,
    String? boxContractType,
  }) async {
    final shipment = ShipmentModel(
      id: const Uuid().v4(),
      direction: 'inbound',
      cargoType: cargoType,
      customerId: customerId,
      customerName: customerName,
      farmId: farmId,
      farmName: farmName,
      driverName: driverName,
      agentName: agentName,
      plateNumber: plateNumber,
      truckPhotoUrl: truckPhotoUrl,
      licensePhotoUrl: licensePhotoUrl,
      isPresorted: isPresorted,
      boxContractType: boxContractType,
    );

    _shipments.insert(0, shipment);

    if (_supabase != null) {
      try {
        await _supabase!.from('shipments').insert(shipment.toJson());
      } catch (_) {}
    }

    notifyListeners();
    return shipment;
  }

  Future<void> addReceivedPallet(PalletModel pallet) async {
    _pallets.insert(0, pallet);
    await StorageService.cachePallets(_pallets);

    if (_supabase != null) {
      try {
        await _supabase!.from('pallets').insert(pallet.toJson());
      } catch (_) {}
    }

    // Send Push Notification if relevant to active customer or all customers
    NotificationService().showCustomerStatusNotification(
      id: pallet.palletCode.hashCode,
      title: '📦 استلام طبلية تمور جديدة (${pallet.palletCode})',
      body: 'تم استلام وتوثيق طبلية (${pallet.customerName}) بوزن صافي: ${pallet.netWeight.toStringAsFixed(1)} كـغ بنجاح.',
    );

    notifyListeners();
  }

  Future<void> recordFieldBoxesInbound({
    required String shipmentId,
    required String customerId,
    String? customerName,
    required int boxCount,
    int damaged = 0,
    int lost = 0,
  }) async {
    final boxRecord = FieldBoxModel(
      id: const Uuid().v4(),
      shipmentId: shipmentId,
      customerId: customerId,
      customerName: customerName,
      boxCount: boxCount,
      damagedCount: damaged,
      lostCount: lost,
    );

    if (_supabase != null) {
      try {
        await _supabase!.from('field_boxes_records').insert(boxRecord.toJson());
      } catch (_) {}
    }

    notifyListeners();
  }

  // --- Transfer & Warehouse Location Operations ---

  List<PalletModel> getPalletsForCustomerInWarehouse(String customerId) {
    return _pallets
        .where((p) =>
            p.customerId == customerId &&
            p.status != 'delivered' &&
            p.status != 'consumed')
        .toList();
  }

  PalletModel? findPalletByCode(String code) {
    try {
      return _pallets.firstWhere(
        (p) =>
            p.palletCode.toUpperCase() == code.toUpperCase() ||
            p.id == code,
      );
    } catch (_) {
      return null;
    }
  }

  PalletModel? findPalletById(String id) {
    try {
      return _pallets.firstWhere((p) => p.id == id || p.palletCode == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> updatePalletLocation({
    required String palletId,
    required String locationType,
    String? row,
    int? col,
    int? layer,
    String? locationCode,
    bool stackOnExisting = false,
    String? targetExistingPalletId,
  }) async {
    final index = _pallets.indexWhere((p) => p.id == palletId);
    if (index == -1) return;

    final pallet = _pallets[index];
    final pairedId = pallet.pairedPalletId;

    PalletModel? targetExistingPallet;
    if (stackOnExisting && targetExistingPalletId != null) {
      final tIdx = _pallets.indexWhere((p) => p.id == targetExistingPalletId);
      if (tIdx != -1) targetExistingPallet = _pallets[tIdx];
    }

    final newStatus = (locationType == AppConstants.locPreSort ||
            locationType == AppConstants.locAutoSort)
        ? 'in_sorting'
        : 'stored';

    final updated = pallet.copyWith(
      locationType: locationType,
      freezerRow: row,
      freezerCol: col,
      freezerLayer: layer,
      locationCode: locationCode,
      status: newStatus,
      pairedPalletId: stackOnExisting ? targetExistingPallet?.id : pallet.pairedPalletId,
      pairedPalletCode: stackOnExisting ? targetExistingPallet?.palletCode : pallet.pairedPalletCode,
      isStackedTop: stackOnExisting ? true : pallet.isStackedTop,
    );
    _pallets[index] = updated;

    // If stacking onto an existing pallet in that slot, pair the existing pallet as well
    if (stackOnExisting && targetExistingPallet != null) {
      final tIdx = _pallets.indexWhere((p) => p.id == targetExistingPallet!.id);
      if (tIdx != -1) {
        _pallets[tIdx] = _pallets[tIdx].copyWith(
          pairedPalletId: pallet.id,
          pairedPalletCode: pallet.palletCode,
          isStackedTop: false,
        );
      }
    }

    // If moving a pallet that was ALREADY paired and moving both together:
    if (pairedId != null && !stackOnExisting) {
      final pIdx = _pallets.indexWhere((p) => p.id == pairedId);
      if (pIdx != -1) {
        _pallets[pIdx] = _pallets[pIdx].copyWith(
          locationType: locationType,
          freezerRow: row,
          freezerCol: col,
          freezerLayer: layer,
          locationCode: locationCode,
          status: newStatus,
        );
      }
    }

    await StorageService.cachePallets(_pallets);

    if (_supabase != null) {
      try {
        await _supabase!.from('pallets').upsert(updated.toJson());
      } catch (_) {}
    }

    // Log the transfer action
    final locName = AppConstants.locationNamesAr[locationType] ?? locationType;
    await logAction(
      actionType: 'transfer',
      title: 'نقل طبلية إلى موقع جديد',
      details: 'تم نقل الطبلية (${pallet.palletCode}) إلى ($locName - موقع $locationCode)${stackOnExisting ? " [تطبيق ومضاعفة فوق الطبلية ${targetExistingPallet?.palletCode}]" : ""}',
      palletCode: pallet.palletCode,
      locationCode: locationCode,
    );

    notifyListeners();
  }

  /// Update any pallet properties (e.g. status consumed)
  Future<void> updatePallet(PalletModel updatedPallet) async {
    final index = _pallets.indexWhere((p) => p.id == updatedPallet.id);
    if (index != -1) {
      _pallets[index] = updatedPallet;
      await StorageService.cachePallets(_pallets);
      if (_supabase != null) {
        try {
          await _supabase!.from('pallets').upsert(updatedPallet.toJson());
        } catch (_) {}
      }
      notifyListeners();
    }
  }

  // --- Sorting Operations (Pre-Sort & Auto-Sort) ---

  /// Returns all booked dates for a specific sorting line (presort vs autosort)
  Set<DateTime> getBookedDatesForSorting(String sortingType) {
    return _sortingBatches
        .where((b) =>
            b.sortingType == sortingType &&
            b.status != 'cancelled' &&
            b.scheduledDate != null)
        .map((b) => DateTime(
              b.scheduledDate!.year,
              b.scheduledDate!.month,
              b.scheduledDate!.day,
            ))
        .toSet();
  }

  Future<SortingBatchModel> startSortingBatch({
    required PalletModel pallet,
    required String sortingType,
    DateTime? scheduledDate,
  }) async {
    // 1. Mark source pallet with active sorting status while preserving its storage location!
    final pIndex = _pallets.indexWhere((p) => p.id == pallet.id);
    if (pIndex != -1) {
      _pallets[pIndex] = _pallets[pIndex].copyWith(status: 'in_sorting');
      await StorageService.cachePallets(_pallets);
    }

    // 2. Create ongoing/planned sorting batch
    final batch = SortingBatchModel(
      id: const Uuid().v4(),
      sourcePalletId: pallet.id,
      sourcePalletCode: pallet.palletCode,
      sourcePalletLocation: pallet.displayLocation,
      customerId: pallet.customerId,
      customerName: pallet.customerName,
      farmId: pallet.farmId,
      farmName: pallet.farmName,
      sortingType: sortingType,
      scheduledDate: scheduledDate ?? DateTime.now(),
      inputWeight: pallet.netWeight,
      status: 'in_progress',
      outputPallets: [],
    );

    _sortingBatches.insert(0, batch);
    await StorageService.cacheSortingBatches(_sortingBatches);

    if (_supabase != null) {
      try {
        await _supabase!.from('sorting_batches').insert(batch.toJson());
      } catch (_) {}
    }

    notifyListeners();
    return batch;
  }

  /// Autosave ongoing sorting batch outputs and details in real-time
  Future<void> updateSortingBatch(SortingBatchModel batch) async {
    final index = _sortingBatches.indexWhere((b) => b.id == batch.id);
    if (index != -1) {
      _sortingBatches[index] = batch;
    } else {
      _sortingBatches.insert(0, batch);
    }
    await StorageService.cacheSortingBatches(_sortingBatches);

    if (_supabase != null) {
      try {
        await _supabase!.from('sorting_batches').upsert(batch.toJson());
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Cancel sorting batch
  Future<void> cancelSortingBatch(String batchId) async {
    final index = _sortingBatches.indexWhere((b) => b.id == batchId);
    if (index != -1) {
      final current = _sortingBatches[index];
      _sortingBatches[index] = current.copyWith(status: 'cancelled');
      
      // Restore source pallet status if it was in_sorting
      final pIndex = _pallets.indexWhere((p) => p.id == current.sourcePalletId);
      if (pIndex != -1) {
        _pallets[pIndex] = _pallets[pIndex].copyWith(status: 'stored');
        await StorageService.cachePallets(_pallets);
      }

      await StorageService.cacheSortingBatches(_sortingBatches);

      if (_supabase != null) {
        try {
          await _supabase!.from('sorting_batches').update({'status': 'cancelled'}).eq('id', batchId);
        } catch (_) {}
      }

      notifyListeners();
    }
  }

  Future<void> completeSortingBatch({
    required String batchId,
    required List<SortingOutputItem> outputPallets,
    required double wasteWeight,
    Map<String, double>? wasteDetails,
  }) async {
    final index = _sortingBatches.indexWhere((b) => b.id == batchId);
    if (index != -1) {
      final current = _sortingBatches[index];
      final totalOutWeight = outputPallets.fold<double>(
        0.0,
        (sum, item) => sum + item.weight,
      );

      final completedBatch = SortingBatchModel(
        id: current.id,
        batchNumber: current.batchNumber,
        sourcePalletId: current.sourcePalletId,
        sourcePalletCode: current.sourcePalletCode,
        customerId: current.customerId,
        customerName: current.customerName,
        farmId: current.farmId,
        farmName: current.farmName,
        sortingType: current.sortingType,
        scheduledDate: current.scheduledDate,
        inputWeight: current.inputWeight,
        outputWeight: totalOutWeight,
        wasteWeight: wasteWeight,
        wasteDetails: wasteDetails,
        outputPallets: outputPallets,
        status: 'completed',
        completedAt: DateTime.now(),
      );

      _sortingBatches[index] = completedBatch;
      await StorageService.cacheSortingBatches(_sortingBatches);

      // Register new output pallets in warehouse
      for (var out in outputPallets) {
        final newPallet = PalletModel(
          id: out.id,
          palletCode: out.palletCode,
          customerId: current.customerId,
          customerName: current.customerName,
          farmId: current.farmId,
          farmName: current.farmName,
          grossWeight: out.weight,
          netWeight: out.weight,
          boxCount: out.boxCount,
          emptyBoxWeight: 0.0,
          emptyPalletWeight: 0.0,
          locationType: AppConstants.locMainFreezer1,
          status: 'sorted',
          category: out.category,
          size: out.size,
          isPresorted: true,
        );
        _pallets.insert(0, newPallet);
      }
      await StorageService.cachePallets(_pallets);

      if (_supabase != null) {
        try {
          await _supabase!.from('sorting_batches').update(completedBatch.toJson()).eq('id', batchId);
        } catch (_) {}
      }

      // Trigger Push Notification for completed sorting output
      NotificationService().showCustomerStatusNotification(
        id: batchId.hashCode,
        title: '✨ اكتمال فرز التمور بنجاح (${current.customerName})',
        body: 'تم الانتهاء من ${current.sortingType == "presort" ? "الفرز الأولي" : "الفرز الآلي"} بإجمالي مخرجات: ${totalOutWeight.toStringAsFixed(1)} كـغ وجاهزة للتبريد/التسليم.',
      );

      notifyListeners();
    }
  }

  // --- Delivery Operations ---

  List<PalletModel> getAutoSortedPalletsForCustomer(String customerId) {
    return _pallets
        .where((p) =>
            p.customerId == customerId &&
            p.status == 'sorted' &&
            p.category != null)
        .toList();
  }

  Future<void> deliverPallets({
    required List<String> palletIds,
    required ShipmentModel shipment,
  }) async {
    for (var id in palletIds) {
      final index = _pallets.indexWhere((p) => p.id == id);
      if (index != -1) {
        _pallets[index] = _pallets[index].copyWith(
          status: 'delivered',
          locationType: AppConstants.locDelivered,
        );
      }
    }
    await StorageService.cachePallets(_pallets);
    _shipments.insert(0, shipment);

    if (_supabase != null) {
      try {
        await _supabase!.from('shipments').insert(shipment.toJson());
        for (var id in palletIds) {
          await _supabase!.from('pallets').update({
            'status': 'delivered',
            'location_type': AppConstants.locDelivered,
          }).eq('id', id);
        }
      } catch (_) {}
    }

    notifyListeners();
  }

  // --- Documents & Signed Receipts Archive ---

  Future<void> saveDocument(DocumentModel doc) async {
    _documents.insert(0, doc);
    await StorageService.cacheDocuments(_documents);

    if (_supabase != null) {
      try {
        await _supabase!.from('documents').insert(doc.toJson());
      } catch (_) {}
    }

    // Trigger Push Notification for uploaded customer document
    NotificationService().showCustomerStatusNotification(
      id: doc.id.hashCode,
      title: '📄 مستند رسمي جديد متاح بحسابك (${doc.title})',
      body: 'أضافت إدارة تمور علي مستنداً جديداً (${doc.docTypeAr})، يمكنك استعراضه وتحميله الآن من مركز الوثائق.',
    );

    notifyListeners();
  }

  List<DocumentModel> getDocumentsForCustomer(String customerId) {
    return _documents.where((d) => d.customerId == customerId).toList();
  }

  // ===========================================================================
  // HARVESTING & PICKING OPERATIONS (عمليات الحصاد والقطاف الميداني)
  // ===========================================================================

  /// Create a new Picking Plan (usually 1 day prior to harvesting)
  Future<PickingOperationModel> createPickingPlan({
    required String customerId,
    required String customerName,
    required String farmId,
    required String farmName,
    required String landName,
    String? landCode,
    required int plannedWorkers,
    required int plannedCrates,
    required double plannedEstimatedKg,
    required DateTime plannedDate,
    required String supervisorName,
    String? supervisorId,
    required String laborTeamLeaderName,
    String? laborTeamLeaderPhone,
    String? notes,
  }) async {
    final newId = const Uuid().v4();
    final count = _pickingOperations.length + 1;
    final code = 'HARV-${DateTime.now().year}-${count.toString().padLeft(3, "0")}';

    final operation = PickingOperationModel(
      id: newId,
      code: code,
      customerId: customerId,
      customerName: customerName,
      farmId: farmId,
      farmName: farmName,
      landName: landName,
      landCode: landCode,
      plannedWorkers: plannedWorkers,
      plannedCrates: plannedCrates,
      plannedEstimatedKg: plannedEstimatedKg,
      plannedDate: plannedDate,
      supervisorName: supervisorName,
      supervisorId: supervisorId,
      laborTeamLeaderName: laborTeamLeaderName,
      laborTeamLeaderPhone: laborTeamLeaderPhone,
      status: 'planned',
      notes: notes,
    );

    _pickingOperations.insert(0, operation);
    await StorageService.cachePickingOperations(_pickingOperations);

    // Automatically reserve and deduct crates from available stock
    final boxShipment = ShipmentModel(
      id: const Uuid().v4(),
      direction: 'outbound',
      cargoType: 'boxes',
      customerId: customerId,
      customerName: customerName,
      farmId: farmId,
      farmName: farmName,
      driverName: supervisorName,
      agentName: laborTeamLeaderName,
      plateNumber: 'فريق الحقل',
      boxContractType: 'picking_crates',
    );
    _shipments.insert(0, boxShipment);

    final boxRecord = FieldBoxModel(
      id: const Uuid().v4(),
      shipmentId: boxShipment.id,
      customerId: customerId,
      customerName: customerName,
      boxCount: plannedCrates,
      damagedCount: 0,
      lostCount: 0,
    );
    _fieldBoxRecords.insert(0, boxRecord);

    await logAction(
      actionType: 'harvest_plan',
      title: 'إنشاء خطة قطاف وصرف صناديق ($code)',
      details: 'تم جدولة عملية قطاف لمزرعة ($farmName - $landName) للمزارع ($customerName) وصرف ($plannedCrates) صندوق حقل من رصيد المصنع.',
      employeeName: supervisorName,
    );

    notifyListeners();
    return operation;
  }

  /// Update an existing Picking Operation
  Future<void> updatePickingOperation(PickingOperationModel updated) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == updated.id);
    if (idx != -1) {
      _pickingOperations[idx] = updated;
      await StorageService.cachePickingOperations(_pickingOperations);
      notifyListeners();
    }
  }

  /// Advance the status of a picking operation with exact timestamp recording
  Future<void> advancePickingLifecycle({
    required String operationId,
    required String newStatus,
    int? actualWorkers,
    String? laborTeamLeader,
  }) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    final now = DateTime.now();

    DateTime? dep = op.departedFacilityTime;
    DateTime? arr = op.arrivedAtFarmTime;
    DateTime? startH = op.harvestingStartTime;
    DateTime? endH = op.harvestingEndTime;
    DateTime? leftF = op.leftFarmTime;
    DateTime? retF = op.returnedFacilityTime;

    String logTitle = '';
    String logDetails = '';

    if (newStatus == 'crates_dispatched') {
      logTitle = 'إرسال الصناديق إلى المزرعة';
      logDetails = 'تم تجهيز وإرسال (${op.plannedCrates}) صندوق إلى مزرعة (${op.farmName})';
    } else if (newStatus == 'team_dispatched') {
      dep = now;
      logTitle = 'انطلاق فريق الحصاد من المصنع';
      logDetails = 'غادر فريق الحصاد (${actualWorkers ?? op.actualWorkers} عامل) برئاسة (${laborTeamLeader ?? op.laborTeamLeaderName}) وإشراف (${op.supervisorName})';
    } else if (newStatus == 'at_farm') {
      arr = now;
      logTitle = 'وصول الفريق إلى المزرعة';
      logDetails = 'وصل مشرف تمور علي وفريق العمل إلى مزرعة (${op.farmName} - قطعة ${op.landName})';
    } else if (newStatus == 'harvesting_in_progress') {
      startH = now;
      logTitle = 'بدء عمليات القطاف الفعلي 🌴';
      logDetails = 'بدأ العمال قطاف عراجين التمور في حقل (${op.farmName})';
    } else if (newStatus == 'harvesting_completed') {
      endH = now;
      logTitle = 'انتهاء قطاف المحصول في الحقل';
      logDetails = 'أنهى العمال جني التمور في الحقل، إجمالي الصناديق المعبأة (${op.totalHarvestedCrates}) صندوق';
    } else if (newStatus == 'in_transit') {
      leftF = now;
      logTitle = 'مغادرة المزرعة باتجاه المصنع 🚚';
      logDetails = 'غادر المشرف وفريق العمل أرض المزرعة في طريق العودة لمركز تمور علي';
    } else if (newStatus == 'returned_to_facility') {
      retF = now;
      logTitle = 'وصول المحصول إلى مركز تمور علي';
      logDetails = 'وصلت شحنات المحصول إلى المصنع وهي بانتظار الوزن الرسمي والفرز';
    }

    op = op.copyWith(
      status: newStatus,
      actualWorkers: actualWorkers ?? op.actualWorkers,
      laborTeamLeaderName: laborTeamLeader ?? op.laborTeamLeaderName,
      departedFacilityTime: dep,
      arrivedAtFarmTime: arr,
      harvestingStartTime: startH,
      harvestingEndTime: endH,
      leftFarmTime: leftF,
      returnedFacilityTime: retF,
    );

    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);

    await logAction(
      actionType: 'harvest_$newStatus',
      title: logTitle,
      details: logDetails,
      employeeName: op.supervisorName,
    );

    notifyListeners();
  }

  /// Add a dispatched load from farm to facility
  Future<void> addHarvestLoad(String operationId, HarvestLoadModel load) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    final updatedLoads = List<HarvestLoadModel>.from(op.loads)..add(load);

    op = op.copyWith(
      loads: updatedLoads,
      status: 'loads_dispatched',
    );

    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);

    await logAction(
      actionType: 'harvest_load',
      title: 'تسيير نقلة تمور رقم (${load.loadNumber}) من الحقل 🚚',
      details: 'انطلقت نقلة تحتوي على (${load.crateCount}) صندوق من مزرعة (${op.farmName}) باتجاه مركز تمور علي',
      employeeName: op.supervisorName,
    );

    notifyListeners();
  }

  /// Add photo documentation during harvesting
  Future<void> addHarvestPhoto(String operationId, HarvestPhotoModel photo) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    final updatedPhotos = List<HarvestPhotoModel>.from(op.photos)..add(photo);

    op = op.copyWith(photos: updatedPhotos);
    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);
    notifyListeners();
  }

  /// Record field expense
  Future<void> addHarvestExpense(String operationId, ExpenseItemModel expense) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    final updatedExp = List<ExpenseItemModel>.from(op.expenses)..add(expense);

    op = op.copyWith(expenses: updatedExp);
    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);
    notifyListeners();
  }

  /// Finalize facility weighing and link to inventory
  Future<void> recordHarvestWeighing({
    required String operationId,
    required double grossWeight,
    required double tareWeight,
    required double netWeight,
  }) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    op = op.copyWith(
      status: 'weighed',
      actualGrossWeight: grossWeight,
      actualTareWeight: tareWeight,
      actualNetWeight: netWeight,
    );

    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);

    await logAction(
      actionType: 'harvest_weighed',
      title: 'وزن واستلام محصول القطاف (${op.code}) ⚖️',
      details: 'تم وزن محصول (${op.customerName} - ${op.farmName}) بصافي: ${netWeight.toStringAsFixed(1)} كـغ (إجمالي: ${grossWeight.toStringAsFixed(1)} كغ)',
      employeeName: op.supervisorName,
    );

    notifyListeners();
  }

  /// Finalize crate reconciliation & financial settlement
  Future<void> finalizePickingSettlement({
    required String operationId,
    required CrateReconciliationModel crateReconciliation,
    required bool isLaborPaid,
    String? settlementNotes,
  }) async {
    final idx = _pickingOperations.indexWhere((o) => o.id == operationId);
    if (idx == -1) return;

    var op = _pickingOperations[idx];
    op = op.copyWith(
      status: 'settled',
      crateReconciliation: crateReconciliation,
      isLaborPaid: isLaborPaid,
      isSettled: true,
      notes: settlementNotes ?? op.notes,
    );

    _pickingOperations[idx] = op;
    await StorageService.cachePickingOperations(_pickingOperations);

    await logAction(
      actionType: 'harvest_settled',
      title: 'إقفال وتسوية عملية القطاف (${op.code}) ✅',
      details: 'تمت مطابقة الصناديق واحتساب أجور العمال (${op.totalLaborCost} د.أ) عبر رئيس العمال (${op.laborTeamLeaderName}) وإقفال العملية',
      employeeName: op.supervisorName,
    );

    notifyListeners();
  }

  /// Completely clear all operational data (pallets, freezers, sorting, shipments, farms, logs, harvesting, documents)
  /// leaves only contacts (customers and employees) with zero farms and empty storage
  Future<void> clearDatabaseAndResetPasswords() async {
    // 1. Wipe remote Supabase tables if connected
    if (_supabase != null) {
      try {
        await _supabase!.from('activity_logs').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('picking_operations').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('sorting_batches').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('pallets').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('farms').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('field_box_records').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('field_boxes_records').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('shipments').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
      try {
        await _supabase!.from('documents').delete().neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}

      // Reset all profiles' passwords to initial default state (needsPasswordChange = true, passwordHash = '1234')
      try {
        await _supabase!.from('profiles').update({
          'password_hash': '1234',
          'needs_password_change': true,
        }).neq('id', '00000000-0000-0000-0000-000000000000');
      } catch (_) {}
    }

    // 2. Wipe in-memory active lists completely (Zero pallets, Zero farms, Zero history)
    _pallets = [];
    _farms = [];
    _sortingBatches = [];
    _shipments = [];
    _documents = [];
    _fieldBoxRecords = [];
    _activityLogs = [];
    _pickingOperations = [];

    // Reset local profiles passwords while keeping all contacts intact
    _profiles = _profiles.map((p) => p.copyWith(
      passwordHash: '1234',
      needsPasswordChange: true,
    )).toList();

    // 3. Clear Local Storage caches completely and persist only cleaned contacts
    await StorageService.clearAllData();
    await StorageService.cacheProfiles(_profiles);
    await StorageService.cachePallets([]);
    await StorageService.cacheSortingBatches([]);
    await StorageService.cacheDocuments([]);
    await StorageService.cacheActivityLogs([]);
    await StorageService.cachePickingOperations([]);

    notifyListeners();
  }
}
