import 'package:flutter/material.dart';
import '../../core/colors.dart';
import '../../services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. Controllers to read the text
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  
  bool _isLoading = false;

  // 2. The Signup Function
  Future<void> _handleSignup() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmController.text.trim();

    // Basic Validation
    if (username.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match!")));
      return;
    }

    setState(() => _isLoading = true);

    // 3. Call FastAPI!
    final success = await ApiService.register(username, password);

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        // Show success message and go back to Login screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! You can now log in."), backgroundColor: Colors.green),
        );
        Navigator.pop(context); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Registration failed. Username might be taken.")),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
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
                const Text("Sign Up", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textBlack)),
                const SizedBox(height: 8),
                const Text("Become a member of signly", style: TextStyle(fontSize: 14, color: AppColors.textGray)),
                const SizedBox(height: 32),

                // Username Field
                TextFormField(controller: _usernameController, decoration: const InputDecoration(hintText: "Username")),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: "Password")),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(controller: _confirmController, obscureText: true, decoration: const InputDecoration(hintText: "Confirm Password")),
                const SizedBox(height: 32),

                // Sign Up Button Wired Up!
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : const Text("Sign up", style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Already have an account? Log in", style: TextStyle(color: AppColors.textBlack)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}