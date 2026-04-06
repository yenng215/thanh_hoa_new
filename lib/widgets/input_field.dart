// lib/widgets/input_field.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class InputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const InputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.isLoading = false,
  });

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  late stt.SpeechToText _speechToText;
  bool _speechEnabled = false;
  bool _isListening = false;
  String _currentLocaleId = 'vi_VN';

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      debugPrint('Initializing speech recognition...');

      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          _setListening(false);
        },
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _setListening(false);
          }
        },
      );

      if (_speechEnabled) {
        final locales = await _speechToText.locales();
        debugPrint('Available locales: $locales');

        // Tìm locale tiếng Việt
        final viLocale = locales.firstWhere(
              (locale) => locale.localeId.startsWith('vi'),
          orElse: () => locales.firstWhere(
                (locale) => locale.localeId.contains('VN'),
            orElse: () => locales.first,
          ),
        );
        _currentLocaleId = viLocale.localeId;
        debugPrint('Selected locale: $_currentLocaleId');
      }
    } catch (e) {
      debugPrint('Init speech error: $e');
      _speechEnabled = false;
    }
  }

  void _setListening(bool listening) {
    if (mounted) {
      setState(() {
        _isListening = listening;
      });
    }
  }

  Future<void> _startListening() async {
    try {
      // 1. Kiểm tra và xin quyền
      var permissionStatus = await Permission.microphone.status;

      if (permissionStatus.isDenied) {
        permissionStatus = await Permission.microphone.request();
      }

      if (permissionStatus.isPermanentlyDenied) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cần cấp quyền Microphone'),
              content: const Text(
                'Vui lòng cấp quyền microphone trong phần Cài đặt của thiết bị.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                  child: const Text('Mở cài đặt'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (!permissionStatus.isGranted) {
        debugPrint('Microphone permission not granted');
        return;
      }

      // 2. Kiểm tra speech engine
      if (!_speechEnabled) {
        final available = await _speechToText.initialize();
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Không thể khởi động nhận dạng giọng nói. '
                      'Vui lòng kiểm tra:\n'
                      '1. Đã cài đặt Google Speech Services\n'
                      '2. Đã tải gói ngôn ngữ Tiếng Việt\n'
                      '3. Có kết nối internet',
                ),
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // 3. Bắt đầu nghe
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            // Cập nhật textfield ngay lập tức
            widget.controller.text = result.recognizedWords;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );

            // Tự động dừng nếu là kết quả cuối
            if (result.finalResult) {
              _stopListening();
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
        partialResults: true,
        localeId: _currentLocaleId,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      );

      if (mounted) {
        setState(() => _isListening = true);
      }
    } catch (e) {
      debugPrint('Error starting listening: $e');
      _setListening(false);
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechToText.stop();
      _setListening(false);
    } catch (e) {
      debugPrint('Error stopping listening: $e');
    }
  }

  /// Xử lý gửi tin nhắn
  void _handleSend() {
    if (widget.isLoading) return;

    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      debugPrint('Sending message: $text');
      widget.onSend();
      widget.controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  /// Bottom sheet cho icon +
  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 160,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF9B89FF)),
              title: const Text('Thư viện ảnh'),
              onTap: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  debugPrint('Ảnh chọn từ thư viện: ${pickedFile.path}');
                  // TODO: Xử lý ảnh ở đây
                }
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF9B89FF)),
              title: const Text('Chụp ảnh'),
              onTap: () async {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  debugPrint('Ảnh chụp: ${pickedFile.path}');
                  // TODO: Xử lý ảnh ở đây
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon +
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF9B89FF)),
            onPressed: () => _showOptionsBottomSheet(context),
          ),

          // Icon Microphone
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: _isListening ? Colors.red : const Color(0xFF9B89FF),
                  size: 28,
                ),
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              if (_isListening)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
            ],
          ),

          // Ô nhập văn bản
          Expanded(
            child: TextField(
              controller: widget.controller,
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: _isListening ? 'Đang nghe...' : 'Nhập câu hỏi của bạn...',
                hintStyle: TextStyle(
                  color: _isListening ? Colors.red : Colors.grey,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),

          // Icon gửi
          IconButton(
            icon: widget.isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF9B89FF),
              ),
            )
                : const Icon(Icons.send, color: Color(0xFF9B89FF)),
            onPressed: widget.isLoading ? null : _handleSend,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    super.dispose();
  }
}