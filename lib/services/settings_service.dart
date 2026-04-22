// lib/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isDarkMode = false;
  String _fontSize = 'Vừa';

  SettingsService() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_auth.currentUser != null) {
        loadSettings();
      }
    });
  }
  bool get isDarkMode => _isDarkMode;
  String get fontSize => _fontSize;
// ✅ Lấy tỷ lệ kích thước chữ
  double get textScaleFactor {
    switch (_fontSize) {
      case 'Nhỏ':
        return 0.85;
      case 'Lớn':
        return 1.2;
      default: // 'Vừa'
        return 1.0;
    }
  }
  // ✅ Lấy theme data dựa trên cài đặt
  ThemeData get themeData {
    if (_isDarkMode) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF9B89FF),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B89FF)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2C2C2C),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[700]!),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF9B89FF)),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white),
          titleMedium: TextStyle(color: Colors.white),
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF9B89FF),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
        ),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7FFFE),
        primaryColor: const Color(0xFF9B89FF),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF9B89FF),
          elevation: 0,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B89FF)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Color(0xFF9B89FF)),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
          titleLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF9B89FF),
          surface: Colors.white,
          background: Color(0xFFF7FFFE),
        ),
      );
    }
  }

  // Lấy tài liệu settings của user hiện tại
  DocumentReference _getSettingsRef() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not logged in');
    }
    return _firestore.collection('users').doc(userId).collection('settings').doc('preferences');
  }

  // Tải cài đặt từ Firestore
  Future<void> loadSettings() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        _isDarkMode = false;
        _fontSize = 'Vừa';
        notifyListeners();
        return;
      }

      final doc = await _getSettingsRef().get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isDarkMode = data['darkMode'] ?? false;
        _fontSize = data['fontSize'] ?? 'Vừa';
      } else {
        _isDarkMode = false;
        _fontSize = 'Vừa';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi tải cài đặt: $e');
      _isDarkMode = false;
      _fontSize = 'Vừa';
      notifyListeners();
    }
  }

  // Lưu cài đặt lên Firestore
  Future<void> saveSettings({
    required bool darkMode,
    required String fontSize,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      await _getSettingsRef().set({
        'darkMode': darkMode,
        'fontSize': fontSize,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _isDarkMode = darkMode;
      _fontSize = fontSize;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi lưu cài đặt: $e');
      throw Exception('Không thể lưu cài đặt');
    }
  }
}