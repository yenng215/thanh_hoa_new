// lib/services/chatbot_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/gemini_service.dart';
import '../services/context_service.dart';
import '../services/firestore_service.dart';
import '../models/qa_model.dart';

class ChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();
  final ContextService _contextService = ContextService();

  // ✅ SỬA: Tạo session mới nhưng KHÔNG lưu vào lịch sử
  Future<String> createNewSession() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc();

    // ❌ XÓA: Không tự động lưu session nữa
    // ✅ Chỉ tạo ID mới, chưa lưu bất cứ document nào

    return sessionRef.id;
  }

  // ✅ THÊM MỚI: Lưu session chỉ khi có tin nhắn đầu tiên
  Future<void> saveSessionToHistory({
    required String sessionId,
    required String title,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = DateTime.now().toIso8601String();
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .set({
      'title': title,
      'created': now,
      'lastMessage': title,
      'lastMessageTime': now,
    });
  }

  // Lưu tin nhắn vào session
  Future<void> saveMessage({
    required String sessionId,
    required String text,
    required bool isUser,
    String? mapDestination,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final messageRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .doc();

    final now = DateTime.now().toIso8601String();
    await messageRef.set({
      'text': text,
      'isUser': isUser,
      'created': now,
      'mapDestination': mapDestination,
    });

    // Cập nhật lastMessage cho session (chỉ khi session đã tồn tại)
    final sessionDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .get();

    if (sessionDoc.exists) {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('sessions')
          .doc(sessionId)
          .update({
        'lastMessage': text.length > 50 ? '${text.substring(0, 50)}...' : text,
        'lastMessageTime': now,
      });
    }
  }

  // Lấy lịch sử chat của session
  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final messagesSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc(sessionId)
        .collection('messages')
        .orderBy('created')
        .get();

    return messagesSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'text': data['text'],
        'isUser': data['isUser'],
        'created': data['created'],
        'mapDestination': data['mapDestination'],
      };
    }).toList();
  }

  // Tạo phản hồi từ Gemini
  Future<String> generateResponse({
    required String question,
    required String sessionId,
  }) async {
    try {
      // Lấy lịch sử chat
      final chatHistory = await getChatHistory(sessionId);

      // Lấy dữ liệu QA từ Firestore
      final qaData = await FirestoreService.loadQAData();

      // Phân tích ngữ cảnh
      final context = _contextService.analyzeContext(question, chatHistory);

      // Kiểm tra có dữ liệu local không
      final hasLocalData = qaData.isNotEmpty;

      // Tìm câu trả lời phù hợp từ dữ liệu QA
      List<QAPair> relevantData = [];
      if (hasLocalData) {
        relevantData = _findRelevantQA(question, qaData);
      }

      // Tạo phản hồi
      final response = await _geminiService.generateSmartResponse(
        question: question,
        availableData: relevantData,
        chatHistory: chatHistory,
        context: context,
        hasLocalData: hasLocalData,
      );

      // Cập nhật ngữ cảnh
      _contextService.updateContext(question, response);

      return response;
    } catch (e) {
      return 'Xin lỗi, tôi gặp sự cố khi xử lý yêu cầu của bạn. Vui lòng thử lại sau.';
    }
  }

  // Tìm câu hỏi liên quan trong dữ liệu QA
  List<QAPair> _findRelevantQA(String question, List<QAPair> qaData) {
    final lowerQuestion = question.toLowerCase();
    final List<QAPair> results = [];

    // Tách từ khóa
    final keywords = lowerQuestion
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((w) => w.length > 2)
        .toSet();

    for (var qa in qaData) {
      final lowerQ = qa.question.toLowerCase();
      int matchCount = 0;

      for (var keyword in keywords) {
        if (lowerQ.contains(keyword)) {
          matchCount++;
        }
      }

      if (matchCount > 0) {
        results.add(qa);
        if (results.length >= 3) break;
      }
    }

    return results;
  }
}