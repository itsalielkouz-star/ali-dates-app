import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/utils/qr_helper.dart';
import '../../data/models/pallet_model.dart';

/// Pixel-perfect Pallet Label Sticker (ملصق الطبلية الرسمي)
/// Specifications:
/// - Facility Header: مركز فرز التمور الآلي (Arabic bigger than English)
/// - Supplier Name: 3 letters of initials (Not full name)
/// - Enlarged high-contrast easy-to-scan QR Code
/// - Product State: "تمر مفروز أولي" or "تمر خام" (تمر خام أو تمر مفروز أولي)
/// - Removal of "وزن الطبلة الفارغة" from table, utilizing all empty space across 3 clear columns:
///   الوزن الصافي | الوزن القائم | عدد الصناديق
/// - "تاريخ الاستلام" displayed clearly in both sticker & QR data
class PalletStickerWidget extends StatelessWidget {
  final PalletModel pallet;

  const PalletStickerWidget({
    super.key,
    required this.pallet,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('yyyy/MM/dd HH:mm').format(pallet.createdAt);
    final supplierInitials = QrHelper.getSupplierInitials(pallet.customerName);
    final isPresorted = pallet.isPresorted;
    final productStatusArabic = isPresorted ? 'تمر مفروز أولي' : 'تمر خام';
    final productStatusEnglish = isPresorted ? 'Pre-Sorted Medjool' : 'Raw Medjool';

    return Container(
      width: 390,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: 2.2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Facility Header Banner (Arabic always bigger than English)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: Colors.black,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'مركز فرز التمور الآلي',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Ali Dates - Automated Sorting Facility',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // 2. Top Header: Supplier Initials, Receiving Date, and Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Right: Supplier Initials & Receiving Date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'المورد: ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.black, width: 2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              supplierInitials,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'تاريخ الاستلام: $dateFormatted',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Left: Enlarged Crisp Black Ali Dates Logo (No background)
                Image.asset(
                  'assets/images/ali_dates_logo.png',
                  width: 75,
                  height: 75,
                  fit: BoxFit.contain,
                  color: Colors.black,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 2, color: Colors.black),

          // 3. Middle Section: Enlarged QR Code (135px) + Product Type Badge + Big Pallet Code
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Enlarged High-Contrast Easy-to-Scan QR Code
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: QrImageView(
                    data: pallet.palletCode,
                    version: QrVersions.auto,
                    size: 135, // Enlarged for ultra fast scanning
                    padding: EdgeInsets.zero,
                    gapless: true,
                    foregroundColor: Colors.black,
                  ),
                ),
                const SizedBox(width: 14),

                // Right Details: تمر خام أو تمر مفروز أولي & Pallet Code (Clean white background)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Product Status Badge: Clean white border
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.black,
                            width: 1.8,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              productStatusArabic,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              productStatusEnglish,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pallet Reference Code Badge: Extra Big & Pure White Background
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'رمز الطبلية المرجعي:',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              pallet.palletCode,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1.5, color: Colors.black),

          // 4. Bottom Table: 3 Wide Columns utilizing all empty space
          // (الوزن الصافي | الوزن القائم | عدد الصناديق)
          Table(
            border: const TableBorder(
              top: BorderSide.none,
              bottom: BorderSide.none,
              left: BorderSide.none,
              right: BorderSide.none,
              horizontalInside: BorderSide(color: Colors.black, width: 1.4),
              verticalInside: BorderSide(color: Colors.black, width: 1.4),
            ),
            children: [
              // Header Row
              const TableRow(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                    child: Text(
                      'الوزن الصافي',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                    child: Text(
                      'الوزن القائم',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                    child: Text(
                      'عدد الصناديق',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                ],
              ),
              // Values Row
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    child: Text(
                      '${pallet.netWeight.toStringAsFixed(1)} كغ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    child: Text(
                      '${pallet.grossWeight.toStringAsFixed(1)} كغ',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                    child: Text(
                      '${pallet.boxCount} صندوق',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
