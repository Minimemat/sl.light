import 'package:flutter/material.dart';

class Preset {
  final String? id; // WordPress post ID
  final String name;
  final String description;
  final IconData icon;
  final List<String> categories;

  // Core WLED effect parameters
  final int fx;
  final List<String>? colors;
  final int? paletteId;
  final int? sx;
  final int? ix;
  final int? c1;
  final int? c2;
  final int? c3;
  final bool? o1;
  final bool? o2;
  final bool? o3;

  // Global state parameters
  final bool? on; // On/off state
  final int? mainseg; // Main segment ID

  // App-specific metadata
  final String? iconName;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final String? createdBy;
  final String? status; // WordPress post status (publish/private)
  final bool isFavorite; // Whether this preset is favorited by the user

  bool isSelected;

  Preset({
    this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.categories,
    required this.fx,
    this.colors,
    this.paletteId,
    this.sx,
    this.ix,
    this.c1,
    this.c2,
    this.c3,
    this.o1,
    this.o2,
    this.o3,
    this.on,
    this.mainseg,
    this.iconName,
    this.dateCreated,
    this.dateModified,
    this.createdBy,
    this.status,
    this.isFavorite = false,
    this.isSelected = false,
  });

  // Convert to WLED settings format (for device control)
  Map<String, dynamic> toSettings() {
    return {
      'effect': fx,
      if (colors != null && colors!.isNotEmpty) 'colors': colors,
      if (paletteId != null) 'palette': paletteId,
      if (sx != null) 'speed': sx,
      if (ix != null) 'intensity': ix,
      if (c1 != null) 'custom1': c1,
      if (c2 != null) 'custom2': c2,
      if (c3 != null) 'custom3': c3,
      if (o1 != null) 'option1': o1,
      if (o2 != null) 'option2': o2,
      if (o3 != null) 'option3': o3,
      if (on != null) 'on': on,
      if (mainseg != null) 'mainseg': mainseg,
    };
  }

  // Helper method to determine if this preset is user-created
  bool get isUserCreated {
    // Local presets (from database) have IDs starting with 'local_'
    if (id?.startsWith('local_') == true) return false;

    // WordPress presets with private status or created by current user are user-created
    return status == 'private' || (createdBy != null && createdBy!.isNotEmpty);
  }

  // Helper method to determine if this preset can be deleted
  bool get canBeDeleted {
    return isUserCreated;
  }

  // Create a copy with updated properties
  Preset copyWith({
    String? id,
    String? name,
    String? description,
    IconData? icon,
    List<String>? categories,
    int? fx,
    List<String>? colors,
    int? paletteId,
    int? sx,
    int? ix,
    int? c1,
    int? c2,
    int? c3,
    bool? o1,
    bool? o2,
    bool? o3,
    bool? on,
    int? mainseg,
    String? iconName,
    DateTime? dateCreated,
    DateTime? dateModified,
    String? createdBy,
    String? status,
    bool? isFavorite,
    bool? isSelected,
  }) {
    return Preset(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      categories: categories ?? this.categories,
      fx: fx ?? this.fx,
      colors: colors ?? this.colors,
      paletteId: paletteId ?? this.paletteId,
      sx: sx ?? this.sx,
      ix: ix ?? this.ix,
      c1: c1 ?? this.c1,
      c2: c2 ?? this.c2,
      c3: c3 ?? this.c3,
      o1: o1 ?? this.o1,
      o2: o2 ?? this.o2,
      o3: o3 ?? this.o3,
      on: on ?? this.on,
      mainseg: mainseg ?? this.mainseg,
      iconName: iconName ?? this.iconName,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      isFavorite: isFavorite ?? this.isFavorite,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  // Convert to WordPress API format
  Map<String, dynamic> toWordPressJson() {
    return {
      'title': name,
      'content': description,
      'status': status ?? 'private', // Default to private
      'meta': {
        // Core WLED effect parameters
        'fx': fx,
        if (colors != null) 'colors': colors,
        if (paletteId != null) 'palette_id': paletteId,
        if (sx != null) 'sx': sx,
        if (ix != null) 'ix': ix,
        if (c1 != null) 'c1': c1,
        if (c2 != null) 'c2': c2,
        if (c3 != null) 'c3': c3,
        if (o1 != null) 'o1': o1,
        if (o2 != null) 'o2': o2,
        if (o3 != null) 'o3': o3,

        // Global state parameters
        if (on != null) 'on': on,
        if (mainseg != null) 'mainseg': mainseg,

        // App-specific metadata
        'categories': categories,
        if (iconName != null) 'icon_name': iconName,
        'is_favorite': isFavorite,
      },
    };
  }

  // Create from WordPress API response
  factory Preset.fromWordPressJson(Map<String, dynamic> json) {
    final meta = json['meta'] ?? {};
    final title = json['title'];
    final content = json['content'];

    return Preset(
      id: json['id']?.toString(),
      name: title is Map ? title['rendered'] ?? '' : title?.toString() ?? '',
      description: content is Map
          ? content['rendered'] ?? ''
          : content?.toString() ?? '',
      icon: _getIconFromName(meta['icon_name']),
      categories: _parseCategories(meta['categories']),

      // Core WLED effect parameters
      fx: meta['fx'] ?? 0,
      colors: _parseColors(meta['colors']),
      paletteId: meta['palette_id'],
      sx: meta['sx'],
      ix: meta['ix'],
      c1: meta['c1'],
      c2: meta['c2'],
      c3: meta['c3'],
      o1: meta['o1'],
      o2: meta['o2'],
      o3: meta['o3'],

      // Global state parameters
      on: meta['on'],
      mainseg: meta['mainseg'],

      // App-specific metadata
      iconName: meta['icon_name'],
      status: json['status'] ?? 'private',
      dateCreated: json['date'] != null
          ? DateTime.tryParse(json['date'])
          : null,
      dateModified: json['modified'] != null
          ? DateTime.tryParse(json['modified'])
          : null,
      createdBy: json['author']?.toString(),
      isFavorite: meta['is_favorite'] ?? false,
    );
  }

  static IconData _getIconFromName(String? iconName) {
    if (iconName == null) return Icons.lightbulb;

    // Map icon names to IconData
    final iconMap = {
      'color_lens': Icons.color_lens,
      'pattern': Icons.pattern,
      'directions_run': Icons.directions_run,
      'waves': Icons.waves,
      'lightbulb': Icons.lightbulb,
      'power_off': Icons.power_off,
      'local_drink': Icons.local_drink,
      'local_florist': Icons.local_florist,
      'local_fire_department': Icons.local_fire_department,
      'directions_car': Icons.directions_car,
      'cake': Icons.cake,
      'attractions': Icons.attractions,
      'nights_stay': Icons.nights_stay,
      'directions': Icons.directions,
    };

    return iconMap[iconName] ?? Icons.lightbulb;
  }

  static List<String> _parseCategories(dynamic categories) {
    if (categories == null) return ['Other'];
    if (categories is List) return categories.cast<String>();
    if (categories is String) return [categories];
    return ['Other'];
  }

  static List<String>? _parseColors(dynamic colors) {
    if (colors == null) return null;
    if (colors is List) return colors.cast<String>();
    return null;
  }
}
