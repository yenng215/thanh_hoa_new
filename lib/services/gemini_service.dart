import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_keys.dart';
import '../models/qa_model.dart';
import '../services/context_service.dart';
import '../services/location_extractor.dart';

class GeminiService {
  static const String baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
  static const String visionUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent";

  // Phân tích ảnh với Gemini Vision
  Future<String> analyzeImage({
    required File image,
    List<Map<String, dynamic>>? chatHistory,
    String? question,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = _getMimeType(image.path);

      // Xây dựng lịch sử chat gần đây để Gemini hiểu ngữ cảnh
      String historySection = '';
      if (chatHistory != null && chatHistory.isNotEmpty) {
        final recent = chatHistory.reversed.take(6).toList().reversed.toList();
        final lines = recent.map((m) {
          final role = m['isUser'] == true ? 'Người dùng' : 'Trợ lý';
          final text = m['text'].toString().replaceAll(RegExp(r'\[MAP:.+?\]'), '').trim();
          return '$role: $text';
        }).where((l) => l.isNotEmpty).join('\n');

        if (lines.isNotEmpty) {
          historySection = '''
=== LỊCH SỬ HỘI THOẠI GẦN ĐÂY ===
$lines
(Dùng lịch sử này để hiểu ngữ cảnh, KHÔNG lặp lại những gì đã nói)
''';
        }
      }
      final bool hasQuestion = question != null && question.trim().isNotEmpty;
      final String prompt = '''
BẠN LÀ TRỢ LÝ DU LỊCH THANH HÓA THÔNG MINH.
Trả lời bằng tiếng Việt, thân thiện và tự nhiên.

$historySection

=== HÌNH ẢNH ===
Người dùng vừa gửi một hình ảnh (đính kèm bên dưới).

${hasQuestion ? '''
=== CÂU HỎI CỦA NGƯỜI DÙNG ===
"${question!.trim()}"

=== CÁCH XỬ LÝ ===
BƯỚC 1 — Nhìn ảnh để hiểu ngữ cảnh (đây là gì: địa điểm, món ăn, sản phẩm, con người, sự kiện...)
BƯỚC 2 — Đọc kỹ CÂU HỎI bên trên và xác định người dùng muốn biết CHÍNH XÁC điều gì.
BƯỚC 3 — Trả lời ĐÚNG TRỌNG TÂM câu hỏi đó, dùng ảnh làm ngữ cảnh.

VÍ DỤ VỀ CÁCH XỬ LÝ ĐÚNG:
• Ảnh: món ăn | Hỏi: "có quán nào bán không?" → Liệt kê ngay tên quán, địa chỉ cụ thể ở Thanh Hóa
• Ảnh: địa điểm | Hỏi: "vé vào cửa bao nhiêu?" → Trả lời giá vé, không mô tả phong cảnh
• Ảnh: sản phẩm | Hỏi: "mua ở đâu?" → Gợi ý nơi mua cụ thể, không giới thiệu sản phẩm
• Ảnh: lễ hội | Hỏi: "tổ chức khi nào?" → Trả lời thời gian, địa điểm tổ chức

QUAN TRỌNG:
• KHÔNG trả lời lan man theo flow mặc định (nhận diện → giới thiệu → tư vấn) nếu câu hỏi không yêu cầu
• Nếu câu hỏi hỏi về "nơi", "chỗ", "quán", "cửa hàng", "địa điểm" → phải có tên và địa chỉ CỤ THỂ
• Nếu không chắc → nói "Bạn có thể tìm ở..." thay vì bịa đặt
''' : '''
=== CÁCH XỬ LÝ ===
Người dùng không kèm câu hỏi. Hãy:
1. Nhận diện nội dung ảnh (địa điểm, món ăn, sự kiện, sản phẩm...)
2. Kết nối với du lịch / văn hóa Thanh Hóa nếu có thể
3. Chủ động gợi ý thông tin hữu ích nhất với khách du lịch
4. Nếu không nhận ra → hỏi lại người dùng
Độ dài: 3-5 câu, đừng dài dòng.
'''}

QUY TẮC CHUNG:
• KHÔNG bịa đặt thông tin. Nếu không chắc → dùng "có thể", "thường thấy ở", "bạn có thể thử tìm tại..."
• Không lặp lại thông tin đã nói trong lịch sử chat
• Trả lời tự nhiên như đang trò chuyện, không liệt kê dạng học thuật

TRẢ LỜI:
''';

      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "inlineData": {
                  "mimeType": mimeType,
                  "data": base64Image
                }
              },
              {
                "text": prompt
              }
            ]
          }
        ],
        "generationConfig": {
          "temperature": 0.7,
          "maxOutputTokens": 1024,
          "topP": 0.95,
          "topK": 40
        }
      };

      print('📸 Đang gửi ảnh lên Gemini Vision...');

      final response = await http.post(
        Uri.parse('$baseUrl?key=${ApiKeys.gemini}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['candidates'][0]['content']['parts'][0]['text'];
        print('✅ Gemini Vision phân tích ảnh thành công');
        return result;
      } else {
        print('❌ Lỗi Gemini Vision: ${response.statusCode}');
        return 'Xin lỗi, tôi không thể xử lý hình ảnh này. Vui lòng thử lại sau.';
      }
    } catch (e) {
      print('❌ Exception trong analyzeImage: $e');
      return 'Xin lỗi, tôi không thể xử lý hình ảnh này. Vui lòng thử lại.';
    }
  }

  String _getMimeType(String path) {
    if (path.toLowerCase().endsWith('.png')) return 'image/png';
    if (path.toLowerCase().endsWith('.jpg') || path.toLowerCase().endsWith('.jpeg')) return 'image/jpeg';
    if (path.toLowerCase().endsWith('.gif')) return 'image/gif';
    if (path.toLowerCase().endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
  String _getImageFallbackResponse() {
    return "Xin lỗi, tôi không thể xử lý hình ảnh này. "
        "Vui lòng thử lại với hình ảnh rõ nét hơn hoặc nhập câu hỏi bằng văn bản. "
        "Tôi sẵn sàng giúp bạn về du lịch Thanh Hóa! 🌟";
  }

  Future<String> generateSmartResponse({
    required String question,
    required List<QAPair> availableData,
    List<Map<String, dynamic>>? chatHistory,
    required ConversationContext context,
    bool hasLocalData = false,
  }) async {
    try {
      // Xây dựng prompt với ngữ cảnh
      String contextPrompt = _buildContextPrompt(chatHistory, context);

      // Chuẩn bị dữ liệu có sẵn
      String availableInfo;
      if (availableData.isEmpty) {
        availableInfo = "⚠️ KHÔNG CÓ DỮ LIỆU TỪ FIREBASE. Bạn hãy dựa vào kiến thức của mình để trả lời về du lịch Thanh Hóa.";
      } else {
        availableInfo = availableData.map((qa) =>
        'Q: ${qa.question}\nA: ${qa.answer}'
        ).join('\n\n');
      }

      // Xác định địa chỉ từ câu hỏi và ngữ cảnh
      final extractedAddress = _extractAddressFromContext(question, context, availableData);

      // Kiểm tra có phải yêu cầu chỉ đường không
      final isDirectionQuery = _isDirectionRequest(question, context);

      // 🌟 PROMPT MỚI - CHO PHÉP GEMINI TỰ TRẢ LỜI
      final prompt = """
      BẠN LÀ TRỢ LÝ DU LỊCH THANH HÓA THÔNG MINH CHỈ TRẢ LỜI CÁC THÔNG TIN VỀ THANH HÓA, CÓ KHẢ NĂNG HIỂU NGỮ CẢNH.
      ${contextPrompt}

      === QUY TẮC XỬ LÝ DỮ LIỆU ===
       ${hasLocalData ?
      "📚 CÓ DỮ LIỆU TỪ FIREBASE: Ưu tiên sử dụng thông tin từ 'DỮ LIỆU CÓ SẴN' bên dưới." :
      "🌐 KHÔNG CÓ DỮ LIỆU TỪ FIREBASE: Hãy dựa vào KIẾN THỨC CỦA BẠN về du lịch Thanh Hóa để trả lời."
      }

      === QUY TẮC CHUNG ===
      1. HIỂU NGỮ CẢNH: Dựa vào chủ đề đang thảo luận và lịch sử trò chuyện
      2. TỰ NHIÊN: Trả lời như đang nói chuyện với người dùng
      3. LIÊN KẾT: Kết hợp nhiều thông tin khi cần
      4. KHÔNG BỊA ĐẶT: Chỉ trả lời đúng điều được hỏi. Không thêm thông tin người dùng không hỏi.Nếu không chắc chắn, hãy nói "Tôi chưa có thông tin về vấn đề này"
      5. Khi hỏi những câu ngoài Thanh Hóa thì sẽ từ chối trả lời ngay, chỉ trả lời DUY NHẤT câu sau đây, KHÔNG thêm bất kỳ nội dung nào khác:
   "Mình là trợ lý du lịch Thanh Hóa. Bạn vui lòng hỏi về địa điểm, lịch trình,món ăn,... ở Thanh Hóa nhé!"

      === QUY TẮC THÊM MAP TAG [MAP:...] ===
      ${_getMapTagRules(isDirectionQuery, extractedAddress, context)}

      === DỮ LIỆU CÓ SẴN ===
      $availableInfo

      === THÔNG TIN BỔ SUNG ===
      • Chủ đề: "${context.currentTopic ?? 'tổng quát'}"
      • Loại câu hỏi: ${isDirectionQuery ? 'CHỈ ĐƯỜNG' : 'THÔNG TIN'}
      • Địa điểm: ${extractedAddress ?? 'Không cụ thể'}
      • Nguồn dữ liệu: ${hasLocalData ? 'Firebase' : 'Kiến thức Gemini'}

      === CÂU HỎI HIỆN TẠI ===
      "$question"

      === HƯỚNG DẪN TRẢ LỜI ===
      1. **Nếu CÓ dữ liệu từ Firebase**: Ưu tiên dùng thông tin từ 'DỮ LIỆU CÓ SẴN'
      2. **Nếu KHÔNG có dữ liệu từ Firebase**: 
        - Dùng kiến thức của bạn về du lịch Thanh Hóa
        - Chỉ trả lời những gì bạn biết chắc chắn
        - Trả lời đúng trọng tâm câu hỏi, không lan man dài dòng.
        - Nếu không biết, trả lời TRỰC TIẾP:
         "Hiện tại tôi chưa cập nhật thông tin về [vấn đề]. Bạn có thể hỏi cụ thể hơn hoặc thử chủ đề khác nhé!"
      3. **Xử lý MAP tag**: Tuân theo quy tắc ở trên

      VÍ DỤ MINH HỌA:
      - Có dữ liệu: Dùng đúng thông tin từ Firebase
      - Không dữ liệu: "Theo tôi biết, Sầm Sơn là bãi biển nổi tiếng ở Thanh Hóa..." (dùng kiến thức Gemini)

      TRẢ LỜI (tự nhiên, thân thiện, hiểu ngữ cảnh):
      """;

      print('📝 Gửi prompt đến Gemini (hasLocalData: $hasLocalData)');

      final response = await http.post(
        Uri.parse('$baseUrl?key=${ApiKeys.gemini}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          "contents": [{"parts": [{"text": prompt}]}],
          "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 8192,
            "topP": 0.95,
            "topK": 40
          }      }),
      );

      String finalResponse;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        finalResponse = data['candidates'][0]['content']['parts'][0]['text'];
        print('✅ Gemini trả lời thành công');
      } else {
        print('❌ Lỗi Gemini: ${response.statusCode} - ${response.body}');
        finalResponse = _getFallbackResponse(question, hasLocalData);
      }

      // Xử lý thêm MAP tag nếu cần
      finalResponse = _processMapTag(finalResponse, question, context, extractedAddress);

      return finalResponse;
    } catch (e) {
      print('❌ Exception trong GeminiService: $e');
      return _getFallbackResponse(question, false);
    }
  }

  // Trả lời dự phòng khi lỗi Gemini
  String _getFallbackResponse(String question, bool hasLocalData) {
    if (!hasLocalData) {
      return "Xin lỗi, hiện tại tôi đang gặp sự cố kết nối. Bạn vui lòng thử lại sau nhé!";
    }
    return "Xin lỗi, tôi chưa hiểu rõ câu hỏi. Bạn có thể nói rõ hơn được không?";
  }

  // Tạo quy tắc MAP tag động
  static String _getMapTagRules(bool isDirectionQuery, String? extractedAddress, ConversationContext context) {
    String rules = "";
//Câu hỏi có chứa từ khóa chỉ đường không
    if (isDirectionQuery && extractedAddress != null) {
      rules = """
      1. ✅ ĐỦ ĐIỀU KIỆN THÊM MAP TAG (yêu cầu chỉ đường + có địa chỉ)
      2. Định dạng: [MAP:$extractedAddress, Thanh Hóa] (nếu chưa có tỉnh)
      3. Vị trí: Đặt ở CUỐI câu trả lời
      """;
    } else if (isDirectionQuery && extractedAddress == null) {
      rules = """
      1. ⚠️ CÓ YÊU CẦU CHỈ ĐƯỜNG nhưng KHÔNG XÁC ĐỊNH ĐƯỢC ĐỊA CHỈ
      2. KHÔNG thêm [MAP:...] vì thiếu địa chỉ cụ thể
      3. Hãy hỏi lại người dùng để biết địa điểm họ muốn đến
      """;
    } else {
      rules = """
      1. ❌ KHÔNG THÊM MAP TAG (không phải yêu cầu chỉ đường)
      2. Chỉ cung cấp thông tin, không thêm [MAP:...]
      """;
    }

    return rules;
  }

  String _processMapTag(String response, String question, ConversationContext context, String? extractedAddress) {
    if (response.contains('[MAP:')) {
      return response;
    }

    if (_shouldAddMapTag(question, response, context, extractedAddress)) {
      String addressForMap = extractedAddress ?? context.locationName ?? '';
      if (addressForMap.isNotEmpty &&
          !_isDefaultThanhHoa(addressForMap) &&
          addressForMap.length > 5) {
        if (!addressForMap.toLowerCase().contains('thanh hóa')) {
          addressForMap = '$addressForMap, Thanh Hóa';
        }
        return '$response [MAP:$addressForMap]';
      }
    }

    return response;
  }
