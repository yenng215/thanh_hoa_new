class LocationExtractor {
  // Danh sách địa danh nổi tiếng Thanh Hóa
  static final Map<String, String> thanhHoaLocations = {
    'thành nhà hồ': 'Thành nhà Hồ, Vĩnh Lộc, Thanh Hóa',
    'sầm sơn': 'Bãi biển Sầm Sơn, Thanh Hóa',
    'suối cá thần': 'Suối cá Thần, Cẩm Lương, Cẩm Thủy, Thanh Hóa',
    'pù luông': 'Khu bảo tồn thiên nhiên Pù Luông, Bá Thước, Thanh Hóa',
    'đền bà chúa': 'Đền Bà Chúa, Thọ Xuân, Thanh Hóa',
    'đền đô': 'Đền Đô, Đông Sơn, Thanh Hóa',
    'chùa sùng nghiêm': 'Chùa Sùng Nghiêm, Vĩnh Lộc, Thanh Hóa',
    'hang cá thần': 'Hang cá Thần, Cẩm Lương, Cẩm Thủy, Thanh Hóa',
    'biển hải tiến': 'Biển Hải Tiến, Hoằng Hóa, Thanh Hóa',
    'núi đọ': 'Núi Đọ, Thiệu Hóa, Thanh Hóa',
    'suối nóng': 'Suối nóng Kim Sơn, Thạch Thành, Thanh Hóa',
    'thác vực': 'Thác Vực, Bá Thước, Thanh Hóa',
    'động tân từ': 'Động Tân Từ, Vĩnh Lộc, Thanh Hóa',
    'vườn quốc gia bến en': 'Vườn quốc gia Bến En, Như Thanh, Thanh Hóa',
    'đền thờ lê hoàn': 'Đền thờ Lê Hoàn, Thọ Xuân, Thanh Hóa',
    'bảo tàng thanh hóa': 'Bảo tàng Thanh Hóa, Thành phố Thanh Hóa',
    'nhà thờ đá': 'Nhà thờ đá Sầm Sơn, Thanh Hóa',
    'chợ thành phố': 'Chợ Thành phố Thanh Hóa',
    'cầu hàm rồng': 'Cầu Hàm Rồng, Thành phố Thanh Hóa',
    'núi rồng': 'Núi Rồng, Sầm Sơn, Thanh Hóa',
  };

  // Từ khóa chỉ đường
  static final List<String> directionKeywords = [
    'chỉ đường',
    'đường đi',
    'làm sao để đến',
    'đến như thế nào',
    'hướng dẫn đường',
    'chỉ đường đến',
    'tìm đường',
    'địa chỉ',
    'vị trí',
    'tọa độ',
    'bản đồ',
    'map',
    'hướng dẫn đi',
    'cách đi',
    'đi bằng cách nào',
    'đi thế nào',
    'đường đến',
    'tuyến đường',
    'phương hướng',
  ];

  // Kiểm tra xem câu hỏi có phải về chỉ đường không
  static bool isDirectionRequest(String question) {
    final lowerQuestion = question.toLowerCase();
    return directionKeywords.any((keyword) => lowerQuestion.contains(keyword));
  }

  // Trích xuất địa chỉ từ câu hỏi
  static String? extractAddress(String question) {
    final lowerQuestion = question.toLowerCase();

    // Tìm trong danh sách địa danh
    for (var entry in thanhHoaLocations.entries) {
      if (lowerQuestion.contains(entry.key)) {
        return entry.value;
      }
    }

    // Nếu không tìm thấy, cố gắng trích xuất
    return _extractLocationFromText(question);
  }

  static String? _extractLocationFromText(String text) {
    final words = text.toLowerCase().split(' ');

    // Loại bỏ các từ chỉ đường
    final filteredWords = words.where((word) =>
    !directionKeywords.any((keyword) => keyword.contains(word))).toList();

    if (filteredWords.isEmpty) return null;

    // Tìm từ khóa địa điểm
    final locationKeywords = ['thành', 'bãi', 'suối', 'đền', 'chùa', 'hang', 'núi', 'biển', 'động', 'vườn', 'bảo tàng', 'chợ', 'cầu'];

    for (int i = 0; i < filteredWords.length; i++) {
      if (locationKeywords.contains(filteredWords[i]) && i + 1 < filteredWords.length) {
        // Ghép từ khóa và từ tiếp theo
        return '${filteredWords[i]} ${filteredWords[i + 1]}';
      }
    }

    // Trả về từ cuối cùng (thường là địa điểm)
    return filteredWords.last;
  }

  // Tạo câu trả lời với MAP tag
  static String addMapTagToResponse(String response, String address) {
    if (!response.contains('[MAP:')) {
      return '$response [MAP:$address]';
    }
    return response;
  }
}