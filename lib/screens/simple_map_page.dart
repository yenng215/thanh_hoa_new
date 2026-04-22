// lib/screens/simple_map_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/map_service.dart';
import 'map_page.dart';

class SimpleMapPage extends StatefulWidget {
  const SimpleMapPage({super.key});

  @override
  State<SimpleMapPage> createState() => _SimpleMapPageState();
}

class _SimpleMapPageState extends State<SimpleMapPage> {
  late MapController _mapController;
  LatLng? _currentLocation;
  LatLng? _destinationLocation;
  String? _destinationAddress;
  String? _startAddress;
  LatLng? _startLocation;
  bool _isLoading = true;
  bool _isMapReady = false;
  double _zoom = 14.0;
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _startController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  // Thêm biến để theo dõi ô nào đang được focus
  FocusNode _startFocusNode = FocusNode();
  FocusNode _destinationFocusNode = FocusNode();

  // Thêm biến để theo dõi trạng thái bàn phím
  bool _isKeyboardVisible = false;

  // Danh sách địa điểm mặc định tại Thanh Hóa
  final List<Map<String, dynamic>> _defaultLocations = [
    {'name': 'Bãi biển Sầm Sơn, Thanh Hóa', 'lat': 19.7333, 'lng': 105.9000},
    {'name': 'Thành nhà Hồ, Vĩnh Lộc, Thanh Hóa', 'lat': 20.0833, 'lng': 105.6000},
    {'name': 'Suối cá thần Cẩm Lương, Thanh Hóa', 'lat': 20.2000, 'lng': 105.1000},
    {'name': 'Khu bảo tồn Pù Luông, Thanh Hóa', 'lat': 20.4167, 'lng': 105.0833},
    {'name': 'Biển Hải Tiến, Hoằng Hóa, Thanh Hóa', 'lat': 19.8667, 'lng': 105.9500},
    {'name': 'Đền Bà Chúa, Thọ Xuân, Thanh Hóa', 'lat': 19.9333, 'lng': 105.4667},
    {'name': 'Vườn quốc gia Bến En, Thanh Hóa', 'lat': 19.5833, 'lng': 105.5333},
    {'name': 'Cầu Hàm Rồng, Thanh Hóa', 'lat': 19.8167, 'lng': 105.7833},
    {'name': 'Chùa Sùng Nghiêm, Thanh Hóa', 'lat': 20.0667, 'lng': 105.6167},
    {'name': 'Núi Trường Lệ, Thanh Hóa', 'lat': 19.7500, 'lng': 105.8333},
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
    _startController.text = 'Vị trí hiện tại';

    // Thêm listener cho focus nodes
    _startFocusNode.addListener(_onFocusChange);
    _destinationFocusNode.addListener(_onFocusChange);

    // Thêm listener để theo dõi bàn phím
    _setupKeyboardListeners();
  }

