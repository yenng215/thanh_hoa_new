import 'package:flutter/material.dart';
import '../services/history_service.dart';
import 'chat_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List sessions = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final data = await HistoryService.getAllSessions();
    data.sort((a, b) => b['created'].compareTo(a['created']));
    setState(() => sessions = data);
  }

  String getTitle(Map session) {
    return session['title'] ?? "Cuộc trò chuyện mới";
  }

  String _formatTime(String created) {
    try {
      final time = DateTime.parse(created);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(time.year, time.month, time.day);

      if (messageDate == today) {
        // Hôm nay: hiển thị giờ:phút
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (messageDate == today.subtract(const Duration(days: 1))) {
        // Hôm qua
        return 'Hôm qua ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else {
        // Cũ hơn: hiển thị ngày/tháng
        return '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return created;
    }
  }

  void deleteSession(String id) async {
    await HistoryService.deleteSession(id);
    load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.6),
            radius: 1.5,
            colors: [
              Color(0xFFE8C6FF),     // Hồng nhạt (trung tâm)
              Color(0xFFC6B8FF),     // Tím nhạt
              Color(0xFFF0DAFF),     // Hồng rất nhạt
              Color(0xFFDAD0FF),     // Tím rất nhạt
              Color(0xFFC6DEFF),     // Xanh dương nhạt
              Color(0xFFDAEAFF),     // Xanh dương rất nhạt
              Colors.white,          // Trắng (viền ngoài)
            ],
            stops: [0.0, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0],
          ),
        ),
        child: Column(
          children: [
            // AppBar với màu trong suốt để thấy gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFC6B8FF).withOpacity(0.8),
                    const Color(0xFFC6B8FF).withOpacity(0.5),
                    const Color(0xFFC6B8FF).withOpacity(0.2),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B89FF).withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  "Lịch sử trò chuyện",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                iconTheme: const IconThemeData(color: Colors.white),
              ),
            ),
            // Nội dung
            Expanded(
              child: sessions.isEmpty
                  ? const Center(
                child: Text(
                  "Chưa có cuộc trò chuyện nào",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: sessions.length,
                itemBuilder: (context, i) {
                  final s = sessions[i];
                  final title = getTitle(s);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(sessionId: s['id']),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC6B8FF).withOpacity(0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFC6B8FF),
                                    Color(0xFFA594FF),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey[500],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTime(s['created']),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: Color(0xFFA594FF)),
                              onSelected: (v) async {
                                if (v == "delete") {
                                  deleteSession(s['id']);
                                }

                                if (v == "rename") {
                                  final controller = TextEditingController(text: title);

                                  showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text("Đổi tên"),
                                      content: TextField(controller: controller),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const Text("Hủy"),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            await HistoryService.renameSession(
                                              s['id'],
                                              controller.text,
                                            );
                                            load();
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFC6B8FF),
                                          ),
                                          child: const Text("Lưu"),
                                        )
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (c) => const [
                                PopupMenuItem(
                                  value: "share",
                                  child: Row(
                                    children: [
                                      Icon(Icons.share, size: 18, color: Color(0xFFC6B8FF)),
                                      SizedBox(width: 8),
                                      Text("Chia sẻ"),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: "rename",
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: Color(0xFFC6B8FF)),
                                      SizedBox(width: 8),
                                      Text("Đổi tên"),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: "delete",
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text("Xóa"),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}