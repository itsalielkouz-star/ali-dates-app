import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/customer_selection_modal.dart';
import 'receiving_truck_screen.dart';

/// Receiving Step 1 Screen (استلام - الخطوة 1)
/// - Customer Selection (العميل)
/// - Farm Dropdown + (+) Add Farm Modal
/// - Slider: تمور vs صناديق حقل (Mandatory)
/// - Next Button (التالي ->)
class ReceivingStep1Screen extends StatefulWidget {
  const ReceivingStep1Screen({super.key});

  @override
  State<ReceivingStep1Screen> createState() => _ReceivingStep1ScreenState();
}

class _ReceivingStep1ScreenState extends State<ReceivingStep1Screen> {
  UserProfile? _selectedCustomer;
  FarmModel? _selectedFarm;
  String _cargoType = 'dates'; // 'dates' (تمور) vs 'boxes' (صناديق حقل)

  @override
  void initState() {
    super.initState();
    // Do NOT preselect customer automatically so user chooses fresh each time
    _selectedCustomer = null;
    _selectedFarm = null;
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
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار العميل أولاً')),
      );
      return;
    }

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
                    const Row(
                      children: [
                        Icon(Icons.add_location_alt_rounded, color: AppColors.navy),
                        SizedBox(width: 8),
                        Text(
                          'إضافة مزرعة جديدة للعميل',
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
                        labelText: 'اسم المزرعة *',
                        hintText: 'مثال: مزرعة النخيل الذهبي 2',
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedGov,
                      decoration: const InputDecoration(labelText: 'المحافظة / المنطقة *'),
                      items: AppConstants.jordanGovernorates
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedGov = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: codeController,
                      decoration: const InputDecoration(
                        labelText: 'كود المزرعة (اختياري)',
                        hintText: 'مثال: F-JOR-09',
                      ),
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
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final newFarm = await SupabaseService().addNewFarm(
                                customerId: _selectedCustomer!.id,
                                name: nameController.text.trim(),
                                governorate: selectedGov,
                                code: codeController.text.trim().isNotEmpty
                                    ? codeController.text.trim()
                                    : null,
                              );
                              if (mounted) {
                                Navigator.of(ctx).pop();
                                setState(() {
                                  _selectedFarm = newFarm;
                                });
                              }
                            },
                            child: const Text('حفظ المزرعة'),
                          ),
                        ),
                      ],
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

  void _onNext() {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد العميل')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceivingTruckScreen(
          customer: _selectedCustomer!,
          farm: _selectedFarm,
          cargoType: _cargoType,
        ),
      ),
    );
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
        title: 'استلام جديد',
        subtitle: 'الخطوة 1: اختيار العميل ونوع الشحنة',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Facility Header Banner (Arabic bigger than English)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.navy.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Column(
                  children: [
                    Text(
                      'مركز فرز التمور الآلي',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Ali Dates - Automated Sorting Facility',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dateGold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 1. Customer Selection Area (العميل)
            CustomerPickerCard(
              selectedCustomer: _selectedCustomer,
              label: 'العميل المورد / المزرعة',
              onCustomerChanged: (val) {
                setState(() {
                  _selectedCustomer = val;
                  final fList = service.getFarmsForCustomer(val.id);
                  _selectedFarm = fList.isNotEmpty ? fList.first : null;
                });
              },
            ),

            const SizedBox(height: 14),

            // 2. Farm Selection Area with (+) Button
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.nature_rounded, color: AppColors.navy),
                            SizedBox(width: 8),
                            Text(
                              'المزرعة التابعة للعميل',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                          ],
                        ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add_rounded, size: 22),
                          tooltip: 'إضافة مزرعة جديدة',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.navyUltraLight,
                            foregroundColor: AppColors.navy,
                          ),
                          onPressed: _openAddFarmModal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (farms.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.warning),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'لا توجد مزارع مسجلة لهذا العميل. اضغط (+) لإضافة مزرعة.',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: _openAddFarmModal,
                              child: const Text('إضافة الآن'),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<FarmModel>(
                        value: _selectedFarm,
                        decoration: const InputDecoration(
                          labelText: 'اختر المزرعة',
                          prefixIcon: Icon(Icons.landscape_rounded),
                        ),
                        isExpanded: true,
                        items: farms.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Text(
                              '${f.name} - ${f.governorate} ${f.code != null ? "(${f.code})" : ""}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedFarm = val);
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // 3. Mandatory Slider between "تمور" and "صناديق حقل"
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.category_rounded, color: AppColors.navy),
                        SizedBox(width: 8),
                        Text(
                          'نوع الشحنة المستلمة (إجباري)',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.navyUltraLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _cargoType = 'dates'),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _cargoType == 'dates'
                                      ? AppColors.navy
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _cargoType == 'dates'
                                      ? [
                                          BoxShadow(
                                            color: AppColors.navy.withAlpha(50),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.eco_rounded,
                                        color: _cargoType == 'dates'
                                            ? AppColors.dateGold
                                            : AppColors.navy,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'تمور',
                                        style: TextStyle(
                                          color: _cargoType == 'dates'
                                              ? Colors.white
                                              : AppColors.navy,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _cargoType = 'boxes'),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: _cargoType == 'boxes'
                                      ? AppColors.navy
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: _cargoType == 'boxes'
                                      ? [
                                          BoxShadow(
                                            color: AppColors.navy.withAlpha(50),
                                            blurRadius: 6,
                                          )
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.all_inbox_rounded,
                                        color: _cargoType == 'boxes'
                                            ? AppColors.dateGold
                                            : AppColors.navy,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'صناديق حقل',
                                        style: TextStyle(
                                          color: _cargoType == 'boxes'
                                              ? Colors.white
                                              : AppColors.navy,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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

            const SizedBox(height: 28),

            // Next Arrow Button (التالي ->)
            ElevatedButton(
              onPressed: _onNext,
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
                  Text(
                    'التالي (معلومات الشحنة)',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_back_rounded, size: 20), // RTL Arrow Forward
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
