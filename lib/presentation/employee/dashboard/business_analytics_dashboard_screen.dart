import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';

/// Executive Business Intelligence & Analytics Dashboard (لوحة تحكم الأعمال الشاملة)
/// 
/// Features:
/// 1. Tab 1: Freezer Capacity Analysis (تحليل سعة الفريزرات):
///    - Interactive Line Chart showing occupied pallets vs capacity percentage
///    - Number of pallets and capacity clearly displayed beside each bar/point
///    - Editable capacities for each freezer with live recalculation
/// 2. Tab 2: 100k Plastic Field Boxes Stock & Balances (مخزون وحركات صناديق الحقل):
///    - Stock meter showing total (default 100k, editable) and available boxes in factory
///    - Automatic deduction whenever boxes are given to customers (Outbound)
///    - Live breakdown table of boxes held by each customer
/// 3. Tab 3: Customer Goods & Dates Yield Breakdown (تحليل بضائع وتمور العملاء):
///    - Master Processed Goods Pie Chart & Category Yield Breakdown
///    - Toggle slider for Dates Ownership: All / Ali Dates Owned Only / Customer Owned Only
///    - Detailed analysis of each customer's goods with rounded numbers & percentages
class BusinessAnalyticsDashboardScreen extends StatefulWidget {
  const BusinessAnalyticsDashboardScreen({super.key});

  @override
  State<BusinessAnalyticsDashboardScreen> createState() =>
      _BusinessAnalyticsDashboardScreenState();
}

