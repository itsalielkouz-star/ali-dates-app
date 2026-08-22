/// Comprehensive Phone Normalizer and Matcher for Jordan (+962 / 079 / 078 / 077)
class PhoneUtils {
  /// Extracts only digit characters
  static String cleanDigits(String rawPhone) {
    return rawPhone.replaceAll(RegExp(r'\D'), '');
  }

  /// Jordanian phone normalizer based on carrier start index '7'
  static String normalizeJordanianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final idx = digits.indexOf('7');
    return idx != -1 ? digits.substring(idx) : digits;
  }

  /// Checks if a phone number is a Jordanian mobile/landline number
  static bool isJordanian(String rawPhone) {
    if (rawPhone.startsWith('odoo_no_phone_')) return false;
    final digits = cleanDigits(rawPhone);
    if (digits.isEmpty) return false;

    // Direct local starts: 079, 078, 077, 07
    if (digits.startsWith('07') && digits.length >= 9) return true;
    if ((digits.startsWith('79') || digits.startsWith('78') || digits.startsWith('77')) && digits.length == 9) return true;

    // International Jordanian formats: 9627..., 009627...
    if (digits.startsWith('9627') || digits.startsWith('009627')) return true;
    if (digits.startsWith('962') && digits.length >= 11) return true;

    return false;
  }

  /// Exact matcher comparing normalized Jordanian core digits
  static bool isPhoneMatch(String a, String b) {
    final normA = normalizeJordanianPhone(a);
    final normB = normalizeJordanianPhone(b);
    if (normA.isEmpty || normB.isEmpty) return false;
    return normA == normB;
  }

  /// Strips all non-digit characters except leading plus, then normalizes
  static String normalize(String rawPhone) {
    // 1. Remove all spaces, dashes, dots, parentheses, slashes, unicode zero-width spaces
    String cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\.\(\)\/\u200B-\u200D\uFEFF]'), '');

    // 2. Remove leading plus or 00
    if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    // 3. Remove Jordan country code (962)
    if (cleaned.startsWith('962')) {
      cleaned = cleaned.substring(3);
    }

    // 4. Ensure it starts with 0 for local 10-digit standard (e.g. 0795457988)
    if (!cleaned.startsWith('0') && cleaned.isNotEmpty) {
      cleaned = '0$cleaned';
    }

    return cleaned;
  }

  /// Returns 9-digit number without leading 0 (e.g. 795457988)
  static String getBaseDigits(String rawPhone) {
    final norm = normalize(rawPhone);
    return norm.startsWith('0') ? norm.substring(1) : norm;
  }

  /// Returns international standard format (+962795457988)
  static String toInternational(String rawPhone) {
    final base = getBaseDigits(rawPhone);
    return '+962$base';
  }

  /// Returns clean local format (0795457988)
  static String toLocal(String rawPhone) {
    return normalize(rawPhone);
  }

  /// Returns clean local format (0796611533)
  static String toDisplay(String rawPhone) {
    return normalize(rawPhone);
  }

  /// Generates all possible string variations for Odoo and database matching
  static Set<String> generateSearchVariants(String rawPhone) {
    final norm = normalize(rawPhone);
    final base = getBaseDigits(rawPhone);
    final trimmedRaw = rawPhone.trim();

    final variants = <String>{
      trimmedRaw,
      norm, // 0795457988
      base, // 795457988
      '+962$base', // +962795457988
      '962$base', // 962795457988
      '00962$base', // 00962795457988
      '+962 $base', // +962 795457988
      '00962 $base', // 00962 795457988
    };

    if (norm.length == 10) {
      // 079 545 7988
      variants.add('${norm.substring(0, 3)} ${norm.substring(3, 6)} ${norm.substring(6)}');
      // 079 5457988
      variants.add('${norm.substring(0, 3)} ${norm.substring(3)}');
      // 079-545-7988
      variants.add('${norm.substring(0, 3)}-${norm.substring(3, 6)}-${norm.substring(6)}');
      // +962 7 9545 7988
      variants.add('+962 ${base.substring(0, 1)} ${base.substring(1, 5)} ${base.substring(5)}');
    }

    return variants;
  }

  /// Compares two phone numbers regardless of format, country code, or spaces
  static bool areEqual(String? phoneA, String? phoneB) {
    if (phoneA == null || phoneB == null) return false;
    if (phoneA.trim().isEmpty || phoneB.trim().isEmpty) return false;
    return getBaseDigits(phoneA) == getBaseDigits(phoneB);
  }
}
