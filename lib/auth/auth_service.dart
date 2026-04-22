// lib/auth/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _currentUser;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  Future<void> refreshUser() async {
    await _auth.currentUser?.reload();
    _currentUser = _auth.currentUser;
    notifyListeners(); // 👈 Quan trọng: cập nhật UI ngay lập tức
  }
  // Đăng ký với Email/Password
  Future<UserCredential> registerWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'Mật khẩu quá yếu';
          break;
        case 'email-already-in-use':
          message = 'Email đã được sử dụng';
          break;
        case 'invalid-email':
          message = 'Email không hợp lệ';
          break;
        default:
          message = 'Đăng ký thất bại: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Đăng ký thất bại: $e');
    }
  }

  // Đăng nhập với Email/Password
  Future<UserCredential> loginWithEmail(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Không tìm thấy tài khoản với email này';
          break;
        case 'wrong-password':
          message = 'Mật khẩu không chính xác';
          break;
        case 'invalid-email':
          message = 'Email không hợp lệ';
          break;
        case 'user-disabled':
          message = 'Tài khoản đã bị vô hiệu hóa';
          break;
        default:
          message = 'Đăng nhập thất bại: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Đăng nhập thất bại: $e');
    }
  }

  // Đăng nhập với Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential;
      } else {
        // Mobile
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          throw Exception('Đăng nhập Google bị hủy');
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        return userCredential;
      }
    } on FirebaseAuthException catch (e) {
      throw Exception('Đăng nhập Google thất bại: ${e.message}');
    } catch (e) {
      throw Exception('Đăng nhập Google thất bại: $e');
    }
  }

  // Gửi email reset mật khẩu
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'Không tìm thấy tài khoản với email này';
          break;
        case 'invalid-email':
          message = 'Email không hợp lệ';
          break;
        default:
          message = 'Gửi email thất bại: ${e.message}';
      }
      throw Exception(message);
    } catch (e) {
      throw Exception('Gửi email thất bại: $e');
    }
  }

  // Đăng xuất
// Đăng xuất
  Future<void> logout() async {
    try {
      print('🔄 Bắt đầu đăng xuất...');

      // Đăng xuất Google
      await _googleSignIn.signOut();
      print('✅ Đã đăng xuất Google');

      // Đăng xuất Firebase
      await _auth.signOut();
      print('✅ Đã đăng xuất Firebase');

      print('✅ Đăng xuất thành công');
    } catch (e) {
      print('❌ Lỗi đăng xuất: $e');
    }
  }
}