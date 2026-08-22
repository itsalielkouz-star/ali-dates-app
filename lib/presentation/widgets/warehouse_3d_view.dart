import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/pallet_model.dart';

/// 3D / Isometric Interactive Warehouse Freezer Rack Grid Visualizer
/// Features:
/// - 16 Rows (A to P)
/// - 8 Columns (1 to 8) with the middle forklift corridor between Col 4 and Col 5
/// - Small unobtrusive door indicator at the top end of the middle aisle (without taking space)
/// - Yellow bar removed as requested
/// - Gravity Rule: Cannot place a pallet on Layer 2 without an existing pallet on Layer 1,
///   or on Layer 3 without an existing pallet on Layer 2 in the same slot.
class Warehouse3DView extends StatefulWidget {
  final String freezerName;
  final List<PalletModel> existingPallets;
  final String? initialLocationCode;
  final void Function(String row, int col, int layer, String locationCode) onSlotSelected;

  const Warehouse3DView({
    super.key,
    required this.freezerName,
    this.existingPallets = const [],
    this.initialLocationCode,
    required this.onSlotSelected,
  });

  @override
  State<Warehouse3DView> createState() => _Warehouse3DViewState();
}

class _Warehouse3DViewState extends State<Warehouse3DView> {
  String _selectedRow = 'A';
  int _selectedCol = 1;
  int _selectedLayer = 1;
  bool _is3DIsometric = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocationCode != null &&
        widget.initialLocationCode!.length >= 3) {
      _selectedRow = widget.initialLocationCode![0].toUpperCase();
      _selectedCol = int.tryParse(widget.initialLocationCode![1]) ?? 1;
      _selectedLayer = int.tryParse(widget.initialLocationCode![2]) ?? 1;
    }
  }

  String get _currentCode => '$_selectedRow$_selectedCol$_selectedLayer';

  bool _isSlotOccupied(String row, int col, int layer) {
    final code = '$row$col$layer';
    return widget.existingPallets.any((p) => p.locationCode == code);
  }

  /// Gravity Rule Check:
  /// Layer 1: Always allowed
  /// Layer 2: Requires Layer 1 in the same (row, col) to have a pallet
  /// Layer 3: Requires Layer 2 in the same (row, col) to have a pallet
  bool _canPlaceAtLayer(String row, int col, int targetLayer) {
    if (targetLayer <= 1) return true;
    for (int l = 1; l < targetLayer; l++) {
      if (!_isSlotOccupied(row, col, l)) {
        return false;
      }
    }
    return true;
  }

  void _handleSelectSlot(String row, int col, int layer) {
    // Check gravity rule
    if (!_canPlaceAtLayer(row, col, layer)) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ قانون الجاذبية: لا يمكن وضع طبلية في الطبقة $layer في الموقع ($row$col) لعدم وجود طبلية تحتها في الطبقة ${layer - 1}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final code = '$row$col$layer';
    final occupiedPallet = widget.existingPallets.where((p) => p.locationCode == code).toList();

    if (occupiedPallet.isNotEmpty) {
      final p = occupiedPallet.first;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ℹ️ الموقع ($code) مشغول بطبلية (${p.palletCode} - ${p.boxCount} صندوق). سيتم تفعيل خيار التطبيق والمضاعفة (Override).',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.dateGold,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _selectedRow = row;
      _selectedCol = col;
      _selectedLayer = layer;
    });
    widget.onSlotSelected(row, col, layer, code);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header & Mode Switcher
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.freezerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'الموقع المختار: $_currentCode',
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _is3DIsometric
                            ? Icons.grid_view_rounded
                            : Icons.threed_rotation_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      tooltip: _is3DIsometric ? 'عرض الشبكة' : 'عرض ثلاثي الأبعاد',
                      onPressed: () {
                        setState(() {
                          _is3DIsometric = !_is3DIsometric;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Layer (Height) Selector Tabs
          Container(
            color: AppColors.navyUltraLight,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'الارتفاع (الطبقة): ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.navy,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 6),
                ...AppConstants.freezerLayers.map((layer) {
                  final isSelected = _selectedLayer == layer;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(
                        layer == 1
                            ? 'الطبقة 1 (أرضي)'
                            : layer == 2
                                ? 'الطبقة 2 (وسط)'
                                : 'الطبقة 3 (علوي)',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.navy,
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) {
                          _handleSelectSlot(_selectedRow, _selectedCol, layer);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          // 3. Warehouse Map Body (16 Rows A-P, 8 Columns with Middle Aisle between 4 & 5, and Top Door)
          SizedBox(
            height: 360,
            child: _is3DIsometric
                ? _buildIsometricWarehouse()
                : _build2DGridWarehouse(),
          ),

          // 4. Compact Warehouse Legend
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegendItem('فارغ متاح', AppColors.rackSlotEmpty, Icons.check_box_outline_blank_rounded),
                _buildLegendItem('موقع محدد', AppColors.dateGold, Icons.check_circle_rounded),
                _buildLegendItem('مشغول بطبلية', AppColors.navy, Icons.inventory_2_rounded),
                _buildLegendItem('ممر فوركلفت', Colors.grey.shade300, Icons.forklift),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  /// 3D Isometric View of Warehouse Racks (16 Rows A-P, 8 Columns: 1-4 | Aisle | 5-8)
  Widget _buildIsometricWarehouse() {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              // Top Door Header positioned exactly above the middle aisle between col 4 & 5
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Space for Row label (28px + 6px) + 4 columns (4 * 46px)
                    const SizedBox(width: 34 + (4 * 46)),

                    // Small compact Door indicator directly at the top of the middle corridor
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.door_front_door_rounded, color: AppColors.dateGold, size: 13),
                          SizedBox(width: 4),
                          Text(
                            'باب الفريزر',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Balance space for 4 columns (4 * 46px)
                    const SizedBox(width: 4 * 46),
                  ],
                ),
              ),

              // 16 Rows (A to P)
              ...AppConstants.freezerRows.map((row) {
                final isTopRow = row == 'A';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Row Label (A to P)
                      Container(
                        width: 28,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.navy,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          row,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Left Bay: Columns 1, 2, 3, 4
                      ...[1, 2, 3, 4].map((col) => _buildIsometricRackSlot(row, col)),

                      // Middle Forklift Corridor between Col 4 and Col 5
                      // User requirement: "add in the aile in the back add 10 pallets to fill the aisle from the end"
                      // Rows G to P (10 rows: G, H, I, J, K, L, M, N, O, P) are filled from the end as pallets
                      Builder(
                        builder: (context) {
                          final rowIndex = AppConstants.freezerRows.indexOf(row);
                          // Total rows is 16. The last 10 rows are indices 6 to 15 (G to P)
                          final isAislePallet = rowIndex >= (AppConstants.freezerRows.length - 10);
                          final aislePalletCode = '${row}M$_selectedLayer';
                          final isSelected = (_selectedRow == row && _selectedCol == 0); // 0 indicates middle aisle pallet

                          if (isAislePallet) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedRow = row;
                                  _selectedCol = 0;
                                });
                                widget.onSlotSelected(row, 0, _selectedLayer, aislePalletCode);
                              },
                              child: Container(
                                width: 48,
                                height: 30,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.dateGold
                                      : const Color(0xFFD97706).withOpacity(0.85),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: isSelected ? AppColors.navy : const Color(0xFFB45309),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        aislePalletCode,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w900,
                                          color: isSelected ? AppColors.navyDark : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }

                          return Container(
                            width: 48,
                            height: 30,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                isTopRow ? '🚪 مدخل' : '||',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      // Right Bay: Columns 5, 6, 7, 8
                      ...[5, 6, 7, 8].map((col) => _buildIsometricRackSlot(row, col)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIsometricRackSlot(String row, int col) {
    final code = '$row$col$_selectedLayer';
    final isSelected = (_selectedRow == row && _selectedCol == col);
    final isOccupied = _isSlotOccupied(row, col, _selectedLayer);
    final canPlace = _canPlaceAtLayer(row, col, _selectedLayer);

    Color bgColor = isSelected
        ? AppColors.dateGold
        : isOccupied
            ? AppColors.navy
            : (!canPlace && _selectedLayer > 1)
                ? const Color(0xFFF8FAFC) // Cannot place due to gravity
                : const Color(0xFFEFF3F8);

    Color textColor = isSelected
        ? AppColors.navyDark
        : isOccupied
            ? Colors.white
            : (!canPlace && _selectedLayer > 1)
                ? Colors.grey.shade400
                : AppColors.navy;

    return GestureDetector(
      onTap: () => _handleSelectSlot(row, col, _selectedLayer),
      child: Container(
        width: 42,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isSelected
                ? AppColors.navy
                : (!canPlace && _selectedLayer > 1)
                    ? Colors.grey.shade300
                    : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.dateGold.withAlpha(120),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              code,
              style: TextStyle(
                color: textColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isOccupied && !isSelected)
              const Positioned(
                top: 2,
                left: 2,
                child: Icon(
                  Icons.circle,
                  color: AppColors.dateGold,
                  size: 5,
                ),
              ),
            if (!canPlace && !isOccupied && _selectedLayer > 1)
              Positioned(
                bottom: 1,
                right: 1,
                child: Icon(
                  Icons.block_rounded,
                  color: Colors.red.shade300,
                  size: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 2D Grid Warehouse Matrix (8 Columns × 16 Rows)
  Widget _build2DGridWarehouse() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.4,
      ),
      itemCount: AppConstants.freezerRows.length * 8,
      itemBuilder: (context, index) {
        final rowIdx = index ~/ 8;
        final colIdx = (index % 8) + 1;
        final row = AppConstants.freezerRows[rowIdx];
        final code = '$row$colIdx$_selectedLayer';
        final isSelected = (_selectedRow == row && _selectedCol == colIdx);
        final isOccupied = _isSlotOccupied(row, colIdx, _selectedLayer);
        final canPlace = _canPlaceAtLayer(row, colIdx, _selectedLayer);

        return InkWell(
          onTap: () => _handleSelectSlot(row, colIdx, _selectedLayer),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.dateGold
                  : isOccupied
                      ? AppColors.navy
                      : (!canPlace && _selectedLayer > 1)
                          ? const Color(0xFFF8FAFC)
                          : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? AppColors.navy : AppColors.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                code,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.navyDark
                      : isOccupied
                          ? Colors.white
                          : (!canPlace && _selectedLayer > 1)
                              ? Colors.grey.shade400
                              : AppColors.navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 10.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
