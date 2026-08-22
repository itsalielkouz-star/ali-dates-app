import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/supabase_service.dart';

/// Customer Inventory Tab (المخزون الحالي وتفصيل الأصناف والأحجام)
class CustomerInventoryTab extends StatelessWidget {
  final UserProfile customer;

  const CustomerInventoryTab({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final customerPallets = service.pallets
        .where((p) =>
            p.customerId == customer.id &&
            p.status != 'delivered' &&
            p.status != 'consumed')
        .toList();

    // Group inventory dynamically from actual pallets
    final Map<String, Map<String, double>> inventoryData = {};
    for (var p in customerPallets) {
      final sizeName = p.size ?? 'عام';
      final catName = p.category ?? 'مفروز';
      inventoryData.putIfAbsent(sizeName, () => {});
      inventoryData[sizeName]![catName] =
          (inventoryData[sizeName]![catName] ?? 0.0) + p.netWeight;
    }

    final totalInventoryWeight = customerPallets.fold<double>(
      0.0,
      (s, p) => s + p.netWeight,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Total Owned Inventory Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'إجمالي رصيد التمور الجاهزة بالمستودع:',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalInventoryWeight.toStringAsFixed(1)} كـغ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ما يعادل ${(totalInventoryWeight / 5).toInt()} صندوق (5 كغ)',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'تفصيل المخزون حسب الحجم والتصنيف:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.navy,
            ),
          ),
          if (inventoryData.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'لا يوجد رصيد تمور مفروزة بالمستودع حالياً',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'سيظهر هنا تفصيل رصيدك فور فرز وتجهيز الطبالي',
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else
            ...inventoryData.entries.map((sizeEntry) {
            final sizeName = sizeEntry.key;
            final categories = sizeEntry.value;
            final sizeTotalWeight =
                categories.values.fold<double>(0.0, (s, w) => s + w);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.navyUltraLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.star_rounded, color: AppColors.navy, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'الحجم: $sizeName',
                              style: const TextStyle(
                                fontSize: 16,
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
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'المجموع: ${sizeTotalWeight.toStringAsFixed(0)} كغ (${(sizeTotalWeight / 5).toInt()} صندوق)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.entries.map((catEntry) {
                        final catName = catEntry.key;
                        final weight = catEntry.value;
                        final boxCount = (weight / 5).toInt();

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    catName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.navy,
                                    ),
                                  ),
                                  Text(
                                    '$weight كغ ($boxCount صندوق)',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
