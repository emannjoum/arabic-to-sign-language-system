import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/skeleton_frame.dart';

class ApiService {
  // CRITICAL: 10.0.2.2 is the special IP Android Emulators use to reach your laptop's localhost
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const storage = FlutterSecureStorage();

  // 1. REGISTER
  static Future<bool> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Register Error: $e');
      return false;
    }
  }

  // 2. LOGIN
  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Save the JWT token securely on the device
        await storage.write(key: 'jwt_token', value: data['access_token']);
        return true;
      }
      return false;
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  // 3. LOGOUT
  static Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }

  // 4. PROCESS TEXT (The Core Pipeline)
  static Future<ProcessResponse?> processText(String text) async {
    try {
      print("Sending to FastAPI: $text");
      
      final response = await http.post(
        Uri.parse('$baseUrl/process'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}), // Matches your UserMessage schema in Python
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Received from FastAPI: ${data['mode']}");
        return ProcessResponse.fromJson(data);
      } else {
        print('Backend Error: ${response.body}');
        return null;
      }
    } catch (e) {
      print('Network Error: $e');
      // If the server is offline, we catch it here so the app doesn't crash
      return null; 
    }
  }
}