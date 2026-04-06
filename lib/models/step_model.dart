// lib/models/step_model.dart
class NavigationStep {
  final String instruction;
  final double distance;
  final double duration;
  final String? maneuver;
  final String? streetName;
  final List<double>? location; // [lat, lng]

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    this.maneuver,
    this.streetName,
    this.location,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    // Xử lý instruction từ OSRM
    String instruction = json['maneuver']?['type'] ?? '';
    final modifier = json['maneuver']?['modifier'] ?? '';
    final streetName = json['name']?.toString().trim() ?? '';

    // Tạo instruction tiếng Việt
    instruction = _formatInstruction(instruction, modifier, streetName);

    return NavigationStep(
      instruction: instruction,
      distance: (json['distance'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toDouble(),
      maneuver: json['maneuver']?['type'],
      streetName: streetName.isNotEmpty ? streetName : null,
      location: json['maneuver']?['location'] != null
          ? [json['maneuver']['location'][1].toDouble(), json['maneuver']['location'][0].toDouble()]
          : null,
    );
  }

  static String _formatInstruction(String type, String modifier, String streetName) {
    final street = streetName.isNotEmpty ? streetName : 'đường';

    switch (type) {
      case 'depart':
        return 'Xuất phát';
      case 'arrive':
        return 'Đến nơi';

    // Rẽ
      case 'turn':
        switch (modifier) {
          case 'left': return 'Rẽ trái vào $street';
          case 'right': return 'Rẽ phải vào $street';
          case 'straight': return 'Đi thẳng vào $street';
          case 'uturn': return 'Quay đầu vào $street';
          default: return 'Rẽ vào $street';
        }

    // Đi theo đường
      case 'continue':
        return 'Đi tiếp vào $street';

    // Vào đường cao tốc
      case 'ramp':
        switch (modifier) {
          case 'left': return 'Đi theo lối rẽ trái vào $street';
          case 'right': return 'Đi theo lối rẽ phải vào $street';
          default: return 'Đi theo lối rẽ vào $street';
        }

    // Nhập làn
      case 'merge':
        return 'Nhập làn vào $street';

    // Ra khỏi đường cao tốc
      case 'off ramp':
        return 'Ra khỏi đường cao tốc vào $street';

    // Vòng xoay
      case 'rotary':
        return 'Đi theo vòng xoay vào $street';

      case 'roundabout':
        final exit = modifier.isNotEmpty ? 'và ra ở lối $modifier' : '';
        return 'Đi theo vòng xoay $exit vào $street';

    // Qua ngã tư
      case 'fork':
        switch (modifier) {
          case 'left': return 'Đi theo nhánh trái vào $street';
          case 'right': return 'Đi theo nhánh phải vào $street';
          default: return 'Đi theo nhánh rẽ vào $street';
        }

    // Kết thúc đường
      case 'end of road':
        return 'Đi đến cuối đường vào $street';

      default:
        if (streetName.isNotEmpty) {
          return 'Đi vào $street';
        }
        return 'Tiếp tục đi';
    }
  }
}