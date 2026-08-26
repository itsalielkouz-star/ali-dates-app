import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/qr_helper.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/shipment_model.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/models/document_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/signature_dialog.dart';
import '../../widgets/pallet_sticker_widget.dart';
import '../employee_home_screen.dart';

/// Receiving Weighing Screen (شاشة التوزين وحساب الوزن الصافي)
class ReceivingWeighingScreen extends StatefulWidget {
  final UserProfile customer;
  final FarmModel? farm;
  final ShipmentModel shipment;
  final bool isPresorted;

  const ReceivingWeighingScreen({
    super.key,
    required this.customer,
    this.farm,
    required this.shipment,
    required this.isPresorted,
  });

  @override
  State<ReceivingWeighingScreen> createState() => _ReceivingWeighingScreenState();
}

class _ReceivingWeighingScreenState extends State<ReceivingWeighingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers with Defaults
  final _emptyPalletWeightController = TextEditingController(text: '16.0'); // Max 30kg, Def 16
  final _emptyBoxWeightController = TextEditingController(text: '0.95'); // Max 1.5kg, Def 0.95
  final _boxCountController = TextEditingController(text: '200'); // Max 250, Def 200
  final _grossWeightController = TextEditingController(text: '1050.0'); // Max 1200kg

  String _selectedLocation = AppConstants.locPreFridge; // Default: Small pre fridge (ثلاجة التعقيم)
  final List<PalletModel> _registeredPallets = [];
  double _calculatedTareWeight = 844.0; // Auto-calculated view only

  @override
  void initState() {
    super.initState();
    _recalculateTare();
  }

  @override
  void dispose() {
    _emptyPalletWeightController.dispose();
    _emptyBoxWeightController.dispose();
    _boxCountController.dispose();
    _grossWeightController.dispose();
    super.dispose();
  }

  void _recalculateTare() {
    final palletEmpty = double.tryParse(_emptyPalletWeightController.text) ?? 16.0;
    final boxEmpty = double.tryParse(_emptyBoxWeightController.text) ?? 0.95;
    final boxes = int.tryParse(_boxCountController.text) ?? 200;
    final gross = double.tryParse(_grossWeightController.text) ?? 0.0;

    final net = PalletModel.calculateTareWeight(
      gross: gross,
      palletEmpty: palletEmpty,
      boxEmpty: boxEmpty,
      boxes: boxes,
    );

    setState(() {
      _calculatedTareWeight = net;
    });
  }

  void _onRegisterNextPallet() {
    if (!_formKey.currentState!.validate()) return;

    final palletEmpty = double.tryParse(_emptyPalletWeightController.text) ?? 16.0;
    final boxEmpty = double.tryParse(_emptyBoxWeightController.text) ?? 0.95;
    final boxes = int.tryParse(_boxCountController.text) ?? 200;
    final gross = double.tryParse(_grossWeightController.text) ?? 0.0;

    final palletCode = QrHelper.generateNewPalletCode();

    final newPallet = PalletModel(
      id: palletCode,
      palletCode: palletCode,
      shipmentId: widget.shipment.id,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      farmId: widget.farm?.id,
      farmName: widget.farm?.name,
      emptyPalletWeight: palletEmpty,
      emptyBoxWeight: boxEmpty,
      boxCount: boxes,
      grossWeight: gross,
      netWeight: _calculatedTareWeight,
      locationType: _selectedLocation,
      isPresorted: widget.isPresorted,
      status: 'received',
    );

    setState(() {
      _registeredPallets.insert(0, newPallet);
      // Reset gross weight for next pallet input
      _grossWeightController.text = '1000.0';
      _recalculateTare();
    });

    // Save in Supabase Service
    SupabaseService().addReceivedPallet(newPallet);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تسجيل الطبلية ($palletCode) بنجاح - الوزن الصافي: ${_calculatedTareWeight.toStringAsFixed(1)} كغ'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPrintLabelDialog(PalletModel pallet) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.qr_code_2_rounded, color: AppColors.navy, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'معاينة ملصق الطبلية (QR Label)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: PalletStickerWidget(pallet: pallet),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: AppColors.navy),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, color: AppColors.navy),
                      label: const Text('حراري مفرد', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
                        final pdfBytes = await PdfGenerator.generatePalletBarcodeLabelPdf(pallet);
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdfBytes,
                          name: 'ملصق_طبلية_${pallet.palletCode}_$ts.pdf',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.grid_view_rounded, color: Colors.white),
                      label: const Text('4 نسخ على A4', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final ts = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
                        final pdfBytes = await PdfGenerator.generatePalletStickersSheetA4Pdf(pallet);
                        await Printing.layoutPdf(
                          onLayout: (PdfPageFormat format) async => pdfBytes,
                          name: 'ملصقات_طبلية_A4_${pallet.palletCode}_$ts.pdf',
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onFinishReceiving() async {
    if (_registeredPallets.isEmpty) {
      // Auto-register current pallet if list is empty
      _onRegisterNextPallet();
    }

    if (_registeredPallets.isEmpty) return;

    // 1. Digital Signature for Ali Dates Receiving Officer
    final employeeSignatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع موظف الاستلام',
      signerRole: 'مسؤول استلام تمور علي',
    );

    if (employeeSignatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع موظف الاستلام لإتمام السند')),
      );
      return;
    }

    // 2. Digital Signature for Driver / Customer Representative
    final driverSignatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع السائق / المندوب',
      signerRole: 'اسم وتوقيع السائق أو وكيل العميل',
    );

    if (driverSignatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع السائق أو المندوب لإتمام السند')),
      );
      return;
    }

    // 3. Generate Arabic PDF Receiving Receipt with Dual Signatures & Attachments
    final pdfBytes = await PdfGenerator.generateReceivingReceiptPdf(
      shipment: widget.shipment,
      pallets: _registeredPallets,
      employeeSignatureBytes: employeeSignatureBytes,
      driverSignatureBytes: driverSignatureBytes,
    );

    // 3. Save Document in Supabase and Customer Portal
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanPlate = widget.shipment.plateNumber.replaceAll(' ', '_').replaceAll('-', '_');
    final docModel = DocumentModel(
      id: 'doc_rec_${widget.shipment.id}_$timestamp',
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      shipmentId: widget.shipment.id,
      docType: 'receiving_receipt',
      title: 'سند استلام شحنة تمور رسمية - (${widget.shipment.plateNumber})',
      fileName: 'سند_استلام_شحنة_${cleanPlate}_$timestamp.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    // 4. Check if receiving is for a Harvest Supervisor and Notify Admins with Full Breakdown
    final service = SupabaseService();
    final harvestOpIdx = service.pickingOperations.indexWhere(
      (o) => o.laborTeamLeaderName.trim().toLowerCase() == widget.customer.name.trim().toLowerCase() ||
             o.supervisorName.trim().toLowerCase() == widget.customer.name.trim().toLowerCase() ||
             o.customerId == widget.customer.id,
    );

    final totalBoxesHarvested = _registeredPallets.fold<int>(0, (sum, p) => sum + p.boxCount);
    final totalNetKg = _registeredPallets.fold<double>(0.0, (sum, p) => sum + p.netWeight);
    final palletCount = _registeredPallets.length;

    String harvestDurationText = 'غير محدد';
    if (harvestOpIdx != -1) {
      final hOp = service.pickingOperations[harvestOpIdx];
      harvestDurationText = hOp.formattedDuration;
      // Advance picking operation to weighed/received
      await service.advancePickingLifecycle(
        operationId: hOp.id,
        newStatus: 'returned_to_facility',
      );
    }

    // Send Detailed Admin Notification
    NotificationService().showCustomerStatusNotification(
      id: widget.shipment.id.hashCode,
      title: '📦 وصول واستلام محصول الحصاد في المصنع',
      body: 'قام ${widget.customer.name} بتسليم المحصول: $totalBoxesHarvested صندوق على $palletCount طبالي (صافي: ${totalNetKg.toStringAsFixed(1)} كغ) - مدة العمل: $harvestDurationText.',
    );

    // 4. Preview / Download & Print PDF
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل استلام الشحنة (${widget.shipment.plateNumber}) بنجاح وإصدار السند الرسمي',
          ),
          backgroundColor: AppColors.success,
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docModel.fileName,
      );

      // Return to Employee Home Screen
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'التوزين واستلام الطبالي',
        subtitle: 'العميل: ${widget.customer.name}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Registered Pallets List (Shows pallets above with weights as requested)
              if (_registeredPallets.isNotEmpty) ...[
                Card(
                  color: AppColors.navyUltraLight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الطبالي المسجلة في هذه الشحنة (${_registeredPallets.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'إجمالي الصافي: ${_registeredPallets.fold<double>(0.0, (s, p) => s + p.netWeight).toStringAsFixed(1)} كغ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._registeredPallets.map((p) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
                                    const SizedBox(width: 6),
                                    Text(p.palletCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text('(${p.boxCount} صندوق)', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('${p.netWeight} كغ صافي', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                                    IconButton(
                                      icon: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.navy),
                                      onPressed: () => _showPrintLabelDialog(p),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Weighing Form Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'بيانات وزن الطبلية الحالية',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Location Dropdown (Default: Small pre fridge ثلاجة التعقيم)
                      DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        decoration: const InputDecoration(
                          labelText: 'الثلاجة / الفريزر المستهدف *',
                          prefixIcon: Icon(Icons.ac_unit_rounded, color: AppColors.navy),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: AppConstants.locPreFridge,
                            child: Text(AppConstants.locationNamesAr[AppConstants.locPreFridge]! + ' (افتراضي)'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.locFirstFridge,
                            child: Text(AppConstants.locationNamesAr[AppConstants.locFirstFridge]!),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.locMainFreezer1,
                            child: Text(AppConstants.locationNamesAr[AppConstants.locMainFreezer1]!),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.locMainFreezer2,
                            child: Text(AppConstants.locationNamesAr[AppConstants.locMainFreezer2]!),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.locSmallFreezer,
                            child: Text(AppConstants.locationNamesAr[AppConstants.locSmallFreezer]!),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLocation = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Row 1: Empty Pallet Weight (Max 30, Def 16) & Box Count (Max 250, Def 200)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emptyPalletWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'وزن الطبلية ف (كغ) *',
                                hintText: '16.0 (أقصى 30)',
                                suffixText: 'كغ',
                              ),
                              onChanged: (_) => _recalculateTare(),
                              validator: (val) {
                                final d = double.tryParse(val ?? '');
                                if (d == null || d <= 0 || d > AppConstants.maxEmptyPalletWeight) {
                                  return 'بين 1 و 30 كغ';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _boxCountController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'عدد الصناديق *',
                                hintText: '200 (أقصى 250)',
                                suffixText: 'صندوق',
                              ),
                              onChanged: (_) => _recalculateTare(),
                              validator: (val) {
                                final i = int.tryParse(val ?? '');
                                if (i == null || i <= 0 || i > AppConstants.maxBoxCount) {
                                  return 'بين 1 و 250';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: Empty Box Weight (Max 1.5kg, Def 0.95) & Gross Weight (Max 1200kg)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _emptyBoxWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'وزن الصندوق ف (كغ) *',
                                hintText: '0.95 (أقصى 1.5)',
                                suffixText: 'كغ',
                              ),
                              onChanged: (_) => _recalculateTare(),
                              validator: (val) {
                                final d = double.tryParse(val ?? '');
                                if (d == null || d <= 0 || d > AppConstants.maxEmptyBoxWeight) {
                                  return 'بين 0.1 و 1.5';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _grossWeightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'الوزن الإجمالي *',
                                hintText: 'طبلية + صناديق + تمر',
                                suffixText: 'كغ',
                              ),
                              onChanged: (_) => _recalculateTare(),
                              validator: (val) {
                                final d = double.tryParse(val ?? '');
                                if (d == null || d <= 0 || d > AppConstants.maxGrossWeight) {
                                  return 'أقصى 1200 كغ';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Tare / Net Weight Calculation Box (View Only - Auto-calculated)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.navy.withAlpha(50),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الوزن الصافي (للقراءة فقط):',
                                  style: TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  'إجمالي - (طبلية ف + صناديق ف)',
                                  style: TextStyle(color: AppColors.dateGold, fontSize: 10),
                                ),
                              ],
                            ),
                            Text(
                              '${_calculatedTareWeight.toStringAsFixed(1)} كـغ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // The 3 Action Buttons (Same Size Icons with Finish under as requested)
              Row(
                children: [
                  // Button 1: (+) الطبلية التالية
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                      label: const Text('+ الطبلية التالية', style: TextStyle(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E88E5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _onRegisterNextPallet,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Button 2: (QR) طباعة رمز الطبلية
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                      label: const Text('طباعة رمز الطبلية', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.navy,
                        side: const BorderSide(color: AppColors.navy, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (_registeredPallets.isNotEmpty) {
                          _showPrintLabelDialog(_registeredPallets.first);
                        } else {
                          _onRegisterNextPallet();
                        }
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Button 3: إنهاء عملية الإستلام (Underneath)
              ElevatedButton.icon(
                icon: const Icon(Icons.verified_rounded, color: AppColors.dateGold, size: 24),
                label: const Text(
                  'إنهاء عملية الإستلام وتوليد السند PDF',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _onFinishReceiving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
