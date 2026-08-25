import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_compressor.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/shipment_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import 'receiving_weighing_screen.dart';
import 'receiving_boxes_screen.dart';

/// Receiving Truck & Cargo Info Screen (معلومات الشحنة)
class ReceivingTruckScreen extends StatefulWidget {
  final UserProfile customer;
  final FarmModel? farm;
  final String cargoType; // 'dates' vs 'boxes'

  const ReceivingTruckScreen({
    super.key,
    required this.customer,
    this.farm,
    required this.cargoType,
  });

  @override
  State<ReceivingTruckScreen> createState() => _ReceivingTruckScreenState();
}

class _ReceivingTruckScreenState extends State<ReceivingTruckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _driverNameController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _plateNumberController = TextEditingController();
  bool _isPresorted = false;
  String _boxContractType = ShipmentModel.contractSorting; // تحديد ملكية الصناديق: 1. من عقد فرز, 2. من عقد تسويق, 3. من عقد شراء

  Uint8List? _truckPhotoBytes;
  Uint8List? _licensePhotoBytes;
  bool _isProcessingLicense = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _driverNameController.dispose();
    _agentNameController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickTruckPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 70,
      );
      if (image != null) {
        final raw = await image.readAsBytes();
        final compressed = await ImageCompressor.compressImage(raw);
        if (mounted) {
          setState(() {
            _truckPhotoBytes = compressed;
          });
        }
      }
    } catch (e) {
      debugPrint('Truck photo picker error: $e');
    }
  }

  Future<void> _pickLicensePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
      );
      if (image != null) {
        setState(() => _isProcessingLicense = true);
        final raw = await image.readAsBytes();

        // Auto-Edge Detection & Perspective Crop Filter for Jordanian License (in background with no disruptive popup)
        final processedLicense = await ImageCompressor.autoDetectAndCropLicense(raw);

        if (mounted) {
          setState(() {
            _licensePhotoBytes = processedLicense;
            _isProcessingLicense = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isProcessingLicense = false);
    }
  }

  Future<void> _onSaveAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    final shipment = await SupabaseService().recordInboundShipment(
      cargoType: widget.cargoType,
      customerId: widget.customer.id,
      customerName: widget.customer.name,
      farmId: widget.farm?.id,
      farmName: widget.farm?.name,
      driverName: _driverNameController.text.trim(),
      agentName: _agentNameController.text.trim(),
      plateNumber: _plateNumberController.text.trim(),
      truckPhotoUrl: _truckPhotoBytes != null
          ? ImageCompressor.bytesToBase64(_truckPhotoBytes!)
          : null,
      licensePhotoUrl: _licensePhotoBytes != null
          ? ImageCompressor.bytesToBase64(_licensePhotoBytes!)
          : null,
      isPresorted: _isPresorted,
      boxContractType: _boxContractType,
    );

    if (!mounted) return;

    if (widget.cargoType == 'dates') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceivingWeighingScreen(
            customer: widget.customer,
            farm: widget.farm,
            shipment: shipment,
            isPresorted: _isPresorted,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReceivingBoxesScreen(
            customer: widget.customer,
            farm: widget.farm,
            shipment: shipment,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'معلومات الشحنة والمركبة',
        subtitle: 'الخطوة 2: تسجيل السائق والمركبة',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Customer & Farm Read-Only Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navyUltraLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.navy.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Facility Header (Arabic bigger than English)
                    const Center(
                      child: Column(
                        children: [
                          Text(
                            'مركز فرز التمور الآلي',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Ali Dates - Automated Sorting Facility',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 18),
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'العميل: ${widget.customer.name}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppColors.navy,
                                ),
                              ),
                              if (widget.farm != null)
                                Text(
                                  'المزرعة: ${widget.farm!.name} (${widget.farm!.governorate})',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Box Ownership Contract Type Selector (تحديد ملكية الصناديق عند الاستلام)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.inventory_2_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'تحديد ملكية الصناديق عند الاستلام *',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            _buildContractOption(
                              title: '1. من عقد فرز',
                              value: ShipmentModel.contractSorting,
                              icon: Icons.filter_alt_rounded,
                            ),
                            const SizedBox(width: 4),
                            _buildContractOption(
                              title: '2. من عقد تسويق',
                              value: ShipmentModel.contractMarketing,
                              icon: Icons.storefront_rounded,
                            ),
                            const SizedBox(width: 4),
                            _buildContractOption(
                              title: '3. من عقد شراء',
                              value: ShipmentModel.contractPurchase,
                              icon: Icons.shopping_cart_rounded,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Driver Name Field (Placed early as requested)
              TextFormField(
                controller: _driverNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم السائق *',
                  hintText: 'أدخل الاسم الثلاثي للسائق',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.navy),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'مطلوب إدخال اسم السائق' : null,
              ),

              const SizedBox(height: 14),

              // Farm Agent / Supervisor Name Field
              TextFormField(
                controller: _agentNameController,
                decoration: const InputDecoration(
                  labelText: 'اسم وكيل العميل أو المشرف *',
                  hintText: 'اسم مندوب المزرعة أو الوكيل',
                  prefixIcon: Icon(Icons.supervisor_account_rounded, color: AppColors.navy),
                ),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'مطلوب إدخال اسم وكيل المزرعة'
                    : null,
              ),

              const SizedBox(height: 14),

              // License Plate Number Field
              TextFormField(
                controller: _plateNumberController,
                decoration: const InputDecoration(
                  labelText: 'رقم المركبة / اللوحة *',
                  hintText: 'مثال: 12-94821',
                  prefixIcon: Icon(Icons.pin_rounded, color: AppColors.navy),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'مطلوب رقم اللوحة' : null,
              ),

              const SizedBox(height: 18),

              // Photos Card: Truck Photo & Driver License (Edge-detected)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.camera_alt_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'صور التوثيق (مركبة ورخصة)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Truck Photo
                          Expanded(
                            child: _buildPhotoUploadBox(
                              title: 'صورة المركبة',
                              photoBytes: _truckPhotoBytes,
                              icon: Icons.local_shipping_rounded,
                              onTap: _pickTruckPhoto,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Driver License Photo with Auto-Edge Detection
                          Expanded(
                            child: _buildPhotoUploadBox(
                              title: 'صورة الرخصة',
                              subtitle: 'قص حواف تلقائي',
                              photoBytes: _licensePhotoBytes,
                              isLoading: _isProcessingLicense,
                              icon: Icons.credit_card_rounded,
                              onTap: _pickLicensePhoto,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pre-Sorted Checkbox (مفروز أولي)
              Card(
                child: CheckboxListTile(
                  value: _isPresorted,
                  activeColor: AppColors.navy,
                  title: const Text(
                    'مفروز أولي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: const Text(
                    'حدد هذا الخيار إذا كان التمر تم فرزه أولياً في المزرعة مسبقاً',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  onChanged: (val) {
                    setState(() => _isPresorted = val ?? false);
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Save & Proceed Button (حفظ - Big and Clear)
              ElevatedButton(
                onPressed: _onSaveAndProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: AppColors.dateGold, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'حـفـظ ومتابعة العملية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploadBox({
    required String title,
    String? subtitle,
    Uint8List? photoBytes,
    bool isLoading = false,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 125,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: photoBytes != null ? AppColors.navy : AppColors.border,
            width: photoBytes != null ? 1.8 : 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
                      SizedBox(height: 6),
                      Text('معالجة الحواف...', style: TextStyle(fontSize: 10)),
                    ],
                  ),
                )
              : photoBytes != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          color: const Color(0xFF0F172A),
                          child: Center(
                            child: Image.memory(
                              photoBytes,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: Colors.black.withOpacity(0.65),
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const Positioned(
                          top: 6,
                          left: 6,
                          child: Icon(Icons.check_circle_rounded, color: AppColors.dateGold, size: 20),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: AppColors.navy, size: 28),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            style: const TextStyle(fontSize: 9, color: AppColors.dateBronze),
                          ),
                        const SizedBox(height: 4),
                        const Text('اضغط للتصوير', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildContractOption({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _boxContractType == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _boxContractType = value),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.navy.withOpacity(0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.dateGold : AppColors.navy,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
