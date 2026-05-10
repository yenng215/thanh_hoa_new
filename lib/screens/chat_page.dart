// lib/screens/chat_page.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chatbot_service.dart';
import '../services/history_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/input_field.dart';
import '../auth/auth_service.dart';
import 'trang_menu.dart';

class ChatPage extends StatefulWidget {
  final String? sessionId;

  const ChatPage({super.key, this.sessionId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with SingleTickerProviderStateMixin {
  final ChatbotService _chatbotService = ChatbotService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentSessionId;
  bool _isTyping = false;
  bool _hasSavedToHistory = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    if (widget.sessionId != null) {
      _currentSessionId = widget.sessionId;//// Mở từ lịch sử → tải lại hội thoại cũ
      _hasSavedToHistory = true;
      await _loadChatHistory();
    } else {
      _currentSessionId = await _chatbotService.createNewSession();
      _hasSavedToHistory = false;
    }
  }

  Future<void> _loadChatHistory() async {
    if (_currentSessionId == null) return;

    final history = await _chatbotService.getChatHistory(_currentSessionId!);
    setState(() {
      _messages = history;
    });
    _scrollToBottom();
  }

  // Kiểm tra kết nối internet
  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Hiện dialog thông báo mất mạng
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF2C2C2C)
            : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text(
              'Mất kết nối mạng',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Vui lòng kiểm tra lại kết nối Wi-Fi hoặc dữ liệu di động rồi thử lại.',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white70
                : Colors.black87,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B89FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendImage(File image, {String? question}) async {
    if (_isLoading || _isTyping) return;

    // Kiểm tra mạng trước
    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      _showNoInternetDialog();
      return;
    }

    // Lưu session vào lịch sử
    if (!_hasSavedToHistory && _messages.isEmpty) {
      try {
        await _chatbotService.saveSessionToHistory(
          sessionId: _currentSessionId!,
          title: question?.isNotEmpty == true ? question! : '[Hình ảnh]',
        ).timeout(const Duration(seconds: 5));
        _hasSavedToHistory = true;
      } catch (_) {
      }
    }

    final userMessage = {
      'text': question ?? '',
      'isUser': true,
      'isImage': true,
      'imagePath': image.path,
      'created': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(userMessage);
      _isLoading = true;
      _isTyping = true;
    });

    _scrollToBottom();

    // Lưu tin nhắn user
    try {
      await _chatbotService.saveMessage(
        sessionId: _currentSessionId!,
        text: question?.isNotEmpty == true ? question! : '[Hình ảnh]',
        isUser: true,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
    }

    try {
      final response = await _chatbotService.generateResponseWithImage(
        image: image,
        sessionId: _currentSessionId!,
        question: question,
      ).timeout(const Duration(seconds: 30));

      final botMessage = {
        'text': response,
        'isUser': false,
        'created': DateTime.now().toIso8601String(),
        'timestamp': DateTime.now(),
      };

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      // Lưu tin nhắn bot (bỏ qua nếu offline)
      try {
        await _chatbotService.saveMessage(
          sessionId: _currentSessionId!,
          text: response,
          isUser: false,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline: bỏ qua
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      final isTimeout = e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout');
      final errorText = isTimeout
          ? 'Không có kết nối mạng. Vui lòng kiểm tra lại internet và thử lại!'
          : 'Không thể xử lý hình ảnh. Vui lòng thử lại sau!';

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isTimeout ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  color: const Color(0xFF9B89FF),
                ),
                const SizedBox(width: 8),
                const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(errorText),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B89FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading || _isTyping) return;

    // Kiểm tra mạng trước
    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      _showNoInternetDialog();
      return;
    }

    // Lưu session vào lịch sử
    if (!_hasSavedToHistory && _messages.isEmpty) {
      try {
        await _chatbotService.saveSessionToHistory(
          sessionId: _currentSessionId!,
          title: text,
        ).timeout(const Duration(seconds: 5));
        _hasSavedToHistory = true;
      } catch (_) {
      }
    }

    final userMessage = {
      'text': text,
      'isUser': true,
      'created': DateTime.now().toIso8601String(),
      'timestamp': DateTime.now(),
    };

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
      _isLoading = true;
      _isTyping = true;
    });

