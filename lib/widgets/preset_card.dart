import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/preset.dart';
import '../data/effects_database.dart';
import '../data/palettes_database.dart';
import 'color_dots_display.dart';

class PresetCard extends StatelessWidget {
  final Preset preset;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onShare;
  final VoidCallback? onDelete;

  const PresetCard({
    super.key,
    required this.preset,
    required this.onTap,
    this.onFavoriteToggle,
    this.onShare,
    this.onDelete,
  });

  Map<String, dynamic> _getEffectById(int fxId) {
    return EffectsDatabase.effectsDatabase.firstWhere(
      (e) => e['id'] == fxId,
      orElse: () => {
        'name': 'Unknown',
        'flags': [],
        'colors': [],
        'parameters': [],
      },
    );
  }

  Map<String, dynamic> _getPaletteById(
    int paletteId,
    List<Map<String, dynamic>> palettes,
  ) {
    return palettes.firstWhere(
      (p) => p['id'] == paletteId,
      orElse: () => {'name': 'Unknown', 'colors': []},
    );
  }

  // Helper function to decode HTML entities
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rdquo;', '"')
        .replaceAll('&ldquo;', '"')
        .replaceAll('&#215;', '×')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&nbsp;', ' ')
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }

  @override
  Widget build(BuildContext context) {
    final effect = _getEffectById(preset.fx);
    final effectColors = (effect['colors'] as List<dynamic>?) ?? [];
    final presetColors = preset.colors ?? [];
    final paletteId = preset.paletteId ?? 0;
    final bool isCustomPattern = preset.categories.contains('Custom Pattern');

    // Ensure presetColors has at least 3 entries (non-custom-pattern only)
    List<String> paddedColors = List.from(presetColors);
    if (!isCustomPattern) {
      while (paddedColors.length < 3) {
        paddedColors.add('000000');
      }
    }

    // Convert hex colors to RGB format for consistency
    List<List<int>> rgbColors = paddedColors.map((hex) {
      final rgb = _hexToRgb(hex);
      return [rgb[0], rgb[1], rgb[2]];
    }).toList();

    // Update palettes with selected colors
    final updatedPalettes = PalettesDatabase.updatePalettesWithSelectedColors(
      rgbColors,
    );
    final palette = preset.paletteId != null
        ? _getPaletteById(preset.paletteId!, updatedPalettes)
        : null;
    final paletteColors = palette != null
        ? (palette['colors'] as List<dynamic>?) ?? []
        : [];

    // Determine the number of colors to show and swatch details
    int numColorsToShow;
    List<String> swatchLabels = [];
    List<List<int>> swatchColors = [];
    if ([2, 3, 4, 5].contains(paletteId)) {
      if (paletteId == 2) {
        // Color 1
        numColorsToShow = 1;
        swatchLabels = ['Fx'];
        swatchColors = [rgbColors[0]];
      } else if (paletteId == 3) {
        // Colors 1&2
        numColorsToShow = 2;
        swatchLabels = ['Fx', 'Bg'];
        swatchColors = [rgbColors[0], rgbColors[1]];
      } else {
        // Color Gradient (4), Colors Only (5)
        numColorsToShow = 3;
        swatchLabels = ['Fx', 'Bg', 'Cs'];
        swatchColors = [rgbColors[0], rgbColors[1], rgbColors[2]];
      }
    } else {
      numColorsToShow = effectColors.where((c) => c != 'Pal').length;
      swatchLabels = effectColors
          .where((c) => c != 'Pal')
          .toList()
          .cast<String>();
      swatchColors = List.generate(numColorsToShow, (index) {
        final colorIdx =
            {
              'Fx': 0,
              'Bg': 1,
              'Cs': 2,
              '1': 0,
              '2': 1,
              '3': 2,
              'Fg': 0,
            }[swatchLabels[index]] ??
            0;
        return rgbColors[colorIdx];
      });
    }

    // Determine if we should show the palette gradient
    final showPaletteGradient = paletteId != 0 && paletteColors.isNotEmpty;

    // Build the color display widget
    Widget colorDisplay;
    if (isCustomPattern) {
      colorDisplay = ColorDotsDisplay(
        hexColors: preset.colors ?? const [],
        width: 48,
        height: 36,
        borderColor: preset.isSelected ? Colors.white : Colors.white70,
        dotSize: 12,
        horizontalMargin: 1,
        verticalMargin: 1,
      );
    } else {
      colorDisplay = Container(
        width: 48,
        height: 24,
        decoration: BoxDecoration(
          border: Border.all(
            color: preset.isSelected ? Colors.white : Colors.white70,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          gradient: showPaletteGradient
              ? LinearGradient(
                  colors: paletteColors.map<Color>((c) {
                    final rgb = (c['color'] as String)
                        .replaceAll(RegExp(r'rgb\(|\)'), '')
                        .split(',')
                        .map(int.parse)
                        .toList();
                    return Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1);
                  }).toList(),
                  stops: paletteColors
                      .map<double>((c) => (c['stop'] as num) / 100)
                      .toList(),
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
        ),
        child: !showPaletteGradient
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  numColorsToShow > 3 ? 3 : numColorsToShow,
                  (index) {
                    final color = swatchColors[index];
                    return Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(color[0], color[1], color[2], 1),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              )
            : null,
      );
    }

    // Determine card color based on user-created status
    Color cardColor;
    if (preset.isSelected) {
      cardColor = Theme.of(context).colorScheme.primary;
    } else if (preset.isUserCreated) {
      // Brighter shade for user-created presets
      cardColor = Theme.of(context).cardColor.withOpacity(0.9);
    } else {
      cardColor = Theme.of(context).cardColor;
    }

    return Card(
      elevation: preset.isSelected ? 8.0 : 2.0,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: preset.isUserCreated
            ? const BorderSide(color: Colors.black, width: 1.0)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Color display on the left
              colorDisplay,
              const SizedBox(width: 16),
              // Text content in the middle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _decodeHtmlEntities(preset.name),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: preset.isSelected ? Colors.white : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Effect: ${effect['name']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: preset.isSelected
                            ? Colors.white70
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Favorites button
              IconButton(
                icon: Icon(
                  preset.isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: preset.isFavorite
                      ? Colors.red
                      : (preset.isSelected ? Colors.white70 : Colors.white70),
                ),
                onPressed: onFavoriteToggle,
                tooltip: preset.isFavorite
                    ? 'Remove from favorites'
                    : 'Add to favorites',
              ),
              // 3-dot menu
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: preset.isSelected ? Colors.white70 : Colors.white70,
                ),
                onSelected: (String value) {
                  switch (value) {
                    case 'share':
                      _sharePreset();
                      break;
                    case 'delete':
                      onDelete?.call();
                      break;
                  }
                },
                itemBuilder: (BuildContext context) {
                  final items = <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, size: 20),
                          SizedBox(width: 8),
                          Text('Share'),
                        ],
                      ),
                    ),
                  ];

                  // Only show delete option for user-created presets
                  if (preset.canBeDeleted) {
                    items.add(
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    );
                  }

                  return items;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Share preset by copying name to clipboard
  void _sharePreset() {
    Clipboard.setData(ClipboardData(text: preset.name));
    // Note: We can't show a SnackBar here since we don't have access to context
    // The parent widget should handle showing feedback
    onShare?.call();
  }

  // Helper function to convert hex to RGB
  List<int> _hexToRgb(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      try {
        final r = int.parse(hex.substring(0, 2), radix: 16);
        final g = int.parse(hex.substring(2, 4), radix: 16);
        final b = int.parse(hex.substring(4, 6), radix: 16);
        return [r, g, b, 0];
      } catch (e) {
        return [255, 255, 255, 0];
      }
    }
    return [255, 255, 255, 0];
  }
}
