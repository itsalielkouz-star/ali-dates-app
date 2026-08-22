import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../core/constants/app_colors.dart';

/// Digital Finger Signature Modal Dialog
class SignatureDialog extends StatefulWidget {
  final String title;
  final String signerRole;

  const SignatureDialog({
    super.key,
    this.title = 'التوقيع الإلكتروني',
    this.signerRole = 'الموظف المسجل',
  });

  static Future<Uint8List?> show(
    BuildContext context, {
    String title = 'التوقيع الإلكتروني',
    String signerRole = 'الموظف المسجل',
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SignatureDialog(
        title: title,
        signerRole: signerRole,
      ),
    );
  }

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3.5,
      penColor: AppColors.navy,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                const Icon(Icons.draw_rounded, color: AppColors.navy, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'يرجى التوقيع بالإصبع في المربع أدناه (${widget.signerRole})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.error),
                  tooltip: 'مسح التوقيع',
                  onPressed: () => _controller.clear(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Signature Canvas Box
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Signature(
                      controller: _controller,
                      height: 220,
                      backgroundColor: Colors.transparent,
                    ),
                    Positioned(
                      bottom: 12,
                      right: 16,
                      child: Text(
                        'مكان التوقيع ✍️',
                        style: TextStyle(
                          color: Colors.grey.withAlpha(100),
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('إلغاء'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_controller.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى التوقيع بالإصبع أولاً'),
                            backgroundColor: AppColors.warning,
                          ),
                        );
                        return;
                      }
                      final bytes = await _controller.toPngBytes();
                      if (context.mounted) {
                        Navigator.of(context).pop(bytes);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'اعتماد التوقيع',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
