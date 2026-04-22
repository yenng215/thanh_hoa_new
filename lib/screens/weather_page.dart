// lib/screens/weather_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../services/map_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _weatherData;
  Map<String, dynamic>? _forecastData;
  bool _isLoading = true;
  String? _errorMessage;
  String _currentLocation = 'Thanh Hóa';

  // Biến cho tìm kiếm
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Hàm helper để cắt ngắn tên địa điểm
  String _truncateLocation(String location, {int maxLength = 25}) {
    if (location.length <= maxLength) return location;
    return '${location.substring(0, maxLength)}...';
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _loadWeatherData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWeatherData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Thử lấy vị trí hiện tại
      try {
        final position = await MapService.getCurrentLocation();

        // Lấy thời tiết hiện tại
        final weather = await WeatherService.getWeatherByCoordinates(
          position.latitude,
          position.longitude,
        );

        // Lấy dự báo 5 ngày
        final forecast = await WeatherService.getForecast(
          position.latitude,
          position.longitude,
        );

        // Lấy tên thành phố
        final address = await MapService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );

        setState(() {
          _weatherData = weather;
          _forecastData = forecast;
          _currentLocation = address.split(',').first;
          _isLoading = false;
        });
      } catch (e) {
        // Fallback: lấy thời tiết Thanh Hóa
        print('⚠️ Không lấy được vị trí, dùng Thanh Hóa mặc định: $e');

        final weather = await WeatherService.getThanhHoaWeather();

        setState(() {
          _weatherData = weather['current'];
          _forecastData = weather['forecast'];
          _currentLocation = 'Thanh Hóa';
          _isLoading = false;
        });
      }

      _animationController.forward();
    } catch (e) {
      print('❌ Lỗi tải thời tiết: $e');
      setState(() {
        _errorMessage = 'Không thể tải dữ liệu thời tiết';
        _isLoading = false;
      });
    }
  }

  // Hàm tìm kiếm địa điểm
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final results = await MapService.searchLocation(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Lỗi tìm kiếm: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Hàm chọn địa điểm từ kết quả tìm kiếm
  Future<void> _selectLocation(Map<String, dynamic> location) async {
    setState(() {
      _isLoading = true;
      _searchController.clear();
      _searchResults = []; // Đóng overlay
    });

    try {
      final lat = location['lat'];
      final lng = location['lng'];
      final name = location['name'].toString().split(',').first;

      // Lấy thời tiết cho địa điểm đã chọn
      final weather = await WeatherService.getWeatherByCoordinates(lat, lng);
      final forecast = await WeatherService.getForecast(lat, lng);

      setState(() {
        _weatherData = weather;
        _forecastData = forecast;
        _currentLocation = name;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể tải thời tiết cho địa điểm này';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Thời tiết',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadWeatherData,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(22),

              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm địa điểm...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white: Colors.grey[400],
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white: Colors.grey[400],
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: isDark ? Colors.white.withOpacity(0.8) : Colors.grey[400],
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchResults = [];
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
                onChanged: _searchLocation,
                onSubmitted: _searchLocation,
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Nội dung chính
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF9B89FF)))
              : _errorMessage != null
              ? _buildErrorWidget()
              : RefreshIndicator(
            onRefresh: _loadWeatherData,
            color: const Color(0xFF9B89FF),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Header với tên vị trí
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildLocationHeader(),
                  ),

                  const SizedBox(height: 16),

                  // Thời tiết hiện tại
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildCurrentWeather(),
                  ),

                  const SizedBox(height: 24),

                  // Dự báo theo giờ
                  if (_forecastData != null)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildHourlyForecast(),
                    ),

                  const SizedBox(height: 24),

                  // Dự báo 5 ngày
                  if (_forecastData != null)
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildDailyForecast(),
                    ),

                  const SizedBox(height: 16),

                  // Chi tiết thời tiết
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildWeatherDetails(),
                  ),

                  const SizedBox(height: 20),

                  // 🌟 LƯU Ý QUAN TRỌNG CHO DU LỊCH
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildTravelWarning(),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Kết quả tìm kiếm
          if (_searchResults.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _searchResults = [];
                    _searchController.clear();
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.9,
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.7,
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF9B89FF),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.location_on, color: Colors.white),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Kết quả tìm kiếm',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _searchResults = [];
                                          _searchController.clear();
                                        });
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),

                              // Danh sách kết quả
                              Expanded(
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final location = _searchResults[index];
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9B89FF).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.place,
                                            color: Color(0xFF9B89FF), size: 20),
                                      ),
                                      title: Text(
                                        _truncateLocation(location['name'].toString().split(',').first, maxLength: 30),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black,
                                        ),
                                      ),
                                      subtitle: Text(
                                        _truncateLocation(location['name'].toString(), maxLength: 50),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF9B89FF).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 14,
                                          color: Color(0xFF9B89FF),
                                        ),
                                      ),
                                      onTap: () => _selectLocation(location),
                                    );
                                  },
                                ),
                              ),

                              // Footer
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                                  borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Tìm thấy ${_searchResults.length} địa điểm',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 🌟 WIDGET LƯU Ý DU LỊCH
  Widget _buildTravelWarning() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_weatherData == null) return const SizedBox();

    final temp = _weatherData!['main']['temp'];
    final weatherMain = _weatherData!['weather'][0]['main'].toLowerCase();
    final description = _weatherData!['weather'][0]['description'].toLowerCase();
    final windSpeed = _weatherData!['wind']['speed'] * 3.6; // km/h
    final humidity = _weatherData!['main']['humidity'];

    // Phân tích điều kiện thời tiết để đưa ra lưu ý
    String warningTitle = "🌤️ Lưu ý cho chuyến đi";
    Color warningColor = Colors.orange;
    List<String> warnings = [];

    // Nhiệt độ
    if (temp > 35) {
      warnings.add("• 🌡️ Nhiệt độ rất cao (>35°C): Hạn chế hoạt động ngoài trời từ 11h-15h, uống nhiều nước, đội mũ, chống nắng kỹ.");
    } else if (temp > 30) {
      warnings.add("• 🌡️ Nhiệt độ cao: Nhớ uống đủ nước, bôi kem chống nắng khi tham quan.");
    } else if (temp < 20) {
      warnings.add("• 🌡️ Trời se lạnh: Mang theo áo khoác mỏng, đặc biệt khi đi biển buổi sáng/tối.");
    } else if (temp < 15) {
      warnings.add("• 🌡️ Trời lạnh: Mặc ấm, chuẩn bị áo khoác dày cho các điểm du lịch vùng núi.");
    }

    // Mưa
    if (weatherMain.contains('rain') || description.contains('mưa')) {
      warningColor = Colors.blue;
      warningTitle = "☔ Cảnh báo mưa";
      warnings.add("• ☔ Trời đang mưa: Mang ô, áo mưa. Các hoạt động ngoài trời có thể bị gián đoạn.");

      // Kiểm tra xác suất mưa từ forecast
      if (_forecastData != null) {
        final list = _forecastData!['list'] as List;
        if (list.isNotEmpty) {
          final pop = list[0]['pop'] * 100;
          if (pop > 70) {
            warnings.add("• 📊 Xác suất mưa ${pop.round()}%: Nên có kế hoạch dự phòng trong nhà.");
          }
        }
      }
    }

    // Gió mạnh
    if (windSpeed > 30) {
      warnings.add("• 💨 Gió mạnh (${windSpeed.round()} km/h): Thận trọng khi đi biển, leo núi. Không nên đi tàu thuyền nhỏ.");
    } else if (windSpeed > 20) {
      warnings.add("• 💨 Gió khá mạnh: Các hoạt động ngoài trời vẫn ổn, nhưng chú ý khi chụp ảnh ở nơi cao.");
    }

    // Độ ẩm cao
    if (humidity > 85) {
      warnings.add("• 💧 Độ ẩm rất cao: Cảm giác oi bức, dễ mệt mỏi. Nên nghỉ ngơi nhiều hơn khi tham quan.");
    }

    // Mây mù - tầm nhìn kém
    final visibility = _weatherData!['visibility'] / 1000;
    if (visibility < 2) {
      warnings.add("• 🌫️ Tầm nhìn kém (<2km): Thận trọng khi lái xe, đặc biệt ở khu vực núi, đèo.");
    }

    // Lưu ý theo địa hình (dựa vào địa điểm hiện tại)
    final location = _currentLocation.toLowerCase();
    if (location.contains('pù luông') || location.contains('núi') || location.contains('rừng')) {
      warnings.add("• 🏔️ Khu vực núi cao: Nhiệt độ thấp hơn 3-5°C so với đồng bằng. Đường trơn trượt nếu có mưa.");
      warnings.add("• 🧗 Chuẩn bị giày leo núi, nước uống, đồ ăn nhẹ. Không đi một mình.");
    } else if (location.contains('sầm sơn') || location.contains('biển') || location.contains('hải tiến')) {
      warnings.add("• 🏖️ Khu vực biển: Chú ý sóng lớn, dòng chảy xa bờ. Không tắm biển khi có cờ đỏ.");
      warnings.add("• ☀️ Thời điểm đẹp nhất để tắm biển: 8h-10h sáng và 15h-17h chiều.");
    } else if (location.contains('thành nhà hồ') || location.contains('di tích')) {
      warnings.add("• 🏛️ Khu di tích lịch sử: Hạn chế leo trèo khu vực cấm. Đi giày thoải mái vì phải đi bộ nhiều.");
    }

    // Nếu không có lưu ý đặc biệt
    if (warnings.isEmpty) {
      warnings.add("• ✅ Thời tiết thuận lợi cho các hoạt động tham quan, du lịch.");
      warnings.add("• 😎 Chúc bạn có chuyến đi vui vẻ tại $_currentLocation!");
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark
            ? null
            : LinearGradient(
          colors: [
            warningColor.withOpacity(0.1),
            warningColor.withOpacity(0.05),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        color: isDark ? const Color(0xFF1E1E1E) : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warningColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  warningColor == Colors.blue ? Icons.umbrella :
                  warningColor == Colors.orange ? Icons.wb_sunny :
                  Icons.info,
                  color: warningColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  warningTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: warningColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...warnings.map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              warning,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                height: 1.4,
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildLocationHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Color(0xFF9B89FF), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _currentLocation,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF9B89FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF9B89FF)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeather() {
    if (_weatherData == null) return const SizedBox();

    final temp = _weatherData!['main']['temp'].round();
    final feelsLike = _weatherData!['main']['feels_like'].round();
    final tempMin = _weatherData!['main']['temp_min'].round();
    final tempMax = _weatherData!['main']['temp_max'].round();
    final humidity = _weatherData!['main']['humidity'];
    final description = _weatherData!['weather'][0]['description'];
    final iconCode = _weatherData!['weather'][0]['icon'];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9B89FF),
            const Color(0xFFB8A9FF),
            const Color(0xFFD6C9FF),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9B89FF).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$temp°',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    WeatherService.translateWeatherDescription(description),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Image.network(
                  WeatherService.getWeatherIcon(iconCode),
                  width: 80,
                  height: 80,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.cloud, color: Colors.white, size: 60);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildWeatherStat(
                icon: Icons.thermostat,
                value: '$tempMax°',
                label: 'Cao nhất',
                color: Colors.orangeAccent,
              ),
              _buildWeatherStat(
                icon: Icons.thermostat,
                value: '$tempMin°',
                label: 'Thấp nhất',
                color: Colors.lightBlueAccent,
              ),
              _buildWeatherStat(
                icon: Icons.thermostat_auto,
                value: '$feelsLike°',
                label: 'Cảm giác',
                color: Colors.greenAccent,
              ),
              _buildWeatherStat(
                icon: Icons.water_drop,
                value: '$humidity%',
                label: 'Độ ẩm',
                color: Colors.blueAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHourlyForecast() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _forecastData!['list'] as List;
    final hourly = list.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.access_time, color: Color(0xFF9B89FF), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Dự báo theo giờ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: hourly.length,
            itemBuilder: (context, index) {
              final item = hourly[index];
              final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
              final temp = item['main']['temp'].round();
              final iconCode = item['weather'][0]['icon'];
              final pop = item['pop'];

              return Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(dt),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF9B89FF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Image.network(
                      WeatherService.getWeatherIcon(iconCode),
                      width: 40,
                      height: 40,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$temp°',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    if (pop > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${(pop * 100).round()}%',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDailyForecast() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _forecastData!['list'] as List;

    final Map<String, dynamic> dailyMap = {};

    for (var item in list) {
      final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
      final dateKey = DateFormat('yyyy-MM-dd').format(dt);

      if (!dailyMap.containsKey(dateKey)) {
        dailyMap[dateKey] = item;
      } else if ((dt.hour - 12).abs() <
          (DateTime.fromMillisecondsSinceEpoch(dailyMap[dateKey]['dt'] * 1000).hour - 12).abs()) {
        dailyMap[dateKey] = item;
      }
    }

    final daily = dailyMap.values.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.calendar_today, color: Color(0xFF9B89FF), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Dự báo 5 ngày tới',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: daily.length,
            separatorBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),
            ),
            itemBuilder: (context, index) {
              final item = daily[index];
              final dt = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
              final tempMax = item['main']['temp_max'].round();
              final tempMin = item['main']['temp_min'].round();
              final iconCode = item['weather'][0]['icon'];
              final description = item['weather'][0]['description'];
              final pop = item['pop'];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Ngày trong tuần
                    SizedBox(
                      width: 60,
                      child: Text(
                        index == 0 ? 'Hôm nay' : DateFormat('E').format(dt),
                        style: TextStyle(
                          fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                          color: index == 0
                              ? const Color(0xFF9B89FF)
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                    ),

                    // Ngày tháng
                    SizedBox(
                      width: 50,
                      child: Text(
                        DateFormat('dd/MM').format(dt),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),

                    // Icon thời tiết
                    Image.network(
                      WeatherService.getWeatherIcon(iconCode),
                      width: 35,
                      height: 35,
                    ),

                    const SizedBox(width: 8),

                    // Mô tả ngắn
                    Expanded(
                      child: Text(
                        WeatherService.translateWeatherDescription(description),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),

                    // Xác suất mưa
                    if (pop > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.water_drop, color: isDark ? Colors.blue[300] : Colors.blue[400], size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${(pop * 100).round()}%',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.blue[300] : Colors.blue[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Nhiệt độ
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$tempMax°/$tempMin°',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeatherDetails() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_weatherData == null) return const SizedBox();

    final windSpeed = (_weatherData!['wind']['speed'] * 3.6).round();
    final windDeg = _weatherData!['wind']['deg'].toDouble();
    final pressure = _weatherData!['main']['pressure'];
    final visibility = _weatherData!['visibility'] / 1000;
    final clouds = _weatherData!['clouds']['all'];
    final sunrise = DateTime.fromMillisecondsSinceEpoch(_weatherData!['sys']['sunrise'] * 1000);
    final sunset = DateTime.fromMillisecondsSinceEpoch(_weatherData!['sys']['sunset'] * 1000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9B89FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.info_outline, color: Color(0xFF9B89FF), size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Chi tiết thời tiết',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildDetailItem(
                icon: Icons.air,
                label: 'Gió',
                value: '$windSpeed km/h',
                subValue: WeatherService.getWindDirection(windDeg),
                iconColor: Colors.blue,
              ),
              _buildDetailItem(
                icon: Icons.compress,
                label: 'Áp suất',
                value: '$pressure hPa',
                iconColor: Colors.purple,
              ),
              _buildDetailItem(
                icon: Icons.visibility,
                label: 'Tầm nhìn',
                value: '${visibility.toStringAsFixed(1)} km',
                iconColor: Colors.teal,
              ),
              _buildDetailItem(
                icon: Icons.cloud,
                label: 'Mây',
                value: '$clouds%',
                iconColor: Colors.grey,
              ),
              _buildDetailItem(
                icon: Icons.wb_sunny,
                label: 'Bình minh',
                value: DateFormat('HH:mm').format(sunrise),
                iconColor: Colors.orange,
              ),
              _buildDetailItem(
                icon: Icons.nights_stay,
                label: 'Hoàng hôn',
                value: DateFormat('HH:mm').format(sunset),
                iconColor: Colors.indigo,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    String? subValue,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (subValue != null)
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off,
                size: 60,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWeatherData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9B89FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Thử lại',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}