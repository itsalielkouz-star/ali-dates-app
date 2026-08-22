import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/pallet_model.dart';

/// Pallet Card Component for List & Grid Views
class PalletCard extends StatelessWidget {
  final PalletModel pallet;
  final VoidCallback? onTap;
  final VoidCallback? onPrintLabel;
  final VoidCallback? onMove;
  final bool isSelected;

  const PalletCard({
    super.key,
    required this.pallet,
    this.onTap,
    this.onPrintLabel,
    this.onMove,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppColors.navy : AppColors.border,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Pallet Code & Status Badge
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
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: AppColors.navy,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pallet.palletCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusBadge(pallet.status),
                ],
              ),
              const Divider(height: 18),

              // Owner & Farm
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pallet.customerName ?? 'العميل',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (pallet.farmName != null && pallet.farmName!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Text(
                        pallet.farmName!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // Metrics Row: Net Weight, Boxes, Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildMetric(
                    'الوزن الصافي',
                    '${pallet.netWeight.toStringAsFixed(1)} كغ',
                    AppColors.navy,
                  ),
                  _buildMetric(
                    'عدد الصناديق',
                    '${pallet.boxCount} صندوق',
                    AppColors.textSecondary,
                  ),
                  _buildMetric(
                    'الموقع',
                    pallet.displayLocation,
                    AppColors.dateBronze,
                  ),
                ],
              ),

              if (pallet.category != null || pallet.size != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.navyUltraLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AppColors.navy),
                      const SizedBox(width: 4),
                      Text(
                        'الصنف: ${pallet.category ?? "عام"} | الحجم: ${pallet.size ?? "مشكل"}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Action Buttons
              if (onPrintLabel != null || onMove != null) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onPrintLabel != null)
                      IconButton(
                        icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
                        tooltip: 'طباعة رمز الطبلية QR',
                        onPressed: onPrintLabel,
                      ),
                    if (onMove != null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.local_shipping_rounded, size: 16),
                        label: const Text('نقل الطبلية', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onMove,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    String text = 'مستلم';
    Color bg = AppColors.infoLight;
    Color fg = AppColors.info;

    switch (status) {
      case 'received':
        text = 'مستلم جديد';
        bg = AppColors.infoLight;
        fg = AppColors.info;
        break;
      case 'stored':
        text = 'في المستودع';
        bg = AppColors.navyUltraLight;
        fg = AppColors.navy;
        break;
      case 'in_sorting':
      case 'in_presort':
      case 'in_autosort':
        text = 'جاري الفرز ⏳';
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'sorted':
        text = 'جاهز للتسليم ✨';
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'delivered':
        text = 'تم التسليم';
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade700;
        break;
      case 'consumed':
        text = 'تم تفكيكها للفرز';
        bg = Colors.purple.shade50;
        fg = Colors.purple.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }
}
