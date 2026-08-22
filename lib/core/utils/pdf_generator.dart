import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/pallet_model.dart';
import '../../data/models/shipment_model.dart';
import '../../data/models/sorting_batch_model.dart';
import 'qr_helper.dart';

/// PDF Document Generator for Ali Dates (تمور علي)
/// Generates crisp, official Arabic vector PDFs matching corporate standard
class PdfGenerator {
  static Uint8List? _cachedLogoBytes;

  /// Loads the official Ali Dates logo for headers, watermarks, and stickers
  static Future<Uint8List?> _loadLogoBytes() async {
    if (_cachedLogoBytes != null) return _cachedLogoBytes;
    try {
      final byteData = await rootBundle.load('assets/images/ali_dates_logo.png');
      _cachedLogoBytes = byteData.buffer.asUint8List();
    } catch (_) {
      try {
        final byteData = await rootBundle.load('assets/images/logo.png');
        _cachedLogoBytes = byteData.buffer.asUint8List();
      } catch (_) {}
    }
    return _cachedLogoBytes;
  }

  /// Official Arabic Typography Font Loader using Amiri (Standard Arabic Naskh)
  static Future<pw.ThemeData> _getArabicTheme() async {
    final font = await PdfGoogleFonts.amiriRegular();
    final fontBold = await PdfGoogleFonts.amiriBold();
    return pw.ThemeData.withFont(base: font, bold: fontBold);
  }

  // --- Official Layout Helpers ---