    _scrollToBottom();

    // Lưu tin nhắn user
    try {
      await _chatbotService.saveMessage(
        sessionId: _currentSessionId!,
        text: text,
        isUser: true,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
    }

    try {
      final response = await _chatbotService.generateResponse(
        question: text,
        sessionId: _currentSessionId!,
      ).timeout(const Duration(seconds: 30));

      String? mapDestination;
      String finalResponse = response;
// Xử lý map destination
      final mapRegex = RegExp(r'\[MAP:(.+?)\]');
      final match = mapRegex.firstMatch(response);
      if (match != null) {
        mapDestination = match.group(1);
        finalResponse = response.replaceAll(mapRegex, '').trim();
      }

      final botMessage = {
        'text': finalResponse,
        'isUser': false,
        'created': DateTime.now().toIso8601String(),
        'mapDestination': mapDestination,
        'timestamp': DateTime.now(),
      };

      setState(() {
        _messages.add(botMessage);
        _isTyping = false;
      });

      // Lưu tin nhắn bot
      try {
        await _chatbotService.saveMessage(
          sessionId: _currentSessionId!,
          text: finalResponse,
          isUser: false,
          mapDestination: mapDestination,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Offline: bỏ qua
      }

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });

      final isTimeout = e.toString().contains('TimeoutException') ||
          e.toString().contains('timeout');
      final errorText = isTimeout
          ? 'Không có kết nối mạng. Vui lòng kiểm tra lại internet và thử lại!'
          : 'Đã có lỗi xảy ra. Vui lòng thử lại sau!';

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isTimeout ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  color: const Color(0xFF9B89FF),
                ),
                const SizedBox(width: 8),
                const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(errorText),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9B89FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: const TrangMenu(),
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: widget.sessionId != null
            ? Padding(
          padding: const EdgeInsets.all(6),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF9B89FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
          ),
        )
            : Builder(
          builder: (context) => Padding(
            padding: const EdgeInsets.all(6),
            child: GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu, color: Colors.white, size: 22),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('lib/assets/logo.png', width: 32, height: 32,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF9B89FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.travel_explore, color: Colors.white, size: 20),
                );
              },
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Thanh Hóa",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  "Travel Assistant",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : const Color(0xFF9B89FF),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return ChatBubble(
                  text: msg['text'],
                  isUser: msg['isUser'],
                  isImage: msg['isImage'] == true,
                  imagePath: msg['imagePath'],
                  mapDestination: msg['mapDestination'],
                  timestamp: msg['timestamp'] != null
                      ? (msg['timestamp'] is DateTime
                      ? msg['timestamp']
                      : DateTime.parse(msg['timestamp']))
                      : null,
                );
              },
            ),
          ),
          InputField(
            controller: _controller,
            onSend: _sendMessage,
            onImageSelected: (image, {question}) {
              if (image != null) {
                _sendImage(image, question: question);
              }
            },
            isLoading: _isLoading || _isTyping,
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE4F7), Color(0xFFFFC0E4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFFFFC0E4).withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC0E4).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'lib/assets/logo.png',
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.smart_toy,
                    color: Color(0xFF9B89FF),
                    size: 20,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              constraints: const BoxConstraints(maxWidth: 100),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE4F7),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: const _TypingDots(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('lib/assets/logo.png', width: 80, height: 80),
          const SizedBox(height: 10),
          Text(
            "Chào mừng bạn đến với\nThanh Hóa Travel Assistant!",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Hãy nhập câu hỏi hoặc gửi ảnh để bắt đầu nhé!",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => __TypingDotsState();
}

class __TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _animations = List.generate(3, (index) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.15,
            index * 0.15 + 0.5,
            curve: Curves.easeInOut,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    double yOffset = 0;

    if (_animations[index].value < 0.5) {
      yOffset = -8 * (_animations[index].value * 2);
    } else {
      yOffset = -8 * (2 - _animations[index].value * 2);
    }

    return Transform.translate(
      offset: Offset(0, yOffset),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF9B89FF),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}