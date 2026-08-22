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

/// Delivery Field Boxes Screen (تسليم صناديق حقل وتأجير)
class DeliveryBoxesScreen extends StatefulWidget {
  final UserProfile customer;
  final FarmModel? farm;
  final ShipmentModel shipment;

  const DeliveryBoxesScreen({
    super.key,
    required this.customer,
    this.farm,
    required this.shipment,
  });

  @override
  State<DeliveryBoxesScreen> createState() => _DeliveryBoxesScreenState();
}

class _DeliveryBoxesScreenState extends State<DeliveryBoxesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _boxCountController = TextEditingController(text: '400');
  final _rentalDaysController = TextEditingController(text: '14'); // 14 days
  final _pricePerBoxController = TextEditingController(text: '0.150'); // 0.150 JOD
  bool _isLoading = false;

  @override
  void dispose() {
    _boxCountController.dispose();
    _rentalDaysController.dispose();
    _pricePerBoxController.dispose();
    super.dispose();
  }

  double get _totalRentalJod {
    final boxes = int.tryParse(_boxCountController.text) ?? 0;
    final price = double.tryParse(_pricePerBoxController.text) ?? 0.0;
    return boxes * price;
  }

  Future<void> _handleFinishDelivery() async {
    if (!_formKey.currentState!.validate()) return;

    final boxCount = int.tryParse(_boxCountController.text) ?? 0;
    final rentalDays = int.tryParse(_rentalDaysController.text) ?? 0;
    final rentalPrice = double.tryParse(_pricePerBoxController.text) ?? 0.0;

    // Confirmation Alert
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد تسليم الصناديق'),
        content: Text(
          'هل أنت متأكد من تسليم $boxCount صندوق حقل للعميل (${widget.customer.name}) بإيجار إجمالي (${_totalRentalJod.toStringAsFixed(2)} د.أ)؟',
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، تأكيد وتوقيع'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // 1. Digital Signature Pad
    final signatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع سند تسليم صناديق الحقل',
      signerRole: 'المستلم / موظف المستودع',
    );

    if (signatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع السند لإنهاء التسليم')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 2. Generate PDF
    final pdfBytes = await PdfGenerator.generateFieldBoxesReceiptPdf(
      shipment: widget.shipment,
      boxCount: boxCount,
      rentalDays: rentalDays,
      rentalPrice: rentalPrice,
      signatureBytes: signatureBytes,
    );

    // 3. Save Document
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final cleanPlate = widget.shipment.plateNumber.replaceAll(' ', '_').replaceAll('-', '_');
    final docModel = DocumentModel(
      id: 'doc_box_del_${widget.shipment.id}_$timestamp',
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      shipmentId: widget.shipment.id,
      docType: 'boxes_receipt',
      title: 'سند تسليم صناديق حقل وإيجار - (${widget.shipment.plateNumber})',
      fileName: 'سند_تسليم_صناديق_حقل_${cleanPlate}_$timestamp.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    setState(() => _isLoading = false);

    // 4. Layout PDF & Return Home
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'تسليم صناديق حقل وإيجار',
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
                            'تفاصيل الصناديق والإيجار',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Box Count (عدد الصناديق)
                      TextFormField(
                        controller: _boxCountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'عدد الصناديق المسلمة *',
                          hintText: 'مثال: 400',
                          suffixText: 'صندوق',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final i = int.tryParse(v ?? '');
                          if (i == null || i <= 0) return 'يرجى إدخال عدد صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Rental Duration (مدة الإيجار بالأيام)
                      TextFormField(
                        controller: _rentalDaysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'مدة الإيجار المتفق عليها *',
                          hintText: 'مثال: 14',
                          suffixText: 'يوم',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 14),

                      // Box Rental Price (إيجار الصندوق بالدينار الأردني)
                      TextFormField(
                        controller: _pricePerBoxController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'إيجار الصندوق الواحد (بالدينار الأردني) *',
                          hintText: '0.150',
                          suffixText: 'د.أ',
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) {
                          final d = double.tryParse(v ?? '');
                          if (d == null || d < 0) return 'مطلوب إدخال السعر بالدينار';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // Total Cost Summary
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.navy.withAlpha(40)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('إجمالي قيمة الإيجار المستحقة:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              '${_totalRentalJod.toStringAsFixed(2)} دينار أردني',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Finish Delivery Button
              ElevatedButton.icon(
                icon: const Icon(Icons.verified_rounded, color: AppColors.dateGold),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'إنهاء التسليم وتوليد السند PDF',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _handleFinishDelivery,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
