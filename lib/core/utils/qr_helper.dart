import 'dart:convert';
import 'package:intl/intl.dart';
import '../../data/models/pallet_model.dart';
import '../../data/models/sorting_batch_model.dart';

/// Helper for Generating & Parsing Pallet QR Codes and Label Printing
class QrHelper {
  /// Generates a standardized QR payload for a raw receiving pallet
  static String generatePalletQrPayload(PalletModel pallet) {
    final payload = {
      'type': 'pallet',
      'id': pallet.id,
      'code': pallet.palletCode,
      'owner': pallet.customerName ?? pallet.customerId,
      'farm': pallet.farmName ?? '',
      'tare': pallet.netWeight,
      'gross': pallet.grossWeight,
      'boxes': pallet.boxCount,
      'presorted': pallet.isPresorted,
      'loc': pallet.locationType,
      'date': pallet.createdAt.toIso8601String(),
    };
    return jsonEncode(payload);
  }

  /// Generates a standardized QR payload for an auto-sorted pallet
  static String generateSortedPalletQrPayload({
    required SortingOutputItem item,
    required String customerName,
    required String farmName,
  }) {
    final payload = {
      'type': 'sorted_pallet',
      'id': item.id,
      'code': item.palletCode,
      'owner': customerName,
      'farm': farmName,
      'category': item.category,
      'size': item.size,
      'boxes': item.boxCount,
      'weight': item.weight,
      'date': DateTime.now().toIso8601String(),
    };
    return jsonEncode(payload);
  }

  /// Parses scanned QR code text into structured data
  static Map<String, dynamic>? parseQrPayload(String rawQr) {
    try {
      if (rawQr.startsWith('{') && rawQr.endsWith('}')) {
        return jsonDecode(rawQr) as Map<String, dynamic>;
      }
      // If simple pallet code text was scanned (e.g. PAL-001)
      return {
        'type': 'pallet_code',
        'code': rawQr,
      };
    } catch (e) {
      return {'code': rawQr};
    }
  }

  /// Generates a new unique Pallet Code (e.g., PAL-2026-8492)
  static String generateNewPalletCode({String prefix = 'PAL'}) {
    final year = DateTime.now().year;
    final randomPart = (DateTime.now().millisecondsSinceEpoch % 90000) + 10000;
    return '$prefix-$year-$randomPart';
  }

  /// Extracts 3 letters initials for supplier name (Not full name on QR sticker)
  static String getSupplierInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'ALM';
    final clean = name.trim();
    final words = clean.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    if (words.length >= 3) {
      return '${words[0].substring(0, 1)}${words[1].substring(0, 1)}${words[2].substring(0, 1)}'.toUpperCase();
    } else if (words.length == 2) {
      final first = words[0].substring(0, 1);
      final second = words[1].length >= 2 ? words[1].substring(0, 2) : words[1].substring(0, 1);
      return '$first$second'.toUpperCase();
    } else {
      return clean.length >= 3 ? clean.substring(0, 3).toUpperCase() : clean.toUpperCase();
    }
  }

  /// Formats date for receipt / label display
  static String formatDate(DateTime date) {
    return DateFormat('yyyy/MM/dd HH:mm').format(date);
  }
}
