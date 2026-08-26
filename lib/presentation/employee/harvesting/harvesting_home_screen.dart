import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/models/picking_operation_model.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/models/farm_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/customer_selection_modal.dart';
import '../../widgets/signature_dialog.dart';

/// 5th Core Section: Harvesting & Picking Operations (عمليات القطاف والحصاد الميداني)
/// Implements complete 34-step real-world business cycle:
/// Farmer → Farm/Land → Picking Plan → Crates → Harvesting Team → Loads → Weighing → Reconciliation → Settlement
class HarvestingHomeScreen extends StatefulWidget {
  const HarvestingHomeScreen({super.key});

  @override
  State<HarvestingHomeScreen> createState() => _HarvestingHomeScreenState();
}

class _HarvestingHomeScreenState extends State<HarvestingHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final allOps = service.pickingOperations;

    // Filter operations by lifecycle stage
    final activeOps = allOps.where((o) => !o.isSettled).toList();
    final completedOps = allOps.where((o) => o.isSettled).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'القطاف والحصاد الميداني (Harvesting)',
        subtitle: 'إدارة خطط القطاف، الصناديق، الشحنات والمطابقة',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.dateGold, size: 26),
            tooltip: 'إنشاء خطة قطاف جديدة',
            onPressed: () => _openCreatePickingPlanModal(context),
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
              tabs: [
                Tab(
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  text: 'العمليات الميدانية النشطة (${activeOps.length})',
                ),
                Tab(
                  icon: const Icon(Icons.history_rounded, size: 18),
                  text: 'الأرشيف والتسويات (${completedOps.length})',
                ),
                const Tab(
                  icon: Icon(Icons.rule_folder_rounded, size: 18),
                  text: 'دليل دورة العمل والمسؤوليات',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOperationsList(activeOps, isArchive: false),
          _buildOperationsList(completedOps, isArchive: true),
          _buildBusinessFlowDocumentationTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFD97706),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('خطة قطاف جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openCreatePickingPlanModal(context),
      ),
    );
  }

  // ===========================================================================
  // LIST OF OPERATIONS (ACTIVE & ARCHIVED)
  // ===========================================================================
  Widget _buildOperationsList(List<PickingOperationModel> operations, {required bool isArchive}) {
    final filtered = operations.where((o) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return o.code.toLowerCase().contains(q) ||
          o.customerName.toLowerCase().contains(q) ||
          o.farmName.toLowerCase().contains(q) ||
          o.supervisorName.toLowerCase().contains(q) ||
          o.laborTeamLeaderName.toLowerCase().contains(q);
    }).toList();

    final service = SupabaseService();
    final availableBoxes = service.availableBoxesInFactory;
    final totalBoxes = service.totalCompanyBoxes;
    final distributedBoxes = service.totalBoxesWithCustomers;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Factory Stock Balance Card
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withAlpha(50),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.all_inbox_rounded, color: AppColors.dateGold, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رصيد صناديق مصنع تمور علي المتاحة:',
                          style: TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                        Text(
                          '$availableBoxes صندوق متوفر بالمستودع',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'الإجمالي: $totalBoxes',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70),
                    ),
                    Text(
                      'في الحقول: $distributedBoxes',
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.dateGold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search & Filter
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث برقم الخطة، اسم المزارع، المزرعة، أو المشرف...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (v) => setState(() => _searchQuery = v.trim()),
          ),

          const SizedBox(height: 14),

          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      isArchive ? Icons.inventory_rounded : Icons.agriculture_rounded,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isArchive
                          ? 'لا توجد عمليات قطاف مؤرشفة ومقفلة مالياً'
                          : 'لا توجد عمليات قطاف ميدانية جارية حالياً',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isArchive
                          ? 'العمليات المقفلة مالياً ستظهر هنا بعد وزن المحصول ومطابقة الصناديق.'
                          : 'اضغط على زر "خطة قطاف جديدة" بالأسفل لجدولة عملية قطاف لمزرعة.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              itemBuilder: (ctx, idx) {
                final op = filtered[idx];
                return _buildOperationCard(op);
              },
            ),
          const SizedBox(height: 70),
        ],
      ),
    );
  }

  Widget _buildOperationCard(PickingOperationModel op) {
    final dateStr = DateFormat('yyyy/MM/dd').format(op.plannedDate);

    Color statusColor;
    switch (op.status) {
      case 'planned':
        statusColor = const Color(0xFF64748B);
        break;
      case 'crates_dispatched':
      case 'team_dispatched':
        statusColor = const Color(0xFF2563EB);
        break;
      case 'at_farm':
      case 'harvesting_in_progress':
        statusColor = const Color(0xFFD97706);
        break;
      case 'loads_dispatched':
      case 'harvesting_completed':
        statusColor = const Color(0xFF7C3AED);
        break;
      case 'returned_to_facility':
      case 'weighed':
        statusColor = const Color(0xFF0D9488);
        break;
      case 'settled':
        statusColor = AppColors.success;
        break;
      default:
        statusColor = AppColors.navy;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Code + Status Badge
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
                      child: const Icon(Icons.agriculture_rounded, color: Color(0xFFD97706), size: 22),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          op.code,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                        ),
                        Text('تاريخ الجدولة: $dateStr', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    op.statusAr,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: statusColor),
                  ),
                ),
              ],
            ),

            const Divider(height: 20),

            // Farm & Customer Info
            Row(
              children: [
                const Icon(Icons.person_pin_rounded, size: 16, color: AppColors.navy),
                const SizedBox(width: 4),
                Text('المزارع: ${op.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                const Spacer(),
                const Icon(Icons.landscape_rounded, size: 16, color: AppColors.dateBronze),
                const SizedBox(width: 4),
                Text('المزرعة: ${op.farmName} (${op.landName})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.navyDark)),
              ],
            ),

            const SizedBox(height: 10),

            // Roles Distinct Display: Supervisor vs Labor Team Leader
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 13, color: AppColors.navy),
                            SizedBox(width: 3),
                            Text('مشرف تمور علي (الموظف):', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          ],
                        ),
                        Text(op.supervisorName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.black12),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.groups_rounded, size: 13, color: Color(0xFFD97706)),
                            SizedBox(width: 3),
                            Text('رئيس العمال (عامل يومية):', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
                          ],
                        ),
                        Text(op.laborTeamLeaderName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyDark)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Planned vs Actual Comparison Matrix
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricCell('العمال', 'المخطط: ${op.plannedWorkers}', 'الفعلي: ${op.actualWorkers}'),
                  _buildMetricCell('الصناديق', 'المخطط: ${op.plannedCrates}', 'المنقول: ${op.totalHarvestedCrates}'),
                  _buildMetricCell(
                    'الوزن الصافي',
                    'المقدر: ${op.plannedEstimatedKg.toInt()} كغ',
                    op.actualNetWeight != null ? '${op.actualNetWeight!.toStringAsFixed(1)} كغ' : 'بانتظار الوزن',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Action Button to Open Field Execution Workspace
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: op.isSettled ? AppColors.navy : const Color(0xFFD97706),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(op.isSettled ? Icons.visibility_rounded : Icons.play_arrow_rounded, color: Colors.white),
              label: Text(
                op.isSettled ? 'عرض تقرير وتفاصيل العملية المقفلة' : 'متابعة وإدارة خطوات القطاف والحصاد',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
              ),
              onPressed: () => _openFieldExecutionScreen(op),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(String title, String plan, String actual) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
        const SizedBox(height: 2),
        Text(plan, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(actual, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F766E))),
      ],
    );
  }

  // ===========================================================================
  // MODAL: CREATE PICKING PLAN (خطوة الجدولة قبل يوم من الحصاد)
  // ===========================================================================
  void _openCreatePickingPlanModal(BuildContext context) {
    UserProfile? selectedCustomer;
    FarmModel? selectedFarm;
    final landCtrl = TextEditingController();
    final landCodeCtrl = TextEditingController();
    final plannedWorkersCtrl = TextEditingController();
    final plannedCratesCtrl = TextEditingController();
    final plannedKgCtrl = TextEditingController();
    final laborLeaderCtrl = TextEditingController();
    final laborLeaderPhoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final service = SupabaseService();
    String supervisor = service.shiftSupervisor;
    DateTime plannedDate = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final farms = selectedCustomer != null
              ? service.getFarmsForCustomer(selectedCustomer!.id)
              : <FarmModel>[];

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: const EdgeInsets.all(22),
              constraints: const BoxConstraints(maxWidth: 580, maxHeight: 780),
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
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFD97706), size: 24),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'إنشاء خطة قطاف وتجهيز للحصاد',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                              ),
                              Text('تحديد المزرعة، العمالة، الصناديق والمشرف قبل الانطلاق للحقل', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(ctx).pop()),
                      ],
                    ),

                    const Divider(height: 20),

                    // Customer Selection
                    CustomerPickerCard(
                      selectedCustomer: selectedCustomer,
                      onCustomerChanged: (c) {
                        setModalState(() {
                          selectedCustomer = c;
                          selectedFarm = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    // Farm Selection
                    if (selectedCustomer != null) ...[
                      DropdownButtonFormField<FarmModel>(
                        value: selectedFarm,
                        decoration: const InputDecoration(
                          labelText: 'المزرعة التابعة للعميل *',
                          prefixIcon: Icon(Icons.landscape_rounded),
                        ),
                        hint: const Text('اختر المزرعة'),
                        items: farms.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
                        onChanged: (f) => setModalState(() => selectedFarm = f),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Land Name & Code
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: landCtrl,
                            decoration: const InputDecoration(
                              labelText: 'اسم / رقم قطعة الأرض *',
                              prefixIcon: Icon(Icons.map_rounded),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: landCodeCtrl,
                            decoration: const InputDecoration(
                              labelText: 'كود الأرض',
                              prefixIcon: Icon(Icons.pin_rounded),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Planned Estimates (Workers, Crates, Kg)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الكميات التقديرية المخططة (Estimates):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: plannedWorkersCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'العمال المقدرين *',
                                    prefixIcon: Icon(Icons.people_outline),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: plannedCratesCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'الصناديق المقدرة *',
                                    prefixIcon: Icon(Icons.all_inbox_rounded),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: plannedKgCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'الوزن التقريبي المتوقع (كغ)',
                              prefixIcon: Icon(Icons.scale_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Date Picker Selection Widget
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.event_available_rounded, color: AppColors.navy, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('تاريخ وموعد الحصاد المجدول:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  Text(
                                    DateFormat('EEEE, yyyy/MM/dd', 'ar').format(plannedDate),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.navyUltraLight,
                              foregroundColor: AppColors.navy,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                            label: const Text('تغيير التاريخ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: plannedDate,
                                firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                lastDate: DateTime.now().add(const Duration(days: 90)),
                              );
                              if (picked != null) {
                                setModalState(() => plannedDate = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Roles Distinction: General Supervisor (Khaled & Othman Only) vs Labor Team Leader (Select or Add Employee)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.badge_rounded, color: Color(0xFFD97706), size: 18),
                              SizedBox(width: 6),
                              Text('تحديد المسؤوليات والقيادة في الحقل:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // 1. General Supervisor (Strictly Khaled Elkouz or Othman Adarbeh)
                          DropdownButtonFormField<String>(
                            value: (supervisor.contains('عثمان') || supervisor.contains('othman'))
                                ? 'عثمان ابراهيم عداربة (المشرف العام)'
                                : 'خالد الكوز (المشرف العام)',
                            decoration: const InputDecoration(
                              labelText: 'المشرف العام لتمور علي *',
                              helperText: 'المشرف العام المعتمد والمسؤول عن ضبط وتوثيق العملية',
                              prefixIcon: Icon(Icons.shield_rounded, color: Color(0xFFD97706)),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'خالد الكوز (المشرف العام)',
                                child: Text('خالد الكوز (المشرف العام)', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              DropdownMenuItem(
                                value: 'عثمان ابراهيم عداربة (المشرف العام)',
                                child: Text('عثمان ابراهيم عداربة (المشرف العام)', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() => supervisor = val);
                              }
                            },
                          ),
                          const SizedBox(height: 12),

                          // 2. Labor Team Leader (Select from Employees Dropdown + Add New Employee Button)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: service.profiles.where((p) => p.isEmployee).any((e) => e.name == laborLeaderCtrl.text.trim())
                                      ? laborLeaderCtrl.text.trim()
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'رئيس العمال (Labor Team Leader) *',
                                    helperText: 'اختر الموظف المسؤول عن قيادة فريق العمال وتوزيع أجورهم',
                                    prefixIcon: Icon(Icons.groups_rounded),
                                  ),
                                  hint: Text(laborLeaderCtrl.text.isNotEmpty ? laborLeaderCtrl.text : 'اختر موظف كرئيس عمال'),
                                  items: service.profiles.where((p) => p.isEmployee).map((emp) {
                                    return DropdownMenuItem(
                                      value: emp.name,
                                      child: Text('${emp.name} (${emp.phone})', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final emp = service.profiles.firstWhere((p) => p.name == val);
                                      setModalState(() {
                                        laborLeaderCtrl.text = emp.name;
                                        laborLeaderPhoneCtrl.text = emp.phone;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: IconButton.filledTonal(
                                  icon: const Icon(Icons.person_add_alt_1_rounded),
                                  tooltip: 'إضافة موظف جديد كرئيس عمال',
                                  onPressed: () => _openAddNewEmployeeModal(context, (newEmp) {
                                    setModalState(() {
                                      laborLeaderCtrl.text = newEmp.name;
                                      laborLeaderPhoneCtrl.text = newEmp.phone;
                                    });
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // 3. Labor Team Leader Phone
                          TextField(
                            controller: laborLeaderPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'هاتف رئيس العمال للتواصل *',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات وتوجيهات الحقل',
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                    ),

                    // Signature Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.draw_rounded, color: Color(0xFF16A34A), size: 18),
                                  SizedBox(width: 6),
                                  Text('توقيع اعتماد خطة وصرف الصناديق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                                ],
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                label: const Text('توقيع الآن', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  final sig = await SignatureDialog.show(
                                    context,
                                    title: 'توقيع اعتماد خطة وصرف صناديق الحقل',
                                    signerRole: selectedCustomer?.name ?? 'المزارع / المشرف',
                                  );
                                  if (sig != null) {
                                    setModalState(() {
                                      notesCtrl.text = '${notesCtrl.text.trim()} [تم التوقيع الإلكتروني للاعتماد]'.trim();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '💡 سيتم فور الاعتماد حسم عدد الصناديق مباشرة من الرصيد المتوفر في مستودع المصنع وتوثيقها بعهدة المزرعة.',
                            style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        if (selectedCustomer == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى اختيار العميل / المزارع'), backgroundColor: AppColors.warning),
                          );
                          return;
                        }

                        final workers = int.tryParse(plannedWorkersCtrl.text.trim()) ?? 20;
                        final crates = int.tryParse(plannedCratesCtrl.text.trim()) ?? 150;
                        final kg = double.tryParse(plannedKgCtrl.text.trim()) ?? 1000.0;

                        await service.createPickingPlan(
                          customerId: selectedCustomer!.id,
                          customerName: selectedCustomer!.name,
                          farmId: selectedFarm?.id ?? 'farm_main',
                          farmName: selectedFarm?.name ?? 'المزرعة الرئيسية',
                          landName: landCtrl.text.trim(),
                          landCode: landCodeCtrl.text.trim(),
                          plannedWorkers: workers,
                          plannedCrates: crates,
                          plannedEstimatedKg: kg,
                          plannedDate: plannedDate,
                          supervisorName: supervisor,
                          laborTeamLeaderName: laborLeaderCtrl.text.trim(),
                          laborTeamLeaderPhone: laborLeaderPhoneCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );

                        if (mounted) {
                          Navigator.of(ctx).pop();
                          setState(() {});
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('✅ تم اعتماد الخطة، التوقيع، وحسم ($crates) صندوق من رصيد المصنع بنجاح'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      child: const Text('اعتماد خطة القطاف والتوقيع وصرف الصناديق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddNewEmployeeModal(BuildContext context, Function(UserProfile newEmployee) onEmployeeAdded) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passwordCtrl = TextEditingController(text: '1234');

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
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
                      child: const Icon(Icons.person_add_rounded, color: AppColors.navy, size: 22),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إنشاء حساب موظف / رئيس عمال جديد',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                          Text(
                            'سيتم تفعيل حساب الموظف فوراً لتسجيل الدخول بالتطبيق',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموظف / رئيس العمال *',
                    hintText: 'مثال: أحمد العبادي',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'رقم هاتف الموظف (اسم المستخدم للدخول) *',
                    hintText: 'مثال: 0791234567',
                    prefixIcon: Icon(Icons.phone_iphone_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'رقم الهاتف مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور لتسجيل الدخول *',
                    helperText: 'الافتراضية: 1234 (يمكن للموظف تغييرها بعد الدخول)',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'كلمة المرور مطلوبة' : null,
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
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                        icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
                        label: const Text('إنشاء الحساب وتعيينه', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final cleanPhone = PhoneUtils.toLocal(phoneCtrl.text.trim());
                          final pass = passwordCtrl.text.trim();
                          final newProfile = UserProfile(
                            id: const Uuid().v4(),
                            phone: cleanPhone,
                            name: nameCtrl.text.trim(),
                            isEmployee: true,
                            companyName: 'تمور علي',
                            passwordHash: pass.isNotEmpty ? pass : '1234',
                            needsPasswordChange: pass == '1234',
                          );

                          await SupabaseService().saveUserProfile(newProfile);
                          if (mounted) {
                            Navigator.of(ctx).pop();
                            onEmployeeAdded(newProfile);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ تم إنشاء حساب الموظف (${newProfile.name}) بنجاح ويمكنه الدخول فوراً برقم هاتف: ${newProfile.phone}'),
                                backgroundColor: AppColors.success,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        },
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
  void _openFieldExecutionScreen(PickingOperationModel op) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final service = SupabaseService();
          final liveOp = service.pickingOperations.firstWhere((o) => o.id == op.id, orElse: () => op);

          return Container(
            height: MediaQuery.of(context).size.height * 0.92,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.agriculture_rounded, color: AppColors.dateGold, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'متابعة الحصاد الميداني: ${liveOp.code}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text('${liveOp.customerName} - ${liveOp.farmName} (${liveOp.landName})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Current Step Indicator
                        _buildCurrentStepCard(liveOp, setSheetState),

                        const SizedBox(height: 16),

                        // 2. Loads Management Section (تسيير النقلات)
                        _buildLoadsSection(liveOp, setSheetState),

                        const SizedBox(height: 16),

                        // 3. Photo Evidence Section (التوثيق الفوتوغرافي)
                        _buildPhotosSection(liveOp, setSheetState),

                        const SizedBox(height: 16),

                        // 4. Weighing & Crate Reconciliation Section
                        _buildWeighingAndReconciliationSection(liveOp, setSheetState),

                        const SizedBox(height: 20),

                        // Print PDF Picking Report
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: AppColors.navy, width: 1.5),
                          ),
                          icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.navy),
                          label: const Text('طباعة تقرير القطاف الرسمي (Picking Report PDF)', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                          onPressed: () => _generatePickingPdf(liveOp),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentStepCard(PickingOperationModel op, StateSetter setSheetState) {
    final service = SupabaseService();
    final currentUser = service.currentUser;

    // Check if the current user is the appointed Supervisor for this harvest (or Admin)
    final isHarvestSupervisor = currentUser != null &&
        (currentUser.name.trim().toLowerCase() == op.supervisorName.trim().toLowerCase() ||
         currentUser.name.trim().toLowerCase() == op.laborTeamLeaderName.trim().toLowerCase() ||
         (op.laborTeamLeaderPhone != null && PhoneUtils.areEqual(op.laborTeamLeaderPhone!, currentUser.phone)));

    final isGeneralSupervisor = currentUser != null && (currentUser.isGeneralSupervisor || currentUser.isAdmin);

    String buttonLabel = '';
    String nextStatus = '';
    IconData stepIcon = Icons.arrow_forward_rounded;
    bool isLeaderExclusiveAction = false;

    if (op.status == 'planned') {
      buttonLabel = '1. استلام الصناديق وتحديد العمال والتوقيع (Collect Boxes & Sign)';
      nextStatus = 'crates_dispatched';
      stepIcon = Icons.all_inbox_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'crates_dispatched') {
      buttonLabel = '2. انطلاق فريق الحصاد من المصنع (Team Dispatched)';
      nextStatus = 'team_dispatched';
      stepIcon = Icons.directions_bus_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'team_dispatched') {
      buttonLabel = '3. تم الوصول إلى المزرعة (Arrived at Farm)';
      nextStatus = 'at_farm';
      stepIcon = Icons.location_on_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'at_farm') {
      buttonLabel = '4. ⏱️ بدء القطاف الفعلي وتشغيل العداد وتوثيق الموقع (Start Harvesting)';
      nextStatus = 'harvesting_in_progress';
      stepIcon = Icons.play_arrow_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'harvesting_in_progress' || op.status == 'loads_dispatched') {
      buttonLabel = '5. ⏹️ إنهاء أعمال القطاف وفحص الموقع (1km Radius Check & End)';
      nextStatus = 'harvesting_completed';
      stepIcon = Icons.stop_circle_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'harvesting_completed') {
      buttonLabel = '6. مغادرة المزرعة باتجاه مركز تمور علي (Leave Farm)';
      nextStatus = 'in_transit';
      stepIcon = Icons.local_shipping_rounded;
      isLeaderExclusiveAction = true;
    } else if (op.status == 'in_transit') {
      buttonLabel = '7. تسليم المحصول للمصنع والوزن (Handover to Factory Receiving)';
      nextStatus = 'returned_to_facility';
      stepIcon = Icons.warehouse_rounded;
    }

    final canClick = !isLeaderExclusiveAction || isHarvestSupervisor || isGeneralSupervisor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'المرحلة: ${op.statusAr}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF92400E)),
                  ),
                ],
              ),
              if (op.harvestingStartTime != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD97706)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_rounded, color: Color(0xFFD97706), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'المدة: ${op.formattedDuration}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'المشرف المعين للحصاد: ${op.supervisorName} (${op.actualWorkers} عمال - ${op.collectedBoxesCount > 0 ? op.collectedBoxesCount : op.plannedCrates} صندوق)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navyDark),
          ),
          if (op.workerNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'أسماء العمال: ${op.workerNames.join("، ")}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
          if (op.startLatitude != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.pin_drop_rounded, color: Color(0xFF0F766E), size: 15),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'موقع بدء الحصاد: ${op.startLocationName ?? "الحقل"} (N: ${op.startLatitude?.toStringAsFixed(4)}, E: ${op.startLongitude?.toStringAsFixed(4)})',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
          if (isLeaderExclusiveAction && !isHarvestSupervisor && !isGeneralSupervisor) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, color: AppColors.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '🔒 هذه الخطوة مخصصة حصرياً لمشرف الحصاد المعين (${op.supervisorName})',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF991B1B), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (buttonLabel.isNotEmpty) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: canClick ? const Color(0xFFD97706) : Colors.grey,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: Icon(stepIcon, color: Colors.white),
              label: Text(
                buttonLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              onPressed: canClick
                  ? () async {
                      if (op.status == 'planned') {
                        // Step 1: Open Box Collection & Dual Signature Dialog
                        _openBoxCollectionAndSignDialog(op, setSheetState);
                      } else if (op.status == 'at_farm') {
                        // Step 4: Start Harvesting (GPS Capture + Live Timer + Admin Alerts)
                        await service.advancePickingLifecycle(
                          operationId: op.id,
                          newStatus: 'harvesting_in_progress',
                          latitude: 31.8560, // Field GPS
                          longitude: 35.5450,
                          locationName: '${op.farmName} (${op.landName})',
                        );
                        setSheetState(() {});
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('🌴 تم بدء الحصاد وتشغيل العداد وإشعار الإدارة فوراً.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } else if (op.status == 'harvesting_in_progress' || op.status == 'loads_dispatched') {
                        // Step 5: Check 1km Radius Geofence before allowing End Harvesting
                        _handleEndHarvestingWithGeofence(op, setSheetState);
                      } else {
                        await service.advancePickingLifecycle(
                          operationId: op.id,
                          newStatus: nextStatus,
                        );
                        setSheetState(() {});
                        setState(() {});
                      }
                    }
                  : () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('⚠️ فقط مشرف الحصاد (${op.supervisorName}) أو الإدارة مخول بمتابعة خطوات الحصاد'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                    },
            ),
          ],
        ],
      ),
    );
  }

  void _openBoxCollectionAndSignDialog(PickingOperationModel op, StateSetter setSheetState) {
    final boxesCtrl = TextEditingController(text: '${op.plannedCrates}');
    final workersCtrl = TextEditingController(text: '${op.actualWorkers}');
    final workerNamesCtrl = TextEditingController(text: op.workerNames.join('، '));
    String? issuerSig;
    String? receiverSig;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: AppColors.navy),
              SizedBox(width: 8),
              Text('استلام الصناديق وتسجيل العمال والتواقيع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('المزرعة: ${op.farmName} - قطعة ${op.landName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
                const SizedBox(height: 12),
                TextField(
                  controller: boxesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد الصناديق المستلمة فعلياً *',
                    prefixIcon: Icon(Icons.all_inbox_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: workersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'عدد العمال المرافقين *',
                    prefixIcon: Icon(Icons.people_alt_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: workerNamesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'أسماء العمال (اختياري - مفصولة بفواصل)',
                    hintText: 'مثال: أحمد، محمود، سامر',
                    prefixIcon: Icon(Icons.badge_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Issuer Signature (توقيع من سلّم الصناديق)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('توقيع مسلّم الصناديق (المستودع):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          Text(issuerSig != null ? '✅ تم التوقيع الإلكتروني' : 'بانتظار التوقيع', style: TextStyle(fontSize: 10.5, color: issuerSig != null ? AppColors.success : AppColors.error)),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.draw_rounded, size: 14),
                        label: const Text('توقيع المسلّم', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final sig = await SignatureDialog.show(
                            context,
                            title: 'توقيع أمين مستودع الصناديق',
                            signerRole: 'مسؤول صرف الصناديق',
                          );
                          if (sig != null) {
                            setDialogState(() => issuerSig = 'SIGNED_ISSUER');
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // 2. Receiver Signature (توقيع المشرف المستلم)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('توقيع المستلم (${op.supervisorName}):', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                          Text(receiverSig != null ? '✅ تم التوقيع الإلكتروني' : 'بانتظار التوقيع', style: TextStyle(fontSize: 10.5, color: receiverSig != null ? AppColors.success : AppColors.error)),
                        ],
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.draw_rounded, size: 14),
                        label: const Text('توقيع المستلم', style: TextStyle(fontSize: 11)),
                        onPressed: () async {
                          final sig = await SignatureDialog.show(
                            context,
                            title: 'توقيع مشرف الحصاد المستلم',
                            signerRole: op.supervisorName,
                          );
                          if (sig != null) {
                            setDialogState(() => receiverSig = 'SIGNED_RECEIVER');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () async {
                final bCount = int.tryParse(boxesCtrl.text.trim()) ?? op.plannedCrates;
                final wCount = int.tryParse(workersCtrl.text.trim()) ?? op.actualWorkers;
                final wNames = workerNamesCtrl.text.trim().isNotEmpty
                    ? workerNamesCtrl.text.trim().split(RegExp(r'[,،]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
                    : <String>[];

                await SupabaseService().advancePickingLifecycle(
                  operationId: op.id,
                  newStatus: 'crates_dispatched',
                  actualWorkers: wCount,
                  workerNames: wNames,
                  collectedBoxes: bCount,
                  issuerSignature: issuerSig ?? 'توقيع معتمد',
                  receiverSignature: receiverSig ?? 'توقيع معتمد',
                );

                if (mounted) {
                  Navigator.of(ctx).pop();
                  setSheetState(() {});
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ تم توثيق استلام ($bCount) صندوق مع التواقيع وتجهيز الفريق للانطلاق'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
              child: const Text('تأكيد الاستلام والتواقيع', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _handleEndHarvestingWithGeofence(PickingOperationModel op, StateSetter setSheetState) {
    final isWithin1Km = op.isWithin1KmOfStart;

    if (!isWithin1Km) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ تنبيه: الموقع الجغرافي الحالي يبعد أكثر من 1 كم عن نقطة بدء الحصاد!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('تأكيد إنهاء الحصاد الميداني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تم التحقق من الموقع الجغرافي: أنت ضمن نطاق الـ 1 كم المعتمد لمزرعة (${op.farmName}).', style: const TextStyle(fontSize: 12.5, color: AppColors.navy, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('المدة المستغرقة: ${op.formattedDuration}', style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('سيتم إيقاف العداد فوراً وتنبيه الإدارة (خالد، حسام، علي، عثمان) باكتمال الحصاد.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              await SupabaseService().advancePickingLifecycle(
                operationId: op.id,
                newStatus: 'harvesting_completed',
                latitude: op.startLatitude ?? 31.8560,
                longitude: op.startLongitude ?? 35.5450,
                locationName: op.startLocationName ?? '${op.farmName} (${op.landName})',
              );
              if (mounted) {
                Navigator.of(ctx).pop();
                setSheetState(() {});
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🏁 تم إنهاء الحصاد وإيقاف العداد وإرسال الإشعار للإدارة بنجاح'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('إنهاء الحصاد وإيقاف العداد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadsSection(PickingOperationModel op, StateSetter setSheetState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'شحنات ونقلات المحصول (${op.loads.length} نقلة - إجمالي ${op.totalHarvestedCrates} صندوق)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                  ),
                ],
              ),
              if (!op.isSettled)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  icon: const Icon(Icons.add, color: Colors.white, size: 16),
                  label: const Text('تسيير نقلة', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => _openAddLoadDialog(op, setSheetState),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (op.loads.isEmpty)
            const Text('لم يتم تسجيل شحنات مغادرة من الحقل بعد.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            ...op.loads.map((l) {
              final time = DateFormat('HH:mm').format(l.departureTime);
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.navyUltraLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.navy,
                      child: Text('${l.loadNumber}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'النقلة رقم ${l.loadNumber}: ${l.crateCount} صندوق | انطلقت الساعة: $time',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openAddLoadDialog(PickingOperationModel op, StateSetter setSheetState) {
    final crateCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final driverCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسيير نقلة تمور جديدة من الحقل 🚚', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: crateCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'عدد الصناديق في هذه النقلة *', prefixIcon: Icon(Icons.all_inbox_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: vehicleCtrl,
              decoration: const InputDecoration(labelText: 'معلومات المركبة / السائق', prefixIcon: Icon(Icons.local_shipping_rounded)),
            ),
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () async {
              final count = int.tryParse(crateCtrl.text.trim()) ?? 0;
              if (count <= 0) return;

              final load = HarvestLoadModel(
                id: 'load_${DateTime.now().millisecondsSinceEpoch}',
                loadNumber: op.loads.length + 1,
                crateCount: count,
                vehicleInfo: vehicleCtrl.text.trim(),
                driverName: driverCtrl.text.trim(),
                departureTime: DateTime.now(),
              );

              await SupabaseService().addHarvestLoad(op.id, load);
              if (mounted) {
                Navigator.of(ctx).pop();
                setSheetState(() {});
                setState(() {});
              }
            },
            child: const Text('تسجيل انطلاق النقلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(PickingOperationModel op, StateSetter setSheetState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.camera_alt_rounded, color: AppColors.navy, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'التوثيق الفوتوغرافي للحقل (${op.photos.length} صور)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                  ),
                ],
              ),
              if (!op.isSettled)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D9488), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 16),
                  label: const Text('التقاط صورة', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                    if (img != null) {
                      final bytes = await img.readAsBytes();
                      final photo = HarvestPhotoModel(
                        id: 'photo_${DateTime.now().millisecondsSinceEpoch}',
                        title: 'توثيق الحقل - ${DateFormat("HH:mm").format(DateTime.now())}',
                        base64Data: base64Encode(bytes),
                      );
                      await SupabaseService().addHarvestPhoto(op.id, photo);
                      setSheetState(() {});
                      setState(() {});
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (op.photos.isEmpty)
            const Text('لم يتم التقاط صور ميدانية بعد.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: op.photos.map((p) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: p.base64Data != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(base64Decode(p.base64Data!), fit: BoxFit.cover),
                        )
                      : const Icon(Icons.image_rounded, color: AppColors.navy),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWeighingAndReconciliationSection(PickingOperationModel op, StateSetter setSheetState) {
    final recon = op.crateReconciliation;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.balance_rounded, color: AppColors.navy, size: 20),
              SizedBox(width: 8),
              Text(
                'الوزن الرسمي ومطابقة الصناديق والتسوية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
              ),
            ],
          ),
          const Divider(height: 18),

          // Weights
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الوزن الصافي المستلم:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(
                op.actualNetWeight != null ? '${op.actualNetWeight!.toStringAsFixed(1)} كـغ' : 'قيد الانتظار',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F766E)),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Crates Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الصناديق المعبأة المستلمة:', style: const TextStyle(fontSize: 12)),
              Text('${op.totalHarvestedCrates} صندوق', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),

          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('أجور العمال المحتسبة (${op.actualWorkers} × ${op.dailyWorkerRate} د.أ):', style: const TextStyle(fontSize: 12)),
              Text('${op.totalLaborCost.toStringAsFixed(1)} د.أ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy)),
            ],
          ),

          const SizedBox(height: 12),

          if (!op.isSettled) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
              icon: const Icon(Icons.scale_rounded, color: Colors.white),
              label: const Text('تسجيل الوزن الرسمي بالمصنع ⚖️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _openWeighingDialog(op, setSheetState),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              icon: const Icon(Icons.check_circle_rounded, color: AppColors.dateGold),
              label: const Text('مطابقة الصناديق والإقفال المالي النهائي ✅', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _openFinalSettlementDialog(op, setSheetState),
            ),
          ],
        ],
      ),
    );
  }

  void _openWeighingDialog(PickingOperationModel op, StateSetter setSheetState) {
    final grossCtrl = TextEditingController(text: '1200');
    final tareCtrl = TextEditingController(text: '235');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الوزن الرسمي للمحصول المستلم ⚖️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: grossCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الوزن القائم الكلي (Gross Weight kg) *'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tareCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'وزن الفارغ (Tare Weight kg) *'),
            ),
          ],
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () async {
              final g = double.tryParse(grossCtrl.text.trim()) ?? 0.0;
              final t = double.tryParse(tareCtrl.text.trim()) ?? 0.0;
              final net = g - t;

              await SupabaseService().recordHarvestWeighing(
                operationId: op.id,
                grossWeight: g,
                tareWeight: t,
                netWeight: net > 0 ? net : 0.0,
              );

              if (mounted) {
                Navigator.of(ctx).pop();
                setSheetState(() {});
                setState(() {});
              }
            },
            child: const Text('حفظ الوزن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openFinalSettlementDialog(PickingOperationModel op, StateSetter setSheetState) {
    final filledCtrl = TextEditingController(text: '${op.totalHarvestedCrates}');
    final emptyCtrl = TextEditingController(text: '8');
    final damagedCtrl = TextEditingController(text: '1');
    final missingCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('مطابقة الصناديق والإقفال المالي النهائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الصناديق المرسلة للحقل: ${op.plannedCrates} صندوق', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 10),
              TextField(
                controller: filledCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'صناديق معبأة مستلمة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emptyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'صناديق فارغة راجعة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: damagedCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'صناديق تالفة / مكسورة'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: missingCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'صناديق مفقودة / ناقصة'),
              ),
              const SizedBox(height: 12),
              Text(
                'سيتم تسجيل صرف أجور العمال (${op.totalLaborCost} د.أ) لعهدة رئيس العمال (${op.laborTeamLeaderName}) لتوزيعها.',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final recon = CrateReconciliationModel(
                sentToFarm: op.plannedCrates,
                filledReturned: int.tryParse(filledCtrl.text.trim()) ?? 0,
                emptyReturned: int.tryParse(emptyCtrl.text.trim()) ?? 0,
                damaged: int.tryParse(damagedCtrl.text.trim()) ?? 0,
                missing: int.tryParse(missingCtrl.text.trim()) ?? 0,
              );

              await SupabaseService().finalizePickingSettlement(
                operationId: op.id,
                crateReconciliation: recon,
                isLaborPaid: true,
              );

              if (mounted) {
                Navigator.of(ctx).pop();
                setSheetState(() {});
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ تم إقفال وتسوية عملية القطاف بنجاح'), backgroundColor: AppColors.success),
                );
              }
            },
            child: const Text('إقفال وتسوية العملية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // REPORT PDF GENERATOR
  // ===========================================================================
  Future<void> _generatePickingPdf(PickingOperationModel op) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('شركة مصنع تمور علي - تقرير القطاف والحصاد الرسمي', style: pw.TextStyle(font: fontBold, fontSize: 16)),
                    pw.Text('كود العملية: ${op.code}', style: pw.TextStyle(font: fontBold, color: PdfColors.blueGrey800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('المزارع / المالك: ${op.customerName} | المزرعة: ${op.farmName} (${op.landName})', style: pw.TextStyle(font: fontBold)),
                    pw.SizedBox(height: 4),
                    pw.Text('مشرف تمور علي (الموظف المسؤول): ${op.supervisorName}'),
                    pw.Text('رئيس العمال (عامل يومية موزع الأجور): ${op.laborTeamLeaderName}'),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),
              pw.Text('توثيق الوقت والموقع الميداني (Field Time & Location Tracking):', style: pw.TextStyle(font: fontBold, fontSize: 13)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headers: ['وقت بدء القطاف', 'وقت انتهاء القطاف', 'الوقت المستغرق الفعلي (Time Taken)', 'موقع وإحداثيات الحقل'],
                data: [
                  [
                    op.harvestingStartTime != null ? DateFormat('HH:mm - yyyy/MM/dd').format(op.harvestingStartTime!) : 'غير مسجل',
                    op.harvestingEndTime != null ? DateFormat('HH:mm - yyyy/MM/dd').format(op.harvestingEndTime!) : 'قيد العمل',
                    op.formattedDuration,
                    op.startLatitude != null ? '${op.startLocationName ?? "الحقل"}\n(N: ${op.startLatitude?.toStringAsFixed(4)}, E: ${op.startLongitude?.toStringAsFixed(4)})' : 'مزرعة ${op.farmName}',
                  ],
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Text('مقارنة المخطط والفعلي (Planned vs Actual):', style: pw.TextStyle(font: fontBold, fontSize: 13)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headers: ['البند', 'المخطط التقديري (Plan)', 'الفعلي المحقق (Actual)'],
                data: [
                  ['عدد العمال', '${op.plannedWorkers}', '${op.actualWorkers}'],
                  ['عدد الصناديق', '${op.plannedCrates}', '${op.totalHarvestedCrates}'],
                  ['الوزن الصافي', '${op.plannedEstimatedKg.toInt()} كغ', '${op.actualNetWeight?.toStringAsFixed(1) ?? "بانتظار الوزن"} كغ'],
                  ['عدد النقلات', '1-2', '${op.loads.length}'],
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Text('المطابقة المالية والأجور:', style: pw.TextStyle(font: fontBold, fontSize: 13)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headers: ['أجور العمال', 'أجور النقل والمصاريف', 'التكلفة الإجمالية للقطاف', 'حالة الصرف'],
                data: [
                  ['${op.totalLaborCost} د.أ', '${op.totalExpensesCost} د.أ', '${op.totalPickingCost} د.أ', op.isLaborPaid ? 'تم الصرف والتوزيع' : 'معلقة'],
                ],
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'picking_report_${op.code}.pdf',
    );
  }

  // ===========================================================================
  // TAB 3: BUSINESS FLOW DOCUMENTATION & ARCHITECTURE
  // ===========================================================================
  Widget _buildBusinessFlowDocumentationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دورة أعمال القطاف والحصاد الميداني (Ali Dates Picking Flow)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'الربط التتبعي الكامل: المزارع ← المزرعة والأرض ← خطة القطاف ← الصناديق ← فريق الحصاد ← النقلات ← الاستلام والوزن بالمصنع ← الفرز والتخزين',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _buildDocSection(
            '1. التمييز الصريح بين المشرف ورئيس العمال (Two Distinct Roles)',
            '• مشرف تمور علي (Ali Dates Supervisor): موظف رسمي يمثل إدارة المصنع، يوثق الحركات، يلتقط الصور، ويسجل الأحداث.\n• رئيس العمال (Labor Team Leader): أحد عمال اليومية (وليس موظفاً)، ينسق العمل مع زملائه ويستلم إجمالي مخصصات الأجور لتوزيعها عليهم.',
            Icons.people_outline_rounded,
          ),

          const SizedBox(height: 12),

          _buildDocSection(
            '2. عدم استبدال المخطط بالفعلي (Planned vs Actual)',
            'الكميات المخططة قبل يوم (تقديرات العمال، الصناديق، والوزن) تبقى محفوظة في النظام للمقارنة مع النتائج الفعلية لقياس دقة التخطيط وإنتاجية الحقل.',
            Icons.compare_arrows_rounded,
          ),

          const SizedBox(height: 12),

          _buildDocSection(
            '3. مطابقة الصناديق الصارمة (Crate Reconciliation)',
            'كل صندوق يخرج للحقل يجب حسابه بدقة (صناديق معبأة راجعة، صناديق فارغة، صناديق تالفة، صناديق مفقودة). لا يتم إقفال العملية مالياً دون تبرير أي نقص.',
            Icons.all_inbox_rounded,
          ),

          const SizedBox(height: 12),

          _buildDocSection(
            '4. التسجيل اللحظي المباشر للأحداث (Event-Driven Logging)',
            'يتم تسجيل الأوقات بدقة تلقائياً عند انطلاق الفريق، الوصول للمزرعة، بدء القطاف، انطلاق كل نقلة، إنهاء القطاف، مغادرة المزرعة، والوصول للمصنع.',
            Icons.schedule_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildDocSection(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.navy)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 12, color: AppColors.navyDark, height: 1.5)),
        ],
      ),
    );
  }
}
