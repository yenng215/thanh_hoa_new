// lib/screens/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/map_service.dart';
import '../widgets/navigation_instructions.dart';
import '../models/step_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math' as math;

class MapPage extends StatefulWidget {
  final String? destination;
  final String? startLocation;
  final double? destinationLat;
  final double? destinationLng;
  final double? startLat;
  final double? startLng;

  const MapPage({
    super.key,
    this.destination,
    this.startLocation,
    this.destinationLat,
    this.destinationLng,
    this.startLat,
    this.startLng,
  });

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  late MapController _mapController;
  LatLng? _currentLocation;
  LatLng? _startLocation;
  LatLng? _destination;
  List<LatLng> _polylinePoints = [];
  List<NavigationStep> _navigationSteps = [];
  bool _showInstructions = false;
  bool _isNavigating = false;
  bool _isNavPanelExpanded = false;

  String _transportMode = 'drive';
  bool _isLoading = true;
  String? _errorMessage;
  double _zoom = 15.0;
  bool _isMapReady = false;
  String? _startAddress;
  String? _endAddress;

  double _distance = 0;
  double _duration = 0;
  bool _isCalculating = false;

  // Biến cho real-time tracking
  StreamSubscription<Position>? _positionStream;
  double _currentBearing = 0;
  int _currentStepIndex = 0;
  AnimationController? _arrowAnimationController;
  Animation<double>? _arrowAnimation;

  double _remainingDistance = 0;

  final List<String> _transportModes = [
    'car',
    'drive',
    'walk',
  ];

  final Map<String, IconData> _transportIcons = {
    'car': Icons.directions_car,
    'drive': Icons.motorcycle,
    'walk': Icons.directions_walk,
  };

