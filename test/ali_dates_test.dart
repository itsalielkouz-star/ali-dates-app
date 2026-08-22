import 'package:flutter_test/flutter_test.dart';
import 'package:ali_dates_app/data/models/pallet_model.dart';
import 'package:ali_dates_app/data/models/user_profile.dart';
import 'package:ali_dates_app/core/utils/qr_helper.dart';
import 'package:ali_dates_app/core/utils/phone_utils.dart';

void main() {
  group('Ali Dates (تمور علي) - Unit Tests', () {
    test('Tare weight calculation formula is accurate', () {
      // Net = Gross - (Empty Pallet Weight + (Empty Box Weight * Box Count))
      // Example: 1050.0 - (16.0 + (0.95 * 200)) = 1050.0 - (16.0 + 190.0) = 1050.0 - 206.0 = 844.0 kg
      final tare = PalletModel.calculateTareWeight(
        gross: 1050.0,
        palletEmpty: 16.0,
        boxEmpty: 0.95,
        boxes: 200,
      );

      expect(tare, 844.0);
    });

    test('Pallet Model initializes correctly with default values', () {
      final pallet = PalletModel(
        id: 'pal_test_01',
        palletCode: 'PAL-2026-101',
        customerId: 'user_01',
        grossWeight: 1000.0,
      );

      expect(pallet.emptyPalletWeight, 16.0);
      expect(pallet.emptyBoxWeight, 0.95);
      expect(pallet.boxCount, 200);
      expect(pallet.netWeight, 794.0);
    });

    test('QR Helper generates standardized pallet code', () {
      final code = QrHelper.generateNewPalletCode(prefix: 'PAL');
      expect(code.startsWith('PAL-'), isTrue);
    });

    test('UserProfile role detection works for Ali Dates workers vs Customers', () {
      final emp = UserProfile(
        id: '1',
        phone: '0791234567',
        name: 'علي الشريف',
        isEmployee: true,
        companyName: 'تمور علي',
      );

      final cust = UserProfile(
        id: '2',
        phone: '0777777777',
        name: 'أبو راشد',
        isEmployee: false,
        companyName: 'مزارع النخيل الذهبي',
      );

      expect(emp.isEmployee, isTrue);
      expect(cust.isEmployee, isFalse);
    });

    test('PhoneUtils normalizes all phone formats correctly (+962, 00962, spaces, dashes)', () {
      const p1 = '+962 7 9545 7988';
      const p2 = '+962795457988';
      const p3 = '00962795457988';
      const p4 = '00962 79 545 7988';
      const p5 = '0795457988';
      const p6 = '079 545 7988';
      const p7 = '795457988';
      const p8 = '79 545 7988';

      expect(PhoneUtils.toLocal(p1), '0795457988');
      expect(PhoneUtils.toLocal(p2), '0795457988');
      expect(PhoneUtils.toLocal(p3), '0795457988');
      expect(PhoneUtils.toLocal(p4), '0795457988');
      expect(PhoneUtils.toLocal(p5), '0795457988');
      expect(PhoneUtils.toLocal(p6), '0795457988');
      expect(PhoneUtils.toLocal(p7), '0795457988');
      expect(PhoneUtils.toLocal(p8), '0795457988');

      expect(PhoneUtils.areEqual(p1, p5), isTrue);
      expect(PhoneUtils.areEqual(p3, p7), isTrue);
      expect(PhoneUtils.toDisplay(p1), '0795457988');
    });

    test('Jordanian Phone Normalization based on customer_dashboard algorithm', () {
      expect(PhoneUtils.normalizeJordanianPhone('0791234567'), equals('791234567'));
      expect(PhoneUtils.normalizeJordanianPhone('+962791234567'), equals('791234567'));
      expect(PhoneUtils.normalizeJordanianPhone('962771234567'), equals('771234567'));
      expect(PhoneUtils.normalizeJordanianPhone('+962 (79) 123-4567'), equals('791234567'));
      expect(PhoneUtils.normalizeJordanianPhone('0781234567'), equals('781234567'));
      expect(PhoneUtils.normalizeJordanianPhone('123456'), equals('123456'));

      expect(PhoneUtils.isPhoneMatch('+962 7 9661 1533', '0796611533'), isTrue);
      expect(PhoneUtils.isPhoneMatch('+962 7 9899 7449', '0798997449'), isTrue);
      expect(PhoneUtils.isPhoneMatch('+962 7 9545 7988', '0795457988'), isTrue);
    });

    test('isJordanian correctly identifies Jordanian numbers and places them first', () {
      expect(PhoneUtils.isJordanian('0795457988'), isTrue);
      expect(PhoneUtils.isJordanian('0781234567'), isTrue);
      expect(PhoneUtils.isJordanian('0777635424'), isTrue);
      expect(PhoneUtils.isJordanian('+962 7 9661 1533'), isTrue);
      expect(PhoneUtils.isJordanian('00962798997449'), isTrue);

      expect(PhoneUtils.isJordanian('+971566825505'), isFalse); // UAE number
      expect(PhoneUtils.isJordanian('odoo_no_phone_102'), isFalse);
    });
  });
}
