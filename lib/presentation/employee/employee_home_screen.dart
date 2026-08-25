import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../widgets/app_brand_logo.dart';
import '../widgets/full_pallet_info_dialog.dart';
import '../widgets/qr_camera_scanner_dialog.dart';
import 'receiving/receiving_step1_screen.dart';
import 'transfer/transfer_home_screen.dart';
import 'sorting/sorting_home_screen.dart';
import 'delivery/delivery_step1_screen.dart';
import 'harvesting/harvesting_home_screen.dart';
import 'dashboard/business_analytics_dashboard_screen.dart';
import '../admin/admin_management_screen.dart';

/// Employee Home Screen for Ali Dates
/// Perfectly balanced 4 equal-sized quarters (2x2) responsive to any screen size
class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  @override
  void initState() {
    super.initState();
    SupabaseService().addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    SupabaseService().removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  void _showEditProfileNameDialog(SupabaseService service) {
    final nameCtrl = TextEditingController(text: service.currentUser?.name ?? 'علي الشريف');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_rounded, color: AppColors.navy),
            SizedBox(width: 8),
            Text('تعديل اسم الموظف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الاسم الظاهر في النظام والتقارير الرسمية:', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.badge_rounded),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
            onPressed: () async {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty && service.currentUser != null) {
                await service.updateProfileName(service.currentUser!.id, newName);
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الاسم بنجاح'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            child: const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final employeeName = service.currentUser?.name ?? 'علي الشريف';
    final hasOngoing = service.hasOngoingSorting;
    final ongoingCount = service.ongoingSortingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 4,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            const AppBrandLogo(size: 38),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_rounded,
                          color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          employeeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'لوحة تحكم موظفي مصنع تمور علي',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (service.currentUser?.isAdmin == true ||
              (service.currentUser?.name.contains('خالد') ?? false) ||
              (service.currentUser?.name.contains('حسام') ?? false) ||
              (service.currentUser?.name.contains('علي') ?? false) ||
              (service.currentUser?.name.contains('عثمان') ?? false)) ...[
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.dateGold),
              tooltip: 'لوحة الإدارة والتحكم (Admin)',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminManagementScreen(),
                  ),
                );
              },
            ),
          ],
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: AppColors.dateGold),
            tooltip: 'لوحة تحكم الأعمال والإحصائيات',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BusinessAnalyticsDashboardScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: Colors.white),
            tooltip: 'تعديل اسم الموظف',
            onPressed: () => _showEditProfileNameDialog(service),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'تسجيل الخروج',
            onPressed: () {
              service.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth;
            final availableHeight = constraints.maxHeight;

            // Responsive container width for desktop/tablet/mobile
            final contentWidth = availableWidth > 700 ? 640.0 : availableWidth;

            return Center(
              child: SizedBox(
                width: contentWidth,
                height: availableHeight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Quick Instant Scanner Button (مسح فوري للطبلية لعرض كامل التفاصيل)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.dateGold, width: 1.5),
                            ),
                          ),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 26, color: AppColors.dateGold),
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مسح سريع (Scan Only)',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    'تشغيل فوري للكاميرا وعرض كافة تفاصيل الطبلية والموقع',
                                    style: TextStyle(fontSize: 10.5, color: Colors.white70),
                                  ),
                                ],
                              ),
                              Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                            ],
                          ),
                          onPressed: () {
                            QrCameraScannerDialog.show(
                              context,
                              onPalletScanned: (scannedPallet) {
                                FullPalletInfoDialog.show(context, scannedPallet);
                              },
                            );
                          },
                        ),
                      ),

                      // 5th Master Field Operation: القطاف والحصاد الميداني (Harvesting)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const HarvestingHomeScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(18),
                            splashColor: const Color(0xFFD97706).withAlpha(50),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFD97706).withAlpha(120), width: 2),
                                gradient: LinearGradient(
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                  colors: [
                                    const Color(0xFFFEF3C7).withOpacity(0.55),
                                    Colors.white,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFD97706).withAlpha(25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withAlpha(35),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.agriculture_rounded, color: Color(0xFFD97706), size: 28),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '5. قطاف وحصاد',
                                              style: TextStyle(
                                                color: Color(0xFF92400E),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '(Harvesting)',
                                              style: TextStyle(
                                                color: AppColors.textMuted,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'جدولة القطاف، إرسال الصناديق، تسيير النقلات، ومطابقة المحصول',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 11.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFD97706), size: 18),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 4 Equal Screen Quarters (2x2 Grid)
                      Expanded(
                        child: Column(
                          children: [
                            // TOP ROW (Quarter 1 & Quarter 2)
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. استلام (Receiving)
                                  Expanded(
                                    child: _buildQuarterButton(
                                      title: 'استلام',
                                      subtitle: 'شحنات التمور وصناديق الحقل',
                                      icon: Icons.move_to_inbox_rounded,
                                      color: const Color(0xFF1E88E5),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const ReceivingStep1Screen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // 2. نقل (Transfer)
                                  Expanded(
                                    child: _buildQuarterButton(
                                      title: 'نقل',
                                      subtitle: 'المواقع، الفريزر، والجدولة',
                                      icon: Icons.alt_route_rounded,
                                      color: const Color(0xFF00897B),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const TransferHomeScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // BOTTOM ROW (Quarter 3 & Quarter 4)
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 3. فرز (Sorting) with RED DOT BADGE
                                  Expanded(
                                    child: _buildQuarterButton(
                                      title: 'فرز',
                                      subtitle: 'خطوط الفرز الأولي والآلي',
                                      icon: Icons.filter_alt_rounded,
                                      color: const Color(0xFFE65100),
                                      badgeCount: ongoingCount,
                                      showRedBadge: hasOngoing,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const SortingHomeScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // 4. تسليم (Delivery)
                                  Expanded(
                                    child: _buildQuarterButton(
                                      title: 'تسليم',
                                      subtitle: 'تسليم التمور والصناديق للعميل',
                                      icon: Icons.local_shipping_rounded,
                                      color: const Color(0xFF2E7D32),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const DeliveryStep1Screen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuarterButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool showRedBadge = false,
    int badgeCount = 0,
  }) {
    return Stack(
      children: [
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(22),
              splashColor: color.withAlpha(50),
              highlightColor: color.withAlpha(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: color.withAlpha(90), width: 2),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      color.withAlpha(20),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withAlpha(30),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Big Icon in styled circle
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: color.withAlpha(25),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withAlpha(50), width: 1.5),
                      ),
                      child: Icon(icon, color: color, size: 42),
                    ),
                    const SizedBox(height: 14),
                    // Title
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Prominent Red Notification Dot on Corner for ongoing sorting processes!
        if (showRedBadge)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withAlpha(150),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              child: Center(
                child: Text(
                  badgeCount > 0 ? '$badgeCount' : '!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
