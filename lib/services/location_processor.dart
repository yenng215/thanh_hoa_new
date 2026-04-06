import '../models/qa_model.dart';

class LocationProcessor {
  // Xử lý câu trả lời từ Gemini và thêm MAP tag nếu cần
  static String processResponse(String response, String originalQuestion, List<QAPair> relevantData) {
    // Kiểm tra xem đã có MAP tag chưa
    if (response.contains('[MAP:')) {
      return response;
    }

    // Kiểm tra xem câu trả lời có chứa thông tin chỉ đường không
    final directionIndicators = [
      'đi theo',
      'rẽ vào',
      'đến',
      'cách',
      'km',
      'quốc lộ',
      'tỉnh lộ',
      'đường',
      'hướng',
      'từ đây',
      'từ vị trí',
    ];

    final hasDirectionInfo = directionIndicators.any((indicator) =>
        response.toLowerCase().contains(indicator));

    if (!hasDirectionInfo) {
      return response;
    }

    // Trích xuất địa điểm từ câu hỏi hoặc dữ liệu
    String? location = _extractLocationFromQA(originalQuestion, relevantData);

    if (location != null) {
      return '$response [MAP:$location]';
    }

    return response;
  }

  static String? _extractLocationFromQA(String question, List<QAPair> relevantData) {
    // Ưu tiên tìm trong relevantData
    for (var qa in relevantData) {
      if (qa.answer.length > 20) { // Câu trả lời đủ dài
        // Tìm tên địa điểm phổ biến
        final locationPatterns = [
          RegExp(r'[Tt]hành [^,.]+'),
          RegExp(r'[Bb]ãi [^,.]+'),
          RegExp(r'[Ss]uối [^,.]+'),
          RegExp(r'[Đđ]ền [^,.]+'),
          RegExp(r'[Cc]hùa [^,.]+'),
          RegExp(r'[Hh]ang [^,.]+'),
          RegExp(r'[Nn]úi [^,.]+'),
          RegExp(r'[Bb]iển [^,.]+'),
          RegExp(r'[Đđ]ộng [^,.]+'),
          RegExp(r'[Vv]ườn [^,.]+'),
          RegExp(r'[Bb]ảo tàng [^,.]+'),
          RegExp(r'[Cc]hợ [^,.]+'),
          RegExp(r'[Cc]ầu [^,.]+'),
        ];

        for (var pattern in locationPatterns) {
          final match = pattern.firstMatch(qa.answer);
          if (match != null) {
            String location = match.group(0)!;
            // Thêm tỉnh Thanh Hóa nếu chưa có
            if (!location.toLowerCase().contains('thanh hóa')) {
              location = '$location, Thanh Hóa';
            }
            return location;
          }
        }
      }
    }

    return null;
  }

  // Tạo danh sách gợi ý địa điểm
  static List<String> getLocationSuggestions(String query) {
    final locations = [
      'Thành nhà Hồ, Vĩnh Lộc, Thanh Hóa',
      'Bãi biển Sầm Sơn, Thanh Hóa',
      'Suối cá Thần, Cẩm Lương, Cẩm Thủy, Thanh Hóa',
      'Khu bảo tồn thiên nhiên Pù Luông, Bá Thước, Thanh Hóa',
      'Đền Bà Chúa, Thọ Xuân, Thanh Hóa',
      'Biển Hải Tiến, Hoằng Hóa, Thanh Hóa',
      'Chùa Sùng Nghiêm, Vĩnh Lộc, Thanh Hóa',
      'Vườn quốc gia Bến En, Như Thanh, Thanh Hóa',
      'Nhà thờ đá Sầm Sơn, Thanh Hóa',
      'Chợ Thành phố Thanh Hóa',
    ];

    if (query.isEmpty) {
      return locations;
    }

    return locations
        .where((location) =>
        location.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}