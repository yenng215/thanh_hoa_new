// lib/widgets/input_field.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class InputField extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(File? image, {String? question})? onImageSelected;
  final bool isLoading;

  const InputField({
    super.key,
    required this.controller,
    required this.onSend,
    this.onImageSelected,
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
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
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
        final viLocale = locales.firstWhere(
              (locale) => locale.localeId.startsWith('vi'),
          orElse: () => locales.firstWhere(
                (locale) => locale.localeId.contains('VN'),
            orElse: () => locales.first,
          ),
        );
        _currentLocaleId = viLocale.localeId;
      }
    } catch (e) {
      debugPrint('Init speech error: $e');
      _speechEnabled = false;
    }
  }

  void _setListening(bool listening) {
    if (mounted) setState(() => _isListening = listening);
  }

  Future<void> _startListening() async {
    try {
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

      if (!permissionStatus.isGranted) return;

      if (!_speechEnabled) {
        final available = await _speechToText.initialize();
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể khởi động nhận dạng giọng nói')),
            );
          }
          return;
        }
      }

      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            widget.controller.text = result.recognizedWords;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
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

      if (mounted) setState(() => _isListening = true);
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

  void _handleSend() {
    if (widget.isLoading) return;

    final text = widget.controller.text.trim();

    if (_selectedImage != null) {
      if (widget.onImageSelected != null) {
        widget.onImageSelected!(_selectedImage, question: text.isNotEmpty ? text : null);
      }
      widget.controller.clear();
      _clearSelectedImage();
      FocusScope.of(context).unfocus();
      return;
    }

    if (text.isNotEmpty) {
      widget.onSend();
      widget.controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _takePhoto() async {
    try {
      final permissionStatus = await Permission.camera.request();

      if (!permissionStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cần cấp quyền camera để chụp ảnh')),
          );
        }
        return;
      }

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  void _showImageOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF9B89FF), size: 28),
              title: Text(
                'Chụp ảnh',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Chụp ảnh mới từ camera',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF9B89FF), size: 28),
              title: Text(
                'Chọn từ thư viện',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Chọn ảnh có sẵn trong máy',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        if (_selectedImage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: _clearSelectedImage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(6),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Chưa gửi',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF9B89FF)),
                onPressed: () => _showImageOptions(context),
              ),
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
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: _isListening
                        ? 'Đang nghe...'
                        : (_selectedImage != null
                        ? 'Nhập câu hỏi về ảnh này...'
                        : 'Nhập câu hỏi hoặc chọn ảnh...'),
                    hintStyle: TextStyle(
                      color: _isListening
                          ? Colors.red
                          : (isDark ? Colors.grey[500] : Colors.grey),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
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
        ),
      ],
    );
  }

  @override
  void dispose() {
    _speechToText.stop();
    _speechToText.cancel();
    super.dispose();
  }
}