import 'package:location/location.dart';

class LocationService {
  final Location _location = Location();
  bool _serviceEnabled = false;

  // Không cần khai báo PermissionStatus ở đây vì package location xử lý nội bộ

  Future<bool> checkAndRequestPermissions() async {
    try {
      // Kiểm tra dịch vụ vị trí
      _serviceEnabled = await _location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await _location.requestService();
        if (!_serviceEnabled) {
          return false;
        }
      }

      // Kiểm tra quyền với package location
      PermissionStatus permissionStatus = await _location.hasPermission();
      if (permissionStatus == PermissionStatus.denied ||
          permissionStatus == PermissionStatus.deniedForever) {
        permissionStatus = await _location.requestPermission();
        if (permissionStatus != PermissionStatus.granted &&
            permissionStatus != PermissionStatus.grantedLimited) {
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Lỗi kiểm tra quyền: $e');
      return false;
    }
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final hasPermission = await checkAndRequestPermissions();
      if (!hasPermission) {
        print('Không có quyền truy cập vị trí');
        return null;
      }

      final locationData = await _location.getLocation();
      print('Vị trí hiện tại: ${locationData.latitude}, ${locationData.longitude}');
      return locationData;
    } catch (e) {
      print('Lỗi khi lấy vị trí: $e');
      return null;
    }
  }

  Stream<LocationData> getLocationStream() {
    return _location.onLocationChanged.handleError((error) {
      print('Lỗi stream vị trí: $error');
    });
  }
}