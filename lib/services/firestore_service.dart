import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qa_model.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'qa_data_dulich';

  // Stream real-time thay vì Future
  static Stream<List<QAPair>> getQADataStream() {
    debugPrint('FirestoreService: getQADataStream called.');
    return _firestore
        .collection(collectionName)
        .snapshots()
        .map((querySnapshot) {
      debugPrint('FirestoreService: Real-time update received: ${querySnapshot.docs.length} documents.');
      if (querySnapshot.docs.isEmpty) {
        debugPrint('FirestoreService: No documents found in collection "$collectionName".');
      }
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return QAPair(
          question: data['question'] ?? '',
          answer: data['answer'] ?? '',
        );
      }).toList();
    });
  }

  static Future<List<QAPair>> loadQAData() async {
    try {
      final querySnapshot = await _firestore.collection(collectionName).get();
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return QAPair(
          question: data['question'] ?? '',
          answer: data['answer'] ?? '',
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ FirestoreService: Lỗi tải dữ liệu QA: $e'); // Sử dụng debugPrint
      return [];
    }
  }
}