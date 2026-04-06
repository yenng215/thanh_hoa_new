// lib/auth/reset_password_sent_page.dart
import 'package:flutter/material.dart';

class ResetPasswordSentPage extends StatelessWidget {
  final String email;

  const ResetPasswordSentPage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFFE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon thành công
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read,
                  size: 50,
                  color: Color(0xFF9B89FF),
                ),
              ),
              const SizedBox(height: 30),

              // Tiêu đề
              const Text(
                'Kiểm tra email của bạn',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),

              // Nội dung
              Text(
                'Chúng tôi đã gửi email đặt lại mật khẩu đến',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9B89FF),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Hướng dẫn
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildInstruction(
                      icon: Icons.mail_outline,
                      text: 'Mở email từ Thanh Hóa Travel Assistant',
                    ),
                    const Divider(height: 20),
                    _buildInstruction(
                      icon: Icons.link,
                      text: 'Nhấp vào link đặt lại mật khẩu trong email',
                    ),
                    const Divider(height: 20),
                    _buildInstruction(
                      icon: Icons.password,
                      text: 'Tạo mật khẩu mới và đăng nhập',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Nút quay lại đăng nhập
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Quay về màn hình đăng nhập
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B89FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Quay lại đăng nhập',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Link mở email app
              TextButton(
                onPressed: () {
                  // Mở ứng dụng email mặc định
                  // Có thể dùng url_launcher để mở mailto:
                },
                child: const Text(
                  'Mở ứng dụng Email',
                  style: TextStyle(
                    color: Color(0xFF9B89FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction({required IconData icon, required String text}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF9B89FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF9B89FF), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}