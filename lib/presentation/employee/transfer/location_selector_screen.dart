import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/warehouse_3d_view.dart';
import '../../widgets/qr_camera_scanner_dialog.dart';
import 'sorting_calendar_modal.dart';
import '../employee_home_screen.dart';

/// Destination Location Selector & 3D Freezer Screen for Transfer
class LocationSelectorScreen extends StatefulWidget {
  final PalletModel pallet;

  const LocationSelectorScreen({
    super.key,
    required this.pallet,
  });

  @override
  State<LocationSelectorScreen> createState() => _LocationSelectorScreenState();
}

class _LocationSelectorScreenState extends State<LocationSelectorScreen> {
  String _selectedLocationType = AppConstants.locMainFreezer1;
  String _freezerRow = 'A';
  int _freezerCol = 1;
  int _freezerLayer = 1;
  String _locationCode = 'A11';

  bool _isPalletScanVerified = false;

  @override
  void initState() {
    super.initState();
    if (widget.pallet.freezerRow != null) _freezerRow = widget.pallet.freezerRow!;
    if (widget.pallet.freezerCol != null) _freezerCol = widget.pallet.freezerCol!;
    if (widget.pallet.freezerLayer != null) _freezerLayer = widget.pallet.freezerLayer!;
    if (widget.pallet.locationCode != null) _locationCode = widget.pallet.locationCode!;
  }

  bool get _isMainFreezer =>
      _selectedLocationType == AppConstants.locMainFreezer1 ||
      _selectedLocationType == AppConstants.locMainFreezer2;

