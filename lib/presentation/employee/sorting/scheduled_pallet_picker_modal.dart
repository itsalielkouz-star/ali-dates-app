import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/sorting_batch_model.dart';
import '../../../data/services/supabase_service.dart';

/// Modal Calendar Dialog to pick scheduled pallets for sorting line
/// - Displays count badge of scheduled pallets on each calendar day
/// - Lists pallets scheduled for the selected day
/// - Allows multi-selection to transfer to the active sorting line screen
/// - Shows warning alert if picking future dates
/// - Shows warning alert if mixing different customers
class ScheduledPalletPickerModal extends StatefulWidget {
  final String sortingType; // 'presort' vs 'autosort'
  final List<String> currentCustomerIdsOnScreen;
  final Function(List<SortingBatchModel> selectedBatches) onBatchesAdded;

  const ScheduledPalletPickerModal({
    super.key,
    required this.sortingType,
    required this.currentCustomerIdsOnScreen,
    required this.onBatchesAdded,
  });

  static Future<void> show(
    BuildContext context, {
    required String sortingType,
    required List<String> currentCustomerIdsOnScreen,
    required Function(List<SortingBatchModel> selectedBatches) onBatchesAdded,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ScheduledPalletPickerModal(
        sortingType: sortingType,
        currentCustomerIdsOnScreen: currentCustomerIdsOnScreen,
        onBatchesAdded: onBatchesAdded,
      ),
    );
  }

  @override
  State<ScheduledPalletPickerModal> createState() => _ScheduledPalletPickerModalState();
}

