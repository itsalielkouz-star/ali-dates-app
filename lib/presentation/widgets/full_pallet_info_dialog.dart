import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_generator.dart';
import '../../data/models/pallet_model.dart';
import 'package:printing/printing.dart';

/// Full Detailed Pallet Inspector Dialog
/// Triggered instantly when scanning any pallet from the quick scan button
class FullPalletInfoDialog extends StatelessWidget {
  final PalletModel pallet;

  const FullPalletInfoDialog({
    super.key,
    required this.pallet,
  });

  static Future<void> show(BuildContext context, PalletModel pallet) {
    return showDialog(
      context: context,
      builder: (ctx) => FullPalletInfoDialog(pallet: pallet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatted = DateFormat('yyyy/MM/dd HH:mm').format(pallet.createdAt);
    final isPresorted = pallet.isPresorted;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Pallet Code and Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy, size: 28),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pallet.palletCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.navy,
                              fontFamily: 'monospace',
                            ),
                          ),
                          Text(
                            isPresorted ? 'طبلية مفروزة أولياً' : 'طبلية خام غير مفروزة',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isPresorted ? const Color(0xFF0284C7) : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const Divider(height: 24, thickness: 1),

              // Comprehensive Pallet Details Grid
              _buildInfoRow('العميل / المالك:', pallet.customerName, icon: Icons.person_rounded),
              _buildInfoRow('المزرعة والمنطقة:', pallet.farmName ?? 'مزرعة عامة', icon: Icons.landscape_rounded),
              _buildInfoRow('تاريخ الاستلام والوزن:', dateFormatted, icon: Icons.calendar_today_rounded),
              _buildInfoRow('الموقع الحالي في المستودع:', pallet.displayLocation, icon: Icons.location_on_rounded, isHighlight: true),
              _buildInfoRow('الصنف والحجم:', '${pallet.variety} - ${pallet.size}', icon: Icons.eco_rounded),
              _buildInfoRow('عدد الصناديق:', '${pallet.boxCount} صندوق', icon: Icons.inventory_2_rounded),
              _buildInfoRow('الوزن الصافي للتمر:', '${pallet.netWeight.toStringAsFixed(1)} كغ', icon: Icons.scale_rounded, isBold: true),
              _buildInfoRow('الوزن الإجمالي القائم:', '${pallet.grossWeight.toStringAsFixed(1)} كغ', icon: Icons.line_weight_rounded),
              _buildInfoRow('وزن الطبلية فارغة:', '${pallet.palletTareWeight.toStringAsFixed(1)} كغ', icon: Icons.layers_outlined),
              _buildInfoRow('حالة التسليم:', pallet.status == 'delivered' ? 'تم تسليمها للعميل' : 'موجودة بالمستودع', icon: Icons.local_shipping_rounded),

              if (pallet.pairedPalletCode != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.navyUltraLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.dateGold),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: AppColors.dateGold, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'طبلية مطبقة مع: (${pallet.pairedPalletCode})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('طباعة الملصق'),
                      onPressed: () async {
                        final pdfBytes = await PdfGenerator.generatePalletBarcodeLabelPdf(pallet);
                        await Printing.layoutPdf(onLayout: (_) => pdfBytes);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {required IconData icon, bool isHighlight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: isHighlight ? AppColors.dateGold : AppColors.navy),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: (isBold || isHighlight) ? FontWeight.w900 : FontWeight.w700,
                color: isHighlight ? AppColors.dateAmber : AppColors.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
