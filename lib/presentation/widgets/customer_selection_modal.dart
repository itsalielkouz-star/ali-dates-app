import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/supabase_service.dart';

/// Full-featured Searchable Customer Selection Modal
class CustomerSelectionModal extends StatefulWidget {
  final UserProfile? currentlySelected;
  final ValueChanged<UserProfile> onSelected;

  const CustomerSelectionModal({
    super.key,
    this.currentlySelected,
    required this.onSelected,
  });

  /// Static helper to show the modal as a full-height bottom sheet or dialog
  static Future<UserProfile?> show(
    BuildContext context, {
    UserProfile? currentlySelected,
  }) async {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CustomerSelectionModal(
        currentlySelected: currentlySelected,
        onSelected: (user) {
          Navigator.of(ctx).pop(user);
        },
      ),
    );
  }

  @override
  State<CustomerSelectionModal> createState() => _CustomerSelectionModalState();
}

class _CustomerSelectionModalState extends State<CustomerSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  List<UserProfile> _allCustomers = [];
  List<UserProfile> _filteredCustomers = [];
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSyncOdoo() async {
    setState(() => _isSyncing = true);
    await SupabaseService().syncWithOdoo(force: true);
    if (mounted) {
      setState(() {
        _loadCustomers();
        _filterCustomers();
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحديث قائمة العملاء (${_allCustomers.length} عميل) من Odoo ERP'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _loadCustomers() {
    _allCustomers = SupabaseService().getCustomerContacts();
    _filteredCustomers = List.from(_allCustomers);
  }

  void _filterCustomers() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredCustomers = List.from(_allCustomers));
      return;
    }

    final queryDigits = PhoneUtils.cleanDigits(query);

    setState(() {
      final list = _allCustomers.where((c) {
        final nameMatch = c.name.toLowerCase().contains(query);
        final phoneMatch = queryDigits.isNotEmpty &&
            PhoneUtils.cleanDigits(c.phone).contains(queryDigits);
        return nameMatch || phoneMatch;
      }).toList();

      list.sort((a, b) {
        final aIsJo = PhoneUtils.isJordanian(a.phone);
        final bIsJo = PhoneUtils.isJordanian(b.phone);
        if (aIsJo && !bIsJo) return -1;
        if (!aIsJo && bIsJo) return 1;

        final aScore = SupabaseService().getCustomerActivityScore(a.id);
        final bScore = SupabaseService().getCustomerActivityScore(b.id);
        if (aScore != bScore) {
          return bScore.compareTo(aScore);
        }

        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      _filteredCustomers = list;
    });
  }

  void _openAddCustomerDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: AppColors.navy, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'إضافة عميل جديد',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم العميل / المزرعة *',
                    hintText: 'مثال: مزرعة النخيل الذهبي',
                    prefixIcon: Icon(Icons.business_rounded),
                  ),
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'يرجى إدخال اسم العميل' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف *',
                    hintText: 'مثال: 0791234567 أو +962791234567',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? 'يرجى إدخال رقم الهاتف' : null,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final newCust = await SupabaseService().addNewCustomerContact(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                          );
                          if (mounted) {
                            Navigator.of(ctx).pop();
                            setState(() {
                              _loadCustomers();
                              _filterCustomers();
                            });
                            widget.onSelected(newCust);
                          }
                        },
                        child: const Text('حفظ واختيار'),
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.85;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.people_alt_rounded, color: AppColors.navy, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'اختيار العميل / المزرعة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.navyUltraLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_allCustomers.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Spacer(),
                // Odoo Sync Button
                IconButton(
                  tooltip: 'مزامنة فورية مع Odoo ERP',
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
                        )
                      : const Icon(Icons.sync_rounded, color: AppColors.navy),
                  onPressed: _isSyncing ? null : _handleSyncOdoo,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Search Bar & Add Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Search Field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو رقم الهاتف...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: AppColors.navyUltraLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // (+) Add Customer Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _openAddCustomerDialog,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Customer List
          Expanded(
            child: _filteredCustomers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'لا توجد نتائج بحث مطابقة لـ "${_searchController.text}"',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _openAddCustomerDialog,
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('إضافة عميل جديد بهذا الاسم'),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _filteredCustomers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 60),
                    itemBuilder: (context, index) {
                      final customer = _filteredCustomers[index];
                      final isSelected = widget.currentlySelected?.id == customer.id ||
                          widget.currentlySelected?.phone == customer.phone;

                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        selected: isSelected,
                        selectedTileColor: AppColors.navyLight.withAlpha(80),
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? AppColors.navy : AppColors.navyUltraLight,
                          child: Text(
                            customer.name.isNotEmpty ? customer.name.substring(0, 1) : 'ع',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.navy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          customer.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? AppColors.navy : Colors.black87,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Row(
                          children: [
                            if (PhoneUtils.isJordanian(customer.phone)) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.shade200, width: 0.5),
                                ),
                                child: const Text(
                                  'أردني',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              customer.phone.startsWith('odoo_no_phone')
                                  ? 'جهة اتصال من Odoo'
                                  : PhoneUtils.toDisplay(customer.phone),
                              textDirection: customer.phone.startsWith('odoo_no_phone')
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? AppColors.navy : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.navy)
                            : const Icon(Icons.chevron_left_rounded, color: AppColors.border),
                        onTap: () => widget.onSelected(customer),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// A clean Customer Picker Selector Card widget that triggers the CustomerSelectionModal
class CustomerPickerCard extends StatelessWidget {
  final UserProfile? selectedCustomer;
  final ValueChanged<UserProfile> onCustomerChanged;
  final VoidCallback? onAddFarm;
  final String label;

  const CustomerPickerCard({
    super.key,
    required this.selectedCustomer,
    required this.onCustomerChanged,
    this.onAddFarm,
    this.label = 'العميل المستلم / المزرعة',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final picked = await CustomerSelectionModal.show(
            context,
            currentlySelected: selectedCustomer,
          );
          if (picked != null) {
            onCustomerChanged(picked);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, color: AppColors.navy, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navyUltraLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_rounded, size: 14, color: AppColors.navy),
                        SizedBox(width: 4),
                        Text(
                          'بحث وتغيير',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedCustomer != null) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.navyLight,
                      child: Text(
                        selectedCustomer!.name.isNotEmpty
                            ? selectedCustomer!.name.substring(0, 1)
                            : 'ع',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedCustomer!.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            selectedCustomer!.phone.startsWith('odoo_no_phone')
                                ? 'جهة اتصال مسجلة في Odoo'
                                : PhoneUtils.toDisplay(selectedCustomer!.phone),
                            textDirection: selectedCustomer!.phone.startsWith('odoo_no_phone')
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.border),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Icon(Icons.touch_app_rounded, color: Colors.grey.shade400, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'اضغط هنا للبحث واختيار العميل...',
                      style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
