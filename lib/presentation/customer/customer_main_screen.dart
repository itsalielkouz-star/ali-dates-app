import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/pallet_model.dart';
import '../../data/services/supabase_service.dart';
import '../auth/login_screen.dart';
import '../widgets/app_brand_logo.dart';
import '../widgets/qr_camera_scanner_dialog.dart';
import 'customer_dashboard_tab.dart';
import 'customer_inventory_tab.dart';
import 'customer_documents_tab.dart';

/// Ali Dates Customer Portal Main Screen
/// Tabbed Navigation:
/// 1. Dashboard (لوحة التحكم وتتبع الشحنات)
/// 2. Inventory (المخزون الحالي)
/// 3. Documents (مركز الوثائق والأرشيف)
class CustomerMainScreen extends StatefulWidget {
  const CustomerMainScreen({super.key});

  @override
  State<CustomerMainScreen> createState() => _CustomerMainScreenState();
}

class _CustomerMainScreenState extends State<CustomerMainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final customer = service.currentUser ?? service.getCustomerContacts().first;

    final tabs = [
      CustomerDashboardTab(customer: customer),
      CustomerInventoryTab(customer: customer),
      CustomerDocumentsTab(customer: customer),
    ];

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
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'بوابة عملاء ومزارعي تمور علي',
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
          // Customer Pallet QR Scanner
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.dateGold),
            tooltip: 'مسح واستعلام طبلية',
            onPressed: () => _openCustomerPalletScanner(customer),
          ),
          // Notification Bell with Red Dot
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                tooltip: 'التنبيهات',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث حالة دفعة التمور الخاصة بك: مجدولة للفرز الآلي'),
                      backgroundColor: AppColors.navy,
                    ),
                  );
                },
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
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
      body: tabs[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.navy,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          elevation: 0,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              activeIcon: Icon(Icons.dashboard_customize_rounded),
              label: 'لوحة التحكم',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2_rounded),
              label: 'المخزون الحالي',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_shared_outlined),
              activeIcon: Icon(Icons.folder_shared_rounded),
              label: 'مركز الوثائق',
            ),
          ],
        ),
      ),
    );
  }

  void _openCustomerPalletScanner(UserProfile customer) {
    QrCameraScannerDialog.show(
      context,
      onPalletScanned: (scannedPallet) {
        // Ownership Check: Check if pallet belongs to this customer
        final isOwner = scannedPallet.customerId == customer.id ||
            scannedPallet.customerName?.trim().toLowerCase() == customer.name.trim().toLowerCase();

        if (!isOwner) {
          // Alert: This is not yours
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 28),
                  SizedBox(width: 8),
                  Text('تنبيه ملكية الطبلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.error)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '❌ هذه الطبلية لا تعود لك (This pallet does not belong to you).',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كود الطبلية: ${scannedPallet.palletCode}\nالمالك المسجل في النظام: ${scannedPallet.customerName ?? "عميل آخر"}.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('حسناً', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        } else {
          // Success: Display full pallet details
          _showCustomerPalletDetailsDialog(scannedPallet);
        }
      },
    );
  }

  void _showCustomerPalletDetailsDialog(PalletModel p) {
    final statusAr = p.status == 'delivered'
        ? 'تم التسليم'
        : p.status == 'sorted'
            ? 'مفروزة وجاهزة'
            : p.status == 'in_sorting'
                ? 'قيد الفرز'
                : 'مخزنة في المستودع';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 480),
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
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 28),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'طبلية معتمدة: ${p.palletCode}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                          ),
                          const Text('هذه الطبلية مسجلة باسمك في المستودع', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
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

                _buildInfoTile('المالك / المزرعة', '${p.customerName} (${p.farmName ?? "المزرعة الرئيسية"})'),
                _buildInfoTile('التصنيف', p.category ?? 'تمر مجهول'),
                _buildInfoTile('الحجم (Size)', p.size ?? 'عام'),
                _buildInfoTile('الوزن الصافي', '${p.netWeight.toStringAsFixed(1)} كـغ (الإجمالي: ${p.grossWeight.toStringAsFixed(1)} كغ)'),
                _buildInfoTile('عدد الصناديق', '${p.boxCount} صندوق'),
                _buildInfoTile('حالة الفرز', p.isPresorted ? 'تمر مفروز أولي' : 'تمر خام غير مفروز'),
                _buildInfoTile('الموقع التخزيني', p.displayLocation),
                _buildInfoTile('حالة الطبلية', statusAr),
                _buildInfoTile('تاريخ الاستلام والتسجيل', DateFormat('yyyy/MM/dd HH:mm').format(p.createdAt)),

                const SizedBox(height: 16),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.navyDark),
            ),
          ),
        ],
      ),
    );
  }
}

