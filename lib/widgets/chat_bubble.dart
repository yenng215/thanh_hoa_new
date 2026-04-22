// lib/widgets/chat_bubble.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../screens/map_page.dart';

class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool? isImage;
  final String? imagePath;
  final String? mapDestination;
  final String? startLocation;
  final DateTime? timestamp;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isImage,
    this.imagePath,
    this.mapDestination,
    this.startLocation,
    this.timestamp,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mapRegex = RegExp(r'\[MAP:(.+?)\]');
    final match = mapRegex.firstMatch(text);
    final String displayText = text.replaceAll(mapRegex, '').trim();
    final String? extractedDestination = match?.group(1);
    final finalDestination = mapDestination ?? extractedDestination;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isUser: false),
          if (!isUser) const SizedBox(width: 8),

          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isUser && finalDestination != null)
                  _buildMapButton(context, finalDestination),

                // Tin nhắn của user có ảnh - SỬA: hình vuông, căn lề trái
                if (isUser && isImage == true && imagePath != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, // Căn lề trái
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(imagePath!),
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (displayText.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9B89FF),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomLeft: Radius.circular(20),
                                bottomRight: Radius.circular(0),
                              ),
                            ),
                            child: Text(
                              displayText,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Tin nhắn text bình thường (không có ảnh)
                if (!(isUser && isImage == true) && displayText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: const BoxConstraints(maxWidth: 260),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF9B89FF) : const Color(0xFFFFE4F7),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(0),
                        bottomRight: isUser ? const Radius.circular(0) : const Radius.circular(20),
                      ),
                    ),
                    child: MarkdownBody(
                      data: displayText,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 15,
                          color: isUser ? Colors.white : Colors.black,
                        ),
                        listBullet: TextStyle(
                          fontSize: 15,
                          color: isUser ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),

                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Text(
                      _formatTime(timestamp!),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 8),
          if (isUser) _buildAvatar(isUser: true),
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUser
            ? const LinearGradient(
          colors: [Color(0xFF9B89FF), Color(0xFF7B68EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Color(0xFFFFE4F7), Color(0xFFFFC0E4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isUser
              ? const Color(0xFF7B68EE).withOpacity(0.3)
              : const Color(0xFFFFC0E4).withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUser ? const Color(0xFF9B89FF) : const Color(0xFFFFC0E4)).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: isUser
            ? const Icon(Icons.person, color: Colors.white, size: 20)
            : Image.asset(
          'lib/assets/logo.png',
          width: 24,
          height: 24,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(Icons.smart_toy, color: Color(0xFF9B89FF), size: 20);
          },
        ),
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, String destination) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapPage(
              destination: destination,
              startLocation: startLocation,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF9B89FF), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, color: const Color(0xFF9B89FF), size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mở bản đồ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF9B89FF),
                  ),
                ),
                if (startLocation != null)
                  Text(
                    'Từ: $startLocation',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}