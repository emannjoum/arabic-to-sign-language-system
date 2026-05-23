import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/skeleton_frame.dart';

class ApiService {
  // static const String baseUrl = 'http://100.116.62.123:8000';
  static const String baseUrl = 'http://127.0.0.1:8000';
  // static const String baseUrl = 'http://192.168.1.11:8000';

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
  static Future<ProcessResponse?> processText(
    String text, {
    String? forceMode,
  }) async {
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

  // 5. ADD BOOKMARK
  static Future<bool> addBookmark(String word) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/bookmarks?word=${Uri.encodeComponent(word)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Bookmark Error: $e');
      return false;
    }
  }

  // 6. REMOVE BOOKMARK
  static Future<bool> removeBookmark(String word) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/bookmarks?word=${Uri.encodeComponent(word)}'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Remove Bookmark Error: $e');
      return false;
    }
  }

  // 7. GET BOOKMARKS
  static Future<List<Map<String, dynamic>>> getBookmarks() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/bookmarks'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('Get Bookmarks Error: $e');
      return [];
    }
  }

  // 8. FETCH TOPICS
  // 8. FETCH TOPICS
  static Future<List<String>> fetchTopics() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/topics'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final List data = decoded is List ? decoded : decoded['topics'] ?? [];
        return data.map((e) => e.toString()).toList();
      }
      print('Fetch Topics Error: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Fetch Topics Error: $e');
      return [];
    }
  }

  // 9. GET PROFILE
  static Future<Map<String, dynamic>?> getProfile() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get Profile Error: $e');
      return null;
    }
  }
}
