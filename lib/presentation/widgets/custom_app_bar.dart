import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Unified Custom AppBar for Ali Dates App
/// Includes company branding, back button with Arabic label, and optional employee header
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final String? employeeName;
  final PreferredSizeWidget? bottom;

  const CustomAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBackButton = true,
    this.onBack,
    this.actions,
    this.employeeName,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(bottom == null ? (employeeName != null ? 75 : 60) : (bottom is TabBar ? 125 : 110));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.navy,
      elevation: 3,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (employeeName != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'الموظف: $employeeName',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                color: Colors.white.withAlpha(200),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      leading: showBackButton
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'رجوع',
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ),
            )
          : null,
      actions: actions,
      bottom: bottom,
    );
  }
}
