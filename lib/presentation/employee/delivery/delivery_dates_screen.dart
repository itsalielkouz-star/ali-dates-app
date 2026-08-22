import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/shipment_model.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/models/document_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/signature_dialog.dart';
import '../../widgets/qr_camera_scanner_dialog.dart';
import '../employee_home_screen.dart';

/// Delivery Auto-Sorted Dates Screen (تسليم التمور المفرزة والمسح)
class DeliveryDatesScreen extends StatefulWidget {
  final UserProfile customer;
  final FarmModel? farm;
  final ShipmentModel shipment;

  const DeliveryDatesScreen({
    super.key,
    required this.customer,
    this.farm,
    required this.shipment,
  });

  @override
  State<DeliveryDatesScreen> createState() => _DeliveryDatesScreenState();
}

class _DeliveryDatesScreenState extends State<DeliveryDatesScreen> {
  final Set<String> _scannedPalletIds = {};

  void _simulateQrScanForPallet(PalletModel pallet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_scanner_rounded, color: AppColors.navy),
            const SizedBox(width: 8),
            Text('مسح طبلية: ${pallet.palletCode}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تم التحقق ومطابقة رمز الطبلية بنجاح بنظام الباركود.'),
            const SizedBox(height: 10),
            Text('الصنف: ${pallet.category ?? "مفروز آلي"} | الحجم: ${pallet.size ?? "عام"}'),
            Text('الوزن: ${pallet.netWeight} كغ | الموقع: ${pallet.displayLocation}'),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('تسليم هذه الطبلية'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _scannedPalletIds.add(pallet.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت إضافة الطبلية (${pallet.palletCode}) لقائمة التسليم'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleFinishDelivery() async {
    if (_scannedPalletIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى مسح واختيار طبلية واحدة على الأقل للتسليم')),
      );
      return;
    }

    // Confirmation Alert (هل أنت متأكد من إنهاء التسليم؟)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: AppColors.navy),
            SizedBox(width: 8),
            Text('تأكيد إنهاء التسليم'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من تسليم ${_scannedPalletIds.length} طبلية للعميل (${widget.customer.name})؟',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، تأكيد وتوقيع السند'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Digital Signature Pad
    final signatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع سند تسليم البضاعة',
      signerRole: 'السائق المستلم / موظف المصنع',
    );

    if (signatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع السند لإنهاء التسليم')),
      );
      return;
    }

    final allPallets = SupabaseService().pallets;
    final deliveredList = allPallets.where((p) => _scannedPalletIds.contains(p.id)).toList();

    // 2. Deliver in Database
    await SupabaseService().deliverPallets(
      palletIds: _scannedPalletIds.toList(),
      shipment: widget.shipment,
    );

    // 3. Generate PDF Delivery Note
    final pdfBytes = await PdfGenerator.generateDeliveryNotePdf(
      shipment: widget.shipment,
      pallets: deliveredList,
      signatureBytes: signatureBytes,
    );

    // 4. Save to Customer Archive
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanPlate = widget.shipment.plateNumber.replaceAll(' ', '_').replaceAll('-', '_');
    final docModel = DocumentModel(
      id: 'doc_del_${widget.shipment.id}_$timestamp',
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      shipmentId: widget.shipment.id,
      docType: 'delivery_note',
      title: 'سند تسليم وإخراج بضاعة رسمي - (${widget.shipment.plateNumber})',
      fileName: 'سند_تسليم_بضاعة_${cleanPlate}_$timestamp.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    // 5. Layout PDF & Return Home
    if (mounted) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docModel.fileName,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    // Get auto-sorted pallets owned by this customer
    final availablePallets = service.pallets
        .where((p) =>
            p.customerId == widget.customer.id &&
            p.status != 'delivered' &&
            p.status != 'consumed')
        .toList();

    final totalDeliveredWeight = availablePallets
        .where((p) => _scannedPalletIds.contains(p.id))
        .fold<double>(0.0, (s, p) => s + p.netWeight);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'تسليم التمور المفرزة',
        subtitle: 'العميل: ${widget.customer.name}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions & Live Camera Scan Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.navy.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, color: AppColors.navy),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'امسح رمز QR بالكاميرا أو اختر طبلية من القائمة أدناه لتسليمها',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy),
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 16),
                    label: const Text('فتح الكاميرا', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    onPressed: () {
                      QrCameraScannerDialog.show(
                        context,
                        onPalletScanned: (p) {
                          setState(() {
                            _scannedPalletIds.add(p.id);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة الطبلية (${p.palletCode}) لقائمة التسليم'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Summary of Scanned Pallets
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('الطبالي المحددة للتسليم', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          '${_scannedPalletIds.length} من ${availablePallets.length}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 30, color: AppColors.border),
                    Column(
                      children: [
                        const Text('إجمالي الوزن المسلم', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(
                          '${totalDeliveredWeight.toStringAsFixed(1)} كغ',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Pallets List
            Text(
              'طبالي التمور الجاهزة للتسليم بالمستودع (${availablePallets.length}):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
            ),
            const SizedBox(height: 8),

            if (availablePallets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text('لا توجد طبالي جاهزة للتسليم حالياً لهذا العميل', style: TextStyle(color: AppColors.textMuted)),
                ),
              )
            else
              ...availablePallets.map((pallet) {
                final isDeliveredChecked = _scannedPalletIds.contains(pallet.id);
                return Card(
                  elevation: isDeliveredChecked ? 3 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isDeliveredChecked ? AppColors.success : AppColors.border,
                      width: isDeliveredChecked ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isDeliveredChecked ? AppColors.successLight : AppColors.navyUltraLight,
                      child: Icon(
                        isDeliveredChecked ? Icons.check_circle_rounded : Icons.inventory_2_rounded,
                        color: isDeliveredChecked ? AppColors.success : AppColors.navy,
                      ),
                    ),
                    title: Text(
                      '${pallet.palletCode} - ${pallet.category ?? "مفروز"} (${pallet.size ?? "عام"})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: Text('الوزن: ${pallet.netWeight} كغ | ${pallet.displayLocation}'),
                    trailing: isDeliveredChecked
                        ? TextButton.icon(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.error, size: 18),
                            label: const Text('إلغاء', style: TextStyle(color: AppColors.error)),
                            onPressed: () {
                              setState(() {
                                _scannedPalletIds.remove(pallet.id);
                              });
                            },
                          )
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                            label: const Text('مسح وتسليم', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () => _simulateQrScanForPallet(pallet),
                          ),
                  ),
                );
              }),

            const SizedBox(height: 24),

            // Finish Delivery Button (إنهاء التسليم)
            ElevatedButton.icon(
              icon: const Icon(Icons.verified_rounded, color: AppColors.dateGold, size: 22),
              label: const Text(
                'إنهاء التسليم وتوليد السند PDF',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _handleFinishDelivery,
            ),
          ],
        ),
      ),
    );
  }
}
