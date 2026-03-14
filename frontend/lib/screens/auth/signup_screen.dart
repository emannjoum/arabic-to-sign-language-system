import 'package:flutter/material.dart';
import '../../core/colors.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

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
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5)),
              ],
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
                TextFormField(decoration: const InputDecoration(hintText: "Username")),
                const SizedBox(height: 16),

                // Password Field
                TextFormField(obscureText: true, decoration: const InputDecoration(hintText: "Password")),
                const SizedBox(height: 16),

                // Confirm Password Field
                TextFormField(obscureText: true, decoration: const InputDecoration(hintText: "Confirm Password")),
                const SizedBox(height: 32),

                // Sign Up Button
                ElevatedButton(
                  onPressed: () {
                    // TODO: Connect later
                  },
                  child: const Text("Sign up", style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 16),

                // Navigate back to Login
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