import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/pdf_generator.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/document_model.dart';
import '../../data/models/shipment_model.dart';
import '../../data/services/supabase_service.dart';

/// Customer Document Center Tab (مركز الوثائق وسندات الاستلام والفرز الموقعة)
class CustomerDocumentsTab extends StatefulWidget {
  final UserProfile customer;

  const CustomerDocumentsTab({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDocumentsTab> createState() => _CustomerDocumentsTabState();
}

class _CustomerDocumentsTabState extends State<CustomerDocumentsTab> {
  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final docs = service.getDocumentsForCustomer(widget.customer.id);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Center Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.navy.withAlpha(40)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.folder_shared_rounded, color: AppColors.navy, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'أرشيف السندات والتقارير الموقعة',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          'جميع سندات الاستلام والفرز والتسليم الرسمية الموقعة إلكترونياً',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'السجلات المؤرخة (${docs.length}):',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 10),

            if (docs.isEmpty)
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
                      Icon(Icons.folder_open_rounded, size: 48, color: AppColors.textMuted),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد سندات أو تقارير مؤرشفة حتى الآن',
                        style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ستظهر هنا سندات الاستلام والفرز والتسليم فور إصدارها',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...docs.map((doc) {
              final dateStr = DateFormat('yyyy/MM/dd', 'ar').format(doc.createdAt);
              IconData docIcon = Icons.description_rounded;
              Color iconBg = AppColors.navyUltraLight;
              Color iconColor = AppColors.navy;

              if (doc.docType == 'sorting_contract' || doc.docType == 'receiving_receipt') {
                docIcon = Icons.filter_alt_rounded;
                iconBg = const Color(0xFFFFF3E0);
                iconColor = const Color(0xFFE65100);
              } else if (doc.docType == 'purchase_contract') {
                docIcon = Icons.shopping_bag_rounded;
                iconBg = const Color(0xFFE8F5E9);
                iconColor = const Color(0xFF2E7D32);
              } else if (doc.docType == 'marketing_contract') {
                docIcon = Icons.storefront_rounded;
                iconBg = const Color(0xFFE3F2FD);
                iconColor = const Color(0xFF1E88E5);
              } else if (doc.docType == 'invoice') {
                docIcon = Icons.receipt_long_rounded;
                iconBg = const Color(0xFFEDE7F6);
                iconColor = const Color(0xFF5E35B1);
              } else if (doc.docType == 'account_statement') {
                docIcon = Icons.account_balance_wallet_rounded;
                iconBg = const Color(0xFFE0F2F1);
                iconColor = const Color(0xFF00796B);
              }

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
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconBg,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(docIcon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.navy,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'النوع: ${doc.docTypeAr} • التاريخ: $dateStr',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, size: 12, color: Colors.green.shade700),
                                const SizedBox(width: 2),
                                Text('موقع', style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      // Action Buttons (View, Download, WhatsApp Share)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // WhatsApp Share Button
                          OutlinedButton.icon(
                            icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                            label: const Text('مشاركة عبر واتساب', style: TextStyle(fontSize: 11, color: Color(0xFF1E7E34), fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF25D366)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            onPressed: () {
                              Share.share(
                                'مرحباً، إليك مستند رسمي من مصنع تمور علي: ${doc.title} - التاريخ: $dateStr',
                                subject: doc.title,
                              );
                            },
                          ),
                          const SizedBox(width: 8),

                          // One-Tap Download / View PDF Button
                          ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 16),
                            label: const Text('معاينة وتنزيل', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onPressed: () async {
                              final pdfBytes = await PdfGenerator.generateReceivingReceiptPdf(
                                shipment: ShipmentModel(
                                  id: doc.id,
                                  direction: 'inbound',
                                  cargoType: 'dates',
                                  customerId: widget.customer.id,
                                  customerName: widget.customer.name,
                                  driverName: 'السائق المسجل',
                                  agentName: 'المشرف',
                                  plateNumber: '12-94821',
                                ),
                                pallets: [],
                              );

                              await Printing.layoutPdf(
                                onLayout: (PdfPageFormat format) async => pdfBytes,
                                name: doc.fileName,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
