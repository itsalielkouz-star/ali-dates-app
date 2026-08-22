import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Ali Dates Brand Logo Widget with graceful Web CORS fallback
class AppBrandLogo extends StatelessWidget {
  final double size;
  final bool showBadge;

  const AppBrandLogo({
    super.key,
    this.size = 50,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: Image.asset(
            'assets/images/logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => _buildVectorLogoFallback(),
          ),
        ),
      ),
    );
  }

  Widget _buildVectorLogoFallback() {
    return Container(
      color: AppColors.navy,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.eco_rounded,
              color: AppColors.dateGold,
              size: size * 0.45,
            ),
            if (size >= 40)
              Text(
                'تمور علي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
