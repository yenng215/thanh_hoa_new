// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'screens/chat_page.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => SettingsService()..loadSettings()),
      ],
      child: Consumer2<AuthService, SettingsService>(  // ✅ Dùng Consumer2 để lắng nghe cả 2 service
        builder: (context, authService, settingsService, child) {
          final settingsService = Provider.of<SettingsService>(context, listen: false);

          // Khi có user đăng nhập, load settings từ Firestore
          if (authService.currentUser != null) {
            // Load settings nếu chưa load hoặc user mới
            WidgetsBinding.instance.addPostFrameCallback((_) {
              settingsService.loadSettings();
            });
          }
          return MaterialApp(
            title: 'Thanh Hóa Travel',
            debugShowCheckedModeBanner: false,
            theme: settingsService.themeData, // ✅ Lấy theme từ SettingsService
            builder: (context, child) {
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(settingsService.textScaleFactor),
                ),
                child: child!,
              );
            },
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    // Thêm key để force rebuild khi cần
    return FutureBuilder(
      future: Future.delayed(Duration.zero),
      builder: (context, snapshot) {
        print('🔐 AuthWrapper - User: ${authService.currentUser?.email ?? 'null'}');

        if (authService.currentUser == null) {
          print('➡️ Chuyển đến LoginPage');
          return const LoginPage();
        }

        print('➡️ Chuyển đến ChatPage');
        return const ChatPage();
      },
    );
  }
}