class _ScheduledPalletPickerModalState extends State<ScheduledPalletPickerModal> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  final Set<String> _selectedBatchIds = {};

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final isAuto = widget.sortingType == 'autosort';
    final lineTheme = isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315);
    final lineSoftBg = isAuto ? const Color(0xFFE3F2FD) : const Color(0xFFFFE0B2);
    final lineDarkText = isAuto ? const Color(0xFF0D47A1) : const Color(0xFFBF360C);

    // Get all in_progress/planned batches for this sorting line
    final allLineBatches = service.sortingBatches.where((b) {
      return b.sortingType == widget.sortingType && b.status == 'in_progress';
    }).toList();

    // Map of scheduled date -> count of pallets
    final Map<String, List<SortingBatchModel>> dateToBatches = {};
    for (var b in allLineBatches) {
      final date = b.scheduledDate ?? b.createdAt;
      final key = '${date.year}-${date.month}-${date.day}';
      dateToBatches.putIfAbsent(key, () => []).add(b);
    }

    final selectedKey = '${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}';
    final batchesForSelectedDate = dateToBatches[selectedKey] ?? [];

    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final monthName = DateFormat('MMMM yyyy', 'ar').format(_focusedMonth);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: lineSoftBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.calendar_month_rounded, color: lineTheme, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuto ? 'جدول طبالي الفرز الآلي' : 'جدول مشغل الفرز الأولي (طاقة 30 طن/يوم)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                      ),
                      Text(
                        isAuto
                            ? 'اختر اليوم واضغط على الطبالي لإضافتها لشاشة خط الفرز'
                            : 'طاقة المشغل: 30 طن يومياً | اختر الطبالي للفرز',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Month Navigator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
                    tooltip: 'الشهر السابق',
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                      });
                    },
                  ),
                  Text(
                    monthName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                    tooltip: 'الشهر التالي',
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Mini Calendar with Counts on Each Day
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.25,
              ),
              itemCount: daysInMonth,
              itemBuilder: (ctx, index) {
                final day = index + 1;
                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                final cellKey = '${cellDate.year}-${cellDate.month}-${cellDate.day}';
                final count = (dateToBatches[cellKey] ?? []).length;
                final isSelected = _selectedDate.year == cellDate.year &&
                    _selectedDate.month == cellDate.month &&
                    _selectedDate.day == cellDate.day;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDate = cellDate;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? lineTheme
                          : (count > 0 ? lineSoftBg : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? lineTheme
                            : (count > 0 ? lineTheme.withAlpha(90) : Colors.grey.shade300),
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : (count > 0 ? lineDarkText : AppColors.textSecondary),
                          ),
                        ),
                        // Number of scheduled pallets on this day
                        if (count > 0)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.white : lineTheme,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? lineTheme : Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const Divider(height: 16),

            // Day Pallets List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طبالي يوم ${DateFormat('dd/MM/yyyy').format(_selectedDate)} (${batchesForSelectedDate.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                ),
                if (batchesForSelectedDate.isNotEmpty)
                  Text(
                    'محدد: ${_selectedBatchIds.length}',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: lineTheme),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Scrollable List of Batches for selected Date
            Expanded(
              child: batchesForSelectedDate.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, color: Colors.grey.shade400, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            'لا توجد طبالي مجدولة في هذا اليوم (${DateFormat('yyyy/MM/dd').format(_selectedDate)})',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: batchesForSelectedDate.length,
                      itemBuilder: (ctx, idx) {
                        final batch = batchesForSelectedDate[idx];
                        final isChecked = _selectedBatchIds.contains(batch.id);

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isChecked ? lineTheme : AppColors.border,
                              width: isChecked ? 2 : 1,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isChecked,
                            activeColor: lineTheme,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedBatchIds.add(batch.id);
                                } else {
                                  _selectedBatchIds.remove(batch.id);
                                }
                              });
                            },
                            title: Text(
                              'طبلية: ${batch.sourcePalletCode ?? batch.sourcePalletId}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('العميل: ${batch.customerName ?? "غير محدد"}', style: const TextStyle(fontSize: 12)),
                                Text(
                                  'الموقع: ${batch.sourcePalletLocation ?? "المستودع"} | الوزن: ${batch.inputWeight} كغ',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 10),

            // Confirm Add Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: lineTheme,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_task_rounded, color: Colors.white),
              label: Text(
                'إضافة الطبالي المحددة (${_selectedBatchIds.length}) إلى خط الفرز',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              onPressed: _selectedBatchIds.isEmpty
                  ? null
                  : () => _handleConfirmAdd(allLineBatches),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirmAdd(List<SortingBatchModel> allBatches) async {
    final chosenBatches = allBatches.where((b) => _selectedBatchIds.contains(b.id)).toList();
    if (chosenBatches.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isFuture = chosenBatches.any((b) {
      final d = b.scheduledDate ?? b.createdAt;
      final bDate = DateTime(d.year, d.month, d.day);
      return bDate.isAfter(today);
    });

    // Check mixed customers
    final customerIds = <String>{...widget.currentCustomerIdsOnScreen};
    for (var b in chosenBatches) {
      customerIds.add(b.customerId);
    }
    final isMixedCustomers = customerIds.length > 1;

    // 1. Future Date Alert Check
    if (isFuture) {
      final bool? proceedFuture = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.alarm_on_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text('تنبيه موعد مستقبلي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
            ],
          ),
          content: const Text(
            'لقد اخترت طبالي مجدولة بتاريخ مستقبلي.\nهل تريد إدخالها وبدء فرزها اليوم على الخط؟',
            style: TextStyle(fontSize: 13, color: AppColors.navyDark),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('متابعة وإضافة'),
            ),
          ],
        ),
      );
      if (proceedFuture != true) return;
    }

    // 2. Mixed Customers Alert Check
    if (isMixedCustomers) {
      final bool? proceedMix = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: const Row(
            children: [
              Icon(Icons.people_alt_rounded, color: AppColors.warning, size: 22),
              SizedBox(width: 8),
              Text('تنبيه خلط عملاء مختلفين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
            ],
          ),
          content: const Text(
            'الطبالي المختارة تعود لأكثر من عميل مختلف على نفس الشاشة.\nهل أنت متأكد من رغبتك بفرز طبالي عملاء متعددين معاً؟',
            style: TextStyle(fontSize: 13, color: AppColors.navyDark),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، متابعة الخلط'),
            ),
          ],
        ),
      );
      if (proceedMix != true) return;
    }

    // For Pre-Sort: Merge selected batches of the same customer into a unified multi-pallet sorting batch (Many-to-Many)
    List<SortingBatchModel> finalBatchesToAdd = [];
    if (widget.sortingType == 'presort' && chosenBatches.length > 1 && !isMixedCustomers) {
      final first = chosenBatches.first;
      final allIds = chosenBatches.expand((b) => b.sourcePalletIds).toSet().toList();
      final allCodes = chosenBatches.expand((b) => b.sourcePalletCodes).toSet().toList();
      final totalInputWeight = chosenBatches.fold<double>(0.0, (sum, b) => sum + b.inputWeight);
      final allOutputs = chosenBatches.expand((b) => b.outputPallets).toList();

      final mergedBatch = SortingBatchModel(
        id: first.id,
        batchNumber: first.batchNumber,
        sourcePalletId: first.sourcePalletId,
        sourcePalletCode: allCodes.join(' + '),
        sourcePalletIds: allIds,
        sourcePalletCodes: allCodes,
        sourcePalletLocation: first.sourcePalletLocation,
        customerId: first.customerId,
        customerName: first.customerName,
        farmId: first.farmId,
        farmName: first.farmName,
        sortingType: 'presort',
        scheduledDate: first.scheduledDate,
        inputWeight: totalInputWeight,
        outputPallets: allOutputs,
        status: 'in_progress',
      );
      finalBatchesToAdd = [mergedBatch];
    } else {
      finalBatchesToAdd = chosenBatches;
    }

    widget.onBatchesAdded(finalBatchesToAdd);
    Navigator.of(context).pop();
  }
}
