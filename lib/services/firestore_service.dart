import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qa_model.dart';
import 'package:flutter/foundation.dart'; // Import for debugPrint

class FirestoreService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String collectionName = 'qa_data_dulich';

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