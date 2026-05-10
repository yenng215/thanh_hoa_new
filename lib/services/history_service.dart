// lib/services/history_service.dart (THÊM PHƯƠNG THỨC saveNewSession)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get _userId => _auth.currentUser?.uid;

  static DocumentReference _getSessionRef(String sessionId) {
    if (_userId == null) throw Exception('User not logged in');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('sessions')
        .doc(sessionId);
  }

  static CollectionReference _getSessionsRef() {//ấy toàn bộ session
    if (_userId == null) throw Exception('User not logged in');
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('sessions');
  }

  // ✅ THÊM MỚI: Lưu session mới vào lịch sử (chỉ khi có tin nhắn đầu tiên)
  static Future<void> saveNewSession({
    required String sessionId,
    required String title,
  }) async {
    try {
      await _getSessionRef(sessionId).set({
        'title': title,
        'created': DateTime.now().toIso8601String(),
        'lastMessage': title,
        'lastMessageTime': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Không thể lưu session: $e');
    }
  }

  // Lấy ds tất cả sessions
  static Future<List<Map<String, dynamic>>> getAllSessions() async {
    try {
      final snapshot = await _getSessionsRef()
          .orderBy('created', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Cuộc trò chuyện mới',
          'created': data['created'] ?? DateTime.now().toIso8601String(),
          'lastMessage': data['lastMessage'] ?? '',
          'lastMessageTime': data['lastMessageTime'] ?? data['created'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Đổi tên session
  static Future<void> renameSession(String sessionId, String newTitle) async {
    try {
      await _getSessionRef(sessionId).update({
        'title': newTitle,
      });
    } catch (e) {
      throw Exception('Không thể đổi tên: $e');
    }
  }

  // Xóa session và tất cả messages con
  static Future<void> deleteSession(String sessionId) async {
    try {
      // Xóa tất cả messages trong session
      final messagesSnapshot = await _getSessionRef(sessionId)
          .collection('messages')
          .get();

      for (var doc in messagesSnapshot.docs) {
        await doc.reference.delete();
      }

      // Xóa session
      await _getSessionRef(sessionId).delete();
    } catch (e) {
      throw Exception('Không thể xóa: $e');
    }
  }

  // Lấy tin nhắn của session
  static Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    try {
      final snapshot = await _getSessionRef(sessionId)
          .collection('messages')
          .orderBy('created')
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'text': data['text'],
          'isUser': data['isUser'],
          'created': data['created'],
          'mapDestination': data['mapDestination'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }
}