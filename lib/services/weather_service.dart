// lib/services/weather_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../config/api_keys.dart';
import 'package:flutter/material.dart';
class WeatherService {
  static const String baseUrl = "https://api.openweathermap.org/data/2.5";

  // Lấy thời tiết theo tên thành phố
  static Future<Map<String, dynamic>> getWeatherByCity(String city) async {
    try {
      print('🌤️ Đang lấy thời tiết cho thành phố: $city');
      final response = await http.get(
        Uri.parse('$baseUrl/weather?q=$city&appid=${ApiKeys.openWeather}&units=metric&lang=vi'),
      );

      if (response.statusCode == 200) {
        print('✅ Lấy thời tiết thành công cho $city');
        return json.decode(response.body);
      } else {
        print('❌ Lỗi lấy thời tiết: ${response.statusCode} - ${response.body}');
        throw Exception('Không thể lấy dữ liệu thời tiết');
      }
    } catch (e) {
      print('❌ Lỗi lấy thời tiết theo thành phố: $e');
      rethrow;
    }
  }

  // Lấy thời tiết theo tọa độ
  static Future<Map<String, dynamic>> getWeatherByCoordinates(double lat, double lon) async {
    try {
      print('🌤️ Đang lấy thời tiết theo tọa độ: ($lat, $lon)');
      final response = await http.get(
        Uri.parse('$baseUrl/weather?lat=$lat&lon=$lon&appid=${ApiKeys.openWeather}&units=metric&lang=vi'),
      );

      if (response.statusCode == 200) {
        print('✅ Lấy thời tiết theo tọa độ thành công');
        return json.decode(response.body);
      } else {
        print('❌ Lỗi lấy thời tiết theo tọa độ: ${response.statusCode}');
        throw Exception('Không thể lấy dữ liệu thời tiết');
      }
    } catch (e) {
      print('❌ Lỗi lấy thời tiết theo tọa độ: $e');
      rethrow;
    }
  }

  // Lấy dự báo thời tiết 5 ngày
  static Future<Map<String, dynamic>> getForecast(double lat, double lon) async {
    try {
      print('📅 Đang lấy dự báo thời tiết 5 ngày cho tọa độ: ($lat, $lon)');

      // API forecast 5 ngày với khoảng cách 3 giờ
      final response = await http.get(
        Uri.parse('$baseUrl/forecast?lat=$lat&lon=$lon&appid=${ApiKeys.openWeather}&units=metric&lang=vi&cnt=40'),
      );

      if (response.statusCode == 200) {
        print('✅ Lấy dự báo thành công');
        final data = json.decode(response.body);

        // Log số lượng dự báo nhận được
        final list = data['list'] as List;
        print('📊 Số lượng dự báo: ${list.length}');

        return data;
      } else {
        print('❌ Lỗi lấy dự báo: ${response.statusCode}');
        throw Exception('Không thể lấy dữ liệu dự báo');
      }
    } catch (e) {
      print('❌ Lỗi lấy dự báo thời tiết: $e');
      rethrow;
    }
  }

  // Lấy thời tiết hiện tại và dự báo cho Thanh Hóa
  static Future<Map<String, dynamic>> getThanhHoaWeather() async {
    // Tọa độ Thanh Hóa
    const double thanhHoaLat = 19.8067;
    const double thanhHoaLon = 105.7850;

    try {
      print('🏙️ Đang lấy thời tiết Thanh Hóa');

      // Lấy thời tiết hiện tại
      final currentWeather = await getWeatherByCoordinates(thanhHoaLat, thanhHoaLon);

      // Lấy dự báo 5 ngày
      final forecast = await getForecast(thanhHoaLat, thanhHoaLon);

      return {
        'current': currentWeather,
        'forecast': forecast,
      };
    } catch (e) {
      print('❌ Lỗi lấy thời tiết Thanh Hóa: $e');
      rethrow;
    }
  }

