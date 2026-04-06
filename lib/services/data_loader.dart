// lib/services/data_loader.dart (giữ lại để tương thích code cũ)

import 'firestore_service.dart';
import '../models/qa_model.dart';

class DataLoader {
  static Future<List<QAPair>> loadQAData() async {
    // Sử dụng Firestore thay vì file local
    return await FirestoreService.loadQAData();
  }
}