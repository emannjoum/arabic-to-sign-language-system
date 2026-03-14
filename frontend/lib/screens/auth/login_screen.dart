import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart'; // Import the API
import '../app_navigation.dart';          // Import the main layout
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 1. Controllers to read the text inside the boxes
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false; // To show a loading spinner

  // 2. The Login Function
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both username and password")),
      );
      setState(() => _isLoading = false);
      return;
    }

    // Call your FastAPI backend!
    final success = await ApiService.login(username, password);

    if (success && mounted) {
      // Navigate to the Home Dashboard and remove the login screen from history
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppNavigation()),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed. Check credentials or server.")),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text("Log In", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                const SizedBox(height: 8),
                const Text("Welcome Back to Signly!", style: TextStyle(fontSize: 14, color: AppColors.textGray)),
                const SizedBox(height: 32),

                // Username Field wired up!
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(hintText: "Username"),
                ),
                const SizedBox(height: 16),

                // Password Field wired up!
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(hintText: "Password"),
                ),
                const SizedBox(height: 32),

                // Login Button wired up!
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Log in", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
                  },
                  child: const Text("Don't have an account? Sign up", style: TextStyle(color: AppColors.textBlack)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}