  // Lấy icon thời tiết từ OpenWeather
  static String getWeatherIcon(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  // Chuyển đổi mô tả thời tiết từ tiếng Anh sang tiếng Việt
  static String translateWeatherDescription(String description) {
    final Map<String, String> translations = {
      'clear sky': 'Trời quang',
      'few clouds': 'Ít mây',
      'scattered clouds': 'Mây rải rác',
      'broken clouds': 'Mây đứt quãng',
      'overcast clouds': 'Nhiều mây',
      'mist': 'Sương mù',
      'fog': 'Sương mù',
      'haze': 'Mù khói',
      'smoke': 'Khói',
      'dust': 'Bụi',
      'sand': 'Cát',
      'ash': 'Tro bụi',
      'squall': 'Gió giật',
      'tornado': 'Lốc xoáy',
      'thunderstorm': 'Giông bão',
      'light rain': 'Mưa nhẹ',
      'moderate rain': 'Mưa vừa',
      'heavy intensity rain': 'Mưa lớn',
      'very heavy rain': 'Mưa rất lớn',
      'extreme rain': 'Mưa cực lớn',
      'freezing rain': 'Mưa đá',
      'light snow': 'Tuyết nhẹ',
      'snow': 'Tuyết',
      'heavy snow': 'Tuyết lớn',
      'sleet': 'Mưa tuyết',
      'shower rain': 'Mưa rào',
      'shower snow': 'Mưa tuyết rào',
      'rain': 'Mưa',
      'thunderstorm with light rain': 'Giông bão mưa nhẹ',
      'thunderstorm with rain': 'Giông bão mưa',
      'thunderstorm with heavy rain': 'Giông bão mưa lớn',
      'light thunderstorm': 'Giông nhẹ',
      'thunderstorm': 'Giông bão',
      'heavy thunderstorm': 'Giông bão lớn',
    };

    // Tìm kiếm chính xác hoặc gần đúng
    final lowerDesc = description.toLowerCase();

    // Ưu tiên tìm chính xác
    if (translations.containsKey(lowerDesc)) {
      return translations[lowerDesc]!;
    }

    // Tìm kiếm chứa từ khóa
    for (var entry in translations.entries) {
      if (lowerDesc.contains(entry.key)) {
        return entry.value;
      }
    }

    // Nếu không tìm thấy, trả về nguyên bản
    return description;
  }

  // Lấy mã màu cho nhiệt độ
  static Color getTemperatureColor(double temp) {
    if (temp < 10) return Colors.lightBlue;
    if (temp < 20) return Colors.blue;
    if (temp < 25) return Colors.green;
    if (temp < 30) return Colors.orange;
    if (temp < 35) return Colors.deepOrange;
    return Colors.red;
  }

  // Lấy hướng gió từ độ
  static String getWindDirection(double deg) {
    if (deg >= 337.5 || deg < 22.5) return 'Bắc';
    if (deg >= 22.5 && deg < 67.5) return 'Đông Bắc';
    if (deg >= 67.5 && deg < 112.5) return 'Đông';
    if (deg >= 112.5 && deg < 157.5) return 'Đông Nam';
    if (deg >= 157.5 && deg < 202.5) return 'Nam';
    if (deg >= 202.5 && deg < 247.5) return 'Tây Nam';
    if (deg >= 247.5 && deg < 292.5) return 'Tây';
    if (deg >= 292.5 && deg < 337.5) return 'Tây Bắc';
    return '';
  }

  // Lấy thông điệp thời tiết
  static String getWeatherMessage(Map<String, dynamic> weatherData) {
    final temp = weatherData['main']['temp'];
    final description = weatherData['weather'][0]['description'].toLowerCase();

    if (description.contains('mưa')) {
      return '☔ Trời đang mưa, nhớ mang ô khi ra ngoài nhé!';
    } else if (temp > 35) {
      return '🥵 Trời rất nóng, hãy uống nhiều nước và đội mũ!';
    } else if (temp > 30) {
      return '😎 Thời tiết nóng, thích hợp đi biển!';
    } else if (temp > 25) {
      return '🌤️ Thời tiết đẹp, lý tưởng để tham quan!';
    } else if (temp > 20) {
      return '😊 Thời tiết mát mẻ, dễ chịu!';
    } else if (temp > 15) {
      return '🍂 Trời se lạnh, nhớ mặc ấm nhé!';
    } else {
      return '❄️ Trời lạnh, giữ ấm cơ thể!';
    }
  }

  // Kiểm tra kết nối API
  static Future<bool> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/weather?q=Thanh Hóa&appid=${ApiKeys.openWeather}&units=metric'),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ Kiểm tra kết nối thất bại: $e');
      return false;
    }
  }
}