class _BusinessAnalyticsDashboardScreenState
    extends State<BusinessAnalyticsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _customerSearchQuery = '';

  // Ownership Filter: 'all' = الكل, 'ali_dates' = تمور علي فقط, 'customers' = تمور المزارعين والعملاء
  String _ownershipFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    SupabaseService().addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    SupabaseService().removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  // --- Dialog: Edit Freezer Capacities ---
  void _openEditCapacityDialog(BuildContext context, String locationKey, String locationName, int currentCapacity) {
    final controller = TextEditingController(text: currentCapacity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.ac_unit_rounded, color: AppColors.navy),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'تعديل سعة: $locationName',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل السعة الاستيعابية القصوى للطبالي في هذا الفريزر:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'السعة القصوى (طبلية)',
                suffixText: 'طبلية',
                prefixIcon: const Icon(Icons.inventory_2_rounded, color: AppColors.navy),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () async {
              final newCap = int.tryParse(controller.text.trim());
              if (newCap != null && newCap > 0) {
                await SupabaseService().updateFreezerCapacity(locationKey, newCap);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث سعة $locationName إلى $newCap طبلية'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ السعة'),
          ),
        ],
      ),
    );
  }

  // --- Dialog: Edit Total Company Boxes Stock ---
  void _openEditTotalBoxesDialog(BuildContext context, int currentTotal) {
    final controller = TextEditingController(text: currentTotal.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.all_inbox_rounded, color: AppColors.navy),
            SizedBox(width: 8),
            Text(
              'تعديل مخزون الصناديق الكلي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجمالي عدد صناديق الحقل البلاستيكية المملوكة لشركة تمور علي:',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'المخزون الكلي (صندوق)',
                suffixText: 'صندوق',
                prefixIcon: const Icon(Icons.all_inbox_rounded, color: AppColors.navy),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () async {
              final newStock = int.tryParse(controller.text.trim());
              if (newStock != null && newStock >= 0) {
                await SupabaseService().updateTotalCompanyBoxes(newStock);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تحديث رصيد الصناديق الكلي إلى ${NumberFormat("#,###").format(newStock)} صندوق'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              }
            },
            child: const Text('حفظ الرصيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(
        title: 'لوحة تحكم الأعمال والإحصائيات',
        subtitle: 'تحليل الفريزرات، الصناديق ومحصول العملاء',
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
                  icon: Icon(Icons.ac_unit_rounded, size: 18),
                  text: 'سعة الفريزرات',
                ),
                Tab(
                  icon: Icon(Icons.all_inbox_rounded, size: 18),
                  text: 'صناديق الحقل (100k)',
                ),
                Tab(
                  icon: Icon(Icons.analytics_rounded, size: 18),
                  text: 'بضائع ومحصول العملاء',
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
            _buildFreezerCapacityTab(),
            _buildFieldBoxesStockTab(),
            _buildCustomerGoodsAnalysisTab(),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: FREEZER CAPACITY & OCCUPANCY ANALYTICS
  // ===========================================================================
  Widget _buildFreezerCapacityTab() {
    final service = SupabaseService();
    final pallets = service.pallets.where((p) => p.status != 'delivered' && p.status != 'consumed').toList();
    final capacities = service.freezerCapacities;

    final List<Map<String, dynamic>> freezerStats = [
      {
        'key': AppConstants.locPreFridge,
        'name': AppConstants.locationNamesAr[AppConstants.locPreFridge]!,
        'color': const Color(0xFF0288D1),
        'icon': Icons.cleaning_services_rounded,
        'pallets': pallets.where((p) => p.locationType == AppConstants.locPreFridge).length,
        'capacity': capacities[AppConstants.locPreFridge] ?? 60,
      },
      {
        'key': AppConstants.locFirstFridge,
        'name': AppConstants.locationNamesAr[AppConstants.locFirstFridge]!,
        'color': const Color(0xFF00897B),
        'icon': Icons.thermostat_rounded,
        'pallets': pallets.where((p) => p.locationType == AppConstants.locFirstFridge).length,
        'capacity': capacities[AppConstants.locFirstFridge] ?? 90,
      },
      {
        'key': AppConstants.locMainFreezer1,
        'name': AppConstants.locationNamesAr[AppConstants.locMainFreezer1]!,
        'color': const Color(0xFF1565C0),
        'icon': Icons.severe_cold_rounded,
        'pallets': pallets.where((p) => p.locationType == AppConstants.locMainFreezer1).length,
        'capacity': capacities[AppConstants.locMainFreezer1] ?? 270,
      },
      {
        'key': AppConstants.locMainFreezer2,
        'name': AppConstants.locationNamesAr[AppConstants.locMainFreezer2]!,
        'color': const Color(0xFF4527A0),
        'icon': Icons.ac_unit_rounded,
        'pallets': pallets.where((p) => p.locationType == AppConstants.locMainFreezer2).length,
        'capacity': capacities[AppConstants.locMainFreezer2] ?? 270,
      },
      {
        'key': AppConstants.locSmallFreezer,
        'name': AppConstants.locationNamesAr[AppConstants.locSmallFreezer]!,
        'color': const Color(0xFFD84315),
        'icon': Icons.kitchen_rounded,
        'pallets': pallets.where((p) => p.locationType == AppConstants.locSmallFreezer).length,
        'capacity': capacities[AppConstants.locSmallFreezer] ?? 120,
      },
    ];

    final int totalStoredPallets = freezerStats.fold<int>(0, (s, f) => s + (f['pallets'] as int));
    final int totalStorageCapacity = freezerStats.fold<int>(0, (s, f) => s + (f['capacity'] as int));
    final int overallOccupancyPct = totalStorageCapacity > 0
        ? ((totalStoredPallets / totalStorageCapacity) * 100).round()
        : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Overall Warehouse Capacity Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.navyLight],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.navy.withOpacity(0.2),
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
                    const Row(
                      children: [
                        Icon(Icons.warehouse_rounded, color: AppColors.dateGold, size: 24),
                        SizedBox(width: 10),
                        Text(
                          'إجمالي سعة التخزين والتبريد',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'نسبة الإشغال: $overallOccupancyPct%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCapacityMetric('الطبالي المخزنة حالياً', '$totalStoredPallets طبلية', Colors.white),
                    _buildCapacityMetric('السعة الكلية للمصنع', '$totalStorageCapacity طبلية', AppColors.dateGold),
                    _buildCapacityMetric('المساحة الشاغرة', '${totalStorageCapacity - totalStoredPallets} طبلية', const Color(0xFF4ADE80)),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalStorageCapacity > 0 ? (totalStoredPallets / totalStorageCapacity).clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      overallOccupancyPct > 90
                          ? AppColors.error
                          : overallOccupancyPct > 70
                              ? AppColors.warning
                              : AppColors.dateGold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Line Chart: Occupancy Percentage Comparison
          Card(
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
                          Icon(Icons.show_chart_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'مخطط نسب إشغال الفريزرات (%)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                          ),
                        ],
                      ),
                      Text(
                        'معدل السعة الفعلية',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 180,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 25,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              interval: 25,
                              getTitlesWidget: (val, meta) => Text(
                                '${val.toInt()}%',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: 1,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < freezerStats.length) {
                                  final name = freezerStats[idx]['name'].toString().replaceAll('الفريزر ', '').replaceAll('الرئيسي ', 'ر ');
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (freezerStats.length - 1).toDouble(),
                        minY: 0,
                        maxY: 100,
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(freezerStats.length, (i) {
                              final count = freezerStats[i]['pallets'] as int;
                              final cap = freezerStats[i]['capacity'] as int;
                              final pct = cap > 0 ? ((count / cap) * 100).roundToDouble() : 0.0;
                              return FlSpot(i.toDouble(), pct.clamp(0.0, 100.0));
                            }),
                            isCurved: true,
                            color: AppColors.navy,
                            barWidth: 3.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                radius: 5,
                                color: freezerStats[index]['color'] as Color,
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: AppColors.navy.withOpacity(0.08),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Detailed Freezer Occupancy List with Edit Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'تفصيل الفريزرات وتعديل السعات',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const Text(
                'اضغط على زر القلم لتعديل السعة',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ...freezerStats.map((freezer) {
            final int currentPallets = freezer['pallets'] as int;
            final int capacity = freezer['capacity'] as int;
            final int pct = capacity > 0 ? ((currentPallets / capacity) * 100).round() : 0;
            final Color color = freezer['color'] as Color;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(freezer['icon'] as IconData, color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                freezer['name'] as String,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$currentPallets طبلية من أصل $capacity طبلية',
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        // Occupancy Badge (Rounded %)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pct > 90
                                ? const Color(0xFFFFEBEE)
                                : pct > 70
                                    ? const Color(0xFFFFF3E0)
                                    : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: pct > 90
                                  ? AppColors.error
                                  : pct > 70
                                      ? AppColors.warning
                                      : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Edit Capacity Button
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.navy),
                          tooltip: 'تعديل السعة الاستيعابية',
                          onPressed: () => _openEditCapacityDialog(
                            context,
                            freezer['key'] as String,
                            freezer['name'] as String,
                            capacity,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: capacity > 0 ? (currentPallets / capacity).clamp(0.0, 1.0) : 0.0,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
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

  Widget _buildCapacityMetric(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 2: 100K PLASTIC FIELD BOXES STOCK & CUSTOMER ALLOCATION
  // ===========================================================================
  Widget _buildFieldBoxesStockTab() {
    final service = SupabaseService();
    final int totalStock = service.totalCompanyBoxes;
    final int totalWithCustomers = service.totalBoxesWithCustomers;
    final int availableInFactory = service.availableBoxesInFactory;
    final int distributedPct = totalStock > 0 ? ((totalWithCustomers / totalStock) * 100).round() : 0;

    final customers = service.getCustomerContacts();
    final filteredCustomers = _customerSearchQuery.isEmpty
        ? customers
        : customers.where((c) => c.name.toLowerCase().contains(_customerSearchQuery.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Boxes Stock Master Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D40), Color(0xFF00796B)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004D40).withOpacity(0.25),
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
                    const Row(
                      children: [
                        Icon(Icons.all_inbox_rounded, color: AppColors.dateGold, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'رصيد ومخزون صناديق الحقل',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: Colors.white70, size: 20),
                      tooltip: 'تعديل رصيد الصناديق الكلي',
                      onPressed: () => _openEditTotalBoxesDialog(context, totalStock),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildBoxesMetric('المتاح في المصنع', NumberFormat('#,###').format(availableInFactory), const Color(0xFF69F0AE)),
                    _buildBoxesMetric('المتداول مع العملاء', NumberFormat('#,###').format(totalWithCustomers), const Color(0xFFFFD54F)),
                    _buildBoxesMetric('المخزون الكلي', NumberFormat('#,###').format(totalStock), Colors.white),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalStock > 0 ? (totalWithCustomers / totalStock).clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD54F)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'نسبة التوزيع للعملاء: $distributedPct% من إجمالي المخزون',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 2. Search Field
          TextField(
            onChanged: (val) => setState(() => _customerSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'بحث باسم العميل لمعرفة رصيد صناديقه...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.navy),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 3. Customer Boxes Allocation List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'أرصدة الصناديق لدى العملاء (${filteredCustomers.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              Text(
                'إجمالي: ${NumberFormat("#,###").format(totalWithCustomers)} صندوق',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dateBronze),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (filteredCustomers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('لا توجد نتائج مطابقة لبحثك', style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredCustomers.length,
              itemBuilder: (ctx, i) {
                final customer = filteredCustomers[i];
                final int boxesHeld = service.getBoxesHeldByCustomer(customer.id);
                final palletsCount = service.pallets.where((p) => p.customerId == customer.id && p.status != 'delivered' && p.status != 'consumed').length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: boxesHeld > 0 ? const Color(0xFFE0F2F1) : Colors.grey.shade100,
                      child: Icon(
                        Icons.inventory_2_rounded,
                        color: boxesHeld > 0 ? const Color(0xFF00796B) : Colors.grey,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                    ),
                    subtitle: Text(
                      '$palletsCount طبلية مخزنة بالمصنع | الهاتف: ${customer.phone.startsWith("odoo") ? "سجل Odoo" : customer.phone}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat("#,###").format(boxesHeld)} صندوق',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: boxesHeld > 0 ? const Color(0xFF00796B) : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          boxesHeld > 0 ? 'بحوزة العميل' : 'لا توجد صناديق',
                          style: TextStyle(fontSize: 10, color: boxesHeld > 0 ? AppColors.dateBronze : Colors.grey),
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

  Widget _buildBoxesMetric(String title, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: CUSTOMER GOODS & DATES YIELD BREAKDOWN
  // ===========================================================================
  Widget _buildCustomerGoodsAnalysisTab() {
    final service = SupabaseService();
    final allCustomers = service.getCustomerContacts();
    final rawActivePallets = service.pallets.where((p) => p.status != 'delivered' && p.status != 'consumed').toList();
    final rawSortingBatches = service.sortingBatches;

    // Filter by Ownership Slider: 'all', 'ali_dates', 'customers'
    final activePallets = rawActivePallets.where((p) {
      if (_ownershipFilter == 'ali_dates') return p.isOwnedByAliDates;
      if (_ownershipFilter == 'customers') return !p.isOwnedByAliDates;
      return true;
    }).toList();

    final sortingBatches = rawSortingBatches.where((b) {
      final isAliBatch = (b.customerName ?? '').toLowerCase().contains('ali') ||
          (b.customerName ?? '').contains('علي');
      if (_ownershipFilter == 'ali_dates') return isAliBatch;
      if (_ownershipFilter == 'customers') return !isAliBatch;
      return true;
    }).toList();

    final customers = allCustomers.where((c) {
      final isAliCust = c.name.toLowerCase().contains('ali') || c.name.contains('علي') || c.isEmployee;
      if (_ownershipFilter == 'ali_dates') return isAliCust;
      if (_ownershipFilter == 'customers') return !isAliCust;
      return true;
    }).toList();

    final int totalStoredWeight = activePallets.fold<double>(0.0, (s, p) => s + p.netWeight).round();
    final int totalSortedOutput = sortingBatches.where((b) => b.status == 'completed').fold<double>(0.0, (s, b) => s + b.outputWeight).round();
    final int totalWaste = sortingBatches.where((b) => b.status == 'completed').fold<double>(0.0, (s, b) => s + b.wasteWeight).round();

    // Aggregate all processed goods across the factory by category
    final Map<String, int> factoryCategoryWeights = {};
    final Map<String, int> factoryCategoryBoxes = {};

    for (final b in sortingBatches.where((b) => b.status == 'completed')) {
      for (final out in b.outputPallets) {
        factoryCategoryWeights[out.category] = (factoryCategoryWeights[out.category] ?? 0) + out.weight.round();
        factoryCategoryBoxes[out.category] = (factoryCategoryBoxes[out.category] ?? 0) + out.boxCount;
      }
    }

    // Colors palette for sorting categories
    final List<Color> chartColors = [
      const Color(0xFF1565C0), // Premium - Blue
      const Color(0xFF00897B), // Delight - Teal
      const Color(0xFFE65100), // Classic - Orange
      const Color(0xFF6A1B9A), // Soft Premium - Purple
      const Color(0xFFC62828), // Red A - Red
      const Color(0xFFAD1457), // Red B - Pink
      const Color(0xFFF9A825), // Bon Bon - Amber
      const Color(0xFF455A64), // Pre-sorted - Slate
    ];

    final sortedCategoryEntries = factoryCategoryWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. OWNERSHIP FILTER SLIDER / SEGMENTED CONTROL
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                _buildOwnershipSegment(
                  title: 'كافة التمور بالمصنع',
                  key: 'all',
                  icon: Icons.all_inclusive_rounded,
                ),
                _buildOwnershipSegment(
                  title: 'تمور ملك "تمور علي"',
                  key: 'ali_dates',
                  icon: Icons.verified_user_rounded,
                ),
                _buildOwnershipSegment(
                  title: 'تمور المزارعين والعملاء',
                  key: 'customers',
                  icon: Icons.people_alt_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 2. Grand Totals Header (Rounded Numbers)
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'إجمالي طبالي التمور',
                  value: '${activePallets.length} طبلية',
                  subtitle: '${NumberFormat("#,###").format(totalStoredWeight)} كغ صافي',
                  icon: Icons.layers_rounded,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'مخرجات الفرز المنجز',
                  value: '${NumberFormat("#,###").format(totalSortedOutput)} كغ',
                  subtitle: '${sortingBatches.where((b) => b.status == "completed").length} دفعة منجزة ($totalWaste كغ فاقد)',
                  icon: Icons.task_alt_rounded,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 3. MASTER PROCESSED GOODS & CATEGORIES CHART (All Processed Yield)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
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
                            'مخطط توزيع مخرجات الفرز والأصناف',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                          ),
                        ],
                      ),
                      Text(
                        'إجمالي المحصول المفرز',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  if (sortedCategoryEntries.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'لم يتم تسجيل دفعات فرز منجزة بعد لعرض المخطط البياني.\nستظهر الأصناف هنا بمجرد إنهاء عمليات الفرز.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else ...[
                    // Pie Chart & Legend
                    SizedBox(
                      height: 190,
                      child: Row(
                        children: [
                          // Pie Chart
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2.5,
                                centerSpaceRadius: 36,
                                sections: List.generate(sortedCategoryEntries.length, (i) {
                                  final entry = sortedCategoryEntries[i];
                                  final int pct = totalSortedOutput > 0 ? ((entry.value / totalSortedOutput) * 100).round() : 0;
                                  final color = chartColors[i % chartColors.length];
                                  return PieChartSectionData(
                                    color: color,
                                    value: entry.value.toDouble(),
                                    title: '$pct%',
                                    radius: 44,
                                    titleStyle: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Quick Legend
                          Expanded(
                            flex: 4,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List.generate(
                                sortedCategoryEntries.length.clamp(0, 5),
                                (i) {
                                  final entry = sortedCategoryEntries[i];
                                  final color = chartColors[i % chartColors.length];
                                  final int pct = totalSortedOutput > 0 ? ((entry.value / totalSortedOutput) * 100).round() : 0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${NumberFormat("#,###").format(entry.value)} كغ ($pct%)',
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Detailed Category Breakdown Table Under the Chart (All Numbers Rounded)
                    const Text(
                      'تفاصيل مخرجات الأصناف والكميات (المعلومات التفصيلية):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                    ),
                    const SizedBox(height: 10),

                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(AppColors.navyUltraLight),
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 12),
                          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(label: Text('الصنف / الجودة')),
                            DataColumn(label: Text('الوزن الصافي')),
                            DataColumn(label: Text('الصناديق')),
                            DataColumn(label: Text('النسبة')),
                          ],
                          rows: List.generate(sortedCategoryEntries.length, (i) {
                            final entry = sortedCategoryEntries[i];
                            final color = chartColors[i % chartColors.length];
                            final boxes = factoryCategoryBoxes[entry.key] ?? 0;
                            final int pct = totalSortedOutput > 0 ? ((entry.value / totalSortedOutput) * 100).round() : 0;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                DataCell(Text('${NumberFormat("#,###").format(entry.value)} كغ')),
                                DataCell(Text('$boxes صندوق')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '$pct%',
                                      style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. Breakdown per Customer (Rounded Weights)
          const Text(
            'تفصيل محصول وطبالي كل عميل',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.navy),
          ),
          const SizedBox(height: 10),

          ...customers.map((cust) {
            final custPallets = activePallets.where((p) => p.customerId == cust.id).toList();
            final custBatches = sortingBatches.where((b) => b.customerId == cust.id).toList();

            final int grossTotal = custPallets.fold<double>(0.0, (s, p) => s + p.grossWeight).round();
            final int netTotal = custPallets.fold<double>(0.0, (s, p) => s + p.netWeight).round();

            // Category breakdown for this customer
            final Map<String, int> categoryWeights = {};
            final Map<String, int> sizeCounts = {};

            for (final p in custPallets) {
              final cat = p.category ?? (p.isPresorted ? 'مفروز أولي' : 'غير مفروز');
              categoryWeights[cat] = (categoryWeights[cat] ?? 0) + p.netWeight.round();

              final sz = p.size ?? 'مشكل';
              sizeCounts[sz] = (sizeCounts[sz] ?? 0) + 1;
            }

            // Also aggregate from completed sorting batch outputs
            for (final b in custBatches) {
              for (final out in b.outputPallets) {
                categoryWeights[out.category] = (categoryWeights[out.category] ?? 0) + out.weight.round();
                sizeCounts[out.size] = (sizeCounts[out.size] ?? 0) + 1;
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: custPallets.isNotEmpty ? AppColors.navyUltraLight : Colors.grey.shade100,
                  child: Text(
                    cust.name.isNotEmpty ? cust.name.substring(0, 1) : 'ع',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: custPallets.isNotEmpty ? AppColors.navy : Colors.grey,
                    ),
                  ),
                ),
                title: Text(
                  cust.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                ),
                subtitle: Text(
                  '${custPallets.length} طبلية | صافي: ${NumberFormat("#,###").format(netTotal)} كغ (القائم: ${NumberFormat("#,###").format(grossTotal)} كغ)',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  const Divider(),
                  // Category breakdown tags
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('توزيع أصناف التمور والجودة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                  ),
                  const SizedBox(height: 6),
                  if (categoryWeights.isEmpty)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('لا توجد طبالي تمور مسجلة حالياً', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: categoryWeights.entries.map((e) {
                        return Chip(
                          backgroundColor: AppColors.navyUltraLight,
                          label: Text(
                            '${e.key}: ${NumberFormat("#,###").format(e.value)} كغ',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 10),

                  // Size breakdown tags
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('توزيع الأحجام (Sizes):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy)),
                  ),
                  const SizedBox(height: 6),
                  if (sizeCounts.isEmpty)
                    const Align(
                      alignment: Alignment.centerRight,
                      child: Text('لا توجد أحجام مفروزة بعد', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: sizeCounts.entries.map((e) {
                        return Chip(
                          backgroundColor: const Color(0xFFFFF3E0),
                          label: Text(
                            '${e.key}: ${e.value} طبلية',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD84315)),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOwnershipSegment({
    required String title,
    required String key,
    required IconData icon,
  }) {
    final isSelected = _ownershipFilter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _ownershipFilter = key),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.dateGold : AppColors.textSecondary,
              ),
              const SizedBox(height: 3),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.navy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