// Hàm kiểm tra xem địa chỉ có phải là "Thanh Hóa" mặc định không
  bool _isDefaultThanhHoa(String address) {
    final lowerAddress = address.toLowerCase();
    return lowerAddress == 'thanh hóa' ||
        lowerAddress == 'thanh hoa' ||
        lowerAddress == 'thanh hóa, thanh hóa' ||
        lowerAddress.trim().isEmpty;
  }
  bool _shouldAddMapTag(String question, String response, ConversationContext context, String? extractedAddress) {
    final directionKeywords = [
      'chỉ đường', 'đường đi', 'làm sao để đến', 'đến như thế nào',
      'hướng dẫn đường', 'chỉ đường đến', 'tìm đường',
      'vị trí', 'tọa độ', 'bản đồ', 'map',
      'hướng dẫn đi', 'cách đi', 'đi bằng cách nào', 'đi thế nào',
      'đường đến', 'tuyến đường', 'phương hướng'
    ];

    final hasDirectionKeyword = directionKeywords.any((keyword) =>
        question.toLowerCase().contains(keyword.toLowerCase()));

    final hasRouteInfo = response.toLowerCase().contains('đi theo') ||
        response.toLowerCase().contains('rẽ') ||
        response.toLowerCase().contains('quốc lộ') ||
        response.toLowerCase().contains('tỉnh lộ') ||
        response.toLowerCase().contains('km từ') ||
        response.toLowerCase().contains('từ đây') ||
        response.toLowerCase().contains('hướng') ||
        response.toLowerCase().contains('đến') && response.toLowerCase().contains('từ');

    final hasSpecificAddress = extractedAddress != null &&
        extractedAddress.isNotEmpty &&
        !extractedAddress.toLowerCase().contains('thanh hóa') &&
        extractedAddress.length > 5;

    return (hasDirectionKeyword || context.isDirectionRelated) &&
        hasRouteInfo &&
        (hasSpecificAddress || context.locationName != null);
  }

  bool _isDirectionRequest(String question, ConversationContext context) {
    final directionKeywords = [
      'chỉ đường', 'đường đi', 'đến', 'bản đồ',
      'map', 'vị trí', 'tọa độ', 'cách đi'
    ];

    final hasDirectionKeyword = directionKeywords.any((keyword) =>
        question.toLowerCase().contains(keyword.toLowerCase()));

    return hasDirectionKeyword || context.isDirectionRelated;
  }

  String? _extractAddressFromContext(String question, ConversationContext context, List<QAPair> availableData) {
    if (context.locationName != null) {
      return context.locationName;
    }

    final extractedAddress = LocationExtractor.extractAddress(question);
    if (extractedAddress != null) {
      return extractedAddress;
    }

    for (var qa in availableData) {
      final locationPatterns = [
        RegExp(r'[Tt]hành\s+[^,.]+'),
        RegExp(r'[Bb]ãi\s+[^,.]+'),
        RegExp(r'[Ss]uối\s+[^,.]+'),
        RegExp(r'[Đđ]ền\s+[^,.]+'),
        RegExp(r'[Cc]hùa\s+[^,.]+'),
        RegExp(r'[Hh]ang\s+[^,.]+'),
        RegExp(r'[Nn]úi\s+[^,.]+'),
        RegExp(r'[Bb]iển\s+[^,.]+'),
      ];

      for (var pattern in locationPatterns) {
        final match = pattern.firstMatch(qa.question);
        if (match != null) {
          String location = match.group(0)!;
          if (!location.toLowerCase().contains('thanh hóa')) {
            location = '$location, Thanh Hóa';
          }
          return location;
        }
      }
    }

    return null;
  }

  String _buildContextPrompt(List<Map<String, dynamic>>? chatHistory, ConversationContext context) {
    StringBuffer prompt = StringBuffer();

    prompt.writeln('NGỮ CẢNH HIỆN TẠI:');
    prompt.writeln('• Chủ đề đang thảo luận: ${context.currentTopic ?? "Mới bắt đầu"}');

    if (context.keywords.isNotEmpty) {
      prompt.writeln('• Từ khóa quan trọng: ${context.keywords.take(5).join(", ")}');
    }

    if (context.locationName != null) {
      prompt.writeln('• Địa điểm được nhắc đến: ${context.locationName}');
    }

    if (context.isDirectionRelated) {
      prompt.writeln('• Đang thảo luận về chỉ đường: CÓ');
    }

    if (chatHistory != null && chatHistory.isNotEmpty) {
      prompt.writeln('\nLỊCH SỬ CHAT GẦN ĐÂY (từ mới đến cũ):');

      final recentHistory = chatHistory.reversed.take(4).toList();
      for (var msg in recentHistory) {
        final role = msg['isUser'] == true ? 'USER' : 'ASSISTANT';
        String text = msg['text'].toString();
        text = text.replaceAll(RegExp(r'\[MAP:.+?\]'), '').trim();

        if (text.isNotEmpty) {
          prompt.writeln('$role: $text');
        }
      }
    }

    if (context.recentTopics.isNotEmpty) {
      prompt.writeln('\nCÁC CHỦ ĐỀ GẦN ĐÂY:');
      prompt.writeln(context.recentTopics.take(3).map((t) => '• $t').join('\n'));
    }

    return prompt.toString();
  }

  String extractLocationFromQuestion(String question, List<QAPair> availableData, ConversationContext context) {
    if (context.locationName != null &&
        (question.contains('đó') || question.contains('đây') || question.contains('nơi'))) {
      return context.locationName!;
    }

    final extractedAddress = LocationExtractor.extractAddress(question);
    if (extractedAddress != null) {
      return extractedAddress;
    }
//Loại bỏ ký tự đặc biệt
    for (var qa in availableData) {
      final processedQuestion = question.toLowerCase()
          .replaceAll(RegExp(r'[^\w\sàáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ]'), ' ')
          .trim();

      if (qa.question.toLowerCase().contains(processedQuestion) ||
          processedQuestion.contains(qa.question.toLowerCase())) {
        return _extractLocationName(qa.answer);
      }
    }

    return context.locationName ?? 'Thanh Hóa';
  }

  String _extractLocationName(String answer) {
    final patterns = [
      RegExp(r'[Tt]hành\s+[^,.]+'),
      RegExp(r'[Bb]ãi\s+[^,.]+'),
      RegExp(r'[Ss]uối\s+[^,.]+'),
      RegExp(r'[Đđ]ền\s+[^,.]+'),
      RegExp(r'[Cc]hùa\s+[^,.]+'),
      RegExp(r'[Hh]ang\s+[^,.]+'),
      RegExp(r'[Nn]úi\s+[^,.]+'),
      RegExp(r'[Bb]iển\s+[^,.]+'),
      RegExp(r'[Vv]ườn\s+[^,.]+'),
      RegExp(r'[Đđ]ộng\s+[^,.]+'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(answer);
      if (match != null) {
        String location = match.group(0)!;
        if (!location.toLowerCase().contains('thanh hóa')) {
          location = '$location, Thanh Hóa';
        }
        return location;
      }
    }

    final firstSentence = answer.split('.')[0];
    return '$firstSentence, Thanh Hóa';
  }
}