import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/image_compressor.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/shipment_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/customer_selection_modal.dart';
import 'delivery_dates_screen.dart';
import 'delivery_boxes_screen.dart';

/// Delivery Step 1 & Truck Information Screen (تسليم - الخطوة 1)
class DeliveryStep1Screen extends StatefulWidget {
  const DeliveryStep1Screen({super.key});

  @override
  State<DeliveryStep1Screen> createState() => _DeliveryStep1ScreenState();
}

class _DeliveryStep1ScreenState extends State<DeliveryStep1Screen> {
  final _formKey = GlobalKey<FormState>();
  UserProfile? _selectedCustomer;
  FarmModel? _selectedFarm;
  String _cargoType = 'dates'; // 'dates' vs 'boxes'

  final _driverNameController = TextEditingController();
  final _agentNameController = TextEditingController();
  final _plateNumberController = TextEditingController();

  Uint8List? _truckPhotoBytes;
  Uint8List? _licensePhotoBytes;
  bool _isProcessingLicense = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final customers = SupabaseService().getCustomerContacts();
    if (customers.isNotEmpty) {
      _selectedCustomer = customers.first;
      final farms = SupabaseService().getFarmsForCustomer(_selectedCustomer!.id);
      if (farms.isNotEmpty) _selectedFarm = farms.first;
    }
  }

  @override
  void dispose() {
    _driverNameController.dispose();
    _agentNameController.dispose();
    _plateNumberController.dispose();
    super.dispose();
  }

  void _openAddCustomerModal() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: AppColors.navy),
                    SizedBox(width: 8),
                    Text(
                      'إضافة عميل / جهة اتصال جديدة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / المزرعة *',
                    hintText: 'مثال: مزرعة النخيل الذهبي',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف *',
                    hintText: 'مثال: 0791234567 أو +962791234567',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'رقم الهاتف مطلوب' : null,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final newCust = await SupabaseService().addNewCustomerContact(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                          );
                          if (mounted) {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _selectedCustomer = newCust;
                              _selectedFarm = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تمت إضافة العميل "${newCust.name}" بنجاح'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Text('حفظ العميل'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAddFarmModal() {
    if (_selectedCustomer == null) return;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    String selectedGov = AppConstants.jordanGovernorates.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'إضافة مزرعة (المنطقة)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'اسم المزرعة *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedGov,
                      decoration: const InputDecoration(labelText: 'المنطقة / المحافظة *'),
                      items: AppConstants.jordanGovernorates
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setModalState(() => selectedGov = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(labelText: 'كود المزرعة (اختياري)'),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final f = await SupabaseService().addNewFarm(
                          customerId: _selectedCustomer!.id,
                          name: nameController.text.trim(),
                          governorate: selectedGov,
                          code: codeController.text.trim().isNotEmpty
                              ? codeController.text.trim()
                              : null,
                        );
                        if (mounted) {
                          Navigator.of(ctx).pop();
                          setState(() => _selectedFarm = f);
                        }
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickTruckPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1024, imageQuality: 70);
      if (image != null) {
        final raw = await image.readAsBytes();
        final compressed = await ImageCompressor.compressImage(raw);
        if (mounted) setState(() => _truckPhotoBytes = compressed);
      }
    } catch (_) {}
  }

  Future<void> _pickLicensePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
      if (image != null) {
        setState(() => _isProcessingLicense = true);
        final raw = await image.readAsBytes();
        final processed = await ImageCompressor.autoDetectAndCropLicense(raw);
        if (mounted) {
          setState(() {
            _licensePhotoBytes = processed;
            _isProcessingLicense = false;
          });
        }
      }
    } catch (_) {
      setState(() => _isProcessingLicense = false);
    }
  }

  void _onSaveAndProceed() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار العميل المستلم')),
      );
      return;
    }

    final shipment = ShipmentModel(
      id: 'ship_out_${DateTime.now().millisecondsSinceEpoch}',
      direction: 'outbound',
      cargoType: _cargoType,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      farmId: _selectedFarm?.id,
      farmName: _selectedFarm?.name,
      driverName: _driverNameController.text.trim(),
      agentName: _agentNameController.text.trim(),
      plateNumber: _plateNumberController.text.trim(),
      truckPhotoUrl: _truckPhotoBytes != null ? ImageCompressor.bytesToBase64(_truckPhotoBytes!) : null,
      licensePhotoUrl: _licensePhotoBytes != null ? ImageCompressor.bytesToBase64(_licensePhotoBytes!) : null,
    );

    if (_cargoType == 'dates') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryDatesScreen(
            customer: _selectedCustomer!,
            farm: _selectedFarm,
            shipment: shipment,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DeliveryBoxesScreen(
            customer: _selectedCustomer!,
            farm: _selectedFarm,
            shipment: shipment,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final customers = service.getCustomerContacts();
    final farms = _selectedCustomer != null
        ? service.getFarmsForCustomer(_selectedCustomer!.id)
        : <FarmModel>[];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'تسليم بضاعة للعميل',
        subtitle: 'الخطوة 1: اختيار العميل وبيانات شاحنة الاستلام',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Customer Selection Area (العميل)
              CustomerPickerCard(
                selectedCustomer: _selectedCustomer,
                label: 'العميل المستلم / صاحب الطلب',
                onCustomerChanged: (val) {
                  setState(() {
                    _selectedCustomer = val;
                    final fList = service.getFarmsForCustomer(val.id);
                    _selectedFarm = fList.isNotEmpty ? fList.first : null;
                  });
                },
              ),

              const SizedBox(height: 12),

              // 2. Farm Dropdown + (+) Modal
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<FarmModel>(
                          value: _selectedFarm,
                          decoration: const InputDecoration(labelText: 'المزرعة (المنطقة)'),
                          isExpanded: true,
                          items: farms.map((f) {
                            return DropdownMenuItem(
                              value: f,
                              child: Text('${f.name} (${f.governorate})', overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedFarm = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _openAddFarmModal,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Slider: تمور vs صناديق حقل (Mandatory)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نوع التسليم (إجباري)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _cargoType = 'dates'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _cargoType == 'dates' ? AppColors.navy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'تمور مفرزة',
                                      style: TextStyle(
                                        color: _cargoType == 'dates' ? Colors.white : AppColors.navy,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () => setState(() => _cargoType = 'boxes'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _cargoType == 'boxes' ? AppColors.navy : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'صناديق حقل',
                                      style: TextStyle(
                                        color: _cargoType == 'boxes' ? Colors.white : AppColors.navy,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 4. Truck & Driver Fields
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'معلومات شاحنة التحميل والسائق',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                      ),
                      const SizedBox(height: 14),

                      // Driver Name (اسم السائق - put earlier before ID)
                      TextFormField(
                        controller: _driverNameController,
                        decoration: const InputDecoration(labelText: 'اسم السائق المستلم *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      // Farm Agent Name (اسم وكيل المزارع)
                      TextFormField(
                        controller: _agentNameController,
                        decoration: const InputDecoration(labelText: 'اسم وكيل المزارع أو المستلم *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),

                      // License Plate Number (رقم النمرة)
                      TextFormField(
                        controller: _plateNumberController,
                        decoration: const InputDecoration(labelText: 'رقم النمرة / اللوحة *'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 16),

                      // Photos (صورة الحمولة + صورة الرخصة)
                      Row(
                        children: [
                          Expanded(
                            child: _buildPhotoBox(
                              title: 'صورة الحمولة',
                              bytes: _truckPhotoBytes,
                              icon: Icons.local_shipping_rounded,
                              onTap: _pickTruckPhoto,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPhotoBox(
                              title: 'صورة الرخصة',
                              subtitle: 'قص حواف تلقائي',
                              bytes: _licensePhotoBytes,
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

              const SizedBox(height: 24),

              // Save & Proceed Button (حفظ - Big & Clear)
              ElevatedButton.icon(
                icon: const Icon(Icons.save_rounded, color: AppColors.dateGold),
                label: const Text(
                  'حـفـظ ومتابعة التسليم',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _onSaveAndProceed,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoBox({
    required String title,
    String? subtitle,
    Uint8List? bytes,
    bool isLoading = false,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bytes != null ? AppColors.navy : AppColors.border),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(bytes, fit: BoxFit.cover),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: AppColors.navy, size: 24),
                      const SizedBox(height: 4),
                      Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      if (subtitle != null)
                        Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.dateBronze)),
                    ],
                  ),
      ),
    );
  }
}