  final Map<String, String> _transportNames = {
    'car': 'Ô tô',
    'drive': 'Xe máy',
    'walk': 'Đi bộ',
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _arrowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _arrowAnimationController!, curve: Curves.easeInOut),
    );

    Future.microtask(() => _initializeMap());
  }

  @override
  void dispose() {
    _mapController.dispose();
    _positionStream?.cancel();
    _arrowAnimationController?.dispose();
    super.dispose();
  }

  // HÀM TÍNH KHOẢNG CÁCH
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Bán kính Trái Đất (km)

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final distance = R * c;

    return distance;
  }

  double _toRadians(double degree) => degree * math.pi / 180;

  // Chỉ theo dõi vị trí thực tế, không tự di chuyển
  void _startLocationTracking() {
    // thì KHÔNG theo dõi vị trí GPS
    if (_startAddress != 'Vị trí hiện tại của bạn' && _startAddress != null) {
      print('📍 Đang dùng điểm bắt đầu tùy chỉnh, không theo dõi GPS');
      return;
    }

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,// Cập nhật khi di chuyển 5 mét
      ),
    ).listen((Position position) {
      if (!mounted || !_isNavigating) return;

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentBearing = position.heading;
        _remainingDistance = _calculateRemainingDistance();// Tính lại khoảng cách

        if (_isMapReady) {
          _mapController.move(_currentLocation!, _zoom);
        }

        _checkNextStep();
      });
    }, onError: (error) {
      print('Lỗi theo dõi vị trí: $error');
    });
  }

  void _checkNextStep() {
    if (_navigationSteps.isEmpty || _currentLocation == null) return;

    final currentStep = _navigationSteps[_currentStepIndex];
    if (currentStep.location != null) {
      final stepPoint = LatLng(currentStep.location![0], currentStep.location![1]);
      final distance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        stepPoint.latitude,
        stepPoint.longitude,
      );

      // Nếu đến gần điểm cần rẽ (dưới 30m)
      if (distance < 0.03 && _currentStepIndex < _navigationSteps.length - 1) {
        setState(() {
          _currentStepIndex++;
        });

        _showNextStepNotification();
      }
    }
  }

  void _showNextStepNotification() {
    if (_currentStepIndex >= _navigationSteps.length) return;

    final nextStep = _navigationSteps[_currentStepIndex];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getManeuverIcon(nextStep.maneuver),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                nextStep.instruction,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: const Color(0xFF9B89FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // HÀM TÍNH KHOẢNG CÁCH CÒN LẠI
  double _calculateRemainingDistance() {
    if (_polylinePoints.isEmpty || _currentLocation == null) return 0;

    double totalRemaining = 0;
    int nearestIndex = 0;
    double minDistance = double.infinity;

    // Tìm điểm gần nhất trên polyline
    for (int i = 0; i < _polylinePoints.length; i++) {
      final distance = _calculateDistance(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        _polylinePoints[i].latitude,
        _polylinePoints[i].longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        nearestIndex = i;
      }
    }

    // Tính tổng khoảng cách từ điểm gần nhất đến cuối
    for (int i = nearestIndex; i < _polylinePoints.length - 1; i++) {
      totalRemaining += _calculateDistance(
        _polylinePoints[i].latitude,
        _polylinePoints[i].longitude,
        _polylinePoints[i + 1].latitude,
        _polylinePoints[i + 1].longitude,
      );
    }

    return totalRemaining;
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
      _showInstructions = false;
      _zoom = 17.0;
      _currentStepIndex = 0;

      if (_startLocation != null) {
        _currentLocation = _startLocation;
      }

      _remainingDistance = _calculateRemainingDistance();
    });

    _startLocationTracking();

    // Nhảy qua bước "depart" nếu cần
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _currentStepIndex == 0 && _navigationSteps.isNotEmpty) {
        final firstStep = _navigationSteps[0];
        if (firstStep.maneuver == 'depart' && _navigationSteps.length > 1) {
          setState(() => _currentStepIndex = 1);
        }
      }
    });

    if (mounted && _isMapReady && _currentLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isMapReady) {
          _mapController.move(_currentLocation!, _zoom);
        }
      });
    }
  }

  void _closeInstructions() {
    setState(() {
      _showInstructions = false;
      _isNavigating = false;
      _isNavPanelExpanded = false;
    });

    _positionStream?.cancel();

    if (_polylinePoints.isNotEmpty && _isMapReady) {
      final bounds = LatLngBounds.fromPoints(_polylinePoints);
      _mapController.fitBounds(
        bounds,
        options: const FitBoundsOptions(padding: EdgeInsets.all(50)),
      );
    }
  }

  // 🌟 HÀM TẠO MARKERS CHO CÁC ĐIỂM CẦN RẼ
  List<Marker> _buildStepMarkers() {
    List<Marker> markers = [];

    for (int i = 0; i < _navigationSteps.length; i++) {
      final step = _navigationSteps[i];
      if (step.location != null && step.maneuver != 'depart' && step.maneuver != 'arrive') {
        markers.add(
          Marker(
            point: LatLng(step.location![0], step.location![1]),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                color: i == _currentStepIndex
                    ? Colors.orange
                    : Colors.blue.withOpacity(0.7),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Center(
                child: Icon(
                  _getManeuverIcon(step.maneuver),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }
// Khởi tạo bản đồ - Hàm chạy đầu tiên khi vào màn hình
  Future<void> _initializeMap() async {
    try {
      await _determineStartLocation();
      await _determineDestination();

      print('📍 Sau khi xác định:');
      print('   Start: $_startLocation ($_startAddress)');
      print('   Current: $_currentLocation');
      print('   Destination: $_destination');

      if (_startLocation != null && _destination != null) {
        await _calculateRoute();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
// Xác định ĐIỂM BẮT ĐẦU
  Future<void> _determineStartLocation() async {
    try {//ƯU TIÊN 1: Nếu có tọa độ từ có sẵn (startLat, startLng)
      if (widget.startLat != null && widget.startLng != null) {
        _startLocation = LatLng(widget.startLat!, widget.startLng!);
        if (widget.startLocation != null) {
          _startAddress = widget.startLocation;
        } else {
          _startAddress = await MapService.getAddressFromCoordinates( // Chuyển tọa độ -> địa chỉ
              widget.startLat!, widget.startLng!);
        }
      }//ƯU TIÊN 2: Nếu có địa chỉ dạng text
      else if (widget.startLocation != null && widget.startLocation!.isNotEmpty) {
        final location = await MapService.getCoordinatesFromAddress(// huyển địa chỉ từ câu hỏi thành tọa độ
            widget.startLocation!);
        _startLocation = LatLng(location.latitude, location.longitude);
        _startAddress = widget.startLocation;
      }
      else {// 🔹 ƯU TIÊN 3 (MẶC ĐỊNH): Lấy vị trí GPS hiện tại của người dùng
        final position = await MapService.getCurrentLocation();
        _currentLocation = LatLng(position.latitude, position.longitude);
        _startLocation = _currentLocation;
        _startAddress = 'Vị trí hiện tại của bạn';
      }

      print('Điểm bắt đầu: $_startAddress ($_startLocation)');
    } catch (e) {
      print('Lỗi xác định điểm bắt đầu: $e');
      _startLocation = const LatLng(19.8067, 105.7850);
      _startAddress = 'Vị trí mặc định';
    }
  }

  Future<void> _determineDestination() async {
    try {
      if (widget.destinationLat != null && widget.destinationLng != null) {
        _destination = LatLng(widget.destinationLat!, widget.destinationLng!);
        _endAddress = await MapService.getAddressFromCoordinates(
            widget.destinationLat!, widget.destinationLng!);
      } else if (widget.destination != null) {
        final location = await MapService.getCoordinatesFromAddress(
            widget.destination!);
        _destination = LatLng(location.latitude, location.longitude);
        _endAddress = widget.destination;
      } else {
        _destination = const LatLng(19.8067, 105.7850);
        _endAddress = 'Thanh Hóa';
      }

      print('Điểm kết thúc: $_endAddress ($_destination)');
    } catch (e) {
      print('Lỗi xác định điểm kết thúc: $e');
      _destination = const LatLng(19.8067, 105.7850);
      _endAddress = 'Thanh Hóa';
    }
  }

  Future<void> _calculateRoute() async {
    if (_startLocation == null || _destination == null) return;

    setState(() {
      _isCalculating = true;
      _showInstructions = false;
      _currentStepIndex = 0;
    });

    try {
      // Chuyển đổi transportMode sang profile OSRM
      String osrmProfile;
      switch (_transportMode) {
        case 'car':
          osrmProfile = 'car';
          break;
        case 'drive':
          osrmProfile = 'car'; // Xe máy cũng dùng profile car
          break;
        case 'walk':
          osrmProfile = 'foot';
          break;
        default:
          osrmProfile = 'car';
      }
      print('🔄 Đang tính route với phương tiện: $_transportMode (OSRM: $osrmProfile)');


      final polyline = await MapService.getRoutePolyline(
        _startLocation!.latitude,
        _startLocation!.longitude,
        _destination!.latitude,
        _destination!.longitude,
        transportMode: osrmProfile,
      );

      final routeInfo = await MapService.getRouteInfo(
        _startLocation!.latitude,
        _startLocation!.longitude,
        _destination!.latitude,
        _destination!.longitude,
        transportMode: osrmProfile, // ← Đã sửa
      );

      final steps = await MapService.getRouteSteps(
        _startLocation!.latitude,
        _startLocation!.longitude,
        _destination!.latitude,
        _destination!.longitude,
        transportMode: osrmProfile, // ← Đã sửa
      );

      double distance = routeInfo['distance'] ?? 0;
      if (distance > 1000) {
        print('⚠️ Khoảng cách quá lớn ($distance km), có thể lỗi API');
        distance = 0;
      }

      setState(() {
        _polylinePoints = polyline.map((coord) => LatLng(coord[0], coord[1])).toList();
        _distance = distance;
        _duration = routeInfo['duration'] ?? 0;
        _navigationSteps = steps;
        _isCalculating = false;
      });

// ✅ Sửa lỗi dispose
      if (mounted && _isMapReady && _polylinePoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            final bounds = LatLngBounds.fromPoints(_polylinePoints);
            _mapController.fitBounds(
              bounds,
              options: const FitBoundsOptions(padding: EdgeInsets.all(70)),
            );
          }
        });
      }

      print('✅ Đã cập nhật route: ${_formatDistance(_distance)} • ${_formatDuration(_duration)}');
    } catch (e) {
      print('❌ Lỗi tính toán tuyến đường: $e');
      setState(() {
        _isCalculating = false;
      });
    }
  }

  String _formatDistance(double km) {
    if (km <= 0) return 'Đang tính...';
    if (km < 0.1) {
      return '${(km * 1000).toStringAsFixed(0)}m';
    } else if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)}m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return 'Đang tính...';
    if (minutes < 1) {
      return '${(minutes * 60).toStringAsFixed(0)} giây';
    } else if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)} phút';
    } else {
      final hours = (minutes / 60).floor();
      final mins = (minutes % 60).round();
      if (mins == 0) {
        return '$hours giờ';
      }
      return '$hours giờ $mins phút';
    }
  }

  IconData _getManeuverIcon(String? maneuver) {
    switch (maneuver) {
      case 'depart': return Icons.play_arrow;
      case 'arrive': return Icons.flag;
      case 'turn':
      case 'ramp':
      case 'fork': return Icons.turn_right;
      case 'continue': return Icons.arrow_forward;
      case 'merge': return Icons.merge_type;
      case 'rotary':
      case 'roundabout': return Icons.rotate_right;
      case 'off ramp': return Icons.exit_to_app;
      case 'end of road': return Icons.stop;
      default: return Icons.directions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isNavigating ? 'ĐANG CHỈ ĐƯỜNG' : 'Chỉ Đường',
              style: const TextStyle(fontSize: 16),
            ),
            if (_startAddress != null && _endAddress != null && !_isNavigating)
              Text(
                'Từ: ${_startAddress!.length > 30 ? '${_startAddress!.substring(0, 30)}...' : _startAddress!}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (_isNavigating && _currentLocation != null)
              Text(
                'Đang theo dõi vị trí...',
                style: const TextStyle(fontSize: 12, color: Colors.greenAccent),
              ),
          ],
        ),
        actions: [
          if (!_isNavigating) ...[
            IconButton(
              icon: const Icon(Icons.edit_location),
              onPressed: _changeStartLocation,
              tooltip: 'Thay đổi điểm bắt đầu',
            ),

            IconButton(
              icon: const Icon(Icons.flag),
              onPressed: _changeDestination,
              tooltip: 'Thay đổi điểm kết thúc',
            ),
          ],
          //IconButton(
          //icon: const Icon(Icons.open_in_new),
          //onPressed: _openInExternalMap,
          //),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentLocation ?? _startLocation ?? const LatLng(19.8067, 105.7850),
              zoom: _zoom,
              minZoom: 5,
              maxZoom: 18,
              onMapReady: () {
                setState(() => _isMapReady = true);

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _isMapReady && _startLocation != null) {
                    _mapController.move(_startLocation!, _zoom);
                  }
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.thanhhoa_travel',
              ),

              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      color: _transportMode == 'walk' ? Colors.green :
                      _transportMode == 'car' ? Colors.blue :
                      const Color(0xFF9B89FF),
                      strokeWidth: 4,
                    ),
                  ],
                ),

              // Mũi tên chỉ vị trí hiện tại - CHỈ HIỆN KHI ĐANG NAVIGATION
              if (_isNavigating && _currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _arrowAnimation!,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _currentBearing * math.pi / 180,
                            child: Transform.scale(
                              scale: _arrowAnimation!.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF9B89FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF9B89FF).withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

              if (_startLocation != null && !_isNavigating)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _startLocation!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.green,
                        size: 40,
                      ),
                    ),
                  ],
                ),

              if (_destination != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _destination!,
                      width: 40,
                      height: 40,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),

              // Marker cho các điểm cần rẽ
              if (_navigationSteps.isNotEmpty && _isNavigating)
                MarkerLayer(
                  markers: _buildStepMarkers(),
                ),
            ],
          ),

          if (!_isNavigating)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _buildInfoPanel(),
            ),

          if (_isNavigating)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: _buildNavigationInfo(),
            ),

          if (_navigationSteps.isNotEmpty && !_isLoading && !_isNavigating)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: NavigationInstructions(
                steps: _navigationSteps,
                onStartNavigation: _startNavigation,
                onClose: _closeInstructions,
                onExpandChanged: (isExpanded) { // ✅ THÊM CALLBACK
                  setState(() {
                    _isNavPanelExpanded = isExpanded;
                  });
                },
              ),
            ),

          if (!_isNavigating && !_showInstructions && !_isNavPanelExpanded)
            Positioned(
              bottom: 70 + MediaQuery.of(context).padding.bottom,
              left: 20,
              right: 20,
              child: _buildTransportSelector(),
            ),

          Positioned(
            right: 20,
            top: 100,
            child: Column(
              children: [
                FloatingActionButton.small(
                  onPressed: () {
                    if (_isMapReady) {
                      _mapController.move(_mapController.center, _zoom + 1);
                      setState(() => _zoom += 1);
                    }
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  onPressed: () {
                    if (_isMapReady) {
                      _mapController.move(_mapController.center, _zoom - 1);
                      setState(() => _zoom -= 1);
                    }
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  onPressed: _moveToCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),

          if (_isNavigating)
            Positioned(
              top: 10,
              right: 10,
              child: FloatingActionButton.small(
                onPressed: _stopNavigation,
                backgroundColor: Colors.red,
                child: const Icon(Icons.stop, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavigationInfo() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lấy bước hiện tại
    NavigationStep? currentStep;
    if (_navigationSteps.isNotEmpty) {
      if (_currentStepIndex < _navigationSteps.length) {
        currentStep = _navigationSteps[_currentStepIndex];
      } else if (_currentStepIndex > 0) {
        currentStep = _navigationSteps[_navigationSteps.length - 1];
      }
    }

    // Nếu đang ở bước "depart" (Xuất phát) thì lấy bước tiếp theo
    if (currentStep?.maneuver == 'depart' && _currentStepIndex + 1 < _navigationSteps.length) {
      currentStep = _navigationSteps[_currentStepIndex + 1];
    }

    String instruction = currentStep?.instruction ?? 'Tiếp tục theo tuyến đường';
    if (instruction.isEmpty || instruction.toLowerCase().contains('depart')) {
      instruction = 'Tiếp tục theo đường chính';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF9B89FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.navigation, color: Color(0xFF9B89FF), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _remainingDistance > 0
                      ? 'Còn ${_formatDistance(_remainingDistance)}'
                      : 'Đang tính...',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tiếp theo: $instruction',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInfoPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _startAddress ?? 'Điểm bắt đầu',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _endAddress ?? 'Điểm đến',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_distance > 0 && !_isCalculating)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatDistance(_distance)} • ${_formatDuration(_duration)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTransportSelector() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _transportModes.map((mode) {
          final isSelected = _transportMode == mode;
          return GestureDetector(
            onTap: () {
              if (_transportMode != mode) {
                setState(() {
                  _transportMode = mode;
                });
                _calculateRoute();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF9B89FF) : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[100]),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Icon(
                        _transportIcons[mode]!,
                        color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey),
                        size: 20,
                      ),
                      if (_isCalculating && isSelected)
                        const Positioned.fill(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _transportNames[mode]!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
    });
    _positionStream?.cancel();
  }

  Future<void> _openInExternalMap() async {
    try {
      if (_startLocation != null && _destination != null) {
        // Chuyển đổi sang mode cho Google Maps
        String googleMode;
        switch (_transportMode) {
          case 'car':
            googleMode = 'driving';
            break;
          case 'drive':
            googleMode = 'driving';
            break;
          case 'walk':
            googleMode = 'walking';
            break;
          default:
            googleMode = 'driving';
        }

        await MapService.openExternalMap(
          _startLocation!.latitude,
          _startLocation!.longitude,
          _destination!.latitude,
          _destination!.longitude,
          transportMode: googleMode,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: ${e.toString()}')),
      );
    }
  }


  Future<void> _changeStartLocation() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StartLocationDialog(currentStart: _startAddress),
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      if (result['type'] == 'current') {
        final position = await MapService.getCurrentLocation();
        _startLocation = LatLng(position.latitude, position.longitude);
        _startAddress = 'Vị trí hiện tại của bạn';
        _currentLocation = _startLocation;
      } else if (result['type'] == 'custom' && result['address'] != null) {
        final location = await MapService.getCoordinatesFromAddress(result['address']);
        _startLocation = LatLng(location.latitude, location.longitude);
        _startAddress = result['address'];
        _currentLocation = _startLocation;
      }

      if (_startLocation != null && _destination != null) {
        await _calculateRoute();
      }

      // ✅ Sửa lỗi dispose
      if (mounted && _isMapReady && _startLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _mapController.move(_startLocation!, _zoom);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  Future<void> _changeDestination() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DestinationDialog(currentEnd: _endAddress),
    );

    if (result == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      if (result['type'] == 'custom' && result['address'] != null) {
        final location =
        await MapService.getCoordinatesFromAddress(result['address']);

        _destination = LatLng(location.latitude, location.longitude);
        _endAddress = result['address'];
      }

      if (_startLocation != null && _destination != null) {
        await _calculateRoute();
      }

      if (mounted && _isMapReady && _destination != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isMapReady) {
            _mapController.move(_destination!, _zoom);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _moveToCurrentLocation() {
    if (_currentLocation != null && _isMapReady) {
      _mapController.move(_currentLocation!, _zoom);
    }
  }
}


class _StartLocationDialog extends StatefulWidget {
  final String? currentStart;

  const _StartLocationDialog({this.currentStart});

  @override
  State<_StartLocationDialog> createState() => __StartLocationDialogState();
}
class _DestinationDialog extends StatefulWidget {
  final String? currentEnd;

  const _DestinationDialog({this.currentEnd});

  @override
  State<_DestinationDialog> createState() => __DestinationDialogState();
}

class __DestinationDialogState extends State<_DestinationDialog> {
  final TextEditingController _addressController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn điểm kết thúc'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Nhập điểm đến',
              hintText: 'Ví dụ: FLC Sầm Sơn',
            ),
          ),
          if (widget.currentEnd != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Hiện tại: ${widget.currentEnd}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = {
              'type': 'custom',
              'address': _addressController.text,
            };
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B89FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}
class __StartLocationDialogState extends State<_StartLocationDialog> {
  final TextEditingController _addressController = TextEditingController();
  int _selectedOption = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn điểm bắt đầu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<int>(
            title: const Text('Vị trí hiện tại của tôi'),
            value: 0,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
          ),
          RadioListTile<int>(
            title: const Text('Địa chỉ khác'),
            value: 1,
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
          ),
          if (_selectedOption == 1)
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Nhập địa chỉ bắt đầu',
                hintText: 'Ví dụ: Bãi biển Sầm Sơn, Thanh Hóa',
              ),
            ),
          if (widget.currentStart != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Hiện tại: ${widget.currentStart}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () {
            final result = {
              'type': _selectedOption == 0 ? 'current' : 'custom',
              'address': _selectedOption == 1 ? _addressController.text : null,
            };
            Navigator.pop(context, result);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9B89FF),
            foregroundColor: Colors.white,
          ),
          child: const Text('Xác nhận'),
        ),
      ],
    );
  }
}