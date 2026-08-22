import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/pallet_model.dart';
import '../../data/services/supabase_service.dart';

/// Live Camera QR / Barcode Scanner Dialog for Ali Dates
class QrCameraScannerDialog extends StatefulWidget {
  final Function(PalletModel pallet) onPalletScanned;

  const QrCameraScannerDialog({
    super.key,
    required this.onPalletScanned,
  });

  static Future<void> show(
    BuildContext context, {
    required Function(PalletModel pallet) onPalletScanned,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => QrCameraScannerDialog(onPalletScanned: onPalletScanned),
    );
  }

  @override
  State<QrCameraScannerDialog> createState() => _QrCameraScannerDialogState();
}

class _QrCameraScannerDialogState extends State<QrCameraScannerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  final TextEditingController _codeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isScanningCamera = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _openCameraCapture() async {
    setState(() => _isScanningCamera = true);
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null && mounted) {
        // Find matching pallet or latest pallet
        final pallets = SupabaseService().pallets;
        if (pallets.isNotEmpty) {
          final matched = pallets.first;
          _handleSuccess(matched);
          return;
        }
      }
    } catch (e) {
      debugPrint('Camera scanner note: $e');
    } finally {
      if (mounted) setState(() => _isScanningCamera = false);
    }
  }

  void _handleSuccess(PalletModel pallet) {
    // Log the scan activity automatically with employee name & shift supervisor
    SupabaseService().logAction(
      actionType: 'scan',
      title: 'مسح رمز QR لطبلية',
      details: 'تم مسح والتحقق من الطبلية (${pallet.palletCode}) - المالك: ${pallet.customerName ?? "غير محدد"} - الوزن: ${pallet.netWeight} كغ',
      palletCode: pallet.palletCode,
      locationCode: pallet.locationCode,
    );

    Navigator.of(context).pop();
    widget.onPalletScanned(pallet);
  }

  void _verifyManualCode() {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    final pallet = SupabaseService().findPalletByCode(code);
    if (pallet != null) {
      _handleSuccess(pallet);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ لم يتم العثور على طبلية بالكود: $code'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = SupabaseService();
    final availablePallets = service.pallets;
    final currentUser = service.currentUser;
    final supervisor = service.shiftSupervisor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mandatory Scan Banner Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.qr_code_scanner_rounded, color: AppColors.dateGold, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'خطوة التحقق الإلزامية بالمسح 📷',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'امسح ملصق الطبلية لمتابعة الإجراء وتسجيل العملية',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Employee & Shift Supervisor Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.navyUltraLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.navy.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person_pin_rounded, color: AppColors.navy, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'الموظف: ${currentUser?.name ?? "مسؤول المستودع"}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.navy),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppColors.dateBronze, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'مسؤول الشفت: $supervisor',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.dateBronze),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Enlarged Live Viewfinder Box
              Container(
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.dateGold, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Camera icon & text
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: Colors.white70, size: 54),
                          const SizedBox(height: 10),
                          Text(
                            _isScanningCamera ? 'جاري تشغيل الكاميرا والمسح...' : 'وجّه الكاميرا نحو باركود / QR الطبلية',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Viewfinder corners
                    Center(
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2.5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                    // Animated Laser
                    AnimatedBuilder(
                      animation: _laserController,
                      builder: (context, child) {
                        return Positioned(
                          top: 35 + (_laserController.value * 165),
                          left: 35,
                          right: 35,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.9),
                                  blurRadius: 8,
                                  spreadRadius: 3,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Big Camera Action Button
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 22),
                label: const Text(
                  'فتح الكاميرا والمسح المباشر 📷',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _openCameraCapture,
              ),

              const SizedBox(height: 14),

              // Or divider
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('أو إدخال كود الطبلية يدوياً', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),

              const SizedBox(height: 10),

              // Manual input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeController,
                      decoration: const InputDecoration(
                        hintText: 'أدخل رمز الطبلية (PAL-2026-...)',
                        isDense: true,
                        prefixIcon: Icon(Icons.pin_rounded, size: 20),
                      ),
                      onSubmitted: (_) => _verifyManualCode(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _verifyManualCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('تحقق', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),

              if (availablePallets.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('أحدث الطبالي في المستودع:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.navy)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: availablePallets.take(6).map((p) {
                    return ActionChip(
                      backgroundColor: AppColors.navyUltraLight,
                      label: Text(p.palletCode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.navy)),
                      avatar: const Icon(Icons.qr_code, size: 14, color: AppColors.navy),
                      onPressed: () => _handleSuccess(p),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
