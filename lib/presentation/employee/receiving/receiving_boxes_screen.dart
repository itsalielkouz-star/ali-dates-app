import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/shipment_model.dart';
import '../../../data/models/document_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/signature_dialog.dart';
import '../employee_home_screen.dart';

/// Receiving Field Boxes Screen (استلام صناديق حقل)
class ReceivingBoxesScreen extends StatefulWidget {
  final UserProfile customer;
  final FarmModel? farm;
  final ShipmentModel shipment;

  const ReceivingBoxesScreen({
    super.key,
    required this.customer,
    this.farm,
    required this.shipment,
  });

  @override
  State<ReceivingBoxesScreen> createState() => _ReceivingBoxesScreenState();
}

class _ReceivingBoxesScreenState extends State<ReceivingBoxesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _boxCountController = TextEditingController(text: '350');
  final _damagedController = TextEditingController(text: '4');
  final _lostController = TextEditingController(text: '2');
  bool _isLoading = false;

  @override
  void dispose() {
    _boxCountController.dispose();
    _damagedController.dispose();
    _lostController.dispose();
    super.dispose();
  }

  Future<void> _onFinishReceiving() async {
    if (!_formKey.currentState!.validate()) return;

    final boxCount = int.tryParse(_boxCountController.text) ?? 0;
    final damaged = int.tryParse(_damagedController.text) ?? 0;
    final lost = int.tryParse(_lostController.text) ?? 0;

    // 1. Digital Signature Pad for the Worker
    final signatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع استلام صناديق الحقل',
      signerRole: 'موظف استلام تمور علي',
    );

    if (signatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع السند لإنهاء عملية الاستلام')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Record Inbound Field Boxes
    await SupabaseService().recordFieldBoxesInbound(
      shipmentId: widget.shipment.id,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      boxCount: boxCount,
      damaged: damaged,
      lost: lost,
    );

    // 3. Generate Arabic PDF
    final pdfBytes = await PdfGenerator.generateFieldBoxesReceiptPdf(
      shipment: widget.shipment,
      boxCount: boxCount,
      damaged: damaged,
      lost: lost,
      signatureBytes: signatureBytes,
    );

    // 4. Save Document
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanPlate = widget.shipment.plateNumber.replaceAll(' ', '_').replaceAll('-', '_');
    final docModel = DocumentModel(
      id: 'doc_box_${widget.shipment.id}_$timestamp',
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      shipmentId: widget.shipment.id,
      docType: 'boxes_receipt',
      title: 'سند استلام صناديق حقل - (${widget.shipment.plateNumber})',
      fileName: 'سند_استلام_صناديق_حقل_${cleanPlate}_$timestamp.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    setState(() => _isLoading = false);

    // 5. Layout / Download PDF & Return Home
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تسجيل استلام صناديق الحقل للشحنة (${widget.shipment.plateNumber}) بنجاح وإصدار السند الرسمي',
          ),
          backgroundColor: AppColors.success,
        ),
      );

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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'استلام صناديق حقل',
        subtitle: 'العميل: ${widget.customer.name}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.all_inbox_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'بيانات الصناديق المستلمة',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Box Count Field (عدد الصناديق)
                      TextFormField(
                        controller: _boxCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الصناديق الكلي المستلم *',
                          hintText: 'مثال: 350',
                          prefixIcon: Icon(Icons.inbox_rounded),
                        ),
                        validator: (val) {
                          final i = int.tryParse(val ?? '');
                          if (i == null || i <= 0) return 'يرجى إدخال عدد صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Damaged Boxes (التالف)
                      TextFormField(
                        controller: _damagedController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الصناديق التالفة (التالف)',
                          hintText: '0',
                          prefixIcon: Icon(Icons.broken_image_rounded, color: AppColors.warning),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Lost Boxes (مفقود)
                      TextFormField(
                        controller: _lostController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الصناديق المفقودة (مفقود)',
                          hintText: '0',
                          prefixIcon: Icon(Icons.help_outline_rounded, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Finish Button: إنهاء الإستلام
              ElevatedButton.icon(
                icon: const Icon(Icons.verified_rounded, color: AppColors.dateGold),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'إنهاء الإستلام وتوليد السند PDF',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isLoading ? null : _onFinishReceiving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
