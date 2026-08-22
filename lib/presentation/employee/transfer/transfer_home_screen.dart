import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/customer_selection_modal.dart';
import '../../widgets/pallet_card.dart';
import '../../widgets/qr_camera_scanner_dialog.dart';
import 'location_selector_screen.dart';

/// Transfer & Location Management Screen (نقل الطبالي وإدارة المواقع)
class TransferHomeScreen extends StatefulWidget {
  const TransferHomeScreen({super.key});

  @override
  State<TransferHomeScreen> createState() => _TransferHomeScreenState();
}

class _TransferHomeScreenState extends State<TransferHomeScreen> {
  UserProfile? _selectedCustomer;
  FarmModel? _selectedFarm;
  PalletModel? _selectedPallet;

  @override
  void initState() {
    super.initState();
    // Do NOT preselect customer automatically so user chooses fresh each time
    _selectedCustomer = null;
    _selectedFarm = null;
    _selectedPallet = null;
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
                              _selectedPallet = null;
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
                      'إضافة مزرعة للعميل',
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
                      decoration: const InputDecoration(labelText: 'المحافظة / المنطقة *'),
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
                      child: const Text('حفظ المزرعة'),
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

  void _openQrScannerSimulator() {
    QrCameraScannerDialog.show(
      context,
      onPalletScanned: (p) {
        setState(() {
          _selectedPallet = p;
        });
        _showPalletIdentifiedDialog(p);
      },
    );
  }

  void _showPalletIdentifiedDialog(PalletModel p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_rounded, color: AppColors.success, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'تم التعرف على الطبلية: ${p.palletCode}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                  ),
                ],
              ),
              const Divider(height: 20),
              Text('المالك / العميل: ${p.customerName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('الوزن الصافي: ${p.netWeight} كغ | الصناديق: ${p.boxCount}'),
              const SizedBox(height: 4),
              Text('حالة التمر: ${p.isPresorted ? "مفروز أولي" : "خام غير مفروز"}'),
              const SizedBox(height: 4),
              Text('الموقع الحالي: ${p.displayLocation}'),
              if (p.pairedPalletCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.navyUltraLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.dateGold),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: AppColors.dateGold, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'طبلية مطبقة مع: (${p.pairedPalletCode}) - عند النقل سيتم نقلهما معاً كوحدة واحدة',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.alt_route_rounded),
                label: Text(p.pairedPalletCode != null ? 'نقل الطبالي المطبقة معاً' : 'نقل هذه الطبلية الآن'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocationSelectorScreen(pallet: p),
                    ),
                  );
                },
              ),
            ],
          ),
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

    final customerPallets = _selectedCustomer != null
        ? service.getPalletsForCustomerInWarehouse(_selectedCustomer!.id)
        : <PalletModel>[];

    return Scaffold(
      appBar: const CustomAppBar(
        title: 'نقل الطبالي وإدارة المواقع',
        subtitle: 'المستودع، الثلاجات، الفريزر، والجدولة',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Customer Selection Area (العميل)
            CustomerPickerCard(
              selectedCustomer: _selectedCustomer,
              label: 'العميل المودع / صاحب الطبالي',
              onCustomerChanged: (val) {
                setState(() {
                  _selectedCustomer = val;
                  _selectedPallet = null;
                  final fList = service.getFarmsForCustomer(val.id);
                  _selectedFarm = fList.isNotEmpty ? fList.first : null;
                });
              },
            ),

            const SizedBox(height: 12),

            // 2. Farm Selection (Optional) with (+) Modal
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<FarmModel>(
                        value: _selectedFarm,
                        decoration: const InputDecoration(
                          labelText: 'المزرعة (اختياري)',
                          prefixIcon: Icon(Icons.landscape_rounded),
                        ),
                        isExpanded: true,
                        items: farms.map((f) {
                          return DropdownMenuItem(
                            value: f,
                            child: Text('${f.name} (${f.governorate})', overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedFarm = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'إضافة مزرعة',
                      onPressed: _openAddFarmModal,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. Big QR Code Scan Button (Opens Camera/Scanner)
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 28, color: AppColors.dateGold),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Text(
                      'مسح رمز الطبلية بالكاميرا (QR)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'التعرف التلقائي الفوري على بيانات الطبلية وموقعها',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _openQrScannerSimulator,
            ),

            const SizedBox(height: 20),

            // 4. List of Pallets Owned by Selected Customer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طبالي العميل في المستودع (${customerPallets.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                if (_selectedPallet != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('إلغاء التحديد'),
                    onPressed: () => setState(() => _selectedPallet = null),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (customerPallets.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'لا توجد طبالي حالياً لهذا العميل في المستودع',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ...customerPallets.map((p) {
                final isSelected = _selectedPallet?.id == p.id;
                return PalletCard(
                  pallet: p,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedPallet = p;
                    });
                  },
                  onMove: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LocationSelectorScreen(pallet: p),
                      ),
                    );
                  },
                );
              }),

            const SizedBox(height: 24),

            // 5. Big Button at bottom: نقل الطبلية
            if (_selectedPallet != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.alt_route_rounded, color: AppColors.dateGold, size: 24),
                label: Text(
                  'نقل الطبلية (${_selectedPallet!.palletCode})',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LocationSelectorScreen(pallet: _selectedPallet!),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
