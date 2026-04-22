// lib/services/map_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/step_model.dart';

class MapService {
  // Lấy vị trí hiện tại của người dùng
  static Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Dịch vụ vị trí chưa được bật');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Quyền truy cập vị trí bị từ chối');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Quyền truy cập vị trí bị từ chối vĩnh viễn');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Geocoding: Chuyển đổi địa chỉ thành tọa độ
  static Future<Location> getCoordinatesFromAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
      throw Exception('Không tìm thấy địa chỉ');
    } catch (e) {
      rethrow;
    }
  }

  // Reverse Geocoding: Chuyển đổi tọa độ thành địa chỉ
  static Future<String> getAddressFromCoordinates(
      double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.subLocality}, ${place.locality}, ${place.country}';
      }
      return '$lat, $lng';
    } catch (e) {
      return '$lat, $lng';
    }
  }

  // Tìm kiếm địa điểm bằng Nominatim API (OpenStreetMap)
  static Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5&countrycodes=vn'),
        headers: {'User-Agent': 'ThanhHoaTravelAssistant/1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          return {
            'name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lng': double.parse(item['lon']),
            'type': item['type'],
          };
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Mở chỉ đường trong ứng dụng bản đồ bên ngoài
  static Future<void> openExternalMap(
      double startLat,
      double startLng,
      double endLat,
      double endLng, {
        String transportMode = 'drive',
        String mapApp = 'google',
      }) async {
    String url;
    String travelMode;

    switch (transportMode) {
      case 'walk':
        travelMode = 'walking';
        break;
      case 'bike':
        travelMode = 'bicycling';
        break;
      default:
        travelMode = 'driving';
    }

    if (mapApp == 'google') {
      url =
      'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=$travelMode';
    } else if (mapApp == 'apple') {
      url = 'http://maps.apple.com/?daddr=$endLat,$endLng&dirflg=$travelMode';
    } else {
      String osrmProfile = transportMode == 'walk' ? 'foot' :
      transportMode == 'bike' ? 'bike' : 'car';
      url =
      'https://www.openstreetmap.org/directions?engine=fossgis_osrm_$osrmProfile&route=$startLng,$startLat;$endLng,$endLat';
    }

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw Exception('Không thể mở bản đồ');
    }
  }

  // Lấy polyline từ OSRM API
  static Future<List<List<double>>> getRoutePolyline(
      double startLat,
      double startLng,
      double endLat,
      double endLng, {
        String transportMode = 'drive',
      }) async {
    try {
      String profile = transportMode == 'walk' ? 'foot' :
      transportMode == 'bike' ? 'bike' : 'car';

      print('📌 Đang tính route với profile: $profile');
      print('📍 Từ: ($startLat, $startLng) đến: ($endLat, $endLng)');

      final url = 'https://router.project-osrm.org/route/v1/$profile/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];
          final coordinates = geometry['coordinates'] as List;

          // 🌟 SỬA: Chia đúng cho 1000 để ra km
          final distance = route['distance'] / 1000;
          final duration = route['duration'] / 60;
          print('✅ Tìm thấy route: ${distance.toStringAsFixed(1)} km, ${duration.toStringAsFixed(0)} phút');

          return coordinates.map<List<double>>((coord) {
            return [coord[1].toDouble(), coord[0].toDouble()];
          }).toList();
        } else {
          print('❌ Không tìm thấy route');
          return [];
        }
      } else {
        print('❌ Lỗi OSRM API: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Lỗi tính toán tuyến đường: $e');
      return [];
    }
  }

  // Tính khoảng cách và thời gian
  static Future<Map<String, double>> getRouteInfo(
      double startLat,
      double startLng,
      double endLat,
      double endLng, {
        String transportMode = 'drive',
      }) async {
    try {
      String profile = transportMode == 'walk' ? 'foot' :
      transportMode == 'bike' ? 'bike' : 'car';

      final response = await http.get(
        Uri.parse(
            'https://router.project-osrm.org/route/v1/$profile/$startLng,$startLat;$endLng,$endLat?overview=false'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // 🌟 SỬA: Chia đúng cho 1000 để ra km
          final distance = route['distance'] / 1000;
          final duration = route['duration'] / 60;

          print('📊 Route info: ${distance.toStringAsFixed(1)} km, ${duration.toStringAsFixed(0)} phút');

          return {
            'distance': distance,
            'duration': duration,
          };
        }
      }
      return {'distance': 0, 'duration': 0};
    } catch (e) {
      print('❌ Lỗi getRouteInfo: $e');
      return {'distance': 0, 'duration': 0};
    }
  }

  // Lấy danh sách chỉ đường chi tiết
  static Future<List<NavigationStep>> getRouteSteps(
      double startLat,
      double startLng,
      double endLat,
      double endLng, {
        String transportMode = 'drive',
      }) async {
    try {
      String profile = transportMode == 'walk' ? 'foot' :
      transportMode == 'bike' ? 'bike' : 'car';

      final response = await http.get(
        Uri.parse(
            'https://router.project-osrm.org/route/v1/$profile/$startLng,$startLat;$endLng,$endLat?overview=full&geometries=geojson&steps=true'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;

          List<NavigationStep> allSteps = [];

          for (var leg in legs) {
            final steps = leg['steps'] as List;
            for (var step in steps) {
              allSteps.add(NavigationStep.fromJson(step));
            }
          }

          print('✅ Lấy được ${allSteps.length} bước chỉ đường');
          return allSteps;
        }
      }
      return [];
    } catch (e) {
      print('❌ Lỗi lấy route steps: $e');
      return [];
    }
  }
}