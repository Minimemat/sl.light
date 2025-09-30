import 'package:flutter/material.dart';
import 'dart:math' as math;

class SwiftUIColorPicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;
  final bool showOpacity;
  final ValueChanged<int>? onCctChanged; // Optional: WLED CCT (0-255)

  const SwiftUIColorPicker({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
    this.showOpacity = false,
    this.onCctChanged,
  });

  @override
  State<SwiftUIColorPicker> createState() => _SwiftUIColorPickerState();
}

class _SwiftUIColorPickerState extends State<SwiftUIColorPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _currentColor;
  late HSVColor _currentHSV;
  late double _opacity;
  final List<Color> _customColors = [
    Colors.black,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.red,
  ];
  
  // Temperature mode state
  bool _isTemperatureMode = false;
  int _currentCct = 127; // WLED CCT 0-255 (approx middle)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _currentColor = widget.initialColor;
    _currentHSV = HSVColor.fromColor(widget.initialColor);
    _opacity = widget.initialColor.opacity;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateColor(Color color) {
    setState(() {
      _isTemperatureMode = false; // Exit temperature mode when selecting a regular color
      _currentColor = color;
      _currentHSV = HSVColor.fromColor(color);
      _opacity = color.opacity;
    });
    widget.onColorChanged(color);
  }
  
  void _updateCct(int cct) {
    final int clamped = cct.clamp(0, 255);
    setState(() {
      _isTemperatureMode = true;
      _currentCct = clamped;
      _currentColor = _colorFromCct(clamped);
      _currentHSV = HSVColor.fromColor(_currentColor);
    });
    // Drive WLED native temperature
    if (widget.onCctChanged != null) {
      widget.onCctChanged!(clamped);
    }
  }

  void _updateHSV(HSVColor hsv) {
    setState(() {
      _isTemperatureMode = false; // Exit temperature mode
    });
    final color = hsv.toColor().withOpacity(_opacity);
    _updateColor(color);
  }

  void _updateOpacity(double opacity) {
    setState(() {
      _opacity = opacity;
    });
    final color = _currentColor.withOpacity(opacity);
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 560,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with current color and action buttons
          Container(
            height: 60,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _currentColor.withOpacity(widget.showOpacity ? _opacity : 1.0),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Cancel button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _currentColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
                // Hex code only
                Expanded(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${_currentColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _currentColor.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                // Save button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(_currentColor),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _currentColor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Tab bar
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              indicatorColor: Colors.black,
              tabs: const [
                Tab(text: 'Grid'),
                Tab(text: 'Spectrum'),
                Tab(text: 'Sliders'),
              ],
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGridView(),
                _buildSpectrumView(),
                _buildSlidersView(),
              ],
            ),
          ),
          // Opacity slider (if enabled)
          if (widget.showOpacity) _buildOpacitySlider(),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top grayscale row (white to black)
          SizedBox(
            height: 32,
            child: Row(
              children: List.generate(12, (index) {
                final grayValue = index == 11 ? 0 : 255 - (index * 23); // 255 to 0, last one perfectly black
                final color = Color.fromRGBO(grayValue, grayValue, grayValue, 1);
                final isSelected = color.value == _currentColor.value;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _updateColor(color),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected
                            ? Border.all(color: Colors.blue, width: 2)
                            : Border.all(color: Colors.grey.shade300, width: 0.5),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Main color spectrum grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 12,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 12 * 11, // 12 columns, 11 rows
              itemBuilder: (context, index) {
                final row = index ~/ 12;
                final col = index % 12;
                
                // Hue progression to include true primaries: red(0°), orange(30°), yellow(60°), green(120°), cyan(180°), blue(240°), purple(270°), magenta(300°)
                final hue = (col * 30.0) % 360; // 0° to 330° in 30° steps
                
                // Create brightness and saturation pattern with vibrant middle (11 rows: 0-10)
                double saturation, brightness;
                
                if (row < 3) {
                  // Top rows: lighter/pastel colors (high brightness, medium saturation)
                  brightness = 0.9 + (row * 0.033); // 0.9 to 0.966
                  saturation = 0.25 + (row * 0.15); // 0.25 to 0.55
                } else if (row < 7) {
                  // Middle rows: vibrant colors with true primaries (high brightness, high saturation)
                  brightness = row == 5 ? 1.0 : 0.9; // Peak brightness at row 5 for true colors
                  saturation = row == 5 ? 1.0 : (0.75 + ((5 - row).abs() * 0.05)); // Peak saturation at row 5
                } else {
                  // Bottom rows: darker colors (lower brightness, high saturation)
                  brightness = 0.1 + ((10 - row) * 0.2); // 0.1 to 0.7
                  saturation = 0.9 + ((10 - row) * 0.025); // 0.9 to 1.0
                }
                
                final color = HSVColor.fromAHSV(1.0, hue, saturation, brightness).toColor();
                final isSelected = color.value == _currentColor.value;
                
                return GestureDetector(
                  onTap: () => _updateColor(color),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                      border: isSelected
                          ? Border.all(color: Colors.blue, width: 2)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Bottom preset colors
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ..._customColors.map((color) => _buildPresetColorCircle(color)),
                if (_customColors.length < 8) _buildAddColorButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetColorCircle(Color color) {
    final isSelected = color.value == _currentColor.value;
    return GestureDetector(
      onTap: () => _updateColor(color),
      onLongPress: () => _removeCustomColor(color),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.blue, width: 3)
              : Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddColorButton() {
    return GestureDetector(
      onTap: _addCurrentColor,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Icon(
          Icons.add,
          color: Colors.grey.shade600,
          size: 20,
        ),
      ),
    );
  }

  void _addCurrentColor() {
    if (_customColors.length < 8 && !_customColors.any((c) => c.value == _currentColor.value)) {
      setState(() {
        _customColors.add(_currentColor);
      });
    }
  }

  void _removeCustomColor(Color color) {
    // Don't allow removing if there are only default colors
    if (_customColors.length > 1) {
      setState(() {
        _customColors.remove(color);
      });
    }
  }

  Widget _buildSpectrumView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Color wheel
          Expanded(
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    final center = Offset(110, 110);
                    final offset = details.localPosition - center;
                    final distance = offset.distance;
                    final angle = math.atan2(offset.dy, offset.dx);
                    
                    if (distance <= 110) {
                      final hue = (angle * 180 / math.pi + 360) % 360;
                      final saturation = (distance / 110).clamp(0.0, 1.0);
                      final hsv = HSVColor.fromAHSV(
                        1.0,
                        hue,
                        saturation,
                        _currentHSV.value,
                      );
                      _updateHSV(hsv);
                    }
                  },
                  child: CustomPaint(
                    painter: ColorWheelPainter(_currentHSV),
                    size: const Size(220, 220),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Brightness slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Brightness: ${(_currentHSV.value * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: !_isTemperatureMode ? Colors.grey[900] : Colors.grey[400],
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackShape: _BrightnessSliderTrackShape(),
                  thumbColor: !_isTemperatureMode 
                    ? Color.lerp(Colors.black, Colors.white, _currentHSV.value)
                    : Colors.grey[400],
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                ),
                child: Slider(
                  value: _currentHSV.value,
                  onChanged: (value) {
                    if (_isTemperatureMode) {
                      setState(() {
                        _isTemperatureMode = false;
                      });
                    }
                    final hsv = _currentHSV.withValue(value);
                    _updateHSV(hsv);
                  },
                  label: '${(_currentHSV.value * 100).round()}%',
                  divisions: 100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidersView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildColorSlider('Red', _currentColor.red / 255, Colors.red, (value) {
            _updateColor(Color.fromRGBO(
              (value * 255).round(),
              _currentColor.green,
              _currentColor.blue,
              _opacity,
            ));
          }),
          const SizedBox(height: 12),
          _buildColorSlider('Green', _currentColor.green / 255, Colors.green, (value) {
            _updateColor(Color.fromRGBO(
              _currentColor.red,
              (value * 255).round(),
              _currentColor.blue,
              _opacity,
            ));
          }),
          const SizedBox(height: 12),
          _buildColorSlider('Blue', _currentColor.blue / 255, Colors.blue, (value) {
            _updateColor(Color.fromRGBO(
              _currentColor.red,
              _currentColor.green,
              (value * 255).round(),
              _opacity,
            ));
          }),
          const SizedBox(height: 12),
          _buildHSVSlider('Brightness', _currentHSV.value, (value) {
            final hsv = _currentHSV.withValue(value);
            _updateHSV(hsv);
          }),
          const SizedBox(height: 12),
          // Divider between brightness and temperature controls
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[300],
            ),
          ),
          _buildTemperatureSlider(),
          const SizedBox(height: 12), // Extra bottom padding
        ],
      ),
    );
  }

  Widget _buildColorSlider(String label, double value, Color sliderColor, ValueChanged<double> onChanged) {
    final displayValue = (value * 255).round();
    final isEnabled = !_isTemperatureMode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $displayValue',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isEnabled ? Colors.grey[900] : Colors.grey[400],
          ),
        ),
        Slider(
          value: value,
          onChanged: (newValue) {
            if (_isTemperatureMode) {
              setState(() {
                _isTemperatureMode = false;
              });
            }
            onChanged(newValue);
          }, // Always enabled to allow exiting temperature mode
          activeColor: isEnabled ? sliderColor : Colors.grey[300],
          inactiveColor: isEnabled ? sliderColor.withOpacity(0.3) : Colors.grey[200],
          thumbColor: isEnabled ? sliderColor : Colors.grey[400],
          overlayColor: WidgetStateProperty.all(
            isEnabled ? sliderColor.withOpacity(0.1) : Colors.transparent,
          ),
          divisions: 255,
          label: displayValue.toString(),
        ),
      ],
    );
  }

  Widget _buildHSVSlider(String label, double value, ValueChanged<double> onChanged) {
    String displayValue;
    if (label == 'Hue') {
      displayValue = '${(value * 360).round()}°';
    } else {
      displayValue = '${(value * 100).round()}%';
    }
    
    // Grey out all sliders when in temperature mode
    final isEnabled = !_isTemperatureMode;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: $displayValue',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isEnabled ? Colors.grey[900] : Colors.grey[400],
          ),
        ),
        label == 'Brightness' 
          ? SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: _BrightnessSliderTrackShape(),
                thumbColor: isEnabled ? Color.lerp(Colors.black, Colors.white, value) : Colors.grey[400],
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
              ),
              child: Slider(
                value: value,
                onChanged: (newValue) {
                  if (_isTemperatureMode) {
                    setState(() {
                      _isTemperatureMode = false;
                    });
                  }
                  onChanged(newValue);
                },
                divisions: 100,
                label: displayValue,
              ),
            )
          : Slider(
              value: value,
              onChanged: (newValue) {
                if (_isTemperatureMode) {
                  setState(() {
                    _isTemperatureMode = false;
                  });
                }
                onChanged(newValue);
              },
              activeColor: isEnabled ? _currentColor : Colors.grey[300],
              inactiveColor: isEnabled ? _currentColor.withOpacity(0.3) : Colors.grey[200],
              thumbColor: isEnabled ? _currentColor : Colors.grey[400],
              overlayColor: WidgetStateProperty.all(
                isEnabled ? _currentColor.withOpacity(0.1) : Colors.transparent,
              ),
              divisions: label == 'Hue' ? 360 : 100,
              label: displayValue,
            ),
      ],
    );
  }

  Widget _buildTemperatureSlider() {
    // Use WLED built-in CCT scale (0-255). Keep color preview via mapping.
    final int currentCct = _isTemperatureMode
        ? _currentCct
        : _estimateCctFromColor(_currentColor);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'CCT: $currentCct',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[900],
              ),
            ),
            if (_isTemperatureMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3), width: 1),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            ],
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackShape: _TemperatureSliderTrackShape(),
            thumbColor: _currentColor,
            overlayColor: _currentColor.withOpacity(0.1),
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
          ),
          child: Slider(
            value: currentCct.toDouble(),
            min: 0,
            max: 255,
            onChanged: (value) {
              _updateCct(value.round());
            },
            divisions: 255,
            label: '$currentCct',
          ),
        ),
      ],
    );
  }

  // Calculate approximate color temperature from RGB
  double _calculateTemperatureFromColor(Color color) {
    final r = color.red / 255.0;
    final b = color.blue / 255.0;
    
    // Simple approximation: cooler colors have more blue, warmer have more red
    final ratio = b / (r + 0.01); // Add small value to avoid division by zero
    
    // Map ratio to temperature range (2500K - 5500K)
    if (ratio > 1.0) {
      // More blue than red (cool)
      return 3500 + (ratio - 1.0) * 2000; // Clamped to 5500K max
    } else {
      // More red than blue (warm)
      return 2500 + ratio * 1000; // 2500K to 3500K range
    }
  }

  // Generate color from temperature (simplified black-body radiation approximation)
  Color _colorFromTemperature(double temperature) {
    double r, g, b;
    
    // Simplified temperature to RGB conversion for 2500K-5500K range
    if (temperature <= 3000) {
      // Warm (reddish) - 2500K to 3000K
      r = 255;
      g = 138 + (temperature - 2500) * 0.234; // 138 to 255
      b = 18 + (temperature - 2500) * 0.194;  // 18 to 115
    } else if (temperature <= 4000) {
      // Neutral-warm - 3000K to 4000K
      r = 255 - (temperature - 3000) * 0.0255; // 255 to 229
      g = 255;
      b = 115 + (temperature - 3000) * 0.14;   // 115 to 255
    } else {
      // Cool (bluish) - 4000K to 5500K
      r = 229 - (temperature - 4000) * 0.043;  // 229 to 165
      g = 255 - (temperature - 4000) * 0.027;  // 255 to 215
      b = 255;
    }
    
    return Color.fromRGBO(
      r.clamp(0, 255).round(),
      g.clamp(0, 255).round(),
      b.clamp(0, 255).round(),
      _opacity,
    );
  }

  // Approximate preview color from WLED CCT value using a 2500K-5500K mapping
  Color _colorFromCct(int cct) {
    // Map 0-255 -> 2500K-5500K for preview only
    final double kelvin = 2500.0 + (cct.clamp(0, 255) * (5500.0 - 2500.0) / 255.0);
    return _colorFromTemperature(kelvin);
  }

  // Roughly estimate a CCT value from current RGB for initializing the slider
  int _estimateCctFromColor(Color color) {
    // Use existing temperature estimator then map back into 0-255 range
    final double kelvin = _calculateTemperatureFromColor(color).clamp(2500.0, 5500.0);
    final double cct = ((kelvin - 2500.0) * 255.0 / (5500.0 - 2500.0));
    return cct.round().clamp(0, 255);
  }

  Widget _buildOpacitySlider() {
    final displayValue = (_opacity * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opacity: $displayValue%',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Slider(
            value: _opacity,
            onChanged: _updateOpacity,
            activeColor: Colors.black,
            inactiveColor: Colors.grey.shade300,
            thumbColor: Colors.black,
            overlayColor: WidgetStateProperty.all(Colors.black.withOpacity(0.1)),
            divisions: 100,
            label: '$displayValue%',
          ),
        ],
      ),
    );
  }


}

