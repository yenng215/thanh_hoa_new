// trang_menu.dart
import 'package:flutter/material.dart';
import '../screens/chat_page.dart';
import '../screens/history_page.dart';
import '../services/history_service.dart';
import 'package:provider/provider.dart';
import '../auth/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../auth/login_page.dart';
import '../screens/weather_page.dart';
import '../screens/settings_page.dart';
import '../screens/contact_support_page.dart';
import '../screens/simple_map_page.dart';
class TrangMenu extends StatelessWidget {
  const TrangMenu({super.key});

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    Navigator.pop(context);
    try {
      await authService.logout();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi đăng xuất: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : null,
          gradient: isDark
              ? null
              : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FFFE),
              Color(0xFFF0E6FF),
              Colors.white,
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF9B89FF), Color(0xFF7B68EE), Color(0xFFB8A9FF)],
                  stops: [0.0, 0.6, 1.0],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            child: Text(
                              currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9B89FF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentUser?.displayName ?? 'Người dùng',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser?.email ?? currentUser?.phoneNumber ?? 'Chưa có thông tin',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuItem(
              context: context,
              icon: Icons.chat_bubble_outline,
              title: "Cuộc trò chuyện mới",
              iconColor: const Color(0xFF9B89FF),
              onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ChatPage())),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.wb_sunny,
              title: "Thời tiết",
              iconColor: const Color(0xFFFFA500),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherPage())),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.map_outlined,
              title: "Bản đồ",
              iconColor: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SimpleMapPage())
              ),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.history_rounded,
              title: "Lịch sử gần đây",
              iconColor: const Color(0xFF4CAF50),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryPage())),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.settings_rounded,
              title: "Cài đặt",
              iconColor: Colors.grey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.help_outline_rounded,
              title: "Liên hệ hỗ trợ",
              iconColor: Colors.teal,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportPage())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Divider(thickness: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE0E0E0)),
            ),
            _buildMenuItem(
              context: context,
              icon: Icons.logout_rounded,
              title: "Đăng xuất",
              iconColor: Colors.red,
              textColor: Colors.red,
              showArrow: false,
              onTap: () => _showLogoutDialog(context, authService),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color iconColor,
    Color? textColor,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor ?? (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
                if (showArrow)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context, AuthService authService) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi ứng dụng?',
          style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600]),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleLogout(context, authService);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}