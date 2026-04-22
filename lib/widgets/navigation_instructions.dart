// lib/widgets/navigation_instructions.dart
import 'package:flutter/material.dart';
import '../models/step_model.dart';

class NavigationInstructions extends StatefulWidget {
  final List<NavigationStep> steps;
  final VoidCallback onStartNavigation;
  final VoidCallback onClose;
  final ValueChanged<bool>? onExpandChanged; // ✅ THÊM CALLBACK

  const NavigationInstructions({
    super.key,
    required this.steps,
    required this.onStartNavigation,
    required this.onClose,
    this.onExpandChanged, // ✅ THÊM
  });

  @override
  State<NavigationInstructions> createState() => _NavigationInstructionsState();
}

class _NavigationInstructionsState extends State<NavigationInstructions>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _heightAnimation;
  final ScrollController _scrollController = ScrollController();
  double _dragStartY = 0;
  double _currentHeight = 0.35;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heightAnimation = Tween<double>(
      begin: 0.35,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    // ✅ GỌI CALLBACK
    widget.onExpandChanged?.call(_isExpanded);
  }

  void _onPanStart(DragStartDetails details) {
    _dragStartY = details.globalPosition.dy;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final screenHeight = MediaQuery.of(context).size.height;
    final delta = details.globalPosition.dy - _dragStartY;
    final deltaPercentage = -delta / screenHeight;

    setState(() {
      _currentHeight = (_currentHeight + deltaPercentage).clamp(0.3, 0.9);
    });
    _dragStartY = details.globalPosition.dy;
  }

  void _onPanEnd(DragEndDetails details) {
    bool newExpandedState;
    if (_currentHeight < 0.5) {
      setState(() {
        _currentHeight = 0.35;
        _isExpanded = false;
      });
      newExpandedState = false;
    } else {
      setState(() {
        _currentHeight = 0.8;
        _isExpanded = true;
      });
      newExpandedState = true;
    }
    // ✅ GỌI CALLBACK
    widget.onExpandChanged?.call(newExpandedState);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: screenWidth,
        height: screenHeight * _currentHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            _buildHeader(isDark),

            // Divider
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(
                height: 1,
                thickness: 1,
                color: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
            ),

            // Instructions
            Expanded(
              child: _currentHeight < 0.5
                  ? _buildSummaryInstructions(isDark)
                  : _buildFullInstructions(isDark),
            ),

            // Start navigation button
            if (_currentHeight < 0.5)
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
                child: ElevatedButton(
                  onPressed: widget.onStartNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9B89FF),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 2,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.navigation, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'BẮT ĐẦU CHỈ ĐƯỜNG',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final totalDistance = widget.steps.fold(0.0, (sum, step) => sum + step.distance) / 1000;
    final totalDuration = widget.steps.fold(0.0, (sum, step) => sum + step.duration) / 60;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF9B89FF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          _currentHeight > 0.5 ? Icons.expand_more : Icons.expand_less,
          color: const Color(0xFF9B89FF),
          size: 20,
        ),
      ),
      title: Text(
        '${_formatDistance(totalDistance)} • ${_formatDuration(totalDuration)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      subtitle: Text(
        '${widget.steps.length} bước',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[500] : Colors.grey[600],
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.close, color: isDark ? Colors.grey[500] : Colors.grey, size: 22),
        onPressed: widget.onClose,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: _toggleExpand,
    );
  }

  Widget _buildSummaryInstructions(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.steps.length > 3 ? 3 : widget.steps.length,
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        return _buildStepTile(step, isDark: isDark, isSummary: true);
      },
    );
  }

  Widget _buildFullInstructions(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.steps.length,
      itemBuilder: (context, index) {
        final step = widget.steps[index];
        return _buildStepTile(step, isDark: isDark);
      },
    );
  }

  Widget _buildStepTile(NavigationStep step, {required bool isDark, bool isSummary = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getManeuverColor(step.maneuver),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getManeuverIcon(step.maneuver),
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Instruction
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: TextStyle(
                    fontSize: isSummary ? 14 : 15,
                    fontWeight: isSummary ? FontWeight.normal : FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: isSummary ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isSummary && step.streetName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      step.streetName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),

          // Distance
          if (step.distance > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _formatDistance(step.distance / 1000),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
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

  Color _getManeuverColor(String? maneuver) {
    switch (maneuver) {
      case 'depart': return Colors.green;
      case 'arrive': return Colors.red;
      case 'turn':
      case 'ramp':
      case 'fork': return Colors.orange;
      case 'continue': return Colors.blue;
      case 'merge': return Colors.purple;
      case 'rotary':
      case 'roundabout': return Colors.teal;
      case 'off ramp': return Colors.indigo;
      case 'end of road': return Colors.brown;
      default: return const Color(0xFF9B89FF);
    }
  }

  String _formatDistance(double km) {
    if (km <= 0) return '';
    if (km < 0.1) {
      return '${(km * 1000).toStringAsFixed(0)}m';
    }
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)}m';
    }
    return '${km.toStringAsFixed(1)}km';
  }

  String _formatDuration(double minutes) {
    if (minutes <= 0) return '';
    if (minutes < 1) {
      return '${(minutes * 60).toStringAsFixed(0)}s';
    }
    if (minutes < 60) {
      return '${minutes.toStringAsFixed(0)}p';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).round();
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h${mins}p';
  }
}