class ColorWheelPainter extends CustomPainter {
  final HSVColor currentHSV;

  ColorWheelPainter(this.currentHSV);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw color wheel
    for (int i = 0; i < 360; i++) {
      final hue = i.toDouble();
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            HSVColor.fromAHSV(1.0, hue, 0.0, currentHSV.value).toColor(),
            HSVColor.fromAHSV(1.0, hue, 1.0, currentHSV.value).toColor(),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      final startAngle = (i - 1) * math.pi / 180;
      final endAngle = i * math.pi / 180;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        true,
        paint,
      );
    }

    // Draw current color indicator
    final currentAngle = currentHSV.hue * math.pi / 180;
    final indicatorRadius = currentHSV.saturation * radius;
    final indicatorCenter = Offset(
      center.dx + indicatorRadius * math.cos(currentAngle),
      center.dy + indicatorRadius * math.sin(currentAngle),
    );

    canvas.drawCircle(
      indicatorCenter,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      indicatorCenter,
      8,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TemperatureSliderTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Create temperature gradient from warm (2500K) to cool (5500K)
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        _colorFromTemperature(2500.0), // Warm (reddish)
        _colorFromTemperature(3000.0), // Warm-neutral
        _colorFromTemperature(3500.0), // Neutral-warm
        _colorFromTemperature(4500.0), // Neutral
        _colorFromTemperature(5500.0), // Cool (bluish)
      ],
      stops: const [0.0, 0.2, 0.4, 0.7, 1.0], // Non-linear: closer spacing at ends
    );

    final paint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..style = PaintingStyle.fill;

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(2)),
      paint,
    );
  }

  // Generate color from temperature (simplified black-body radiation approximation)
  Color _colorFromTemperature(double temperature) {
    double r, g, b;
    
    // Simplified temperature to RGB conversion for 2500K-5500K range
    if (temperature <= 3000) {
      // Warm (reddish) - 2500K to 3000K
      r = 255;
      g = 138 + (temperature - 2500) * 0.234; // 138 to 255
      b = 18 + (temperature - 2500) * 0.194;  // 18 to 115
    } else if (temperature <= 4000) {
      // Neutral-warm - 3000K to 4000K
      r = 255 - (temperature - 3000) * 0.0255; // 255 to 229
      g = 255;
      b = 115 + (temperature - 3000) * 0.14;   // 115 to 255
    } else {
      // Cool (bluish) - 4000K to 5500K
      r = 229 - (temperature - 4000) * 0.043;  // 229 to 165
      g = 255 - (temperature - 4000) * 0.027;  // 255 to 215
      b = 255;
    }
    
    return Color.fromRGBO(
      r.clamp(0, 255).round(),
      g.clamp(0, 255).round(),
      b.clamp(0, 255).round(),
      1.0,
    );
  }
}

class _BrightnessSliderTrackShape extends SliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final double trackHeight = sliderTheme.trackHeight ?? 4.0;
    final double trackLeft = offset.dx;
    final double trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // Create brightness gradient from black to white
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: const [
        Colors.black,
        Colors.white,
      ],
    );

    final paint = Paint()
      ..shader = gradient.createShader(trackRect)
      ..style = PaintingStyle.fill;

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(2)),
      paint,
    );
  }
} 