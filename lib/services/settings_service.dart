// lib/services/settings_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SettingsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isDarkMode = false;
  String _fontSize = 'Vừa';

  bool get isDarkMode => _isDarkMode;
  String get fontSize => _fontSize;

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
      final doc = await _getSettingsRef().get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _isDarkMode = data['darkMode'] ?? false;
        _fontSize = data['fontSize'] ?? 'Vừa';
      } else {
        // Cài đặt mặc định
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
      await _getSettingsRef().set({
        'darkMode': darkMode,
        'fontSize': fontSize,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _isDarkMode = darkMode;
      _fontSize = fontSize;
      notifyListeners();
    } catch (e) {
      debugPrint('Lỗi lưu cài đặt: $e');
      throw Exception('Không thể lưu cài đặt');
    }
  }

  // Cập nhật chế độ tối
  Future<void> setDarkMode(bool value) async {
    await saveSettings(darkMode: value, fontSize: _fontSize);
  }

  // Cập nhật cỡ chữ
  Future<void> setFontSize(String value) async {
    await saveSettings(darkMode: _isDarkMode, fontSize: value);
  }

  // Lấy kích thước chữ cho ứng dụng
  double getTextScaleFactor() {
    switch (_fontSize) {
      case 'Nhỏ':
        return 0.85;
      case 'Lớn':
        return 1.15;
      default:
        return 1.0;
    }
  }
}