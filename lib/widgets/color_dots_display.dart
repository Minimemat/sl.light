import 'package:flutter/material.dart';

class ColorDotsDisplay extends StatelessWidget {
  final List<String> hexColors;
  final double width;
  final double height;
  final Color borderColor;
  final double dotSize;
  final double horizontalMargin;
  final double verticalMargin;
  final List<Color>? gradientColors;
  final List<double>? gradientStops;

  const ColorDotsDisplay({
    super.key,
    required this.hexColors,
    this.width = 48,
    this.height = 36,
    this.borderColor = Colors.white70,
    this.dotSize = 12,
    this.horizontalMargin = 1,
    this.verticalMargin = 1,
    this.gradientColors,
    this.gradientStops,
  });

  List<int> _hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      try {
        final r = int.parse(hex.substring(0, 2), radix: 16);
        final g = int.parse(hex.substring(2, 4), radix: 16);
        final b = int.parse(hex.substring(4, 6), radix: 16);
        return [r, g, b];
      } catch (_) {}
    }
    return [255, 255, 255];
  }

  @override
  Widget build(BuildContext context) {
    final bool useGradient = (gradientColors != null && gradientColors!.isNotEmpty);
    if (useGradient) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: gradientColors!,
            stops: gradientStops,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      );
    }

    final List<List<int>> colors = (hexColors)
        .take(6)
        .map((hex) {
          final rgb = _hexToRgb(hex);
          return [rgb[0], rgb[1], rgb[2]];
        })
        .toList();

    List<List<int>> topRow;
    List<List<int>> bottomRow;
    if (colors.length <= 3) {
      topRow = colors;
      bottomRow = const [];
    } else if (colors.length == 4) {
      topRow = colors.take(2).toList();
      bottomRow = colors.sublist(2);
    } else {
      topRow = colors.take(3).toList();
      bottomRow = colors.sublist(3);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(topRow.length, (index) {
              final color = topRow[index];
              return Container(
                width: dotSize,
                height: dotSize,
                margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(color[0], color[1], color[2], 1),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
          if (bottomRow.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(bottomRow.length, (index) {
                final color = bottomRow[index];
                return Container(
                  width: dotSize,
                  height: dotSize,
                  margin: EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(color[0], color[1], color[2], 1),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}


