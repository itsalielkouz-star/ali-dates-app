import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart';
import '../models/farm_model.dart';
import '../models/pallet_model.dart';
import '../models/sorting_batch_model.dart';
import '../models/document_model.dart';

/// Offline-First Local Storage Service
/// Ensures smooth operations inside freezers and cold storage when network is unstable
class StorageService {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('StorageService not initialized. Call init() first.');
    }
    return _prefs!;
  }

  // --- Current User Session ---
  static const String _keyCurrentUser = 'current_user_profile';

  static Future<void> saveCurrentUser(UserProfile user) async {
    await prefs.setString(_keyCurrentUser, jsonEncode(user.toJson()));
  }

  static UserProfile? getCurrentUser() {
    final str = prefs.getString(_keyCurrentUser);
    if (str == null) return null;
    try {
      return UserProfile.fromJson(jsonDecode(str));
    } catch (e) {
      return null;
    }
  }

  static Future<void> clearUser() async {
    await prefs.remove(_keyCurrentUser);
  }

  // --- Cached Profiles ---
  static const String _keyProfiles = 'cached_profiles';
  static Future<void> cacheProfiles(List<UserProfile> profiles) async {
    final list = profiles.map((p) => p.toJson()).toList();
    await prefs.setString(_keyProfiles, jsonEncode(list));
  }

  static List<UserProfile> getCachedProfiles() {
    final str = prefs.getString(_keyProfiles);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => UserProfile.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Cached Pallets ---
  static const String _keyPallets = 'cached_pallets';
  static Future<void> cachePallets(List<PalletModel> pallets) async {
    final list = pallets.map((p) => p.toJson()).toList();
    await prefs.setString(_keyPallets, jsonEncode(list));
  }

  static List<PalletModel> getCachedPallets() {
    final str = prefs.getString(_keyPallets);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => PalletModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Cached Sorting Batches ---
  static const String _keySortingBatches = 'cached_sorting_batches';
  static Future<void> cacheSortingBatches(List<SortingBatchModel> batches) async {
    final list = batches.map((b) => b.toJson()).toList();
    await prefs.setString(_keySortingBatches, jsonEncode(list));
  }

  static List<SortingBatchModel> getCachedSortingBatches() {
    final str = prefs.getString(_keySortingBatches);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => SortingBatchModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Cached Documents ---
  static const String _keyDocuments = 'cached_documents';
  static Future<void> cacheDocuments(List<DocumentModel> docs) async {
    final list = docs.map((d) => d.toJson()).toList();
    await prefs.setString(_keyDocuments, jsonEncode(list));
  }

  static List<DocumentModel> getCachedDocuments() {
    final str = prefs.getString(_keyDocuments);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => DocumentModel.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Cached Activity Logs ---
  static const String _keyActivityLogs = 'cached_activity_logs';
  static const String _keyShiftSupervisor = 'shift_supervisor_name';

  static Future<void> cacheActivityLogs(List<dynamic> logs) async {
    final list = logs.map((l) => l.toJson()).toList();
    await prefs.setString(_keyActivityLogs, jsonEncode(list));
  }

  static List<Map<String, dynamic>> getCachedActivityLogs() {
    final str = prefs.getString(_keyActivityLogs);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveShiftSupervisor(String name) async {
    await prefs.setString(_keyShiftSupervisor, name);
  }

  static String getShiftSupervisor() {
    return prefs.getString(_keyShiftSupervisor) ?? 'خالد الكوز (المشرف العام)';
  }

  // --- Cached Picking / Harvesting Operations ---
  static const String _keyPickingOperations = 'cached_picking_operations';

  static Future<void> cachePickingOperations(List<dynamic> list) async {
    final raw = list.map((e) => e.toJson()).toList();
    await prefs.setString(_keyPickingOperations, jsonEncode(raw));
  }

  static List<Map<String, dynamic>> getCachedPickingOperations() {
    final str = prefs.getString(_keyPickingOperations);
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  // --- Executive Dashboard Settings ---
  static const String _keyFreezerCapacities = 'freezer_capacities';
  static const String _keyTotalCompanyBoxes = 'total_company_boxes';

  static Future<void> saveFreezerCapacities(Map<String, int> capacities) async {
    await prefs.setString(_keyFreezerCapacities, jsonEncode(capacities));
  }

  static Map<String, int> getFreezerCapacities() {
    final str = prefs.getString(_keyFreezerCapacities);
    if (str == null) {
      return {
        'pre_fridge': 60,
        'first_fridge': 90,
        'main_freezer_1': 270,
        'main_freezer_2': 270,
        'small_freezer': 120,
      };
    }
    try {
      final map = jsonDecode(str) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, int.tryParse(v.toString()) ?? 100));
    } catch (e) {
      return {
        'pre_fridge': 60,
        'first_fridge': 90,
        'main_freezer_1': 270,
        'main_freezer_2': 270,
        'small_freezer': 120,
      };
    }
  }

  static Future<void> saveTotalCompanyBoxes(int total) async {
    await prefs.setInt(_keyTotalCompanyBoxes, total);
  }

  static int getTotalCompanyBoxes() {
    return prefs.getInt(_keyTotalCompanyBoxes) ?? 100000;
  }
}
