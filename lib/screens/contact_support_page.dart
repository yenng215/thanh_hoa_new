// lib/screens/contact_support_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContactSupportPage extends StatefulWidget {
  const ContactSupportPage({super.key});

  @override
  State<ContactSupportPage> createState() => _ContactSupportPageState();
}

class _ContactSupportPageState extends State<ContactSupportPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FFFE),
      appBar: AppBar(
        title: const Text(
          'Liên hệ hỗ trợ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF9B89FF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. HEADER
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9B89FF),
                  const Color(0xFFB8A9FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Icon(Icons.support_agent, size: 50, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Chúng tôi luôn sẵn sàng hỗ trợ bạn!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Phản hồi trong vòng 24h',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // 2. THÔNG TIN LIÊN HỆ
          const Text(
            '📞 Thông tin liên hệ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          _buildContactCard(
            icon: Icons.email_outlined,
            title: 'Email hỗ trợ',
            content: 'support@thanhhoatravel.com',
            color: Colors.blue,
            onTap: () => _launchEmail(),
          ),

          _buildContactCard(
            icon: Icons.phone_outlined,
            title: 'Hotline',
            content: '1900 1234 (8:00 - 22:00)',
            color: Colors.green,
            onTap: () => _launchPhone(),
          ),

          const SizedBox(height: 25),

          // 3. CÂU HỎI THƯỜNG GẶP
          const Text(
            '❓ Câu hỏi thường gặp',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          _buildFAQItem(
            question: 'Làm sao để tìm đường đến địa điểm?',
            answer: 'Bạn chỉ cần hỏi "Chỉ đường đến [tên địa điểm]" (ví dụ: "Chỉ đường đến Sầm Sơn"). Sau đó nhấn vào nút bản đồ màu tím để xem đường đi chi tiết.',
          ),

          _buildFAQItem(
            question: 'Ứng dụng có mất phí không?',
            answer: 'Hoàn toàn miễn phí! Bạn có thể sử dụng tất cả tính năng mà không mất bất kỳ chi phí nào.',
          ),


          _buildFAQItem(
            question: 'Tôi muốn báo lỗi hoặc góp ý?',
            answer: 'Bạn có thể sử dụng form "Gửi phản hồi" bên dưới hoặc gửi email trực tiếp đến support@thanhhoatravel.com',
          ),

          _buildFAQItem(
            question: 'Ứng dụng có hỗ trợ giọng nói không?',
            answer: 'Có! Bạn có thể nhấn vào icon micro để nói câu hỏi thay vì gõ chữ.',
          ),

          const SizedBox(height: 25),

          // 4. FORM GỬI PHẢN HỒI
          const Text(
            '📝 Gửi phản hồi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Tiêu đề',
                      hintText: 'Ví dụ: Góp ý tính năng, Báo lỗi...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.title, color: Color(0xFF9B89FF)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _contentController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Nội dung',
                      hintText: 'Nhập nội dung chi tiết...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Icon(Icons.message, color: Color(0xFF9B89FF)),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B89FF),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSending
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Gửi phản hồi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),

          // 5. MẠNG XÃ HỘI
          const Text(
            '🌐 Kết nối với chúng tôi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialButton(
                  icon: Icons.facebook,
                  color: const Color(0xFF1877F2),
                  label: 'Facebook',
                  onTap: () => _launchSocial('fb'),
                ),
                _buildSocialButton(
                  icon: Icons.sms,
                  color: const Color(0xFF0068FF),
                  label: 'Zalo',
                  onTap: () => _launchSocial('zalo'),
                ),
                _buildSocialButton(
                  icon: Icons.email,
                  color: Colors.red,
                  label: 'Gmail',
                  onTap: () => _launchEmail(),
                ),
                _buildSocialButton(
                  icon: Icons.youtube_searched_for,
                  color: Colors.red,
                  label: 'YouTube',
                  onTap: () => _launchSocial('youtube'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 6. THÔNG TIN THÊM
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thời gian hỗ trợ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thứ 2 - Thứ 6: 8:00 - 22:00\nThứ 7 - Chủ nhật: 9:00 - 18:00',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(content),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_forward_ios, color: color, size: 16),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF9B89FF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.help_outline,
            color: Color(0xFF9B89FF),
            size: 18,
          ),
        ),
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final email = 'support@thanhhoatravel.com';
    final url = 'mailto:$email?subject=Hỗ trợ từ người dùng';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showSnackBar('Không thể mở ứng dụng email');
    }
  }

  Future<void> _launchPhone() async {
    final url = 'tel:19001234';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      _showSnackBar('Không thể thực hiện cuộc gọi');
    }
  }

  void _openLiveChat(BuildContext context) {
    _showSnackBar('Tính năng đang phát triển. Vui lòng gửi email!');
  }

  void _launchSocial(String platform) {
    String url;
    switch (platform) {
      case 'fb':
        url = 'https://facebook.com/thanhhoatravel';
        break;
      case 'zalo':
        url = 'https://zalo.me/19001234';
        break;
      case 'youtube':
        url = 'https://youtube.com/@thanhhoatravel';
        break;
      default:
        url = 'https://facebook.com/thanhhoatravel';
    }

    _showSnackBar('Đang mở $platform...');
    // TODO: Thực tế sẽ launchUrl
  }

  Future<void> _sendFeedback() async {
    if (_titleController.text.isEmpty || _contentController.text.isEmpty) {
      _showSnackBar('Vui lòng nhập đầy đủ tiêu đề và nội dung');
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('feedback')
          .add({
        'userId': user?.uid,
        'userEmail': user?.email,
        'title': _titleController.text,
        'content': _contentController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _contentController.clear();

      _showSnackBar('✅ Gửi phản hồi thành công! Cảm ơn bạn.');
    } catch (e) {
      _showSnackBar('❌ Lỗi gửi phản hồi: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}