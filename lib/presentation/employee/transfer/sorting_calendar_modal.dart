import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/services/supabase_service.dart';

/// Interactive Calendar Modal for Booking Sorting Slots
/// Features:
/// - 2 Separate independent schedules for Pre-Sort (فرز أولي) vs Auto-Sort (فرز آلي)
/// - Disables past dates strictly (cannot schedule in the past)
/// - Accurate date-specific bookings (never grey out identical days across other months)
/// - High-contrast readable typography
class SortingCalendarModal extends StatefulWidget {
  final String sortingType; // 'presort' vs 'autosort'
  final void Function(DateTime selectedDate) onDateSelected;

  const SortingCalendarModal({
    super.key,
    required this.sortingType,
    required this.onDateSelected,
  });

  static Future<DateTime?> show(
    BuildContext context, {
    required String sortingType,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => SortingCalendarModal(
        sortingType: sortingType,
        onDateSelected: (d) => Navigator.of(ctx).pop(d),
      ),
    );
  }

  @override
  State<SortingCalendarModal> createState() => _SortingCalendarModalState();
}

class _SortingCalendarModalState extends State<SortingCalendarModal> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateUtils.getDaysInMonth(
      _focusedMonth.year,
      _focusedMonth.month,
    );
    final monthName = DateFormat('MMMM yyyy', 'ar').format(_focusedMonth);
    final isAuto = widget.sortingType == 'autosort';

    // Get exact booked dates for this specific sorting line
    final bookedDates = SupabaseService().getBookedDatesForSorting(widget.sortingType);

    final lineThemeColor = isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315);
    final lineSoftBg = isAuto ? const Color(0xFFE3F2FD) : const Color(0xFFFFE0B2);
    final lineDarkText = isAuto ? const Color(0xFF0D47A1) : const Color(0xFFBF360C);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: lineSoftBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isAuto ? Icons.precision_manufacturing_rounded : Icons.filter_alt_rounded,
                    color: lineThemeColor,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAuto ? 'جدولة خط الفرز الآلي' : 'جدولة مشغل الفرز الأولي (طاقة 30 طن/يوم)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        isAuto
                            ? 'جدول مواعيد مستقل للفرز الآلي'
                            : 'طاقة تشغيلية يومية: 30 طن/يوم (${AppConstants.preSortDailyCapacityKg.toInt()} كغ) للفرز الأولي',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Month Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.navy.withAlpha(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: AppColors.navy),
                    tooltip: 'الشهر السابق',
                    onPressed: () {
                      final prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
                      // Don't navigate before current month
                      if (prevMonth.year < now.year || (prevMonth.year == now.year && prevMonth.month < now.month)) {
                        return;
                      }
                      setState(() {
                        _focusedMonth = prevMonth;
                      });
                    },
                  ),
                  Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: AppColors.navy),
                    tooltip: 'الشهر التالي',
                    onPressed: () {
                      setState(() {
                        _focusedMonth = DateTime(
                          _focusedMonth.year,
                          _focusedMonth.month + 1,
                          1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Calendar Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.1,
              ),
              itemCount: daysInMonth,
              itemBuilder: (context, index) {
                final day = index + 1;
                final cellDate = DateTime(_focusedMonth.year, _focusedMonth.month, day);
                final isPast = cellDate.isBefore(today);
                final isBooked = bookedDates.contains(cellDate);
                final isDisabled = isPast || isBooked;

                final isSelected = _selectedDay != null &&
                    _selectedDay!.year == cellDate.year &&
                    _selectedDay!.month == cellDate.month &&
                    _selectedDay!.day == cellDate.day;

                Color cellBg;
                Color textColor;
                Border? border;

                if (isPast) {
                  cellBg = Colors.grey.shade100;
                  textColor = Colors.grey.shade400;
                  border = Border.all(color: Colors.grey.shade200);
                } else if (isBooked) {
                  cellBg = Colors.grey.shade200;
                  textColor = Colors.grey.shade600;
                  border = Border.all(color: Colors.grey.shade400);
                } else if (isSelected) {
                  cellBg = lineThemeColor;
                  textColor = Colors.white;
                  border = null;
                } else {
                  cellBg = lineSoftBg;
                  textColor = lineDarkText;
                  border = Border.all(color: lineThemeColor.withAlpha(80));
                }

                return InkWell(
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _selectedDay = cellDate;
                          });
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellBg,
                      borderRadius: BorderRadius.circular(8),
                      border: border,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        if (isBooked && !isPast)
                          Positioned(
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade700,
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: const Text(
                                'محجوز',
                                style: TextStyle(fontSize: 6.5, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegendItem(lineThemeColor, 'محدد'),
                _buildLegendItem(lineSoftBg, 'متاح للحجز', textColor: lineDarkText),
                _buildLegendItem(Colors.grey.shade300, 'محجوز / سابق', textColor: Colors.grey.shade700),
              ],
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lineThemeColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _selectedDay == null
                        ? null
                        : () => widget.onDateSelected(_selectedDay!),
                    child: const Text(
                      'تأكيد الموعد',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {Color? textColor}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.black26, width: 0.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor ?? AppColors.navy),
        ),
      ],
    );
  }
}