  static pw.Widget _buildOfficialHeader({
    required Uint8List? logoBytes,
    required String docTitle,
    required String dateStr,
    required String docRef,
  }) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Left: Official Logo
            if (logoBytes != null)
              pw.Container(
                width: 55,
                height: 55,
                child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
              )
            else
              pw.Container(
                width: 55,
                height: 55,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColor.fromHex('013D5A'), width: 1.5),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'تمور علي',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('013D5A'),
                    ),
                  ),
                ),
              ),

            // Right: Official Company Header Contact
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'مركز فرز التمور الآلي',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('013D5A'),
                  ),
                ),
                pw.Text(
                  'Ali Dates - Automated Sorting Facility',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'شركة خالد الكوز وشركاه، الكرامة، الاردن | هاتف: 0798997449',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Text('تاريخ الاستلام: $dateStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.Text('  |  ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                    pw.Text('المرجع: $docRef', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Divider(thickness: 1, color: PdfColor.fromHex('013D5A')),
      ],
    );
  }

  static pw.Widget _buildOfficialWatermark(Uint8List? logoBytes) {
    if (logoBytes == null) return pw.SizedBox();
    return pw.Center(
      child: pw.Opacity(
        opacity: 0.04,
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          width: 320,
          fit: pw.BoxFit.contain,
        ),
      ),
    );
  }

  static pw.Widget _buildOfficialFooter({
    required int pageNum,
    required int totalPages,
    required String title,
  }) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
        pw.SizedBox(height: 2),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'صفحة $pageNum من $totalPages',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
            pw.Text(
              title,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Text(
              'تمور علي - نظام إدارة المستودعات والفرز',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  // --- 1. Arabic Inbound Receiving Receipt (سند استلام تمور رسمي) ---

  static Future<Uint8List> generateReceivingReceiptPdf({
    required ShipmentModel shipment,
    required List<PalletModel> pallets,
    Uint8List? employeeSignatureBytes,
    Uint8List? driverSignatureBytes,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(shipment.createdAt);
    final totalNetWeight = pallets.fold<double>(0.0, (sum, p) => sum + p.netWeight);
    final totalGrossWeight = pallets.fold<double>(0.0, (sum, p) => sum + p.grossWeight);
    final totalBoxes = pallets.fold<int>(0, (sum, p) => sum + p.boxCount);
    final docRef = 'REC-${shipment.plateNumber.replaceAll(' ', '')}';

    // Decode Attached Photos if available
    Uint8List? licenseBytes;
    Uint8List? truckBytes;
    if (shipment.licensePhotoUrl != null && shipment.licensePhotoUrl!.isNotEmpty) {
      try {
        licenseBytes = base64Decode(shipment.licensePhotoUrl!);
      } catch (_) {}
    }
    if (shipment.truckPhotoUrl != null && shipment.truckPhotoUrl!.isNotEmpty) {
      try {
        truckBytes = base64Decode(shipment.truckPhotoUrl!);
      } catch (_) {}
    }

    final hasAttachmentsPage = licenseBytes != null || truckBytes != null;
    final totalPages = hasAttachmentsPage ? 2 : 1;

    // PAGE 1: Formal Receiving Receipt
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              _buildOfficialWatermark(logoBytes),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Official Header
                  _buildOfficialHeader(
                    logoBytes: logoBytes,
                    docTitle: 'سند استلام شحنة تمور رسمية',
                    dateStr: dateStr,
                    docRef: docRef,
                  ),

                  pw.SizedBox(height: 10),

                  // Title Banner & Box Ownership Contract Type
                  pw.Center(
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'سند استلام شحنة تمور رسمية',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColor.fromHex('013D5A'),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Container(
                          height: 1.5,
                          width: 140,
                          color: PdfColor.fromHex('D4AF37'),
                        ),
                        pw.SizedBox(height: 4),
                        // Contract Box Ownership Badge under receipt title
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('013D5A'),
                            borderRadius: pw.BorderRadius.circular(3),
                          ),
                          child: pw.Text(
                            'ملكية الصناديق: ${shipment.boxContractType ?? ShipmentModel.contractSorting}',
                            style: pw.TextStyle(
                              fontSize: 9.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 10),

                  // Shipment Info Box (Structured clean Arabic cells)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1'), width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('العميل / المزرعة:', shipment.customerName ?? 'عميل تمور علي'),
                            _buildPdfInfoField('اسم السائق:', shipment.driverName),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('وكيل العميل / المشرف:', shipment.agentName),
                            _buildPdfInfoField('رقم المركبة:', shipment.plateNumber),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('نوع التمر:', shipment.isPresorted ? 'تمر مفروز أولي' : 'تمر خام'),
                            _buildPdfInfoField('عدد الطبالي المستلمة:', '${pallets.length} طبلية'),
                          ],
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 12),

                  // Pallets Table Header
                  pw.Text(
                    'تفاصيل الطبالي والأوزان المستلمة:',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                  ),
                  pw.SizedBox(height: 6),

                  // Pallets Table (Clean 5 columns utilizing all empty space)
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColor.fromHex('94A3B8'), width: 0.5),
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('E2E8F0')),
                        children: [
                          _buildTableHeaderCell('#'),
                          _buildTableHeaderCell('رمز الطبلية'),
                          _buildTableHeaderCell('حالة التمر'),
                          _buildTableHeaderCell('عدد الصناديق'),
                          _buildTableHeaderCell('الوزن القائم'),
                          _buildTableHeaderCell('الوزن الصافي'),
                        ],
                      ),
                      // Data Rows
                      ...pallets.asMap().entries.map((entry) {
                        final i = entry.key + 1;
                        final p = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildTableCell('$i'),
                            _buildTableCell(p.palletCode),
                            _buildTableCell(p.isPresorted ? 'تمر مفروز أولي' : 'تمر خام'),
                            _buildTableCell('${p.boxCount} صندوق'),
                            _buildTableCell('${p.grossWeight.toStringAsFixed(1)} كغ'),
                            _buildTableCell('${p.netWeight.toStringAsFixed(1)} كغ', isBold: true),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // Summary Box
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F1F5F9'),
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: PdfColor.fromHex('013D5A'), width: 1),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text('إجمالي الصناديق: $totalBoxes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text('إجمالي الوزن القائم: ${totalGrossWeight.toStringAsFixed(1)} كغ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Text(
                          'إجمالي الوزن الصافي: ${totalNetWeight.toStringAsFixed(1)} كغ',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColor.fromHex('013D5A')),
                        ),
                      ],
                    ),
                  ),

                  pw.Spacer(),

                  // Dual Digital Signatures Section
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1'), width: 0.8),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Party 1: Ali Dates Receiving Officer
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'الفريق الأول (موظف الاستلام):',
                                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text('السيد خالد علي الكوز / مسؤول الاستلام', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.SizedBox(height: 4),
                              if (employeeSignatureBytes != null)
                                pw.Container(
                                  height: 40,
                                  child: pw.Image(pw.MemoryImage(employeeSignatureBytes), fit: pw.BoxFit.contain),
                                )
                              else
                                pw.Container(
                                  height: 35,
                                  child: pw.Center(child: pw.Text('__________________', style: const pw.TextStyle(color: PdfColors.grey500))),
                                ),
                              pw.Text('التوقيع الإلكتروني المعتمد', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                            ],
                          ),
                        ),

                        pw.Container(width: 1, height: 65, color: PdfColor.fromHex('E2E8F0')),

                        // Party 2: Driver / Customer Representative
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(
                                'الفريق الثاني (السائق / المندوب):',
                                style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text('${shipment.driverName} / ${shipment.agentName}', style: const pw.TextStyle(fontSize: 8.5)),
                              pw.SizedBox(height: 4),
                              if (driverSignatureBytes != null)
                                pw.Container(
                                  height: 40,
                                  child: pw.Image(pw.MemoryImage(driverSignatureBytes), fit: pw.BoxFit.contain),
                                )
                              else
                                pw.Container(
                                  height: 35,
                                  child: pw.Center(child: pw.Text('__________________', style: const pw.TextStyle(color: PdfColors.grey500))),
                                ),
                              pw.Text('اسم وتوقيع السائق / المندوب', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 8),

                  // Footer
                  _buildOfficialFooter(
                    pageNum: 1,
                    totalPages: totalPages,
                    title: 'سند استلام تمور - ${shipment.customerName ?? ""}',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // PAGE 2: Official Shipment Attachments (License & Truck Photos)
    if (hasAttachmentsPage) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                _buildOfficialWatermark(logoBytes),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildOfficialHeader(
                      logoBytes: logoBytes,
                      docTitle: 'مرفقات الشحنة والوثائق الثبوتية الرسمية',
                      dateStr: dateStr,
                      docRef: docRef,
                    ),

                    pw.SizedBox(height: 10),

                    // Title Banner
                    pw.Center(
                      child: pw.Column(
                        children: [
                          pw.Text(
                            'مرفقات الشحنة والوثائق الثبوتية الرسمية',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColor.fromHex('013D5A'),
                            ),
                          ),
                          pw.SizedBox(height: 2),
                          pw.Container(
                            height: 1.5,
                            width: 160,
                            color: PdfColor.fromHex('D4AF37'),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // Metadata Info Bar
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('F8FAFC'),
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColor.fromHex('CBD5E1'), width: 0.8),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('رقم المركبة: ${shipment.plateNumber}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('السائق: ${shipment.driverName}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('العميل: ${shipment.customerName ?? ""}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 12),

                    // 2-Column Photos Grid
                    pw.Expanded(
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // 1. Driver License Photo
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
                                borderRadius: pw.BorderRadius.circular(6),
                                color: PdfColors.white,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('013D5A'),
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                    child: pw.Text(
                                      'رخصة قيادة السائق / هوية المندوب',
                                      style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  if (licenseBytes != null)
                                    pw.Expanded(
                                      child: pw.Image(
                                        pw.MemoryImage(licenseBytes),
                                        fit: pw.BoxFit.contain,
                                      ),
                                    )
                                  else
                                    pw.Expanded(
                                      child: pw.Center(
                                        child: pw.Text('لا توجد صورة رخصة مرفقة', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
                                      ),
                                    ),
                                  pw.SizedBox(height: 4),
                                  pw.Text('اسم السائق: ${shipment.driverName}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                          ),

                          pw.SizedBox(width: 12),

                          // 2. Truck / Vehicle Photo
                          pw.Expanded(
                            child: pw.Container(
                              padding: const pw.EdgeInsets.all(8),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
                                borderRadius: pw.BorderRadius.circular(6),
                                color: PdfColors.white,
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.center,
                                children: [
                                  pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColor.fromHex('013D5A'),
                                      borderRadius: pw.BorderRadius.circular(3),
                                    ),
                                    child: pw.Text(
                                      'صورة المركبة ولوحة الشاحنة',
                                      style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold),
                                    ),
                                  ),
                                  pw.SizedBox(height: 8),
                                  if (truckBytes != null)
                                    pw.Expanded(
                                      child: pw.Image(
                                        pw.MemoryImage(truckBytes),
                                        fit: pw.BoxFit.contain,
                                      ),
                                    )
                                  else
                                    pw.Expanded(
                                      child: pw.Center(
                                        child: pw.Text('لا توجد صورة مركبة مرفقة', style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
                                      ),
                                    ),
                                  pw.SizedBox(height: 4),
                                  pw.Text('رقم اللوحة: ${shipment.plateNumber}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Verification Stamp Note
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('ECFDF5'),
                        border: pw.Border.all(color: PdfColor.fromHex('10B981'), width: 0.8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'تم التدقيق والمطابقة وتوثيق الصور إلكترونياً بواسطة نظام تمور علي',
                            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('047857')),
                          ),
                          pw.Text(dateStr, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('047857'))),
                        ],
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    // Footer
                    _buildOfficialFooter(
                      pageNum: 2,
                      totalPages: totalPages,
                      title: 'مرفقات الشحنة - ${shipment.customerName ?? ""}',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // --- 2. Single Thermal Pallet Sticker (100mm x 85mm) ---

  static Future<Uint8List> generatePalletBarcodeLabelPdf(
    PalletModel pallet, {
    String productEnglish = 'Raw Medjool',
    String productArabic = 'تمر مجهول',
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(100 * PdfPageFormat.mm, 85 * PdfPageFormat.mm, marginAll: 3 * PdfPageFormat.mm),
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        build: (pw.Context context) {
          return _buildPalletStickerContent(
            pallet: pallet,
            logoBytes: logoBytes,
            productEnglish: productEnglish,
            productArabic: productArabic,
            scaleFactor: 1.0,
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- 3. A4 Sheet with 4 Duplicates (2x2 Grid of A6 Stickers) ---

  static Future<Uint8List> generatePalletStickersSheetA4Pdf(
    PalletModel pallet, {
    String productEnglish = 'Raw Medjool',
    String productArabic = 'تمر مجهول',
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        margin: const pw.EdgeInsets.all(6 * PdfPageFormat.mm),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // Top Row (2 Stickers)
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: _buildPalletStickerContent(
                          pallet: pallet,
                          logoBytes: logoBytes,
                          productEnglish: productEnglish,
                          productArabic: productArabic,
                          scaleFactor: 1.15,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: _buildPalletStickerContent(
                          pallet: pallet,
                          logoBytes: logoBytes,
                          productEnglish: productEnglish,
                          productArabic: productArabic,
                          scaleFactor: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Horizontal Cut Guide Line
              pw.Container(
                height: 1,
                color: PdfColors.grey400,
                margin: const pw.EdgeInsets.symmetric(vertical: 2),
              ),

              // Bottom Row (2 Stickers)
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: _buildPalletStickerContent(
                          pallet: pallet,
                          logoBytes: logoBytes,
                          productEnglish: productEnglish,
                          productArabic: productArabic,
                          scaleFactor: 1.15,
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: _buildPalletStickerContent(
                          pallet: pallet,
                          logoBytes: logoBytes,
                          productEnglish: productEnglish,
                          productArabic: productArabic,
                          scaleFactor: 1.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Reusable Sticker Content Builder:
  /// - NO "الاستلام"
  /// - Big Black Logo OUTSIDE the QR Code
  /// - Large Unobstructed Easy-to-Scan Monotone QR Code
  /// - "Raw Medjool - تمر مجهول" (No "المادة:")
  /// - 4 Columns: الوزن الصافي | الوزن القائم | وزن الطبلية فارغة | عدد الصناديق
  /// Reusable Sticker Content Builder matching exact requirements:
  /// - Header: مركز فرز التمور الآلي (Arabic bigger than English)
  /// - Supplier initials: 3 letters (Not full name)
  /// - Date: تاريخ الاستلام clearly formatted
  /// - Enlarged QR Code
  /// - Product Type: تمر خام أو تمر مفروز أولي
  /// - 3 Columns: الوزن الصافي | الوزن القائم | عدد الصناديق (Empty pallet weight removed, using all empty space)
  static pw.Widget _buildPalletStickerContent({
    required PalletModel pallet,
    required Uint8List? logoBytes,
    required String productEnglish,
    required String productArabic,
    double scaleFactor = 1.0,
  }) {
    final dateStr = DateFormat('yyyy/MM/dd HH:mm').format(pallet.createdAt);
    final supplierInitials = QrHelper.getSupplierInitials(pallet.customerName);
    final isPresorted = pallet.isPresorted;
    final productStatusAr = isPresorted ? 'تمر مفروز أولي' : 'تمر خام';
    final productStatusEn = isPresorted ? 'Pre-Sorted Medjool' : 'Raw Medjool';

    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 1.8),
        borderRadius: pw.BorderRadius.circular(2),
        color: PdfColors.white,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          // 0. Facility Top Banner (Arabic bigger than English)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            color: PdfColors.black,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'مركز فرز التمور الآلي',
                  style: pw.TextStyle(
                    fontSize: 9 * scaleFactor,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.Text(
                  'Ali Dates - Automated Sorting Facility',
                  style: pw.TextStyle(
                    fontSize: 6.5 * scaleFactor,
                    color: PdfColors.grey300,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 2),

          // 1. Supplier Initials, Date, and Crisp Black Logo OUTSIDE QR Code
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'المورد: ',
                          style: pw.TextStyle(
                            fontSize: 9.5 * scaleFactor,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                          ),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.black,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(
                            supplierInitials,
                            style: pw.TextStyle(
                              fontSize: 10 * scaleFactor,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      'تاريخ الاستلام: $dateStr',
                      style: pw.TextStyle(
                        fontSize: 8 * scaleFactor,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(width: 4),

              // Logo
              if (logoBytes != null)
                pw.Container(
                  width: 32 * scaleFactor,
                  height: 32 * scaleFactor,
                  child: pw.Image(
                    pw.MemoryImage(logoBytes),
                    fit: pw.BoxFit.contain,
                  ),
                )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black)),
                  child: pw.Text('تمور علي', style: pw.TextStyle(fontSize: 8 * scaleFactor, fontWeight: pw.FontWeight.bold)),
                ),
            ],
          ),

          pw.Divider(thickness: 1.0, color: PdfColors.black, height: 3),

          // 2. Middle Section: Enlarged QR Code + Product State (تمر خام أو تمر مفروز أولي) + Pallet Code
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Enlarged Pure Monotone QR Code
              pw.Container(
                padding: const pw.EdgeInsets.all(1.5),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 1),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: pallet.palletCode,
                  color: PdfColors.black,
                  width: 64 * scaleFactor, // Enlarged QR code
                  height: 64 * scaleFactor,
                ),
              ),
              pw.SizedBox(width: 6),

              // Right: Product State & Pallet Code
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.black, width: 0.8),
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            productStatusAr,
                            style: pw.TextStyle(
                              fontSize: 11 * scaleFactor,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
                            ),
                          ),
                          pw.Text(
                            productStatusEn,
                            style: pw.TextStyle(
                              fontSize: 7.5 * scaleFactor,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(2),
                        border: pw.Border.all(color: PdfColors.grey600, width: 0.6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'رمز الطبلية المرجعي:',
                            style: pw.TextStyle(fontSize: 6.5 * scaleFactor, color: PdfColors.grey800),
                          ),
                          pw.Text(
                            pallet.palletCode,
                            style: pw.TextStyle(
                              fontSize: 9.5 * scaleFactor,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.black,
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

          pw.Divider(thickness: 1.0, color: PdfColors.black, height: 3),

          // 3. Bottom Table: 3 Wide Columns utilizing all empty space
          // (الوزن الصافي | الوزن القائم | عدد الصناديق)
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.black, width: 1),
            children: [
              // Header Row
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        'الوزن الصافي',
                        style: pw.TextStyle(fontSize: 8 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        'الوزن القائم',
                        style: pw.TextStyle(fontSize: 8 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        'عدد الصناديق',
                        style: pw.TextStyle(fontSize: 8 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              // Values Row
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        '${pallet.netWeight.toStringAsFixed(1)} كغ',
                        style: pw.TextStyle(fontSize: 10 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        '${pallet.grossWeight.toStringAsFixed(1)} كغ',
                        style: pw.TextStyle(fontSize: 10 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                    child: pw.Center(
                      child: pw.Text(
                        '${pallet.boxCount} صندوق',
                        style: pw.TextStyle(fontSize: 10 * scaleFactor, fontWeight: pw.FontWeight.bold),
                      ),
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

  // --- Other Document Types (Sorting, Delivery, Field Boxes) ---

  static Future<Uint8List> generateSortingResultsPdf({
    required SortingBatchModel batch,
    required bool isAuto,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(batch.createdAt);
    final docRef = 'SORT-${batch.id.substring(0, 6)}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              _buildOfficialWatermark(logoBytes),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildOfficialHeader(
                    logoBytes: logoBytes,
                    docTitle: isAuto ? 'تقرير نتائج الفرز الآلي والمحصول' : 'تقرير نتائج الفرز الأولي',
                    dateStr: dateStr,
                    docRef: docRef,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      isAuto ? 'تقرير نتائج الفرز الآلي وتصنيف الجودة' : 'تقرير نتائج الفرز الأولي اليدوي',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('العميل:', batch.customerName ?? 'عميل تمور علي'),
                            _buildPdfInfoField('المزرعة:', batch.farmName ?? 'المزرعة الرئيسية'),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('الوزن الأصلي المدخل:', '${batch.inputWeight.toStringAsFixed(1)} كغ'),
                            _buildPdfInfoField('إجمالي الإنتاج المفرز:', '${batch.outputWeight.toStringAsFixed(1)} كغ'),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('الفاقد / التالف:', '${batch.wasteWeight.toStringAsFixed(1)} كغ (${((batch.wasteWeight / (batch.inputWeight > 0 ? batch.inputWeight : 1)) * 100).toStringAsFixed(1)}%)'),
                            _buildPdfInfoField('نوع الفرز:', isAuto ? 'فرز آلي حديث' : 'فرز أولي يدوي'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('تفصيل مخرجات الفرز والأصناف:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A'))),
                  pw.SizedBox(height: 6),
                  if (isAuto)
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromHex('E2E8F0')),
                          children: [
                            _buildTableHeaderCell('#'),
                            _buildTableHeaderCell('رمز الطبلية'),
                            _buildTableHeaderCell('التصنيف'),
                            _buildTableHeaderCell('الحجم'),
                            _buildTableHeaderCell('عدد الصناديق'),
                            _buildTableHeaderCell('الوزن الإجمالي'),
                          ],
                        ),
                        ...batch.outputPallets.asMap().entries.map((entry) {
                          final i = entry.key + 1;
                          final item = entry.value;
                          return pw.TableRow(
                            children: [
                              _buildTableCell('$i'),
                              _buildTableCell(item.palletCode),
                              _buildTableCell(item.category),
                              _buildTableCell(item.size),
                              _buildTableCell('${item.boxCount} صندوق'),
                              _buildTableCell('${item.weight.toStringAsFixed(1)} كغ', isBold: true),
                            ],
                          );
                        }),
                      ],
                    ),
                  pw.Spacer(),
                  if (signatureBytes != null)
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Column(
                        children: [
                          pw.Text('توقيع مسؤول الفرز:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Image(pw.MemoryImage(signatureBytes), height: 40),
                        ],
                      ),
                    ),
                  _buildOfficialFooter(pageNum: 1, totalPages: 1, title: 'تقرير نتائج الفرز - تمور علي'),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateDeliveryReceiptPdf({
    required ShipmentModel shipment,
    required List<PalletModel> pallets,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(shipment.createdAt);
    final totalWeight = pallets.fold<double>(0.0, (sum, p) => sum + p.netWeight);
    final docRef = 'DEL-${shipment.plateNumber.replaceAll(' ', '')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              _buildOfficialWatermark(logoBytes),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildOfficialHeader(
                    logoBytes: logoBytes,
                    docTitle: 'سند تسليم وإخراج بضاعة رسمي',
                    dateStr: dateStr,
                    docRef: docRef,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'سند تسليم وإخراج بضاعة رسمي',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('العميل المستلم:', shipment.customerName ?? 'عميل تمور علي'),
                            _buildPdfInfoField('السائق المستلم:', shipment.driverName),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('رقم المركبة:', shipment.plateNumber),
                            _buildPdfInfoField('إجمالي الوزن المسلم:', '${totalWeight.toStringAsFixed(1)} كغ'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text('تفاصيل الطبالي المسلمة:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A'))),
                  pw.SizedBox(height: 6),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColor.fromHex('CBD5E1'), width: 0.5),
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: PdfColor.fromHex('E2E8F0')),
                        children: [
                          _buildTableHeaderCell('#'),
                          _buildTableHeaderCell('رمز الطبلية'),
                          _buildTableHeaderCell('التصنيف'),
                          _buildTableHeaderCell('الحجم'),
                          _buildTableHeaderCell('الوزن المسلم'),
                        ],
                      ),
                      ...pallets.asMap().entries.map((entry) {
                        final i = entry.key + 1;
                        final p = entry.value;
                        return pw.TableRow(
                          children: [
                            _buildTableCell('$i'),
                            _buildTableCell(p.palletCode),
                            _buildTableCell(p.category ?? 'مفروز آلي'),
                            _buildTableCell(p.size ?? 'مشكل'),
                            _buildTableCell('${p.netWeight.toStringAsFixed(1)} كغ', isBold: true),
                          ],
                        );
                      }),
                    ],
                  ),
                  pw.Spacer(),
                  if (signatureBytes != null)
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Column(
                        children: [
                          pw.Text('توقيع المستلم:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Image(pw.MemoryImage(signatureBytes), height: 40),
                        ],
                      ),
                    ),
                  _buildOfficialFooter(pageNum: 1, totalPages: 1, title: 'سند تسليم تمور - تمور علي'),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> generateFieldBoxesReceiptPdf({
    required ShipmentModel shipment,
    required int boxCount,
    int damaged = 0,
    int lost = 0,
    int rentalDays = 0,
    double rentalPrice = 0.0,
    Uint8List? signatureBytes,
  }) async {
    final pdf = pw.Document();
    final theme = await _getArabicTheme();
    final logoBytes = await _loadLogoBytes();

    final dateStr = DateFormat('yyyy/MM/dd - HH:mm').format(shipment.createdAt);
    final totalJod = boxCount * rentalPrice;
    final docRef = 'BOX-${shipment.plateNumber.replaceAll(' ', '')}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              _buildOfficialWatermark(logoBytes),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildOfficialHeader(
                    logoBytes: logoBytes,
                    docTitle: 'سند حركة صناديق حقل وإيجار',
                    dateStr: dateStr,
                    docRef: docRef,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Center(
                    child: pw.Text(
                      'سند حركة صناديق حقل وإيجار',
                      style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('013D5A')),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('F8FAFC'),
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColor.fromHex('CBD5E1')),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('العميل:', shipment.customerName ?? ''),
                            _buildPdfInfoField('السائق:', shipment.driverName),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfInfoField('عدد الصناديق:', '$boxCount'),
                            _buildPdfInfoField('التالف:', '$damaged'),
                          ],
                        ),
                        if (rentalPrice > 0) ...[
                          pw.SizedBox(height: 6),
                          pw.Row(
                            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                            children: [
                              _buildPdfInfoField('سعر الإيجار:', '$rentalPrice د.أ'),
                              _buildPdfInfoField('إجمالي المبلغ:', '${totalJod.toStringAsFixed(2)} د.أ'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Spacer(),
                  if (signatureBytes != null)
                    pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Column(
                        children: [
                          pw.Text('توقيع المستلم:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 4),
                          pw.Image(pw.MemoryImage(signatureBytes), height: 40),
                        ],
                      ),
                    ),
                  _buildOfficialFooter(pageNum: 1, totalPages: 1, title: 'سند صناديق حقل - تمور علي'),
                ],
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // --- Shared Cell Widgets ---

  static pw.Widget _buildPdfInfoField(String label, String value) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(color: PdfColors.grey700, fontSize: 9.5),
        ),
        pw.SizedBox(width: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9.5, color: PdfColors.black),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColor.fromHex('013D5A')),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      ),
    );
  }

  // --- Aliases for Backward Compatibility ---

  static Future<Uint8List> generateSortingReportPdf({
    required SortingBatchModel batch,
    bool isAuto = false,
    Uint8List? signatureBytes,
  }) =>
      generateSortingResultsPdf(
        batch: batch,
        isAuto: isAuto || (batch.outputPallets.isNotEmpty),
        signatureBytes: signatureBytes,
      );

  static Future<Uint8List> generateDeliveryNotePdf({
    required ShipmentModel shipment,
    required List<PalletModel> pallets,
    Uint8List? signatureBytes,
  }) =>
      generateDeliveryReceiptPdf(
        shipment: shipment,
        pallets: pallets,
        signatureBytes: signatureBytes,
      );
}
