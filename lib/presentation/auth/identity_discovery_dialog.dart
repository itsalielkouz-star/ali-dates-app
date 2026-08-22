import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/phone_utils.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/supabase_service.dart';

/// Interactive Identity Discovery, Name Editing & Role Confirmation Modal
class IdentityDiscoveryDialog extends StatefulWidget {
  final UserProfile user;
  final String sourceDescription;
  final void Function(UserProfile confirmedUser) onProceed;

  const IdentityDiscoveryDialog({
    super.key,
    required this.user,
    required this.sourceDescription,
    required this.onProceed,
  });

  static Future<void> show(
    BuildContext context, {
    required UserProfile user,
    required String sourceDescription,
    required void Function(UserProfile confirmedUser) onProceed,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => IdentityDiscoveryDialog(
        user: user,
        sourceDescription: sourceDescription,
        onProceed: onProceed,
      ),
    );
  }

  @override
  State<IdentityDiscoveryDialog> createState() => _IdentityDiscoveryDialogState();
}

class _IdentityDiscoveryDialogState extends State<IdentityDiscoveryDialog> {
  late TextEditingController _nameController;
  late bool _isEmployee;
  bool _isEditingName = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _isEmployee = widget.user.isEmployee;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    setState(() => _isSaving = true);
    final confirmedName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.user.name;

    final updated = await SupabaseService().updateUserProfile(
      userId: widget.user.id,
      name: confirmedName,
      isEmployee: _isEmployee,
      companyName: _isEmployee ? 'تمور علي' : confirmedName,
    );

    setState(() => _isSaving = false);
    if (mounted) {
      Navigator.of(context).pop();
      widget.onProceed(updated ?? widget.user.copyWith(name: confirmedName, isEmployee: _isEmployee));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _isEmployee ? const Color(0xFFE8F5E9) : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isEmployee ? Icons.badge_rounded : Icons.agriculture_rounded,
                    size: 42,
                    color: _isEmployee ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              const Text(
                'تم التعرف على حسابك!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'يمكنك تأكيد الاسم ونوع الحساب أو تعديلهما مباشرة:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),

              // Details Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.navyUltraLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Identified Name Row
                    Row(
                      children: [
                        const Icon(Icons.person_rounded, size: 20, color: AppColors.navy),
                        const SizedBox(width: 8),
                        const Text(
                          'الاسم:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        if (!_isEditingName) ...[
                          Expanded(
                            flex: 3,
                            child: Text(
                              _nameController.text,
                              textAlign: TextAlign.end,
                              textDirection: TextDirection.rtl,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.navy),
                            tooltip: 'تعديل الاسم',
                            onPressed: () => setState(() => _isEditingName = true),
                          ),
                        ],
                      ],
                    ),

                    if (_isEditingName) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                hintText: 'أدخل الاسم الكامل',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
                            onPressed: () => setState(() => _isEditingName = false),
                          ),
                        ],
                      ),
                    ],

                    const Divider(height: 20),

                    // 2. Role Selector (Worker vs Customer)
                    Row(
                      children: [
                        Icon(
                          _isEmployee ? Icons.badge_rounded : Icons.storefront_rounded,
                          size: 20,
                          color: _isEmployee ? const Color(0xFF2E7D32) : const Color(0xFF1565C0),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'نوع الحساب:',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Toggle Buttons for Role
                    Row(
                      children: [
                        // Worker Button
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmployee = true),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: _isEmployee ? const Color(0xFF2E7D32) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isEmployee ? const Color(0xFF2E7D32) : AppColors.border,
                                  width: _isEmployee ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.badge_rounded,
                                    size: 18,
                                    color: _isEmployee ? Colors.white : AppColors.navy,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'موظف / كادر',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isEmployee ? Colors.white : AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Customer Button
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _isEmployee = false),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: !_isEmployee ? const Color(0xFF1565C0) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !_isEmployee ? const Color(0xFF1565C0) : AppColors.border,
                                  width: !_isEmployee ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.agriculture_rounded,
                                    size: 18,
                                    color: !_isEmployee ? Colors.white : AppColors.navy,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'عميل / مزارع',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: !_isEmployee ? Colors.white : AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Divider(height: 20),

                    // 3. Normalized Phone
                    Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded, size: 20, color: AppColors.navy),
                        const SizedBox(width: 8),
                        const Text(
                          'رقم الهاتف:',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        Text(
                          PhoneUtils.toDisplay(widget.user.phone),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.navy,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),

                    // 4. Source description
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'المصدر: ${widget.sourceDescription}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Confirm & Proceed Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isEmployee ? const Color(0xFF1B5E20) : AppColors.navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _handleConfirm,
                child: _isSaving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isEmployee ? 'المتابعة إلى تطبيق الموظفين' : 'المتابعة إلى بوابة العملاء',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
