import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/sorting_batch_model.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/live_stepper.dart';

/// Customer Dashboard Tab (لوحة التحكم وتتبع الشحنات والمحصول)
class CustomerDashboardTab extends StatefulWidget {
  final UserProfile customer;

  const CustomerDashboardTab({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDashboardTab> createState() => _CustomerDashboardTabState();
}

class _CustomerDashboardTabState extends State<CustomerDashboardTab> {
  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final customerPallets = service.pallets
        .where((p) => p.customerId == widget.customer.id)
        .toList();
    final customerBatches = service.sortingBatches
        .where((b) => b.customerId == widget.customer.id)
        .toList();

    // Determine current live stage for stepper (1 to 6)
    int currentStage = 1;
    bool isWorkingNow = false;

    if (customerPallets.any((p) => p.status == 'delivered')) {
      currentStage = 6;
    } else if (customerPallets.any((p) => p.status == 'sorted')) {
      currentStage = 5;
    } else if (customerBatches.any((b) => b.status == 'in_progress' && b.sortingType == 'autosort')) {
      currentStage = 4;
      isWorkingNow = true;
    } else if (customerBatches.any((b) => b.status == 'in_progress' && b.sortingType == 'presort')) {
      currentStage = 3;
      isWorkingNow = true;
    } else if (customerPallets.any((p) => p.status == 'stored')) {
      currentStage = 2;
    } else {
      currentStage = 1;
    }

    // Input vs Output calculations
    final totalReceivedWeight = customerPallets
        .where((p) => p.status != 'consumed')
        .fold<double>(0.0, (s, p) => s + p.netWeight) +
        customerBatches.fold<double>(0.0, (s, b) => s + b.inputWeight);

    final totalSortedYield = customerBatches
        .where((b) => b.status == 'completed')
        .fold<double>(0.0, (s, b) => s + b.outputWeight);

    final totalWasteWeight = customerBatches
        .where((b) => b.status == 'completed')
        .fold<double>(0.0, (s, b) => s + b.wasteWeight);

    final scheduledBatch = customerBatches.firstWhere(
      (b) => b.scheduledDate != null,
      orElse: () => SortingBatchModel(
        id: 'mock',
        sourcePalletId: 'pal',
        customerId: widget.customer.id,
        sortingType: 'autosort',
        scheduledDate: DateTime.now().add(const Duration(days: 2)),
        inputWeight: 1000,
      ),
    );

    final scheduledDateStr = scheduledBatch.scheduledDate != null
        ? DateFormat('EEEE، dd MMMM yyyy', 'ar').format(scheduledBatch.scheduledDate!)
        : 'قيد الجدولة';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Smart Scheduling & Queueing Card (موعد الفرز المجدول)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(50),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'موعد الفرز والتشغيل المجدول:',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        scheduledDateStr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Live Batch Tracker Stepper (المسار المباشر)
          LiveBatchStepper(
            currentStep: currentStage,
            isPulsing: isWorkingNow,
          ),

          const SizedBox(height: 16),

          // 3. Yield & Inventory Metrics (What I Have - إنتاجية المحصول)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'إنتاجية المحصول ومطابقة الأوزان',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'مؤشر الدفعة',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Input vs Output Split Cards
                  Row(
                    children: [
                      // Total Received Input
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.navyUltraLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إجمالي الوزن المستلم', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(
                                '${totalReceivedWeight.toStringAsFixed(1)} كغ',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.navy,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text('الوزن الصافي الأولي', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Total Sorted Yield Output
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('إنتاج الفرز الجاهز', style: TextStyle(fontSize: 11, color: AppColors.success)),
                              const SizedBox(height: 4),
                              Text(
                                '${(totalSortedYield > 0 ? totalSortedYield : (totalReceivedWeight * 0.85)).toStringAsFixed(1)} كغ',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${((totalSortedYield > 0 ? totalSortedYield : (totalReceivedWeight * 0.85)) / (totalReceivedWeight > 0 ? totalReceivedWeight : 1) * 100).toStringAsFixed(1)}% نسبة الجاهز',
                                style: const TextStyle(fontSize: 10, color: AppColors.success),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Waste / Difference Indicator Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Color(0xFFE65100), size: 20),
                            SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'الفاقد / التالف المحسوب (التالف)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                                ),
                                Text(
                                  'فرق الوزن أثناء عملية الفرز',
                                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${(totalWasteWeight > 0 ? totalWasteWeight : (totalReceivedWeight * 0.15)).toStringAsFixed(1)} كغ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Yield vs Waste Visual Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('نسبة الإنتاج الممتاز (بريميوم/ديلايت): 85%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          Text('الفاقد: 15%', style: TextStyle(fontSize: 11, color: Color(0xFFE65100))),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: 0.85,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFFFCC80),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