  void _scanToVerifyPallet() {
    QrCameraScannerDialog.show(
      context,
      onPalletScanned: (scannedPallet) {
        final expectedCode = widget.pallet.palletCode.trim().toUpperCase();
        final scannedCode = scannedPallet.palletCode.trim().toUpperCase();

        if (scannedCode == expectedCode || scannedPallet.id == widget.pallet.id) {
          setState(() {
            _isPalletScanVerified = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم التحقق من مطابقة كود الطبلية ($expectedCode) بنجاح! يمكنك إتمام النقل الآن.'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ في التحقق: الطبلية الممسوحة ($scannedCode) لا تطابق الطبلية المحددة للنقل ($expectedCode)'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  Future<void> _handleConfirmMove() async {
    // If moving to sorting lines (فرز أولي / فرز آلي)
    if (_selectedLocationType == AppConstants.locPreSort ||
        _selectedLocationType == AppConstants.locAutoSort) {
      final selectedDate = await SortingCalendarModal.show(
        context,
        sortingType: _selectedLocationType == AppConstants.locPreSort
            ? 'presort'
            : 'autosort',
      );

      if (selectedDate == null) return;

      // Start sorting batch and put pallet on hold
      await SupabaseService().startSortingBatch(
        pallet: widget.pallet,
        sortingType: _selectedLocationType == AppConstants.locPreSort
            ? 'presort'
            : 'autosort',
        scheduledDate: selectedDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحويل الطبلية إلى خط (${AppConstants.locationNamesAr[_selectedLocationType]}) وجدولتها بتاريخ (${selectedDate.year}/${selectedDate.month}/${selectedDate.day})',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          (route) => false,
        );
      }
      return;
    }

    // Normal move to warehouse cold storage / 3D freezers
    bool stackOnExisting = false;
    String? targetExistingPalletId;

    if (_isMainFreezer) {
      final existingAtSlot = SupabaseService().pallets.where((p) {
        return p.id != widget.pallet.id &&
            p.locationType == _selectedLocationType &&
            p.locationCode == _locationCode &&
            p.status != 'delivered' &&
            p.status != 'consumed';
      }).toList();

      if (existingAtSlot.isNotEmpty) {
        final existingPallet = existingAtSlot.first;
        targetExistingPalletId = existingPallet.id;

        // Check box capacity limits: (126 box / 250 cardboard max)
        final combinedBoxes = widget.pallet.boxCount + existingPallet.boxCount;
        const maxBoxesAllowed = 126; // 126 plastic boxes
        const maxCardboardAllowed = 250; // 250 cardboard boxes

        final isOverLimit = combinedBoxes > maxBoxesAllowed;

        final bool? confirmStack = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(
                  isOverLimit ? Icons.warning_amber_rounded : Icons.layers_rounded,
                  color: isOverLimit ? AppColors.error : AppColors.dateGold,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  isOverLimit ? 'تنبيه تجاوز حد التطبيق' : 'تطبيق ومضاعفة الطبالي (Override)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الموقع ($_locationCode) يحتوي بالفعل على طبلية (${existingPallet.palletCode}) بعدد صناديق (${existingPallet.boxCount}).',
                  style: const TextStyle(fontSize: 13, color: AppColors.navyDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'المجموع مع الطبلية الحالية (${widget.pallet.boxCount} صندوق) سيكون: $combinedBoxes صندوق.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                ),
                const SizedBox(height: 6),
                Text(
                  'الحد الموصى به: 126 صندوق بلاستيك / 250 صندوق كرتون.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                if (isOverLimit) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: const Text(
                      '⚠️ هل أنت متأكد من رغبتك بتطبيق الطبلية فوقها بالرغم من تجاوز الحد الأقصى؟',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  const Text(
                    '✅ المجموع يقع ضمن الحد المسموح (أقل من 126 صندوق). عند النقل لاحقاً سيتم التعامل معهما كطبلية واحدة.',
                    style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء واختيار موقع آخر', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOverLimit ? AppColors.error : AppColors.navy,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  isOverLimit ? 'نعم، متأكد وطبّق الطبلية' : 'تأكيد التطبيق والمضاعفة',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (confirmStack != true) return;
        stackOnExisting = true;
      }
    }

    await SupabaseService().updatePalletLocation(
      palletId: widget.pallet.id,
      locationType: _selectedLocationType,
      row: _isMainFreezer ? _freezerRow : null,
      col: _isMainFreezer ? _freezerCol : null,
      layer: _isMainFreezer ? _freezerLayer : null,
      locationCode: _isMainFreezer ? _locationCode : null,
      stackOnExisting: stackOnExisting,
      targetExistingPalletId: targetExistingPalletId,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            stackOnExisting
                ? 'تم تطبيق ومضاعفة الطبلية (${widget.pallet.palletCode}) بنجاح في الموقع ($_locationCode)'
                : 'تم نقل الطبلية (${widget.pallet.palletCode}) بنجاح إلى (${AppConstants.locationNamesAr[_selectedLocationType]} ${_isMainFreezer ? "- موقع " + _locationCode : ""})',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show Pre-Sort only if pallet was unchecked for pre-sorted
    final canPreSort = !widget.pallet.isPresorted;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'تحديد موقع الطبلية',
        subtitle: 'الطبلية: ${widget.pallet.palletCode} (${widget.pallet.netWeight} كغ)',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pallet Specs Summary Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.navyUltraLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.navy.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppColors.navy, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.pallet.customerName} - ${widget.pallet.palletCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                        ),
                        Text(
                          'الموقع الحالي: ${widget.pallet.displayLocation} | الوزن: ${widget.pallet.netWeight} كغ',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Location Target Selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'اختر وجهة النقل المطلوبة:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildLocationChip(AppConstants.locPreFridge, Icons.ac_unit_rounded),
                        _buildLocationChip(AppConstants.locFirstFridge, Icons.kitchen_rounded),
                        _buildLocationChip(AppConstants.locMainFreezer1, Icons.view_in_ar_rounded),
                        _buildLocationChip(AppConstants.locMainFreezer2, Icons.view_in_ar_rounded),
                        _buildLocationChip(AppConstants.locSmallFreezer, Icons.severe_cold_rounded),
                        if (canPreSort)
                          _buildLocationChip(AppConstants.locPreSort, Icons.filter_alt_rounded, isHighlight: true),
                        _buildLocationChip(AppConstants.locAutoSort, Icons.precision_manufacturing_rounded, isHighlight: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // If Main Freezer 1 or 2 Selected -> Show Interactive 3D Model View!
            if (_isMainFreezer) ...[
              Warehouse3DView(
                freezerName: AppConstants.locationNamesAr[_selectedLocationType]!,
                existingPallets: SupabaseService().pallets,
                initialLocationCode: _locationCode,
                onSlotSelected: (row, col, layer, code) {
                  setState(() {
                    _freezerRow = row;
                    _freezerCol = col;
                    _freezerLayer = layer;
                    _locationCode = code;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),

            // Confirm Move Button
            ElevatedButton.icon(
              icon: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.dateGold,
              ),
              label: Text(
                (_selectedLocationType == AppConstants.locPreSort ||
                        _selectedLocationType == AppConstants.locAutoSort)
                    ? 'جدولة وحجز موعد الفرز'
                    : 'تأكيد نقل الطبلية إلى الموقع المحدد',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _handleConfirmMove,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationChip(String locKey, IconData icon, {bool isHighlight = false}) {
    final isSelected = _selectedLocationType == locKey;
    final title = AppConstants.locationNamesAr[locKey] ?? locKey;

    final textColor = isSelected
        ? Colors.white
        : isHighlight
            ? const Color(0xFFBF360C)
            : AppColors.navy;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 18,
        color: textColor,
      ),
      label: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      selectedColor: isHighlight ? const Color(0xFFE65100) : AppColors.navy,
      backgroundColor: isHighlight ? const Color(0xFFFFE0B2) : Colors.white,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : isHighlight
                ? const Color(0xFFF57C00)
                : AppColors.border,
        width: 1.2,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedLocationType = locKey;
          });
        }
      },
    );
  }
}
