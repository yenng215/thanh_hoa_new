import 'dart:collection';
import 'location_extractor.dart';

class ConversationContext {
  String? currentTopic;
  List<String> keywords = [];
  String? locationName;
  bool isDirectionRelated = false;
  bool requiresMap = false;
  DateTime lastUpdated = DateTime.now();
  Queue<String> recentTopics = Queue<String>();
  Map<String, dynamic> entities = {};

  ConversationContext();

  @override
  String toString() {
    return 'Topic: $currentTopic, Keywords: $keywords, Location: $locationName';
  }
}

class ContextService {
  ConversationContext _currentContext = ConversationContext();
  final int _maxRecentTopics = 5;

  // Phân tích ngữ cảnh từ câu hỏi và lịch sử
  ConversationContext analyzeContext(String question, List<Map<String, dynamic>>? chatHistory) {
    final context = ConversationContext();

    // Trích xuất từ khóa
    context.keywords = _extractKeywords(question);

    // Xác định chủ đề
    context.currentTopic = _determineTopic(question, chatHistory);

    // Kiểm tra liên quan đến chỉ đường
    context.isDirectionRelated = LocationExtractor.isDirectionRequest(question) ||
        _isDirectionRelated(question, context.keywords);

    // Trích xuất địa danh
    context.locationName = _extractLocationName(question, chatHistory);

    // Kiểm tra cần hiển thị bản đồ
    context.requiresMap = _requiresMap(question, context);

    // Lưu chủ đề gần đây
    if (context.currentTopic != null) {
      _addRecentTopic(context.currentTopic!);
    }

    return context;
  }

  // Cập nhật ngữ cảnh sau khi nhận phản hồi
  void updateContext(String question, String response) {
    final keywords = _extractKeywords(question + " " + response);
    _currentContext.keywords.addAll(keywords);
    _currentContext.keywords = _currentContext.keywords.toSet().toList();

    // Cập nhật thời gian
    _currentContext.lastUpdated = DateTime.now();

    // Xác định lại chủ đề từ câu trả lời
    final topic = _determineTopicFromResponse(response);
    if (topic != null) {
      _currentContext.currentTopic = topic;
      _addRecentTopic(topic);
    }
  }

  // Lấy ngữ cảnh hiện tại
  ConversationContext get currentContext => _currentContext;

  // Đặt lại ngữ cảnh
  void resetContext() {
    _currentContext = ConversationContext();
  }

  // Trích xuất từ khóa quan trọng
  List<String> _extractKeywords(String text) {
    final stopWords = {
      'và', 'hoặc', 'nhưng', 'mà', 'của', 'để', 'với', 'từ', 'về',
      'trong', 'ngoài', 'trên', 'dưới', 'trước', 'sau', 'khi', 'nếu',
      'thì', 'là', 'có', 'không', 'gì', 'nào', 'đâu', 'bao', 'giờ'
    };

    final words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\sàáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ]'), ' ')
        .split(' ')
        .where((word) => word.length > 2 && !stopWords.contains(word))
        .toList();

    return words;
  }

  // Xác định chủ đề
  String? _determineTopic(String question, List<Map<String, dynamic>>? chatHistory) {
    // Ưu tiên chủ đề từ lịch sử gần đây
    if (_currentContext.currentTopic != null &&
        DateTime.now().difference(_currentContext.lastUpdated).inMinutes < 5) {
      return _currentContext.currentTopic;
    }

    // Tìm trong lịch sử chat
    if (chatHistory != null && chatHistory.length > 1) {
      final lastMessages = chatHistory.reversed.take(3).toList();

      for (var msg in lastMessages) {
        final text = msg['text'].toString().toLowerCase();

        // Kiểm tra các chủ đề phổ biến
        final topics = {
          'du lịch': ['du lịch', 'thăm quan', 'đi chơi', 'nghỉ dưỡng', 'địa điểm', 'thắng cảnh'],
          'ăn uống': ['ăn', 'uống', 'nhà hàng', 'quán ăn', 'đặc sản', 'nem chua', 'món ngon'],
          'khách sạn': ['khách sạn', 'nhà nghỉ', 'nơi ở', 'chỗ ngủ', 'lưu trú'],
          'di chuyển': ['đi lại', 'phương tiện', 'xe', 'bus', 'taxi', 'chỉ đường'],
          'lịch sử': ['lịch sử', 'văn hóa', 'truyền thống', 'di tích', 'cổ'],
          'mua sắm': ['mua sắm', 'chợ', 'siêu thị', 'quà lưu niệm', 'đồ lưu niệm'],
        };

        for (var entry in topics.entries) {
          if (entry.value.any((keyword) => text.contains(keyword))) {
            return entry.key;
          }
        }
      }
    }

    return null;
  }

  // Xác định từ phản hồi
  String? _determineTopicFromResponse(String response) {
    final topics = {
      'du lịch': ['địa điểm', 'thắng cảnh', 'du lịch', 'tham quan', 'nổi tiếng'],
      'ăn uống': ['nhà hàng', 'quán ăn', 'đặc sản', 'món ngon', 'ẩm thực'],
      'khách sạn': ['khách sạn', 'resort', 'homestay', 'nơi ở', 'lưu trú'],
      'di chuyển': ['đường đi', 'phương tiện', 'khoảng cách', 'giờ đi', 'chỉ đường'],
    };

    final lowerResponse = response.toLowerCase();
    for (var entry in topics.entries) {
      if (entry.value.any((keyword) => lowerResponse.contains(keyword))) {
        return entry.key;
      }
    }

    return _currentContext.currentTopic;
  }

  // Kiểm tra liên quan đến chỉ đường
  bool _isDirectionRelated(String question, List<String> keywords) {
    final directionWords = [
      'đường', 'đến', 'chỉ', 'hướng',
      'bản đồ', 'map', 'vị trí'
    ];

    return directionWords.any((word) =>
    question.contains(word) || keywords.contains(word));
  }

  // Trích xuất tên địa điểm
  String? _extractLocationName(String question, List<Map<String, dynamic>>? chatHistory) {
    // Ưu tiên từ ngữ cảnh hiện tại
    if (_currentContext.locationName != null &&
        question.toLowerCase().contains(_currentContext.locationName!.toLowerCase())) {
      return _currentContext.locationName;
    }

    // Tìm trong lịch sử chat
    if (chatHistory != null) {
      for (var msg in chatHistory.reversed.take(5)) {
        final text = msg['text'].toString();

        // Tìm tên địa điểm phổ biến Thanh Hóa
        final locations = [
          'thành nhà hồ', 'sầm sơn', 'suối cá thần', 'pù luông',
          'đền bà chúa', 'biển hải tiến', 'bến en', 'hàm rồng',
          'suối cá cẩm lương', 'cẩm lương'
        ];

        for (var location in locations) {
          if (text.toLowerCase().contains(location)) {
            return LocationExtractor.thanhHoaLocations[location];
          }
        }
      }
    }

    return null;
  }

  bool _requiresMap(String question, ConversationContext context) {
    return context.isDirectionRelated ||
        question.contains('bản đồ') ||
        question.contains('map') ||
        question.contains('chỉ đường');
  }

  void _addRecentTopic(String topic) {
    _currentContext.recentTopics.addFirst(topic);
    if (_currentContext.recentTopics.length > _maxRecentTopics) {
      _currentContext.recentTopics.removeLast();
    }
  }
}