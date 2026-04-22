// lib/screens/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  String _fontSize = 'Vừa';
  bool _isLoading = true;

  final List<String> _fontSizes = ['Nhỏ', 'Vừa', 'Lớn'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      await settingsService.loadSettings();
      setState(() {
        _darkMode = settingsService.isDarkMode;
        _fontSize = settingsService.fontSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Lỗi tải cài đặt: $e');
    }
  }

  // ✅ Tự động lưu khi thay đổi
  Future<void> _autoSaveSettings() async {
    try {
      final settingsService = Provider.of<SettingsService>(context, listen: false);
      await settingsService.saveSettings(
        darkMode: _darkMode,
        fontSize: _fontSize,
      );
    } catch (e) {
      _showSnackBar('❌ Lỗi lưu cài đặt: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Cài đặt'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        // ✅ ĐÃ XÓA NÚT LƯU
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B89FF)))
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Tài khoản', Icons.person_outline),
          _buildProfileCard(user),
          const SizedBox(height: 16),
          _buildSettingItem(
            icon: Icons.lock_outline,
            title: 'Đổi mật khẩu',
            subtitle: 'Thay đổi mật khẩu đăng nhập',
            onTap: () => _showChangePasswordDialog(context),
          ),
          const Divider(height: 30, thickness: 1),
          _buildSectionHeader('Hiển thị', Icons.brightness_4),
          _buildSwitchItem(
            icon: Icons.dark_mode,
            title: 'Chế độ tối',
            value: _darkMode,
            onChanged: (value) async {
              setState(() => _darkMode = value);
              await _autoSaveSettings(); // ✅ Tự động lưu
            },
          ),
          _buildChoiceItem(
            icon: Icons.text_fields,
            title: 'Cỡ chữ',
            value: _fontSize,
            options: _fontSizes,
            onSelected: (value) async {
              setState(() => _fontSize = value);
              await _autoSaveSettings(); // ✅ Tự động lưu
            },
          ),
          const Divider(height: 30, thickness: 1),
          _buildSectionHeader('Thông tin ứng dụng', Icons.info_outline),
          _buildInfoItem(icon: Icons.update, title: 'Phiên bản', value: '1.0.0'),
          _buildSettingItem(icon: Icons.star_outline, title: 'Đánh giá ứng dụng', onTap: () => _rateApp(context)),
          _buildSettingItem(icon: Icons.share, title: 'Giới thiệu bạn bè', onTap: () => _shareApp(context)),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: const Color(0xFF9B89FF), size: 18),
          ),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF9B89FF))),
        ],
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF9B89FF), width: 2)),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF9B89FF).withOpacity(0.1),
              child: Text(user?.email?.substring(0, 1).toUpperCase() ?? 'U', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF9B89FF))),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user?.displayName ?? 'Người dùng', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _showEditProfileDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit, size: 14, color: Color(0xFF9B89FF)),
                        const SizedBox(width: 4),
                        Text('Chỉnh sửa', style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF9B89FF))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF9B89FF), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])) : null,
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey[400] : Colors.grey),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchItem({required IconData icon, required String title, required bool value, required Function(bool) onChanged}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))],
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF9B89FF), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF9B89FF),
      ),
    );
  }

  Widget _buildChoiceItem({required IconData icon, required String title, required String value, required List<String> options, required Function(String) onSelected}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF9B89FF), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
        subtitle: Text(value, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF9B89FF)),
          onSelected: onSelected,
          itemBuilder: (context) => options.map((option) => PopupMenuItem(value: option, child: Text(option, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
        ),
      ),
    );
  }

  Widget _buildInfoItem({required IconData icon, required String title, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 1))],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFF9B89FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: const Color(0xFF9B89FF), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black)),
        trailing: Text(value, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500)),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          title: Text('Đổi mật khẩu', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: obscureCurrent,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu hiện tại',
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9B89FF)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF9B89FF)),
                    onPressed: () => setState(() => obscureCurrent = !obscureCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Mật khẩu mới',
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF9B89FF)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF9B89FF)),
                    onPressed: () => setState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Xác nhận mật khẩu mới',
                  labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF9B89FF)),
                  suffixIcon: IconButton(
                    icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off, color: const Color(0xFF9B89FF)),
                    onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text('Hủy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (currentPasswordController.text.isEmpty || newPasswordController.text.isEmpty || confirmPasswordController.text.isEmpty) {
                  _showSnackBar('Vui lòng nhập đầy đủ thông tin');
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  _showSnackBar('Mật khẩu mới phải có ít nhất 6 ký tự');
                  return;
                }
                if (newPasswordController.text != confirmPasswordController.text) {
                  _showSnackBar('Mật khẩu xác nhận không khớp');
                  return;
                }
                setState(() => isLoading = true);
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) throw Exception('Chưa đăng nhập');
                  if (user.email == null) throw Exception('Không có email');
                  final credential = EmailAuthProvider.credential(email: user.email!, password: currentPasswordController.text);
                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPasswordController.text);
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _showSnackBar('✅ Đổi mật khẩu thành công!');
                  }
                } on FirebaseAuthException catch (e) {
                  String message;
                  switch (e.code) {
                    case 'wrong-password': message = 'Mật khẩu hiện tại không đúng'; break;
                    case 'weak-password': message = 'Mật khẩu mới quá yếu'; break;
                    case 'requires-recent-login': message = 'Vui lòng đăng nhập lại trước khi đổi mật khẩu'; break;
                    default: message = 'Lỗi: ${e.message}';
                  }
                  _showSnackBar('❌ $message');
                } catch (e) {
                  _showSnackBar('❌ Lỗi: $e');
                } finally {
                  setState(() => isLoading = false);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9B89FF),foregroundColor: Colors.white,),
              child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Đổi mật khẩu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final nameController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );
    bool isLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          title: Text('Chỉnh sửa hồ sơ', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: nameController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              labelText: 'Tên hiển thị',
              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person, color: Color(0xFF9B89FF)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Hủy', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (nameController.text.trim().isEmpty) {
                  _showSnackBar('Vui lòng nhập tên hiển thị');
                  return;
                }
                setState(() => isLoading = true);
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) throw Exception('Chưa đăng nhập');

                  final newName = nameController.text.trim();

                  // 1. Cập nhật displayName
                  await user.updateDisplayName(newName);

                  // 2. Force refresh user (quan trọng)
                  await user.reload();

                  // 3. Lấy lại user mới nhất
                  final refreshedUser = FirebaseAuth.instance.currentUser;

                  // 4. Cập nhật AuthService để UI biết
                  final authService = Provider.of<AuthService>(context, listen: false);
                  authService.refreshUser(); // ✅ Cần thêm method này

                  if (mounted) {
                    Navigator.pop(dialogContext);
                    _showSnackBar('✅ Cập nhật thành công!');

                    // 5. Force rebuild toàn bộ trang
                    setState(() {});
                  }
                } catch (e) {
                  _showSnackBar('❌ Lỗi: ${e.toString()}');
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
    style: TextButton.styleFrom(
    backgroundColor: const Color(0xFF9B89FF),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: isLoading
    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text('Lưu', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _rateApp(BuildContext context) => _showSnackBar('Tính năng đang phát triển');
  void _shareApp(BuildContext context) => _showSnackBar('Tính năng đang phát triển');
}