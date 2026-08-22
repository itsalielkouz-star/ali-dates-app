import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Live Batch Tracker Visual Stepper for Customer App
/// Steps:
/// 1. Received (استلام)
/// 2. Cold Storage (في الثلاجة/الفريزر)
/// 3. Pre-Sorting (فرز أولي)
/// 4. Auto-Sorting (فرز آلي)
/// 5. Ready for Pickup (جاهز للتسليم)
/// 6. Delivered (تم التسليم)
class LiveBatchStepper extends StatefulWidget {
  final int currentStep; // 1 to 6
  final bool isPulsing; // If batch is currently actively being worked on

  const LiveBatchStepper({
    super.key,
    required this.currentStep,
    this.isPulsing = false,
  });

  @override
  State<LiveBatchStepper> createState() => _LiveBatchStepperState();
}

class _LiveBatchStepperState extends State<LiveBatchStepper>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  static const List<Map<String, dynamic>> _steps = [
    {'title': 'استلام', 'icon': Icons.move_to_inbox_rounded},
    {'title': 'في الثلاجة', 'icon': Icons.ac_unit_rounded},
    {'title': 'فرز أولي', 'icon': Icons.filter_alt_rounded},
    {'title': 'فرز آلي', 'icon': Icons.precision_manufacturing_rounded},
    {'title': 'جاهز للتسليم', 'icon': Icons.check_circle_outline_rounded},
    {'title': 'تم التسليم', 'icon': Icons.local_shipping_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timeline_rounded, color: AppColors.navy, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'مسار تتبع الشحنة والفرز المباشر',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.navy,
                    ),
                  ),
                ],
              ),
              if (widget.isPulsing)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.navyUltraLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.navy.withAlpha(50)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.autorenew_rounded,
                              size: 12, color: AppColors.navy),
                          SizedBox(width: 4),
                          Text(
                            'جاري العمل الآن',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Horizontal Visual Steps Timeline
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_steps.length, (index) {
                final stepNum = index + 1;
                final isCompleted = stepNum < widget.currentStep;
                final isCurrent = stepNum == widget.currentStep;
                final isFuture = stepNum > widget.currentStep;

                return Row(
                  children: [
                    _buildStepNode(
                      stepNum: stepNum,
                      title: _steps[index]['title'],
                      icon: _steps[index]['icon'],
                      isCompleted: isCompleted,
                      isCurrent: isCurrent,
                      isFuture: isFuture,
                    ),
                    if (index < _steps.length - 1)
                      Container(
                        width: 24,
                        height: 3,
                        color: isCompleted
                            ? AppColors.navy
                            : AppColors.border,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode({
    required int stepNum,
    required String title,
    required IconData icon,
    required bool isCompleted,
    required bool isCurrent,
    required bool isFuture,
  }) {
    Color circleColor = AppColors.border;
    Color iconColor = AppColors.textMuted;
    Color textColor = AppColors.textMuted;

    if (isCompleted) {
      circleColor = AppColors.navy;
      iconColor = Colors.white;
      textColor = AppColors.navy;
    } else if (isCurrent) {
      circleColor = AppColors.navy;
      iconColor = Colors.white;
      textColor = AppColors.navy;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrent ? AppColors.navy : circleColor,
                border: isCurrent
                    ? Border.all(
                        color: Colors.white,
                        width: 2.5 + (_pulseController.value * 1.5),
                      )
                    : null,
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: AppColors.navy.withAlpha(80),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : icon,
                color: iconColor,
                size: 20,
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 60,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  isCurrent || isCompleted ? FontWeight.bold : FontWeight.normal,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
