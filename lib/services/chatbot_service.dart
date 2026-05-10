// lib/services/chatbot_service.dart

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:string_similarity/string_similarity.dart';
import '../services/gemini_service.dart';
import '../services/context_service.dart';
import '../services/firestore_service.dart';
import '../models/qa_model.dart';

class ChatbotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GeminiService _geminiService = GeminiService();
  final ContextService _contextService = ContextService();
  final double _similarityThreshold = 0.5;

  Future<String> createNewSession() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    final sessionRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('sessions')
        .doc();

    return sessionRef.id;
  }

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


  // Xử lý gửi ảnh - Gọi Gemini Vision để phân tích
  Future<String> generateResponseWithImage({
    required File image,
    required String sessionId,
    String? question,
  }) async {
    try {
      final chatHistory = await getChatHistory(sessionId);

      final response = await _geminiService.analyzeImage(
        image: image,
        chatHistory: chatHistory,
        question: question,
      );

      return response;
    } catch (e) {
      print('❌ Lỗi xử lý ảnh trong ChatbotService: $e');
      return 'Xin lỗi, tôi không thể xử lý hình ảnh này. Vui lòng thử lại với hình ảnh rõ hơn hoặc nhập câu hỏi bằng văn bản.';
    }
  }

  Future<String> generateResponse({
    required String question,
    required String sessionId,
  }) async {
    try {
      final chatHistory = await getChatHistory(sessionId);
      final qaData = await FirestoreService.loadQAData();
      final context = _contextService.analyzeContext(question, chatHistory);
      final hasLocalData = qaData.isNotEmpty;
// Tìm câu hỏi liên quan (độ tương đồng ≥ 0.5)
      List<QAPair> relevantData = [];
      if (hasLocalData) {
        relevantData = _findRelevantQA(question, qaData);
      }

      print('📊 Tìm thấy ${relevantData.length} cặp QA phù hợp');

      final response = await _geminiService.generateSmartResponse(
        question: question,
        availableData: relevantData,
        chatHistory: chatHistory,
        context: context,
        hasLocalData: hasLocalData,
      );

      _contextService.updateContext(question, response);

      return response;
    } catch (e) {
      return 'Xin lỗi, tôi gặp sự cố khi xử lý yêu cầu của bạn. Vui lòng thử lại sau.';
    }
  }

  List<QAPair> _findRelevantQA(String question, List<QAPair> qaData) {
    final lowerQuestion = question.toLowerCase().trim();
    final List<MapEntry<QAPair, double>> scored = [];

    for (var qa in qaData) {
      final score = StringSimilarity.compareTwoStrings(
          lowerQuestion, qa.question.toLowerCase());

      if (score >= _similarityThreshold) {
        scored.add(MapEntry(qa, score));
      }
    }

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(3).map((e) => e.key).toList();
  }
}