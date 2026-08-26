import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/pdf_generator.dart';
import '../../../core/utils/qr_helper.dart';
import '../../../data/models/sorting_batch_model.dart';
import '../../../data/models/document_model.dart';
import '../../../data/services/supabase_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/signature_dialog.dart';
import '../employee_home_screen.dart';

/// Active Sorting Process Detail Screen (فرز أولي / فرز آلي)
class SortingProcessScreen extends StatefulWidget {
  final SortingBatchModel batch;

  const SortingProcessScreen({
    super.key,
    required this.batch,
  });

  @override
  State<SortingProcessScreen> createState() => _SortingProcessScreenState();
}

class _SortingProcessScreenState extends State<SortingProcessScreen> {
  late final List<SortingOutputItem> _outputItems;
  final Map<String, double> _preSortDefectWeights = {};
  bool _isAutoSort = true;

  @override
  void initState() {
    super.initState();
    _isAutoSort = widget.batch.sortingType == 'autosort';
    _outputItems = List.from(widget.batch.outputPallets);

    if (!_isAutoSort) {
      for (var defect in AppConstants.preSortDefects) {
        _preSortDefectWeights[defect] =
            widget.batch.wasteDetails?[defect] ?? 0.0;
      }
    }
  }

  double get _totalOutputWeight {
    if (_isAutoSort) {
      return _outputItems.fold<double>(0.0, (sum, item) => sum + item.weight);
    } else {
      return _preSortDefectWeights.values
          .fold<double>(0.0, (sum, w) => sum + w);
    }
  }

  double get _calculatedWaste {
    final diff = widget.batch.inputWeight - _totalOutputWeight;
    return diff > 0 ? double.parse(diff.toStringAsFixed(1)) : 0.0;
  }

  void _openAddPalletModal() {
    if (_isAutoSort) {
      _openAutoSortAddModal();
    } else {
      _openPreSortEditModal();
    }
  }

