import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';
import '../models/qa_model.dart';
import 'map_page.dart';

class MapSuggestionsScreen extends StatefulWidget {
  final String query;

  const MapSuggestionsScreen({super.key, required this.query});

  @override
  State<MapSuggestionsScreen> createState() => _MapSuggestionsScreenState();
}

class _MapSuggestionsScreenState extends State<MapSuggestionsScreen> {
  List<QAPair> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    try {
      final allQA = await FirestoreService.loadQAData();

      // Lọc các QA liên quan đến địa điểm
      final filtered = allQA.where((qa) {
        final lowerQuestion = qa.question.toLowerCase();
        final lowerQuery = widget.query.toLowerCase();

        return lowerQuestion.contains(lowerQuery) ||
            lowerQuestion.contains('đường') ||
            lowerQuestion.contains('đến') ||
            lowerQuestion.contains('đi') ||
            qa.answer.toLowerCase().contains('thanh hóa');
      }).toList();

      setState(() {
        _suggestions = filtered;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openMap(String destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(destination: destination),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gợi ý cho "${widget.query}"'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _suggestions.isEmpty
          ? const Center(child: Text('Không tìm thấy gợi ý nào'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final qa = _suggestions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: Text(
                qa.question,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                qa.answer.length > 100
                    ? '${qa.answer.substring(0, 100)}...'
                    : qa.answer,
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                // Trích xuất địa điểm từ câu hỏi
                final locationName = qa.question
                    .replaceAll('đường đi đến', '')
                    .replaceAll('chỉ đường', '')
                    .replaceAll('đến', '')
                    .trim();

                _openMap('$locationName, Thanh Hóa');
              },
            ),
          );
        },
      ),
    );
  }
}