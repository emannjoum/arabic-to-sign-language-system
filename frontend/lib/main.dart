import 'package:flutter/material.dart';
import 'core/app_theme.dart';
import 'screens/app_navigation.dart';
import 'screens/auth/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const SignlyApp());
}

class SignlyApp extends StatelessWidget {
  const SignlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'Signly',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        home: const _Splash(),
      ),
    );
  }
}

class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await ApiService.getToken();
    
    // 1. If there's no token at all, go straight to Login
    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // 2. If a token exists, test it by trying to get the user's profile
    final profile = await ApiService.getProfile();
    
    if (!mounted) return;

    if (profile == null) {
      // 3. The token is expired! Delete it and go to Login
      await ApiService.logout(); 
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else {
      // 4. The token is healthy! Go to the main app
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
