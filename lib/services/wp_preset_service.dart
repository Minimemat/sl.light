import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/preset.dart';
import '../utils/constants.dart';

class WPPresetService {
  /// Fetch all presets from WordPress
  /// Returns user's own presets + public presets from others
  Future<List<Preset>> getPresets({String? jwt}) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};

      // Add JWT token if provided for authenticated requests
      if (jwt != null) {
        headers['Authorization'] = 'Bearer $jwt';
      }

      final response = await http.get(
        Uri.parse('$wledPresetsUrl?per_page=100'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final presets = data.map((e) => Preset.fromWordPressJson(e)).toList();

        print('Fetched ${presets.length} presets from WordPress');
        return presets;
      } else {
        print(
          'Failed to fetch presets: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to fetch presets: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching presets: $e');
      throw Exception('Failed to fetch presets: $e');
    }
  }

  /// Get presets by category
  Future<List<Preset>> getPresetsByCategory(
    String category, {
    String? jwt,
  }) async {
    final allPresets = await getPresets(jwt: jwt);

    if (category == 'All') {
      return allPresets;
    }

    return allPresets
        .where((preset) => preset.categories.contains(category))
        .toList();
  }

  /// Create a new preset (for future use when users can create presets)
  Future<Preset> createPreset(String jwt, Preset preset) async {
    try {
      final response = await http.post(
        Uri.parse(wledPresetsUrl),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(preset.toWordPressJson()),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Preset.fromWordPressJson(data);
      } else {
        print(
          'Failed to create preset: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to create preset: ${response.statusCode}');
      }
    } catch (e) {
      print('Error creating preset: $e');
      throw Exception('Failed to create preset: $e');
    }
  }

  /// Update an existing preset
  Future<Preset> updatePreset(String jwt, Preset preset) async {
    if (preset.id == null) {
      throw Exception('Preset ID is required for updates');
    }

    try {
      final response = await http.post(
        Uri.parse('$wledPresetsUrl/${preset.id}'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(preset.toWordPressJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Preset.fromWordPressJson(data);
      } else {
        print(
          'Failed to update preset: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to update preset: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating preset: $e');
      throw Exception('Failed to update preset: $e');
    }
  }

  /// Delete a preset
  Future<void> deletePreset(String jwt, String presetId) async {
    try {
      final response = await http.delete(
        Uri.parse('$wledPresetsUrl/$presetId?force=true'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        print(
          'Failed to delete preset: ${response.statusCode} ${response.body}',
        );
        throw Exception('Failed to delete preset: ${response.statusCode}');
      }
    } catch (e) {
      print('Error deleting preset: $e');
      throw Exception('Failed to delete preset: $e');
    }
  }

  /// Make a preset public (share it)
  Future<Preset> sharePreset(String jwt, Preset preset) async {
    final sharedPreset = preset.copyWith(status: 'publish');
    return await updatePreset(jwt, sharedPreset);
  }

  /// Make a preset private (unshare it)
  Future<Preset> unsharePreset(String jwt, Preset preset) async {
    final privatePreset = preset.copyWith(status: 'private');
    return await updatePreset(jwt, privatePreset);
  }

  /// Mark a preset as deleted (move to "Deleted" category)
  Future<Preset> markAsDeleted(String jwt, Preset preset) async {
    final deletedCategories = List<String>.from(preset.categories);
    if (!deletedCategories.contains('Deleted')) {
      deletedCategories.add('Deleted');
    }
    final deletedPreset = preset.copyWith(categories: deletedCategories);
    return await updatePreset(jwt, deletedPreset);
  }

  /// Toggle favorite status of a preset
  Future<Preset> toggleFavorite(String jwt, Preset preset) async {
    final updatedPreset = preset.copyWith(isFavorite: !preset.isFavorite);
    return await updatePreset(jwt, updatedPreset);
  }

  /// Batch upload presets (for migration)
  Future<List<Preset>> uploadPresets(
    String jwt,
    List<Preset> presets, {
    bool makePublic = true,
  }) async {
    final uploadedPresets = <Preset>[];

    print('Starting batch upload of ${presets.length} presets...');

    for (int i = 0; i < presets.length; i++) {
      try {
        final preset = presets[i];

        // Convert icon to icon name for WordPress
        final iconName = _getIconName(preset.icon);

        // Create preset with proper metadata
        final presetToUpload = preset.copyWith(
          status: makePublic ? 'publish' : 'private',
          iconName: iconName,
          // Set default values for missing WordPress fields
          on: preset.on ?? true,
          mainseg: preset.mainseg ?? 0,
        );

        final uploaded = await createPreset(jwt, presetToUpload);
        uploadedPresets.add(uploaded);

        print('Uploaded preset ${i + 1}/${presets.length}: ${preset.name}');

        // Small delay to avoid overwhelming the server
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        print('Failed to upload preset ${presets[i].name}: $e');
        // Continue with next preset instead of failing completely
      }
    }

    print(
      'Batch upload completed. ${uploadedPresets.length}/${presets.length} presets uploaded successfully.',
    );
    return uploadedPresets;
  }

  /// Convert IconData to string name for WordPress storage
  String _getIconName(IconData icon) {
    final iconMap = {
      Icons.color_lens.codePoint: 'color_lens',
      Icons.pattern.codePoint: 'pattern',
      Icons.directions_run.codePoint: 'directions_run',
      Icons.waves.codePoint: 'waves',
      Icons.lightbulb.codePoint: 'lightbulb',
      Icons.power_off.codePoint: 'power_off',
      Icons.local_drink.codePoint: 'local_drink',
      Icons.local_florist.codePoint: 'local_florist',
      Icons.local_fire_department.codePoint: 'local_fire_department',
      Icons.directions_car.codePoint: 'directions_car',
      Icons.cake.codePoint: 'cake',
      Icons.attractions.codePoint: 'attractions',
      Icons.nights_stay.codePoint: 'nights_stay',
      Icons.directions.codePoint: 'directions',
    };

    return iconMap[icon.codePoint] ?? 'lightbulb';
  }
}
