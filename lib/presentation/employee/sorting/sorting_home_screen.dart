import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/qr_helper.dart';
import '../../../data/models/document_model.dart';
import '../../../data/models/pallet_model.dart';
import '../../../data/models/sorting_batch_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/pallet_sticker_widget.dart';
import '../../widgets/signature_dialog.dart';
import '../../widgets/qr_camera_scanner_dialog.dart';
import '../employee_home_screen.dart';
import 'scheduled_pallet_picker_modal.dart';

/// Complete Redesigned Unified Sorting Workspace Screen (فرز أولي & فرز آلي)
class SortingHomeScreen extends StatefulWidget {
  const SortingHomeScreen({super.key});

  @override
  State<SortingHomeScreen> createState() => _SortingHomeScreenState();
}

class _SortingHomeScreenState extends State<SortingHomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Active batches loaded onto the workspace per tab
  final List<SortingBatchModel> _activePreSortBatches = [];
  final List<SortingBatchModel> _activeAutoSortBatches = [];

  // Verified scanned source pallet IDs (Only shows 'جاري الفرز' if scanned and validated first)
  final Set<String> _scannedVerifiedBatchIds = {};

  // Expanded/currently focused batch ID on screen
  String? _expandedBatchId;

  // Customizable Carton Sizes (أحجام وأوزان الكراتين المتاحة بالكيلوغرام)
  final List<double> _cartonSizesKg = [5.0, 1.0, 2.0, 3.0, 4.0, 10.0];
  double _selectedCartonSizeKg = 5.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    // Batches should only be loaded when user opens the planner and selects pallets
  }

  void _openManageCartonSizesModal(StateSetter setParentModalState) {
    final newSizeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSizeModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.straighten_rounded, color: AppColors.navy),
                SizedBox(width: 8),
                Text('إدارة أحجام وأوزان الكرتون', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: newSizeCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'إضافة حجم كرتون جديد',
                            hintText: 'مثال: 0.5 أو 7.5',
                            suffixText: 'كغ',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        label: const Text('إضافة', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          final val = double.tryParse(newSizeCtrl.text.trim());
                          if (val != null && val > 0 && !_cartonSizesKg.contains(val)) {
                            setState(() {
                              _cartonSizesKg.add(val);
                              _cartonSizesKg.sort();
                              _selectedCartonSizeKg = val;
                            });
                            setSizeModalState(() {});
                            setParentModalState(() {});
                            newSizeCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('الأحجام والأوزان المتاحة الحالية:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _cartonSizesKg.map((sz) {
                      return Chip(
                        backgroundColor: _selectedCartonSizeKg == sz ? AppColors.navy : AppColors.navyUltraLight,
                        label: Text(
                          '$sz كغ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _selectedCartonSizeKg == sz ? Colors.white : AppColors.navy,
                          ),
                        ),
                        deleteIcon: const Icon(Icons.close_rounded, size: 16),
                        deleteIconColor: _selectedCartonSizeKg == sz ? Colors.white70 : AppColors.error,
                        onDeleted: _cartonSizesKg.length > 1
                            ? () {
                                setState(() {
                                  _cartonSizesKg.remove(sz);
                                  if (_selectedCartonSizeKg == sz) {
                                    _selectedCartonSizeKg = _cartonSizesKg.first;
                                  }
                                });
                                setSizeModalState(() {});
                                setParentModalState(() {});
                              }
                            : null,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('تم'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _loadSavedActiveBatches() {
    final allBatches = SupabaseService().sortingBatches;
    for (var b in allBatches.where((b) => b.status == 'in_progress')) {
      if (b.sortingType == 'presort') {
        if (!_activePreSortBatches.any((existing) => existing.id == b.id)) {
          _activePreSortBatches.add(b);
        }
      } else {
        if (!_activeAutoSortBatches.any((existing) => existing.id == b.id)) {
          _activeAutoSortBatches.add(b);
        }
      }
    }
    if (_currentActiveBatches.isNotEmpty) {
      _expandedBatchId = _currentActiveBatches.first.id;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentSortingType => _tabController.index == 0 ? 'presort' : 'autosort';
  List<SortingBatchModel> get _currentActiveBatches =>
      _tabController.index == 0 ? _activePreSortBatches : _activeAutoSortBatches;

  void _openCalendarPicker() {
    final currentCustomerIds = _currentActiveBatches.map((b) => b.customerId).toList();

    ScheduledPalletPickerModal.show(
      context,
      sortingType: _currentSortingType,
      currentCustomerIdsOnScreen: currentCustomerIds,
      onBatchesAdded: (newBatches) {
        if (newBatches.isEmpty) return;

        setState(() {
          if (_currentActiveBatches.isEmpty) {
            // Combine all new batches into a single unified batch widget
            final first = newBatches.first;
            final allPalletIds = <String>{};
            final allPalletCodes = <String>{};
            double totalInput = 0.0;
            final allOutputs = <SortingOutputItem>[];

            for (var b in newBatches) {
              allPalletIds.addAll(b.sourcePalletIds);
              allPalletCodes.addAll(b.sourcePalletCodes);
              totalInput += b.inputWeight;
              allOutputs.addAll(b.outputPallets);
            }

            final unifiedBatch = SortingBatchModel(
              id: first.id,
              batchNumber: first.batchNumber,
              sourcePalletId: allPalletIds.first,
              sourcePalletCode: allPalletCodes.first,
              sourcePalletIds: allPalletIds.toList(),
              sourcePalletCodes: allPalletCodes.toList(),
              sourcePalletLocation: first.sourcePalletLocation,
              customerId: first.customerId,
              customerName: first.customerName,
              farmId: first.farmId,
              farmName: first.farmName,
              sortingType: _currentSortingType,
              scheduledDate: first.scheduledDate,
              inputWeight: totalInput,
              outputPallets: allOutputs,
              status: 'in_progress',
              createdAt: first.createdAt,
            );

            _currentActiveBatches.add(unifiedBatch);
            _expandedBatchId = unifiedBatch.id;
          } else {
            // Merge additional selected pallets into the existing active unified widget
            final existing = _currentActiveBatches.first;
            final allPalletIds = Set<String>.from(existing.sourcePalletIds);
            final allPalletCodes = Set<String>.from(existing.sourcePalletCodes);
            double totalInput = existing.inputWeight;
            final allOutputs = List<SortingOutputItem>.from(existing.outputPallets);

            for (var b in newBatches) {
              for (var pid in b.sourcePalletIds) {
                if (!allPalletIds.contains(pid)) {
                  allPalletIds.add(pid);
                  final p = SupabaseService().findPalletById(pid);
                  if (p != null) totalInput += p.netWeight;
                }
              }
              for (var code in b.sourcePalletCodes) {
                allPalletCodes.add(code);
              }
              for (var out in b.outputPallets) {
                if (!allOutputs.any((o) => o.id == out.id)) {
                  allOutputs.add(out);
                }
              }
            }

            final mergedBatch = existing.copyWith(
              sourcePalletIds: allPalletIds.toList(),
              sourcePalletCodes: allPalletCodes.toList(),
              inputWeight: totalInput,
              outputPallets: allOutputs,
            );

            _currentActiveBatches[0] = mergedBatch;
            _expandedBatchId = mergedBatch.id;
            _autosaveBatch(mergedBatch);
          }
        });
      },
    );
  }

  Future<void> _autosaveBatch(SortingBatchModel batch) async {
    await SupabaseService().updateSortingBatch(batch);
  }

  @override
  Widget build(BuildContext context) {
    final isAuto = _tabController.index == 1;
    final activeBatches = _currentActiveBatches;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'شاشة وعمليات خطوط الفرز',
        subtitle: isAuto ? 'خط الفرز الآلي الحديث' : 'خط الفرز الأولي اليدوي',
        actions: [
          // Shift Supervisor Button
          IconButton(
            tooltip: 'مسؤول الشفت الحالي',
            icon: const Icon(Icons.shield_rounded, color: AppColors.dateGold),
            onPressed: _openShiftSupervisorModal,
          ),
          // Activity Log Button
          IconButton(
            tooltip: 'سجل عمليات المسح والفرز',
            icon: const Icon(Icons.history_edu_rounded, color: Colors.white),
            onPressed: _openActivityLogModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315),
          indicatorWeight: 4,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          tabs: const [
            Tab(
              icon: Icon(Icons.filter_alt_rounded),
              text: 'الفرز الأولي',
            ),
            Tab(
              icon: Icon(Icons.precision_manufacturing_rounded),
              text: 'الفرز الآلي',
            ),
          ],
        ),
      ),
      body: activeBatches.isEmpty
          ? _buildEmptyState(isAuto)
          : Column(
              children: [
                // Top Batch Overview Strip
                _buildBatchesHeaderBar(activeBatches, isAuto),

                // Main Batch Workspace
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: activeBatches.length,
                    itemBuilder: (ctx, idx) {
                      final batch = activeBatches[idx];
                      return _buildSortingBatchWorkspaceCard(batch, isAuto, idx);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Bottom Calendar Button
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
                  label: Text(
                    isAuto ? 'جدول طبالي الفرز الآلي' : 'جدول طبالي الفرز الأولي',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  onPressed: _openCalendarPicker,
                ),
              ),

              if (activeBatches.isNotEmpty) ...[
                const SizedBox(width: 10),
                IconButton(
                  tooltip: 'مسح الشاشة',
                  icon: const Icon(Icons.clear_all_rounded, color: AppColors.error),
                  onPressed: () {
                    setState(() {
                      _currentActiveBatches.clear();
                      _expandedBatchId = null;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isAuto) {
    final lineTheme = isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315);
    final lineSoftBg = isAuto ? const Color(0xFFE3F2FD) : const Color(0xFFFFE0B2);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: lineSoftBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isAuto ? Icons.precision_manufacturing_rounded : Icons.filter_alt_rounded,
                size: 56,
                color: lineTheme,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isAuto ? 'شاشة الفرز الآلي فارغة حالياً' : 'شاشة الفرز الأولي فارغة حالياً',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.navy),
            ),
            const SizedBox(height: 8),
            const Text(
              'اضغط على زر جدول المواعيد بالأسفل لعرض الطبالي المجدولة واختيار ما تريد إدخاله إلى خط الفرز الآن.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: lineTheme, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: Icon(Icons.calendar_month_rounded, color: lineTheme),
              label: Text(
                'فتح جدول الطبالي المجدولة',
                style: TextStyle(fontWeight: FontWeight.bold, color: lineTheme, fontSize: 14),
              ),
              onPressed: _openCalendarPicker,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchesHeaderBar(List<SortingBatchModel> batches, bool isAuto) {
    final totalInput = batches.fold<double>(0.0, (s, b) => s + b.inputWeight);
    final totalOutput = batches.fold<double>(0.0, (s, b) {
      return s + b.outputPallets.fold<double>(0.0, (sub, o) => sub + o.weight);
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.navyUltraLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.layers_rounded, color: AppColors.navy, size: 18),
              const SizedBox(width: 6),
              Text(
                'الطبالي المدخلة: ${batches.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              Text(
                'إجمالي المدخل: ${totalInput.toStringAsFixed(1)} كغ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const Text('  |  ', style: TextStyle(color: Colors.black26)),
              Text(
                'المنجز: ${totalOutput.toStringAsFixed(1)} كغ',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortingBatchWorkspaceCard(SortingBatchModel batch, bool isAuto, int batchIndex) {
    final isExpanded = _expandedBatchId == batch.id;
    final totalOut = batch.outputPallets.fold<double>(0.0, (s, o) => s + o.weight);
    final remaining = batch.inputWeight - totalOut;
    final isOverflow = remaining < 0;

    // Sort output items: in-progress on top, full/checked at bottom
    final sortedOutputs = List<SortingOutputItem>.from(batch.outputPallets);
    sortedOutputs.sort((a, b) {
      if (a.isFull && !b.isFull) return 1;
      if (!a.isFull && b.isFull) return -1;
      return 0;
    });

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isExpanded ? AppColors.navy : AppColors.border,
          width: isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Source Pallet Header Card Banner
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () {
              setState(() {
                _expandedBatchId = isExpanded ? null : batch.id;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isExpanded ? AppColors.navy : AppColors.navyUltraLight,
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(15),
                  bottom: Radius.circular(isExpanded ? 0 : 15),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAuto ? Icons.precision_manufacturing_rounded : Icons.filter_alt_rounded,
                            color: isExpanded ? AppColors.dateGold : AppColors.navy,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            batch.sourcePalletCodes.length > 1
                                ? 'طبالي الإدخال (${batch.sourcePalletCodes.length}): ${batch.sourcePalletCodes.join(" + ")}'
                                : 'طبلية الإدخال: ${batch.sourcePalletCode ?? batch.sourcePalletId}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isExpanded ? Colors.white : AppColors.navy,
                            ),
                          ),
                        ],
                      ),
                      // Scan Validation & Status Badge
                      Row(
                        children: [
                          if (_scannedVerifiedBatchIds.contains(batch.id))
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF22C55E)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'جاري الفرز ⚡',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF15803D),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            InkWell(
                              onTap: () => _scanAndVerifySourcePallet(batch),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.amber.shade700),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.qr_code_scanner_rounded, color: Colors.amber.shade900, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      'مسح للفرز 📷',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(width: 6),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isExpanded ? Colors.white24 : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isExpanded ? Colors.white38 : AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, color: isExpanded ? AppColors.dateGold : AppColors.navy, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  batch.sourcePalletLocation ?? 'المستودع الرئيسي',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isExpanded ? Colors.white : AppColors.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'العميل: ${batch.customerName ?? "غير محدد"}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isExpanded ? Colors.white70 : AppColors.navyDark,
                        ),
                      ),
                      Text(
                        'إجمالي وزن الإدخال: ${batch.inputWeight.toStringAsFixed(1)} كغ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isExpanded ? Colors.white : AppColors.dateBronze,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 2. Expanded Workspace Detail (Top Half Inputs + Bottom Half Outputs)
          if (isExpanded) ...[
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- SECTION 1: TOP HALF - INPUT PALLETS (طبالي الإدخال للمشغل) ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.navy.withAlpha(50)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.input_rounded, color: AppColors.navy, size: 18),
                                const SizedBox(width: 6),
                                Text(
                                  'الجزء العلوي: طبالي الإدخال (Inputs) - [${batch.sourcePalletCodes.length}]',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                                ),
                              ],
                            ),
                            Text(
                              'الوزن المدخل: ${batch.inputWeight.toStringAsFixed(1)} كغ',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.dateBronze),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // List of source pallets with Empty Pallet Button
                        ...batch.sourcePalletCodes.map((code) {
                          final matchedPallet = SupabaseService().findPalletByCode(code);
                          final isConsumed = matchedPallet?.status == 'consumed';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isConsumed ? Colors.grey.shade100 : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isConsumed ? Colors.grey.shade300 : AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        isConsumed ? Icons.check_circle_outline_rounded : Icons.inventory_2_outlined,
                                        size: 18,
                                        color: isConsumed ? AppColors.textMuted : AppColors.navy,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              code,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13,
                                                fontFamily: 'monospace',
                                                decoration: isConsumed ? TextDecoration.lineThrough : null,
                                                color: isConsumed ? AppColors.textMuted : AppColors.navy,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (matchedPallet != null)
                                              Text(
                                                '${matchedPallet.netWeight.toStringAsFixed(1)} كغ | ${matchedPallet.boxCount} صندوق',
                                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // "طبلية فرغت" Empty Pallet Button with Confirmation Modal
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isConsumed ? Colors.grey.shade400 : const Color(0xFFE65100),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: Icon(
                                    isConsumed ? Icons.history_rounded : Icons.delete_sweep_rounded,
                                    size: 15,
                                  ),
                                  label: Text(
                                    isConsumed ? 'تم التفريغ (بالأرشيف) ✓' : 'طبلية فرغت 🗑️',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: () async {
                                    if (matchedPallet != null) {
                                      if (!isConsumed) {
                                        // Seek confirmation modal
                                        final bool? confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            title: const Row(
                                              children: [
                                                Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 26),
                                                SizedBox(width: 8),
                                                Text('تأكيد تفريغ واستهلاك الطبلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
                                              ],
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'سيتم الآن تفريغ الطبلية المرجعية ($code) ونقلها إلى سجل الأرشيف.',
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.navy),
                                                ),
                                                const SizedBox(height: 10),
                                                Container(
                                                  padding: const EdgeInsets.all(10),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFFFF7ED),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFFDBA74)),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        '• الوزن الصافي للبضاعة: ${matchedPallet.netWeight.toStringAsFixed(1)} كغ (${matchedPallet.boxCount} صندوق)',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF9A3412)),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      const Text(
                                                        '• ستبقى بضاعة الطبلية محجوزة قيد المعالجة (On Hold) داخل خط الفرز حتى تقوم بتعبئة طبالي المخرجات المستهدفة بالكامل.',
                                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412)),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      const Text(
                                                        '• لن يتم نقل هذه الطبلية إلى أي موقع تخزين جديد وسيتم اعتبارها مستهلكة ومنتهية من المخزون.',
                                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF9A3412)),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              OutlinedButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: const Text('إلغاء'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100)),
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                child: const Text('تأكيد التفريغ والاستهلاك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;
                                      }

                                      final newStatus = isConsumed ? 'in_warehouse' : 'consumed';
                                      await SupabaseService().updatePallet(matchedPallet.copyWith(status: newStatus));
                                      setState(() {});
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(isConsumed
                                                ? 'تمت استعادة الطبلية ($code) إلى المخزون'
                                                : 'تم تفريغ الطبلية ($code) ونقلها للأرشيف واحتساب وزنها قيد التعبئة'),
                                            backgroundColor: isConsumed ? AppColors.navy : AppColors.success,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // --- SECTION 2: BOTTOM HALF - OUTPUT PALLETS & BALANCE (مخرجات الفرز وتوازن البضاعة) ---
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOverflow ? const Color(0xFFFFEBEE) : AppColors.navyUltraLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOverflow ? Colors.red.shade400 : AppColors.navy.withAlpha(50),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.balance_rounded, size: 18, color: isOverflow ? Colors.red.shade900 : AppColors.navy),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          isOverflow
                                              ? '⚠️ فائض عن الرصيد المدخل: ${( -remaining ).toStringAsFixed(1)} كغ-'
                                              : 'رصيد البضاعة قيد التعبئة (On Hold): ${remaining.toStringAsFixed(1)} كغ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: isOverflow ? Colors.red.shade900 : AppColors.navy,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'تم فرز وتعبئة: ${totalOut.toStringAsFixed(1)} كغ  |  إجمالي رصيد المصدر: ${batch.inputWeight.toStringAsFixed(1)} كغ',
                                    style: TextStyle(fontSize: 11, color: isOverflow ? Colors.red.shade700 : AppColors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // (+) Add Output Pallet Button
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                              label: const Text('إضافة طبلية مخرجات +', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                              onPressed: () => _openAddOutputPalletDialog(batch, isAuto),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Outcome Pallets List
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'الجزء السفلي: طبالي المخرجات (${batch.outputPallets.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.navy),
                      ),
                      const Text(
                        'اضغط (✓) لاكتمال الطبلية ونقلها للأسفل',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (sortedOutputs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text(
                          'لا توجد طبالي مخرجات مضافة لهذه الدفعة بعد.\nاضغط على زر (إضافة طبلية مخرجات +) أعلاه.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    ...sortedOutputs.map((item) {
                      return _buildOutputPalletItemCard(batch, item, isAuto);
                    }),

                  const SizedBox(height: 16),
                  const Divider(),

                  // Bottom Action Buttons: Done (إنهاء) & Cancel (إلغاء الدفعة)
                  Row(
                    children: [
                      // Cancel Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('إلغاء الدفعة', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _handleCancelBatch(batch),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Done Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                          label: const Text(
                            'إنهاء الفرز وتوليد التقرير',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                          ),
                          onPressed: () => _handleFinishBatch(batch, isAuto),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOutputPalletItemCard(SortingBatchModel batch, SortingOutputItem item, bool isAuto) {
    final isFull = item.isFull;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isFull ? const Color(0xFFF0FDF4) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFull ? const Color(0xFF22C55E) : AppColors.border,
          width: isFull ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Status Icon / Tick Button
            IconButton(
              icon: Icon(
                isFull ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isFull ? const Color(0xFF16A34A) : Colors.grey.shade400,
                size: 26,
              ),
              tooltip: isFull ? 'الطبلية ممتلئة (اضغط لإلغاء القفل)' : 'تعليم كطبلية ممتلئة ومكتملة',
              onPressed: () {
                final updatedList = batch.outputPallets.map((o) {
                  if (o.id == item.id) {
                    return o.copyWith(isFull: !o.isFull);
                  }
                  return o;
                }).toList();
                final updatedBatch = batch.copyWith(outputPallets: updatedList);
                setState(() {
                  final bIdx = _currentActiveBatches.indexWhere((b) => b.id == batch.id);
                  if (bIdx != -1) _currentActiveBatches[bIdx] = updatedBatch;
                });
                _autosaveBatch(updatedBatch);
              },
            ),

            const SizedBox(width: 6),

            // Item Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAuto ? '${item.category} (${item.size})' : item.category,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isFull ? const Color(0xFF166534) : AppColors.navy,
                        ),
                      ),
                      if (isFull) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ممتلئة ✓',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الرمز: ${item.palletCode} | ${item.boxCount} صندوق | نوع الصناديق: ${item.isCardboard ? "كرتون (5كغ)" : "بلاستيك/حقل"}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  Text(
                    'صافي التمر: ${item.weight.toStringAsFixed(1)} كغ | القائم: ${item.grossWeight.toStringAsFixed(1)} كغ',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dateBronze),
                  ),
                ],
              ),
            ),

            // Edit & Print QR Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Edit Button
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.navy),
                  tooltip: 'تعديل وزن وصناديق الطبلية',
                  onPressed: () => _openEditOutputPalletDialog(batch, item, isAuto),
                ),

                // QR Print Button
                IconButton(
                  icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
                  tooltip: 'طباعة ملصق الطبلية الرسمي QR',
                  onPressed: () => _showPalletQrDialog(batch, item),
                ),

                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  tooltip: 'حذف الطبلية',
                  onPressed: () {
                    final updatedList = batch.outputPallets.where((o) => o.id != item.id).toList();
                    final updatedBatch = batch.copyWith(outputPallets: updatedList);
                    setState(() {
                      final bIdx = _currentActiveBatches.indexWhere((b) => b.id == batch.id);
                      if (bIdx != -1) _currentActiveBatches[bIdx] = updatedBatch;
                    });
                    _autosaveBatch(updatedBatch);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAddOutputPalletDialog(SortingBatchModel batch, bool isAuto) {
    String selectedCategory = isAuto ? AppConstants.autoSortCategories.first : AppConstants.preSortDefects.first;
    String selectedSize = isAuto ? AppConstants.autoSortSizes.first : 'مشكل';
    bool isCardboard = false;
    final boxCountController = TextEditingController(text: '30');
    final palletTareController = TextEditingController(text: '${AppConstants.defaultEmptyPalletWeight}');
    final boxTareController = TextEditingController(text: '0.95');
    final grossWeightController = TextEditingController(text: '175.0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final boxCount = int.tryParse(boxCountController.text.trim()) ?? 0;
          final palletTare = double.tryParse(palletTareController.text.trim()) ?? AppConstants.defaultEmptyPalletWeight;
          final boxTare = double.tryParse(boxTareController.text.trim()) ?? 0.95;
          final gross = double.tryParse(grossWeightController.text.trim()) ?? 0.0;

          // Pure dates net weight calculation
          double netDatesWeight = 0.0;
          if (isCardboard) {
            netDatesWeight = boxCount * _selectedCartonSizeKg; // Dynamic carton size kg
          } else {
            final tareTotal = palletTare + (boxCount * boxTare);
            netDatesWeight = (gross - tareTotal) > 0 ? (gross - tareTotal) : 0.0;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.add_box_rounded, color: isAuto ? const Color(0xFF1565C0) : const Color(0xFFD84315)),
                      const SizedBox(width: 8),
                      const Text(
                        'إضافة طبلية مفرزة جديدة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Selection
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'الصنف / الجودة *'),
                    items: (isAuto ? AppConstants.autoSortCategories : AppConstants.preSortDefects)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Size Selection (Only for Auto-Sorting خط الفرز الآلي)
                  if (isAuto) ...[
                    DropdownButtonFormField<String>(
                      value: selectedSize,
                      decoration: const InputDecoration(labelText: 'الحجم (Size) *'),
                      items: AppConstants.autoSortSizes
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSize = val);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Pre-sort only: Cardboard toggle
                  if (!isAuto) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.navyUltraLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'هل الصناديق كرتون؟',
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                          ),
                          Switch(
                            value: isCardboard,
                            activeColor: const Color(0xFFD84315),
                            onChanged: (val) {
                              setModalState(() => isCardboard = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cardboard Size (kg) Dropdown with (+) Add/Manage Button
                    if (isCardboard) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<double>(
                              value: _cartonSizesKg.contains(_selectedCartonSizeKg) ? _selectedCartonSizeKg : _cartonSizesKg.first,
                              decoration: const InputDecoration(
                                labelText: 'وزن/حجم الكرتونة *',
                                prefixIcon: Icon(Icons.straighten_rounded),
                              ),
                              items: _cartonSizesKg.map((sz) {
                                return DropdownMenuItem(
                                  value: sz,
                                  child: Text('$sz كغ كرتون', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCartonSizeKg = val);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.tune_rounded),
                            tooltip: 'إدارة أحجام وأوزان الكرتون (إضافة/حذف)',
                            onPressed: () => _openManageCartonSizesModal(setModalState),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],

                  // Box Count
                  TextFormField(
                    controller: boxCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                    decoration: InputDecoration(
                      labelText: isCardboard ? 'عدد الكراتين *' : 'عدد الصناديق *',
                      suffixText: isCardboard ? 'كرتونة' : 'صندوق',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Detailed weights if NOT cardboard
                  if (!isCardboard && !isAuto) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: palletTareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'وزن الطبلية ف', suffixText: 'كغ'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: boxTareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'وزن الصندوق ف', suffixText: 'كغ'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: grossWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'الوزن القائم الكامل *', suffixText: 'كغ'),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Calculated Pure Date Weight
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navy.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صافي وزن التمر المحسوب:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        Text(
                          '${netDatesWeight.toStringAsFixed(1)} كغ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                          onPressed: () {
                            if (boxCount <= 0) return;
                            final newCode = QrHelper.generateNewPalletCode(prefix: 'PAL-SORT');
                            final newItem = SortingOutputItem(
                              id: newCode,
                              batchId: batch.id,
                              palletCode: newCode,
                              category: selectedCategory,
                              size: selectedSize,
                              boxCount: boxCount,
                              weight: netDatesWeight,
                              isCardboard: isCardboard,
                              boxTareWeight: isCardboard ? 0.5 : boxTare,
                              palletTareWeight: palletTare,
                              grossWeight: isCardboard ? (netDatesWeight + (boxCount * 0.5) + palletTare) : gross,
                              isFull: false,
                            );

                            final updatedOutputs = [...batch.outputPallets, newItem];
                            final updatedBatch = batch.copyWith(outputPallets: updatedOutputs);

                            setState(() {
                              final bIdx = _currentActiveBatches.indexWhere((b) => b.id == batch.id);
                              if (bIdx != -1) _currentActiveBatches[bIdx] = updatedBatch;
                            });

                            _autosaveBatch(updatedBatch);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('إضافة الطبلية'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openEditOutputPalletDialog(SortingBatchModel batch, SortingOutputItem item, bool isAuto) {
    String selectedCategory = item.category;
    String selectedSize = item.size;
    bool isCardboard = item.isCardboard;
    final boxCountController = TextEditingController(text: '${item.boxCount}');
    final palletTareController = TextEditingController(text: '${item.palletTareWeight}');
    final boxTareController = TextEditingController(text: '${item.boxTareWeight}');
    final grossWeightController = TextEditingController(text: '${item.grossWeight}');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final boxCount = int.tryParse(boxCountController.text.trim()) ?? 0;
          final palletTare = double.tryParse(palletTareController.text.trim()) ?? AppConstants.defaultEmptyPalletWeight;
          final boxTare = double.tryParse(boxTareController.text.trim()) ?? 0.95;
          final gross = double.tryParse(grossWeightController.text.trim()) ?? 0.0;

          double netDatesWeight = 0.0;
          if (isCardboard) {
            netDatesWeight = boxCount * _selectedCartonSizeKg;
          } else {
            final tareTotal = palletTare + (boxCount * boxTare);
            netDatesWeight = (gross - tareTotal) > 0 ? (gross - tareTotal) : 0.0;
          }

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: AppColors.navy),
                      SizedBox(width: 8),
                      Text(
                        'تعديل بيانات الطبلية المفرزة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Category Selection
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'الصنف / الجودة *'),
                    items: (isAuto ? AppConstants.autoSortCategories : AppConstants.preSortDefects)
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Size Selection (Only for Auto-Sorting خط الفرز الآلي)
                  if (isAuto) ...[
                    DropdownButtonFormField<String>(
                      value: selectedSize,
                      decoration: const InputDecoration(labelText: 'الحجم (Size) *'),
                      items: AppConstants.autoSortSizes
                          .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => selectedSize = val);
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (!isAuto) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.navyUltraLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('هل الصناديق كرتون؟', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                          Switch(
                            value: isCardboard,
                            activeColor: const Color(0xFFD84315),
                            onChanged: (val) {
                              setModalState(() => isCardboard = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (isCardboard) ...[
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<double>(
                              value: _cartonSizesKg.contains(_selectedCartonSizeKg) ? _selectedCartonSizeKg : _cartonSizesKg.first,
                              decoration: const InputDecoration(
                                labelText: 'وزن/حجم الكرتونة *',
                                prefixIcon: Icon(Icons.straighten_rounded),
                              ),
                              items: _cartonSizesKg.map((sz) {
                                return DropdownMenuItem(
                                  value: sz,
                                  child: Text('$sz كغ كرتون', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCartonSizeKg = val);
                                  setModalState(() {});
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.tune_rounded),
                            tooltip: 'إدارة أحجام وأوزان الكرتون (إضافة/حذف)',
                            onPressed: () => _openManageCartonSizesModal(setModalState),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],

                  TextFormField(
                    controller: boxCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                    decoration: InputDecoration(
                      labelText: isCardboard ? 'عدد الكراتين *' : 'عدد الصناديق *',
                      suffixText: isCardboard ? 'كرتونة' : 'صندوق',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  if (!isCardboard && !isAuto) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: palletTareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'وزن الطبلية ف', suffixText: 'كغ'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: boxTareController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'وزن الصندوق ف', suffixText: 'كغ'),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: grossWeightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'الوزن القائم الكامل *', suffixText: 'كغ'),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.navy.withAlpha(50)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('صافي وزن التمر المحسوب:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                        Text(
                          '${netDatesWeight.toStringAsFixed(1)} كغ',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                          onPressed: () {
                            if (boxCount <= 0) return;
                            final updatedItem = item.copyWith(
                              category: selectedCategory,
                              size: selectedSize,
                              boxCount: boxCount,
                              weight: netDatesWeight,
                              isCardboard: isCardboard,
                              boxTareWeight: isCardboard ? 0.5 : boxTare,
                              palletTareWeight: palletTare,
                              grossWeight: isCardboard ? (netDatesWeight + (boxCount * 0.5) + palletTare) : gross,
                            );

                            final updatedOutputs = batch.outputPallets.map((o) => o.id == item.id ? updatedItem : o).toList();
                            final updatedBatch = batch.copyWith(outputPallets: updatedOutputs);

                            setState(() {
                              final bIdx = _currentActiveBatches.indexWhere((b) => b.id == batch.id);
                              if (bIdx != -1) _currentActiveBatches[bIdx] = updatedBatch;
                            });

                            _autosaveBatch(updatedBatch);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('حفظ التعديل'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPalletQrDialog(SortingBatchModel batch, SortingOutputItem item) {
    // Generate transient PalletModel for official sticker printing
    final pallet = PalletModel(
      id: item.id,
      palletCode: item.palletCode,
      customerId: batch.customerId,
      customerName: batch.customerName,
      farmId: batch.farmId,
      farmName: batch.farmName,
      grossWeight: item.grossWeight,
      netWeight: item.weight,
      boxCount: item.boxCount,
      emptyBoxWeight: item.boxTareWeight,
      emptyPalletWeight: item.palletTareWeight,
      locationType: AppConstants.locMainFreezer1,
      status: 'sorted',
      category: item.category,
      size: item.size,
      isPresorted: true,
      createdAt: DateTime.now(),
    );

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'معاينة ملصق الطبلية الرسمي',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Live Sticker Preview
              PalletStickerWidget(pallet: pallet),

              const SizedBox(height: 16),

              Row(
                children: [
                  // 1. Single Thermal Label
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.receipt_rounded, size: 18),
                      label: const Text('حراري مفرد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final pdfBytes = await PdfGenerator.generatePalletBarcodeLabelPdf(pallet);
                        await Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                          name: 'label_${pallet.palletCode}.pdf',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. A4 Sheet (4 Duplicates)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('4 ملصقات A4', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final pdfBytes = await PdfGenerator.generatePalletStickersSheetA4Pdf(pallet);
                        await Printing.layoutPdf(
                          onLayout: (format) async => pdfBytes,
                          name: 'a4_stickers_${pallet.palletCode}.pdf',
                        );
                      },
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

  Future<void> _handleCancelBatch(SortingBatchModel batch) async {
    final bool? confirmCancel = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('تأكيد إلغاء العملية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من رغبتك بإلغاء فرز الطبلية (${batch.sourcePalletCode ?? batch.sourcePalletId})؟\nسيتم إرجاع الطبلية إلى حالة التخزين في المستودع.',
          style: const TextStyle(fontSize: 13, color: AppColors.navyDark),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('لا، تراجع', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('نعم، إلغاء العملية'),
          ),
        ],
      ),
    );

    if (confirmCancel == true) {
      await SupabaseService().cancelSortingBatch(batch.id);
      setState(() {
        _currentActiveBatches.removeWhere((b) => b.id == batch.id);
        if (_expandedBatchId == batch.id) _expandedBatchId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء عملية الفرز وإعادة الطبلية للمستودع')),
        );
      }
    }
  }

  Future<void> _handleFinishBatch(SortingBatchModel batch, bool isAuto) async {
    final totalOut = batch.outputPallets.fold<double>(0.0, (s, o) => s + o.weight);
    final diff = batch.inputWeight - totalOut;

    // Waste difference alert
    if (diff > 0.5) {
      final bool? proceedWaste = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.scale_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('تنبيه فرق الوزن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy)),
            ],
          ),
          content: Text(
            'هناك ${diff.toStringAsFixed(1)} كغ فرق في وزن الطبالي المفرزة.\nهل تريد اعتبارها بضاعة تالفة / فاقد تصنيع؟',
            style: const TextStyle(fontSize: 14, color: AppColors.navyDark),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('تعديل الأوزان', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('نعم، فاقد تالف'),
            ),
          ],
        ),
      );
      if (proceedWaste != true) return;
    }

    // Digital Signature
    final signatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع تقرير نتائج الفرز',
      signerRole: 'مسؤول خط الفرز والإنتاج',
    );

    if (signatureBytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب توقيع التقرير لإنهاء عملية الفرز')),
        );
      }
      return;
    }

    final wasteWeight = diff > 0 ? diff : 0.0;

    await SupabaseService().completeSortingBatch(
      batchId: batch.id,
      outputPallets: batch.outputPallets,
      wasteWeight: wasteWeight,
    );

    final completedBatch = batch.copyWith(
      outputWeight: totalOut,
      wasteWeight: wasteWeight,
      status: 'completed',
      completedAt: DateTime.now(),
    );

    final pdfBytes = await PdfGenerator.generateSortingReportPdf(
      batch: completedBatch,
      isAuto: isAuto,
      signatureBytes: signatureBytes,
    );

    final docModel = DocumentModel(
      id: 'doc_sort_${batch.id}',
      customerId: batch.customerId,
      customerName: batch.customerName,
      batchId: batch.id,
      docType: 'sorting_report',
      title: 'تقرير نتائج الفرز - ${batch.customerName}',
      fileName: 'sorting_report_${batch.id.substring(0, 6)}.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    setState(() {
      _currentActiveBatches.removeWhere((b) => b.id == batch.id);
      if (_expandedBatchId == batch.id) _expandedBatchId = null;
    });

    if (mounted) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docModel.fileName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إنهاء عملية الفرز وتسجيل المخرجات في المستودع بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  void _scanAndVerifySourcePallet(SortingBatchModel batch) {
    QrCameraScannerDialog.show(
      context,
      onPalletScanned: (scannedPallet) {
        // Validate if scanned pallet matches any of the source pallets of this batch
        final scannedCode = scannedPallet.palletCode.trim().toUpperCase();
        final scannedId = scannedPallet.id;

        final expectedCodes = batch.sourcePalletCodes.map((c) => c.trim().toUpperCase()).toList();
        final expectedIds = batch.sourcePalletIds;

        final isMatch = expectedCodes.contains(scannedCode) ||
            expectedIds.contains(scannedId) ||
            expectedCodes.isEmpty ||
            (batch.sourcePalletCode != null && batch.sourcePalletCode!.toUpperCase().contains(scannedCode));

        if (isMatch) {
          setState(() {
            _scannedVerifiedBatchIds.add(batch.id);
            _expandedBatchId = batch.id;
          });

          // Log Sort start scan
          SupabaseService().logAction(
            actionType: 'sort_start',
            title: 'بدء الفرز والتحقق من طبلية المصدر',
            details: 'تم التحقق من طبلية المصدر (${scannedPallet.palletCode}) بنجاح وبدء خط الفرز - العميل: ${batch.customerName ?? "غير محدد"}',
            palletCode: scannedPallet.palletCode,
            locationCode: batch.sourcePalletLocation,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم التحقق من طبلية المصدر (${scannedPallet.palletCode}) بنجاح! بدأ الفرز الآن.'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ خطأ: الطبلية الممسوحة ($scannedCode) لا تطابق طبالي المصدر للدفعة (${batch.sourcePalletCodes.join(", ")})'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }

  void _openShiftSupervisorModal() {
    final service = SupabaseService();
    final employees = service.profiles.where((p) => p.isEmployee).toList();
    final currentSupervisor = service.shiftSupervisor;
    String selectedSupervisor = currentSupervisor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 450),
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
                      child: const Icon(Icons.shield_rounded, color: AppColors.dateGold, size: 24),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مسؤول الشفت لخطوط الفرز',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                        ),
                        Text(
                          'تحديد المشرف المسؤول عن هذه الوردية والعمليات',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: employees.any((e) => e.name == selectedSupervisor) ? selectedSupervisor : null,
                  decoration: const InputDecoration(
                    labelText: 'اختر مسؤول الشفت *',
                    prefixIcon: Icon(Icons.person_pin_rounded),
                  ),
                  hint: Text(selectedSupervisor),
                  items: [
                    ...employees.map((e) => DropdownMenuItem(value: e.name, child: Text(e.name))),
                    const DropdownMenuItem(value: 'خالد الكوز (المشرف العام)', child: Text('خالد الكوز (المشرف العام)')),
                    const DropdownMenuItem(value: 'علي الكوز (المدير العام)', child: Text('علي الكوز (المدير العام)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedSupervisor = val);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('إلغاء', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                        onPressed: () async {
                          await service.setShiftSupervisor(selectedSupervisor);
                          if (mounted) {
                            setState(() {});
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ تم تعيين مسؤول الشفت: $selectedSupervisor وبدء الوردية'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        child: const Text('حفظ وبدء الوردية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
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

  void _openActivityLogModal() {
    final service = SupabaseService();
    final logs = service.activityLogs;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(18),
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.navyUltraLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_edu_rounded, color: AppColors.navy, size: 24),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'سجل عمليات المسح والفرز والنقل 📋',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                        ),
                        Text(
                          'يوثق اسم الموظف، مسؤول الشفت، ووقت كل عملية مسح وفرز ونقل',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Supervisor tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'مسؤول الوردية الحالي: ${service.shiftSupervisor}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.navy),
                    ),
                    Text(
                      'إجمالي العمليات المسجلة: ${logs.length}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Logs List
              Expanded(
                child: logs.isEmpty
                    ? const Center(
                        child: Text(
                          'لا توجد عمليات مسجلة بعد في السجل الحالي.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, idx) {
                          final item = logs[idx];
                          final timeStr = DateFormat('yyyy/MM/dd HH:mm:ss').format(item.timestamp);
                          final isScan = item.actionType == 'scan';
                          final isShift = item.actionType == 'shift_start';
                          final isTransfer = item.actionType == 'transfer';

                          final icon = isScan
                              ? Icons.qr_code_scanner_rounded
                              : isShift
                                  ? Icons.shield_rounded
                                  : isTransfer
                                      ? Icons.drive_file_move_rounded
                                      : Icons.filter_alt_rounded;

                          final color = isScan
                              ? const Color(0xFF0D9488)
                              : isShift
                                  ? AppColors.dateGold
                                  : isTransfer
                                      ? const Color(0xFF2563EB)
                                      : AppColors.navy;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Icon(icon, color: color, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.navy),
                                            ),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.details,
                                          style: const TextStyle(fontSize: 11.5, color: AppColors.navyDark),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                                            const SizedBox(width: 3),
                                            Text(
                                              'الموظف: ${item.employeeName}',
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                            ),
                                            if (item.supervisorName != null) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.shield_outlined, size: 12, color: AppColors.dateBronze),
                                              const SizedBox(width: 3),
                                              Text(
                                                'إشراف: ${item.supervisorName}',
                                                style: const TextStyle(fontSize: 10.5, color: AppColors.dateBronze),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