  void _setupKeyboardListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).addListener(_handleKeyboardVisibility);
      }
    });
  }

  void _handleKeyboardVisibility() {
    final hasFocus = FocusScope.of(context).hasFocus;
    final isKeyboardVisible = hasFocus &&
        (FocusScope.of(context).focusedChild != null);

    if (_isKeyboardVisible != isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = isKeyboardVisible;
      });
    }
  }

  void _onFocusChange() {
    // Khi focus thay đổi, xóa kết quả tìm kiếm cũ
    if (!_startFocusNode.hasFocus && !_destinationFocusNode.hasFocus) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _destinationController.dispose();
    _startController.dispose();
    _debounce?.cancel();
    _startFocusNode.removeListener(_onFocusChange);
    _destinationFocusNode.removeListener(_onFocusChange);
    _startFocusNode.dispose();
    _destinationFocusNode.dispose();
    FocusScope.of(context).removeListener(_handleKeyboardVisibility);
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await MapService.getCurrentLocation();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _startLocation = _currentLocation;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _currentLocation = const LatLng(19.8067, 105.7850);
        _startLocation = _currentLocation;
        _isLoading = false;
      });
    }
  }

  void _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isSearching = true);
      try {
        final results = await MapService.searchLocation(query);
        List<Map<String, dynamic>> finalResults = results;
        if (finalResults.isEmpty) {
          finalResults = _defaultLocations
              .where((loc) => loc['name'].toLowerCase().contains(query.toLowerCase()))
              .toList();
        }
        if (mounted) {
          setState(() {
            _searchResults = finalResults;
            _isSearching = false;
          });
        }
      } catch (e) {
        final filtered = _defaultLocations
            .where((loc) => loc['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
        if (mounted) {
          setState(() {
            _searchResults = filtered;
            _isSearching = false;
          });
        }
      }
    });
  }

  void _selectLocation(Map<String, dynamic> location) {
    // Ẩn bàn phím và clear focus
    FocusScope.of(context).unfocus();

    // Kiểm tra ô nào đang được focus để cập nhật đúng
    if (_startFocusNode.hasFocus) {
      // Chọn làm điểm bắt đầu
      setState(() {
        _startLocation = LatLng(location['lat'], location['lng']);
        _startAddress = location['name'];
        _startController.text = location['name'];
        _searchResults = [];
        _isSearching = false;
      });

    } else if (_destinationFocusNode.hasFocus) {
      // Chọn làm điểm đến
      setState(() {
        if (location.containsKey('location')) {
          _destinationLocation = location['location'];
          _destinationAddress = location['address'];
          _destinationController.text = _destinationAddress ?? '';
        } else {
          _destinationLocation = LatLng(location['lat'], location['lng']);
          _destinationAddress = location['name'];
          _destinationController.text = location['name'];
        }
        _searchResults = [];
        _isSearching = false;
        _zoom = 15;
      });
      if (_isMapReady && _destinationLocation != null) {
        _mapController.move(_destinationLocation!, _zoom);
      }

    }
  }

  void _selectDestinationFromMap(Map<String, dynamic> location) {
    setState(() {
      if (location.containsKey('location')) {
        _destinationLocation = location['location'];
        _destinationAddress = location['address'];
        _destinationController.text = _destinationAddress ?? '';
      } else {
        _destinationLocation = LatLng(location['lat'], location['lng']);
        _destinationAddress = location['name'];
        _destinationController.text = location['name'];
      }
      _zoom = 15;
    });
    if (_isMapReady && _destinationLocation != null) {
      _mapController.move(_destinationLocation!, _zoom);
    }

  }

  void _navigate() {
    if (_destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Vui lòng chọn điểm đến')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          destinationLat: _destinationLocation!.latitude,
          destinationLng: _destinationLocation!.longitude,
          destination: _destinationAddress,
          startLat: _startLocation?.latitude,
          startLng: _startLocation?.longitude,
          startLocation: _startAddress,
        ),
      ),
    );
  }

  void _setStartAsCurrentLocation() {
    // Ẩn bàn phím
    FocusScope.of(context).unfocus();

    if (_currentLocation != null) {
      setState(() {
        _startLocation = _currentLocation;
        _startController.text = 'Vị trí hiện tại của bạn';
        _startAddress = 'Vị trí hiện tại của bạn';
        _searchResults = [];
      });

    }
  }

  void _moveToCurrentLocation() {
    if (_currentLocation != null && _isMapReady) {
      _mapController.move(_currentLocation!, _zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Chỉ đường',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Ẩn bàn phím khi tap ra ngoài
          FocusScope.of(context).unfocus();
        },
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B89FF)))
            : Column(
          children: [
            // Input panel
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Điểm bắt đầu
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.circle, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _startController,
                          focusNode: _startFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Điểm bắt đầu',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.my_location, size: 20),
                                  onPressed: _setStartAsCurrentLocation,
                                  tooltip: 'Vị trí hiện tại',
                                ),
                                if (_startController.text.isNotEmpty && _startController.text != 'Vị trí hiện tại của bạn')
                                  IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _startController.clear();
                                        _startLocation = null;
                                        _startAddress = null;
                                        _searchResults = [];
                                      });
                                    },
                                  ),
                              ],
                            ),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onChanged: (value) {
                            if (value.isNotEmpty && value != 'Vị trí hiện tại của bạn') {
                              _searchLocation(value);
                            } else {
                              setState(() {
                                _searchResults = [];
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Điểm đến
// Điểm đến
                  // Điểm đến - Updated with X button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          focusNode: _destinationFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Điểm đến...',
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // X button for destination (always show if text is not empty)

                                // Map button
                                IconButton(
                                  icon: const Icon(Icons.map, size: 20),
                                  onPressed: () async {
                                    FocusScope.of(context).unfocus();
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PickLocationMap(
                                          initialLocation: _destinationLocation,
                                          title: 'Chọn điểm đến',
                                        ),
                                      ),
                                    );
                                    if (result != null && mounted) {
                                      _selectDestinationFromMap(result);
                                    }
                                  },
                                  tooltip: 'Chọn trên bản đồ',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _destinationController.clear();
                                      _destinationLocation = null;
                                      _destinationAddress = null;
                                      _searchResults = [];
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              _searchLocation(value);
                            } else {
                              setState(() {
                                _searchResults = [];
                              });
                            }
                          },
                          onSubmitted: (value) {
                            if (_searchResults.isNotEmpty) {
                              _selectLocation(_searchResults.first);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  // Khung gợi ý chung cho cả điểm bắt đầu và điểm đến
                  if ((_searchResults.isNotEmpty || _isSearching) && (_startFocusNode.hasFocus || _destinationFocusNode.hasFocus))
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      constraints: const BoxConstraints(
                        maxHeight: 250,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _isSearching
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                            : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final location = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                _startFocusNode.hasFocus ? Icons.circle : Icons.flag,
                                color: _startFocusNode.hasFocus ? Colors.green : Colors.red,
                                size: 18,
                              ),
                              title: Text(
                                location['name'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              subtitle: _startFocusNode.hasFocus && _startController.text == 'Vị trí hiện tại'
                                  ? null
                                  : null,
                              trailing: Icon(
                                _startFocusNode.hasFocus ? Icons.add_location_alt : Icons.location_on,
                                color: const Color(0xFF9B89FF),
                                size: 18,
                              ),
                              onTap: () => _selectLocation(location),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bản đồ
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _currentLocation,
                      zoom: _zoom,
                      minZoom: 8,
                      maxZoom: 18,
                      onMapReady: () {
                        setState(() => _isMapReady = true);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.thanhhoa_travel',
                      ),
                      if (_startLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _startLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 40),
                            ),
                          ],
                        ),
                      if (_destinationLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _destinationLocation!,
                              width: 40,
                              height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Chỉ hiển thị nút zoom và my location khi bàn phím KHÔNG hiển thị
                  if (!_isKeyboardVisible)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Column(
                        children: [
                          FloatingActionButton.small(
                            onPressed: () {
                              if (_isMapReady) {
                                setState(() => _zoom += 1);
                                _mapController.move(_mapController.center, _zoom);
                              }
                            },
                            child: const Icon(Icons.add),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            onPressed: () {
                              if (_isMapReady) {
                                setState(() => _zoom -= 1);
                                _mapController.move(_mapController.center, _zoom);
                              }
                            },
                            child: const Icon(Icons.remove),
                          ),
                          const SizedBox(height: 8),
                          FloatingActionButton.small(
                            onPressed: _moveToCurrentLocation,
                            child: const Icon(Icons.my_location),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Chỉ hiển thị nút chỉ đường khi bàn phím KHÔNG hiển thị
            if (!_isKeyboardVisible)
              Container(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _navigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9B89FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'CHỈ ĐƯỜNG',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// PickLocationMap (giữ nguyên như code cũ)
class PickLocationMap extends StatefulWidget {
  final LatLng? initialLocation;
  final String title;
  const PickLocationMap({
    super.key,
    this.initialLocation,
    required this.title,
  });

  @override
  State<PickLocationMap> createState() => _PickLocationMapState();
}

class _PickLocationMapState extends State<PickLocationMap> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  String? _selectedAddress;
  bool _isMapReady = false;
  double _zoom = 14;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _getAddressFromLocation();
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _getAddressFromLocation() async {
    if (_selectedLocation == null) return;
    try {
      final address = await MapService.getAddressFromCoordinates(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = '${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  void _onTapLocation(LatLng point) async {
    setState(() {
      _selectedLocation = point;
      _selectedAddress = null;
    });
    try {
      final address = await MapService.getAddressFromCoordinates(point.latitude, point.longitude);
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedAddress = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        });
      }
    }
  }

  void _confirm() {
    if (_selectedLocation != null && _selectedAddress != null) {
      Navigator.pop(context, {
        'location': _selectedLocation,
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF9B89FF),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: widget.initialLocation ?? const LatLng(19.8067, 105.7850),
                zoom: _zoom,
                onTap: (_, point) => _onTapLocation(point),
                onMapReady: () {
                  setState(() => _isMapReady = true);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.thanhhoa_travel',
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 50,
                        height: 50,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.5),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.place, color: Colors.white, size: 30),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Column(
                children: [
                  FloatingActionButton.small(
                    onPressed: () {
                      if (_isMapReady) {
                        setState(() => _zoom += 1);
                        _mapController.move(_mapController.center, _zoom);
                      }
                    },
                    child: const Icon(Icons.add),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    onPressed: () {
                      if (_isMapReady) {
                        setState(() => _zoom -= 1);
                        _mapController.move(_mapController.center, _zoom);
                      }
                    },
                    child: const Icon(Icons.remove),
                  ),
                ],
              ),
            ),
            if (_selectedLocation != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[600] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9B89FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: Color(0xFF9B89FF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedAddress ?? 'Đang tải địa chỉ...',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _confirm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF9B89FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'CHỌN ĐIỂM NÀY',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}