  void _openAutoSortAddModal() {
    String selectedCategory = AppConstants.autoSortCategories.first;
    String selectedSize = AppConstants.autoSortSizes.first;
    final boxCountController = TextEditingController(text: '30'); // 30 boxes * 5kg = 150kg

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final boxes = int.tryParse(boxCountController.text) ?? 0;
          final wt = boxes * AppConstants.autoSortBoxWeight;
          final currentTotalWithNew = _totalOutputWeight + wt;
          final remaining = widget.batch.inputWeight - currentTotalWithNew;
          final isOverflow = remaining < 0;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Row with Dynamic Remaining Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_box_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'إضافة طبلية مفرزة جديدة',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.navy),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isOverflow ? const Color(0xFFFFEBEE) : AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverflow ? Colors.red : AppColors.navy.withAlpha(40),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOverflow
                                  ? 'فائض: ${( -remaining ).toStringAsFixed(1)} كغ-'
                                  : 'المتبقي: ${remaining.toStringAsFixed(1)} كغ',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isOverflow ? Colors.red.shade900 : AppColors.navy,
                              ),
                            ),
                            Text(
                              'من أصل: ${widget.batch.inputWeight.toStringAsFixed(1)} كغ',
                              style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(labelText: 'التصنيف (Category) *'),
                    items: AppConstants.autoSortCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy))))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Size Dropdown
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
                  const SizedBox(height: 12),

                  // Box Count Field
                  TextFormField(
                    controller: boxCountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                    decoration: const InputDecoration(
                      labelText: 'عدد الصناديق (كل صندوق 5 كغ) *',
                      suffixText: 'صندوق',
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),

                  // Auto-Calculated Weight Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.navyUltraLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي وزن الطبلية المحسوب:', style: TextStyle(fontSize: 12, color: AppColors.navyDark)),
                        Text(
                          '$wt كـغ ($boxes × 5كغ)',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  if (isOverflow) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'الوزن الأصلي أقل من الوزن المفرز',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الوزن المدخل (${widget.batch.inputWeight} كغ) أقل من إجمالي الإنتاج (${currentTotalWithNew.toStringAsFixed(1)} كغ)',
                            style: TextStyle(color: Colors.red.shade900, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  if (isOverflow)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('تراجع وتعديل'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            if (boxes <= 0) return;
                            _addNewSortingOutput(boxes, wt, selectedCategory, selectedSize);
                            Navigator.of(ctx).pop();
                          },
                          child: const Text('متابعة رغم ذلك', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('إلغاء', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                            onPressed: () {
                              if (boxes <= 0) return;
                              _addNewSortingOutput(boxes, wt, selectedCategory, selectedSize);
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

  void _addNewSortingOutput(int boxes, double wt, String category, String size) {
    final newCode = QrHelper.generateNewPalletCode(prefix: 'PAL-SORT');
    final newItem = SortingOutputItem(
      id: newCode,
      batchId: widget.batch.id,
      palletCode: newCode,
      category: category,
      size: size,
      boxCount: boxes,
      weight: wt,
    );

    setState(() {
      _outputItems.add(newItem);
    });
  }

  void _openPreSortEditModal() {
    final controllers = {
      for (var k in AppConstants.preSortDefects)
        k: TextEditingController(
          text: (_preSortDefectWeights[k] ?? 0.0) > 0
              ? _preSortDefectWeights[k]!.toStringAsFixed(1)
              : '',
        )
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final inputWeight = widget.batch.inputWeight;
          final currentTotal = controllers.values.fold<double>(
            0.0,
            (sum, c) => sum + (double.tryParse(c.text.trim()) ?? 0.0),
          );
          final remainingWeight = inputWeight - currentTotal;
          final isOverflow = remainingWeight < 0;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Dynamic Remaining Amount Badge (Red Box from Image)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.filter_alt_rounded, color: AppColors.navy),
                          SizedBox(width: 8),
                          Text(
                            'توزيع أوزان الفرز الأولي',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
                          ),
                        ],
                      ),

                      // Dynamic Decreasing Amount Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOverflow ? const Color(0xFFFFEBEE) : AppColors.navyUltraLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isOverflow ? Colors.red : AppColors.navy.withAlpha(50),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOverflow
                                  ? 'فائض: ${( -remainingWeight ).toStringAsFixed(1)} كغ-'
                                  : 'المتبقي: ${remainingWeight.toStringAsFixed(1)} كغ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isOverflow ? Colors.red.shade900 : AppColors.navy,
                              ),
                            ),
                            Text(
                              'الوزن المدخل: ${inputWeight.toStringAsFixed(1)} كغ',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // 2. Defect Category Fields
                  ...AppConstants.preSortDefects.map((defect) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextFormField(
                        controller: controllers[defect],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                        decoration: InputDecoration(
                          labelText: 'وزن ($defect) بالكيلوغرام',
                          suffixText: 'كغ',
                          suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    );
                  }),

                  // 3. Overflow Warning Message if in minus
                  if (isOverflow) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade400, width: 1.2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'الوزن الأصلي أقل من الوزن المفرز',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'الوزن الأصلي المدخل ($inputWeight كغ) أقل من مجموع الأوزان الحالية (${currentTotal.toStringAsFixed(1)} كغ) بمقدار ${(currentTotal - inputWeight).toStringAsFixed(1)} كغ.',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 4. Action Buttons (Go back + small proceed button if in minus)
                  if (isOverflow)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('تراجع وتعديل الأوزان', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              for (var entry in controllers.entries) {
                                _preSortDefectWeights[entry.key] =
                                    double.tryParse(entry.value.text) ?? 0.0;
                              }
                            });
                            Navigator.of(ctx).pop();
                          },
                          child: const Text(
                            'متابعة رغم ذلك',
                            style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () {
                        setState(() {
                          for (var entry in controllers.entries) {
                            _preSortDefectWeights[entry.key] =
                                double.tryParse(entry.value.text) ?? 0.0;
                          }
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'حفظ الأوزان (${currentTotal.toStringAsFixed(1)} كغ)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPrintOutputLabel(SortingOutputItem item) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code_2_rounded, size: 50, color: AppColors.navy),
              const SizedBox(height: 10),
              Text(
                'ملصق طبلية مفرزة: ${item.palletCode}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.navy),
              ),
              const SizedBox(height: 8),
              Text('العميل: ${widget.batch.customerName}', style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w600)),
              Text('الصنف: ${item.category} | الحجم: ${item.size}', style: const TextStyle(color: AppColors.navyDark)),
              Text('الوزن: ${item.weight} كغ (${item.boxCount} صندوق)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.navy),
                icon: const Icon(Icons.print_rounded),
                label: const Text('طباعة الملصق'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إرسال الملصق للطباعة')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleFinishSorting() async {
    final diff = widget.batch.inputWeight - _totalOutputWeight;

    if (diff > 0.5) {
      final bool? proceedAsWaste = await showDialog<bool>(
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

      if (proceedAsWaste != true) return;
    }

    // 2. Digital Signature for Sorting Supervisor
    final signatureBytes = await SignatureDialog.show(
      context,
      title: 'توقيع تقرير نتائج الفرز',
      signerRole: 'مسؤول خط الفرز والإنتاج',
    );

    if (signatureBytes == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب توقيع التقرير لإنهاء عملية الفرز')),
      );
      return;
    }

    final wasteWeight = diff > 0 ? diff : 0.0;

    // 3. Complete Batch in Supabase
    await SupabaseService().completeSortingBatch(
      batchId: widget.batch.id,
      outputPallets: _outputItems,
      wasteWeight: wasteWeight,
      wasteDetails: !_isAutoSort ? _preSortDefectWeights : null,
    );

    final completedBatch = SortingBatchModel(
      id: widget.batch.id,
      sourcePalletId: widget.batch.sourcePalletId,
      sourcePalletCode: widget.batch.sourcePalletCode,
      sourcePalletLocation: widget.batch.sourcePalletLocation,
      customerId: widget.batch.customerId,
      customerName: widget.batch.customerName,
      farmId: widget.batch.farmId,
      farmName: widget.batch.farmName,
      sortingType: widget.batch.sortingType,
      inputWeight: widget.batch.inputWeight,
      outputWeight: _totalOutputWeight,
      wasteWeight: wasteWeight,
      wasteDetails: !_isAutoSort ? _preSortDefectWeights : null,
      outputPallets: _outputItems,
      status: 'completed',
      createdAt: widget.batch.createdAt,
    );

    final pdfBytes = await PdfGenerator.generateSortingReportPdf(
      batch: completedBatch,
      isAuto: _isAutoSort,
      signatureBytes: signatureBytes,
    );

    // 4. Save Document to Customer Archive
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final docModel = DocumentModel(
      id: 'doc_sort_${widget.batch.id}_$timestamp',
      customerId: widget.batch.customerId,
      customerName: widget.batch.customerName,
      batchId: widget.batch.id,
      docType: 'sorting_report',
      title: 'تقرير نتائج الفرز - ${widget.batch.customerName}',
      fileName: 'تقرير_نتائج_الفرز_${(widget.batch.customerName ?? "عميل").replaceAll(' ', '_')}_$timestamp.pdf',
    );
    await SupabaseService().saveDocument(docModel);

    // 5. Layout PDF & Return Home
    if (mounted) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: docModel.fileName,
      );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlanned = widget.batch.isPlanned;
    final scheduledDateStr = widget.batch.scheduledDate != null
        ? DateFormat('yyyy/MM/dd').format(widget.batch.scheduledDate!)
        : null;

    return Scaffold(
      appBar: CustomAppBar(
        title: _isAutoSort ? 'خط الفرز الآلي' : 'خط الفرز الأولي',
        subtitle: 'العميل: ${widget.batch.customerName}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Banner (جاري الفرز + الموقع الحالي)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status Badge (جاري الفرز الآن أو مخطط)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPlanned ? const Color(0xFFE0F2FE) : AppColors.dateGold,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPlanned ? Icons.event_rounded : Icons.autorenew_rounded,
                              color: isPlanned ? const Color(0xFF0369A1) : AppColors.navyDark,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isPlanned ? 'مخطط ومجدول 📅 ($scheduledDateStr)' : 'جاري الفرز الآن',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isPlanned ? const Color(0xFF0369A1) : AppColors.navyDark,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Location Badge right next to it!
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on_rounded, color: AppColors.dateGold, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.batch.sourcePalletLocation ?? 'المستودع الرئيسي',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'طبلية المصدر: ${widget.batch.sourcePalletCode ?? widget.batch.sourcePalletId}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderWeightMetric('الوزن الأصلي المدخل', '${widget.batch.inputWeight} كغ'),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildHeaderWeightMetric('إجمالي المفرز الحالي', '${_totalOutputWeight.toStringAsFixed(1)} كغ'),
                      Container(width: 1, height: 30, color: Colors.white24),
                      _buildHeaderWeightMetric('التالف المحسوب', '$_calculatedWaste كغ'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Middle Button: إضافة طبلية
            ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_rounded, color: AppColors.dateGold),
              label: Text(
                _isAutoSort ? 'إضافة طبلية مفرزة جديدة' : 'تعديل أصناف الفرز الأولي',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _openAddPalletModal,
            ),

            const SizedBox(height: 20),

            // Outputs Display Area
            if (_isAutoSort) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الطبالي المفرزة آلياً (${_outputItems.length})',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
                  ),
                  Text(
                    'المجموع: ${_totalOutputWeight.toStringAsFixed(1)} كغ',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.dateBronze),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_outputItems.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'لم يتم تسجيل أي طبالي مفرزة بعد.\nاضغط على الزر أعلاه لإضافة الطبالي المنتجة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _outputItems.length,
                  itemBuilder: (ctx, idx) {
                    final item = _outputItems[idx];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2_rounded, color: AppColors.navy),
                        title: Text(
                          '${item.category} - حجم (${item.size})',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy),
                        ),
                        subtitle: Text(
                          'الرمز: ${item.palletCode} | ${item.boxCount} صندوق × 5كغ',
                          style: const TextStyle(color: AppColors.navyDark),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${item.weight.toStringAsFixed(1)} كغ',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy, fontSize: 14),
                            ),
                            IconButton(
                              icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.navy),
                              tooltip: 'طباعة الملصق',
                              onPressed: () => _showPrintOutputLabel(item),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              tooltip: 'حذف',
                              onPressed: () {
                                setState(() {
                                  _outputItems.removeAt(idx);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // Pre-Sort Breakdown Display
              const Text(
                'تفصيل أوزان الفرز الأولي والعيوب:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.navy),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: AppConstants.preSortDefects.map((defect) {
                      final wt = _preSortDefectWeights[defect] ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(defect, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.navy)),
                            Text(
                              '$wt كغ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: wt > 0 ? AppColors.navy : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Finish Sorting Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _handleFinishSorting,
              child: const Text(
                'إنهاء الفرز وتوليد التقرير الرسمي والتوقيع',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWeightMetric(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}
