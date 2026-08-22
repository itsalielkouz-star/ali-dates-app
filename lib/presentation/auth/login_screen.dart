import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/supabase_service.dart';
import '../employee/employee_home_screen.dart';
import '../customer/customer_main_screen.dart';
import '../widgets/app_brand_logo.dart';
import 'change_password_dialog.dart';
import 'identity_discovery_dialog.dart';
import '../../core/utils/phone_utils.dart';

/// Login Screen for Ali Dates (Employees & Customers)
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _routeUser(UserProfile user) {
    if (user.isEmployee) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmployeeHomeScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CustomerMainScreen()),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final rawPhone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    final result = await SupabaseService().login(rawPhone, password);
    setState(() => _isLoading = false);

    if (result != null && mounted) {
      final user = result.user;

      void proceedToApp(UserProfile confirmedUser) {
        if (password == '1234' || confirmedUser.needsPasswordChange) {
          ChangePasswordDialog.show(
            context,
            user: confirmedUser,
            onPasswordChanged: () {
              _routeUser(confirmedUser);
            },
          );
        } else {
          _routeUser(confirmedUser);
        }
      }

      // Show Identity Discovery Dialog so the user sees what name and app role was recognized
      IdentityDiscoveryDialog.show(
        context,
        user: user,
        sourceDescription: result.sourceDescription,
        onProceed: proceedToApp,
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('بيانات الدخول غير صحيحة، يرجى التأكد من رقم الهاتف وكلمة المرور'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ali Dates Logo & Brand Header
                const AppBrandLogo(size: 96),
                const SizedBox(height: 16),
                const Text(
                  AppConstants.appNameAr,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ali Dates - Jordan Facility',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.appTagline,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 28),

                // Login Form Card
                Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'تسجيل الدخول',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'أدخل رقم هاتفك لتسجيل الدخول التلقائي',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Phone Number Field (Username)
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(
                                labelText: 'رقم الهاتف المسجل',
                                hintText: '079XXXXXXX',
                                prefixIcon: Icon(Icons.phone_iphone_rounded, color: AppColors.navy),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال رقم الهاتف';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Field
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور (الافتراضية: 1234)',
                                prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.navy),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_rounded
                                        : Icons.visibility_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال كلمة المرور';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
