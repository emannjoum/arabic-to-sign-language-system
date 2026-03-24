import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/skeleton_frame.dart';

class ApiService {
  static const String baseUrl = 'http://100.116.62.123:8000';
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

  // GET TOKEN HELPER
  static Future<String?> getToken() async {
    return await storage.read(key: 'jwt_token');
  }
  
  // 4. PROCESS TEXT (The Core Pipeline)
  static Future<ProcessResponse?> processText(String text, {String? forceMode}) async {
    try {
      final token = await getToken();
      
      // 2. Build the JSON body dynamically
      final Map<String, dynamic> bodyData = {"text": text};
      if (forceMode != null) {
        bodyData["force_mode"] = forceMode;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/process'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bodyData), // Send the updated body
      );

      if (response.statusCode == 200) {
        return ProcessResponse.fromJson(jsonDecode(response.body));
      } else {
        print("Backend Error: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Network Error: $e");
      return null;
    }
  }
}