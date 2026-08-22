import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/services/storage_service.dart';
import 'data/services/supabase_service.dart';
import 'presentation/auth/login_screen.dart';
import 'presentation/employee/employee_home_screen.dart';
import 'presentation/customer/customer_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Local Storage Cache
  await StorageService.init();

  // 2. Initialize Supabase & Sync State
  await SupabaseService().initialize();

  runApp(const AliDatesApp());
}

class AliDatesApp extends StatelessWidget {
  const AliDatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = SupabaseService().currentUser;

    Widget initialScreen = const LoginScreen();
    if (currentUser != null) {
      if (currentUser.isEmployee) {
        initialScreen = const EmployeeHomeScreen();
      } else {
        initialScreen = const CustomerMainScreen();
      }
    }

    return MaterialApp(
      title: '${AppConstants.appNameAr} - ${AppConstants.appNameEn}',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Arabic Localization & RTL Directionality
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'JO'), // Arabic (Jordan)
        Locale('ar', ''),
      ],
      locale: const Locale('ar', 'JO'),
      home: initialScreen,
    );
  }
}
