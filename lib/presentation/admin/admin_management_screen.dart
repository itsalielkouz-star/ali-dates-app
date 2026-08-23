import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/document_model.dart';
import '../../data/models/activity_log_model.dart';
import '../../data/models/pallet_model.dart';
import '../../data/services/supabase_service.dart';
import '../widgets/custom_app_bar.dart';

/// Full Executive Admin Control & Shift Intelligence Portal
/// Specifically customized for:
/// - خالد الكوز (Khaled Elkouz)
/// - حسام الكوز (Husam Elkouz)
/// - علي الكوز (Ali Elkouz)
/// - عثمان ابراهيم عداربة (Othman Ibrahim Adarbeh)
class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchCustomerQuery = '';
  String _searchLogsQuery = '';
  String _selectedActionFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final adminUser = service.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'لوحة الإدارة والتحكم الشاملة (Admin Portal)',
        subtitle: 'المشرف: ${adminUser?.name ?? "الإدارة العامة - تمور علي"}',
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            tooltip: 'تفريغ قاعدة البيانات وإعادة ضبط كلمات المرور',
            onPressed: () => _confirmClearDatabase(context, service),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.navy,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.dateGold,
              indicatorWeight: 3.5,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.upload_file_rounded, size: 18),
                  text: 'رفع وثائق للعملاء',
                ),
                Tab(
                  icon: Icon(Icons.history_edu_rounded, size: 18),
                  text: 'سجل العمليات والنقل',
                ),
                Tab(
                  icon: Icon(Icons.summarize_rounded, size: 18),
                  text: 'تقارير الورديات',
                ),
                Tab(
                  icon: Icon(Icons.insights_rounded, size: 18),
                  text: 'تحليل أداء الموظفين',
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildCustomerDocUploadTab(service),
            _buildActivityLogsTab(service),
            _buildShiftReportsTab(service),
            _buildShiftAnalysisTab(service),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: UPLOAD DOCUMENTS FOR SPECIFIC CUSTOMER
  // ===========================================================================
  Widget _buildCustomerDocUploadTab(SupabaseService service) {
    final customers = service.getCustomerContacts().where((c) {
      if (_searchCustomerQuery.isEmpty) return true;
      return c.name.toLowerCase().contains(_searchCustomerQuery.toLowerCase()) ||
          c.phone.contains(_searchCustomerQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
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
                  color: AppColors.navy.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: AppColors.dateGold, size: 36),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'رفع وتوثيق المستندات الرسمية للعملاء',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ارفع عقود الفرز، إشعارات الشراء، الفواتير، وسندات التسليم ليراها العميل مباشرة في حسابه.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search customer bar
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم العميل أو المزارع أو الهاتف...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
              suffixIcon: _searchCustomerQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _searchCustomerQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
            onChanged: (val) => setState(() => _searchCustomerQuery = val.trim()),
          ),

          const SizedBox(height: 14),

          Text(
            'قائمة العملاء والمزارعين (${customers.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
          ),

          const SizedBox(height: 8),

          if (customers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('لم يتم العثور على عملاء مطابقين للبحث', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: customers.length,
              itemBuilder: (ctx, idx) {
                final c = customers[idx];
                final docs = service.getDocumentsForCustomer(c.id);

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.navyUltraLight,
                          child: Text(
                            c.name.isNotEmpty ? c.name[0] : 'ع',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 18),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الهاتف: ${c.phone} | عدد الوثائق: ${docs.length}',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.file_upload_rounded, color: Colors.white, size: 18),
                          label: const Text('رفع وثيقة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
                          onPressed: () => _openUploadDocModal(c),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openUploadDocModal(UserProfile customer) {
    final titleCtrl = TextEditingController();
    String docType = 'receiving_receipt';
    String? selectedFileName;
    String? pickedBase64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.upload_file_rounded, color: AppColors.navy, size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رفع وثيقة للعميل: ${customer.name}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                            ),
                            const Text('سيتمكن العميل من تحميلها واستعراضها عبر تطبيقه', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Doc Type Dropdown
                  DropdownButtonFormField<String>(
                    value: docType,
                    decoration: const InputDecoration(
                      labelText: 'نوع الوثيقة *',
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'receiving_receipt', child: Text('سند استلام تمور')),
                      DropdownMenuItem(value: 'sorting_report', child: Text('تقرير نتائج الفرز')),
                      DropdownMenuItem(value: 'delivery_note', child: Text('سند تسليم بضاعة')),
                      DropdownMenuItem(value: 'boxes_receipt', child: Text('سند صناديق حقل')),
                      DropdownMenuItem(value: 'contract', child: Text('عقد تشغيل أو شراء')),
                      DropdownMenuItem(value: 'invoice', child: Text('فاتورة رسمية / كشف حساب')),
                    ],
                    onChanged: (v) {
                      if (v != null) setModalState(() => docType = v);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Title
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'عنوان أو وصف الوثيقة *',
                      hintText: 'مثال: عقد فرز موسم 2026 - دفعة تمور المجهول',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Pick File / Image Button
                  InkWell(
                    onTap: () async {
                      try {
                        final picker = ImagePicker();
                        final photo = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                        );
                        if (photo != null) {
                          final bytes = await photo.readAsBytes();
                          setModalState(() {
                            selectedFileName = photo.name;
                            pickedBase64 = base64Encode(bytes);
                          });
                        }
                      } catch (e) {
                        debugPrint('Picker error: $e');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: selectedFileName != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedFileName != null ? AppColors.success : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            selectedFileName != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                            color: selectedFileName != null ? AppColors.success : AppColors.navy,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              selectedFileName ?? 'اضغط لاختيار ملف (PDF أو صورة)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: selectedFileName != null ? AppColors.success : AppColors.navy,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى كتابة عنوان الوثيقة'), backgroundColor: AppColors.warning),
                              );
                              return;
                            }

                            final doc = DocumentModel(
                              id: 'admin_doc_${DateTime.now().millisecondsSinceEpoch}',
                              customerId: customer.id,
                              customerName: customer.name,
                              docType: docType,
                              title: title,
                              fileName: selectedFileName ?? 'official_doc_${customer.id.substring(0, 4)}.pdf',
                              pdfBase64: pickedBase64,
                            );

                            await SupabaseService().saveDocument(doc);
                            await SupabaseService().logAction(
                              actionType: 'doc_upload',
                              title: 'رفع وثيقة جديدة للعميل',
                              details: 'تم رفع وثيقة (${doc.title}) للعميل (${customer.name}) بواسطة الإدارة',
                              palletCode: customer.phone,
                            );

                            if (mounted) {
                              Navigator.of(ctx).pop();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ تم رفع وثيقة (${doc.title}) بنجاح إلى حساب ${customer.name}'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                          child: const Text('حفظ ورفع الوثيقة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 2: AUDIT LOGS & PALLET MOVEMENTS (سجل العمليات وحركات النقل)
  // ===========================================================================
  Widget _buildActivityLogsTab(SupabaseService service) {
    final allLogs = service.activityLogs;
    final filteredLogs = allLogs.where((log) {
      if (_selectedActionFilter != 'all' && log.actionType != _selectedActionFilter) {
        return false;
      }
      if (_searchLogsQuery.isNotEmpty) {
        final q = _searchLogsQuery.toLowerCase();
        return log.title.toLowerCase().contains(q) ||
            log.details.toLowerCase().contains(q) ||
            log.employeeName.toLowerCase().contains(q) ||
            (log.palletCode?.toLowerCase().contains(q) ?? false) ||
            (log.supervisorName?.toLowerCase().contains(q) ?? false);
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'ابحث في السجل عن كود طبلية، اسم موظف، أو مشرف...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _searchLogsQuery = v.trim()),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedActionFilter,
                dropdownColor: Colors.white,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('كافة العمليات')),
                  DropdownMenuItem(value: 'scan', child: Text('عمليات المسح 📷')),
                  DropdownMenuItem(value: 'transfer', child: Text('حركات النقل 🔄')),
                  DropdownMenuItem(value: 'sort_start', child: Text('بدء الفرز 🏭')),
                  DropdownMenuItem(value: 'shift_start', child: Text('بدء الورديات 🛡️')),
                  DropdownMenuItem(value: 'doc_upload', child: Text('رفع وثائق 📄')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedActionFilter = v);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'سجل الحركات المفصل (${filteredLogs.length} حركة):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
          ),

          const SizedBox(height: 10),

          if (filteredLogs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('لا توجد عمليات مسجلة مطابقة لمعايير البحث', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredLogs.length,
              itemBuilder: (ctx, idx) {
                final log = filteredLogs[idx];
                final timeStr = DateFormat('yyyy/MM/dd - HH:mm:ss').format(log.timestamp);
                final isScan = log.actionType == 'scan';
                final isTransfer = log.actionType == 'transfer';
                final isShift = log.actionType == 'shift_start';

                final color = isScan
                    ? const Color(0xFF0D9488)
                    : isTransfer
                        ? const Color(0xFF2563EB)
                        : isShift
                            ? AppColors.dateGold
                            : AppColors.navy;

                final icon = isScan
                    ? Icons.qr_code_scanner_rounded
                    : isTransfer
                        ? Icons.drive_file_move_rounded
                        : isShift
                            ? Icons.shield_rounded
                            : Icons.check_circle_outline_rounded;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: color.withOpacity(0.12),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    log.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy),
                                  ),
                                  Text(timeStr, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(log.details, style: const TextStyle(fontSize: 12, color: AppColors.navyDark)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.navyUltraLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 12, color: AppColors.navy),
                                        const SizedBox(width: 3),
                                        Text('القائم بالعملية: ${log.employeeName}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                                      ],
                                    ),
                                  ),
                                  if (log.supervisorName != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.shield_outlined, size: 12, color: AppColors.dateBronze),
                                          const SizedBox(width: 3),
                                          Text('إشراف الشفت: ${log.supervisorName}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.dateBronze)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 3: SHIFT REPORTS & EXPORT (تقارير الورديات والشفتات)
  // ===========================================================================
  Widget _buildShiftReportsTab(SupabaseService service) {
    final logs = service.activityLogs;
    final totalScans = logs.where((l) => l.actionType == 'scan').length;
    final totalTransfers = logs.where((l) => l.actionType == 'transfer').length;
    final totalSorts = logs.where((l) => l.actionType == 'sort_start').length;

    final Map<String, List<ActivityLogModel>> supervisorGroups = {};
    for (var l in logs) {
      final sup = l.supervisorName ?? 'غير محدد';
      supervisorGroups.putIfAbsent(sup, () => []).add(l);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shift Summary Dashboard
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ملخص أداء الوردية الحالية',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'المشرف النشط: ${service.shiftSupervisor}',
                          style: const TextStyle(color: AppColors.dateGold, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.dateGold),
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.navy, size: 18),
                      label: const Text('تصدير تقرير الشفت PDF', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 12)),
                      onPressed: () => _generateShiftReportPdf(service),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildShiftStatCard('إجمالي المسحات', '$totalScans', Icons.qr_code_scanner_rounded, const Color(0xFF2DD4BF)),
                    const SizedBox(width: 10),
                    _buildShiftStatCard('حركات النقل', '$totalTransfers', Icons.drive_file_move_rounded, const Color(0xFF60A5FA)),
                    const SizedBox(width: 10),
                    _buildShiftStatCard('دفعات الفرز', '$totalSorts', Icons.filter_alt_rounded, const Color(0xFFFBBF24)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'تفصيل الورديات حسب مسؤولي الشفت:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
          ),

          const SizedBox(height: 10),

          ...supervisorGroups.entries.map((entry) {
            final supervisor = entry.key;
            final supLogs = entry.value;
            final scans = supLogs.where((l) => l.actionType == 'scan').length;
            final transfers = supLogs.where((l) => l.actionType == 'transfer').length;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ExpansionTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.navyUltraLight,
                  child: Icon(Icons.shield_rounded, color: AppColors.dateBronze),
                ),
                title: Text(
                  'مسؤول الشفت: $supervisor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                ),
                subtitle: Text(
                  'إجمالي العمليات: ${supLogs.length} | مسح: $scans | نقل: $transfers',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: supLogs.take(5).length,
                    itemBuilder: (context, idx) {
                      final item = supLogs[idx];
                      return ListTile(
                        dense: true,
                        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        subtitle: Text('${item.details} (الموظف: ${item.employeeName})', style: const TextStyle(fontSize: 11)),
                        trailing: Text(DateFormat('HH:mm').format(item.timestamp), style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShiftStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Future<void> _generateShiftReportPdf(SupabaseService service) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    final logs = service.activityLogs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('شركة مصنع تمور علي - تقرير الوردية والعمليات', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                  pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('مسؤول الشفت: ${service.shiftSupervisor}', style: pw.TextStyle(font: fontBold)),
                  pw.Text('إجمالي الحركات المسجلة: ${logs.length} حركة'),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Table.fromTextArray(
              headers: ['الوقت', 'العملية', 'التفاصيل', 'الموظف المنفذ', 'مسؤول الشفت'],
              headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
              cellAlignment: pw.Alignment.centerRight,
              data: logs.take(30).map((l) {
                return [
                  DateFormat('HH:mm:ss').format(l.timestamp),
                  l.title,
                  l.details,
                  l.employeeName,
                  l.supervisorName ?? '-',
                ];
              }).toList(),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'shift_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }

  // ===========================================================================
  // TAB 4: SHIFT ANALYSIS & EMPLOYEE PRODUCTIVITY (تحليل أداء الموظفين)
  // ===========================================================================
  Widget _buildShiftAnalysisTab(SupabaseService service) {
    final logs = service.activityLogs;

    final Map<String, int> employeeActivityCount = {};
    for (var l in logs) {
      final emp = l.employeeName;
      employeeActivityCount[emp] = (employeeActivityCount[emp] ?? 0) + 1;
    }

    final sortedEmployees = employeeActivityCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee Leaderboard & Productivity
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.leaderboard_rounded, color: AppColors.navy, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'ترتيب إنتاجية ونشاط الموظفين في الوردية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (sortedEmployees.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('لا توجد بيانات إنتاجية مسجلة بعد', style: TextStyle(color: AppColors.textMuted)),
                    ),
                  )
                else
                  ...sortedEmployees.map((e) {
                    final percentage = (e.value / logs.length * 100).toStringAsFixed(1);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                              Text('${e.value} عملية ($percentage%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyLight)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: logs.isNotEmpty ? e.value / logs.length : 0.0,
                            backgroundColor: AppColors.navyUltraLight,
                            color: AppColors.navy,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action Type Distribution
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, color: AppColors.dateGold, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'توزيع العمليات حسب النوع',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeStatCard('مسح QR', '${logs.where((l) => l.actionType == 'scan').length}', const Color(0xFF0D9488)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeStatCard('نقل وتطبيق', '${logs.where((l) => l.actionType == 'transfer').length}', const Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildTypeStatCard('فرز وتعبئة', '${logs.where((l) => l.actionType == 'sort_start').length}', AppColors.dateBronze),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeStatCard(String label, String count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _confirmClearDatabase(BuildContext context, SupabaseService service) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Text('تفريغ قاعدة البيانات بالكامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من تفريغ كافة البيانات التشغيلية (الطبليات، الورديات، عمليات القطاف، سجلات الحركات) وإعادة ضبط كلمات المرور لجميع الحسابات إلى الحالة الأولية (1234)؟',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('تفريغ وإعادة ضبط'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await service.clearDatabaseAndResetPasswords();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ تم تفريغ قاعدة البيانات وإعادة ضبط كلمات المرور بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
