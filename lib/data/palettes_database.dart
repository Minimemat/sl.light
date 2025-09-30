// palettes_database.dart
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PalettesDatabase {
  static const List<Map<String, dynamic>> palettesDatabase = [
    // Standard palettes from WLED documentation (IDs 0-70)
    {
      'id': 0,
      'name': 'Default',
      'description': 'The palette is automatically selected depending on the effect. For most effects, this is the primary color.',
      'colors': [
        {'color': 'rgb(85, 0, 171)', 'stop': 0},
        {'color': 'rgb(132, 0, 124)', 'stop': 6},
        {'color': 'rgb(181, 0, 75)', 'stop': 13},
        {'color': 'rgb(229, 0, 27)', 'stop': 19},
        {'color': 'rgb(232, 23, 0)', 'stop': 25},
        {'color': 'rgb(184, 71, 0)', 'stop': 31},
        {'color': 'rgb(171, 119, 0)', 'stop': 38},
        {'color': 'rgb(171, 171, 0)', 'stop': 44},
        {'color': 'rgb(171, 85, 0)', 'stop': 50},
        {'color': 'rgb(221, 34, 0)', 'stop': 56},
        {'color': 'rgb(242, 0, 14)', 'stop': 63},
        {'color': 'rgb(194, 0, 62)', 'stop': 69},
        {'color': 'rgb(143, 0, 113)', 'stop': 75},
        {'color': 'rgb(95, 0, 161)', 'stop': 82},
        {'color': 'rgb(47, 0, 208)', 'stop': 88},
        {'color': 'rgb(0, 7, 249)', 'stop': 94},
      ],
    },
    {
      'id': 1,
      'name': 'Random Cycle',
      'description': 'The palette changes to a random one every few seconds. Subject to change.',
      'colors': [
        {'color': 'rgb(156, 112, 171)', 'stop': 0},
        {'color': 'rgb(5, 123, 189)', 'stop': 25},
        {'color': 'rgb(221, 125, 219)', 'stop': 50},
        {'color': 'rgb(92, 242, 235)', 'stop': 75},
      ],
    },
    {
      'id': 2,
      'name': 'Color 1',
      'description': 'A palette consisting only of the primary color.',
      'colors': [
        {'color': 'rgb(255, 0, 0)', 'stop': 0},
        {'color': 'rgb(255, 0, 0)', 'stop': 50},
      ],
    },
    {
      'id': 3,
      'name': 'Colors 1&2',
      'description': 'Consists of the primary and secondary color.',
      'colors': [
        {'color': 'rgb(255, 0, 0)', 'stop': 0},
        {'color': 'rgb(255, 0, 0)', 'stop': 25},
        {'color': 'rgb(8, 255, 0)', 'stop': 50},
        {'color': 'rgb(8, 255, 0)', 'stop': 75},
      ],
    },
    {
      'id': 4,
      'name': 'Color Gradient',
      'description': 'A palette which is a mixture of all segment colors.',
      'colors': [
        {'color': 'rgb(0, 0, 255)', 'stop': 0},
        {'color': 'rgb(8, 255, 0)', 'stop': 33},
        {'color': 'rgb(255, 0, 0)', 'stop': 67},
      ],
    },
    {
      'id': 5,
      'name': 'Colors Only',
      'description': 'Contains primary, secondary and tertiary colors.',
      'colors': [
        {'color': 'rgb(255, 0, 0)', 'stop': 0},
        {'color': 'rgb(255, 0, 0)', 'stop': 6},
        {'color': 'rgb(255, 0, 0)', 'stop': 13},
        {'color': 'rgb(255, 0, 0)', 'stop': 19},
        {'color': 'rgb(255, 0, 0)', 'stop': 25},
        {'color': 'rgb(8, 255, 0)', 'stop': 31},
        {'color': 'rgb(8, 255, 0)', 'stop': 38},
        {'color': 'rgb(8, 255, 0)', 'stop': 44},
        {'color': 'rgb(8, 255, 0)', 'stop': 50},
        {'color': 'rgb(8, 255, 0)', 'stop': 56},
        {'color': 'rgb(0, 0, 255)', 'stop': 63},
        {'color': 'rgb(0, 0, 255)', 'stop': 69},
        {'color': 'rgb(0, 0, 255)', 'stop': 75},
        {'color': 'rgb(0, 0, 255)', 'stop': 81},
        {'color': 'rgb(0, 0, 255)', 'stop': 88},
        {'color': 'rgb(255, 0, 0)', 'stop': 94},
      ],
    },
    {
      'id': 6,
      'name': 'Party',
      'description': 'Rainbow without green hues.',
      'colors': [
        {'color': 'rgb(85, 0, 171)', 'stop': 0},
        {'color': 'rgb(132, 0, 124)', 'stop': 6},
        {'color': 'rgb(181, 0, 75)', 'stop': 13},
        {'color': 'rgb(229, 0, 27)', 'stop': 19},
        {'color': 'rgb(232, 23, 0)', 'stop': 25},
        {'color': 'rgb(184, 71, 0)', 'stop': 31},
        {'color': 'rgb(171, 119, 0)', 'stop': 38},
        {'color': 'rgb(171, 171, 0)', 'stop': 44},
        {'color': 'rgb(171, 85, 0)', 'stop': 50},
        {'color': 'rgb(221, 34, 0)', 'stop': 56},
        {'color': 'rgb(242, 0, 14)', 'stop': 63},
        {'color': 'rgb(194, 0, 62)', 'stop': 69},
        {'color': 'rgb(143, 0, 113)', 'stop': 75},
        {'color': 'rgb(95, 0, 161)', 'stop': 82},
        {'color': 'rgb(47, 0, 208)', 'stop': 88},
        {'color': 'rgb(0, 7, 249)', 'stop': 94},
      ],
    },
    {
      'id': 7,
      'name': 'Cloud',
      'description': 'Gray-blueish colors.',
      'colors': [
        {'color': 'rgb(0, 0, 255)', 'stop': 0},
        {'color': 'rgb(0, 0, 139)', 'stop': 6},
        {'color': 'rgb(0, 0, 139)', 'stop': 13},
        {'color': 'rgb(0, 0, 139)', 'stop': 19},
        {'color': 'rgb(0, 0, 139)', 'stop': 25},
        {'color': 'rgb(0, 0, 139)', 'stop': 31},
        {'color': 'rgb(0, 0, 139)', 'stop': 38},
        {'color': 'rgb(0, 0, 139)', 'stop': 44},
        {'color': 'rgb(0, 0, 255)', 'stop': 50},
        {'color': 'rgb(0, 0, 139)', 'stop': 56},
        {'color': 'rgb(135, 206, 235)', 'stop': 63},
        {'color': 'rgb(135, 206, 235)', 'stop': 69},
        {'color': 'rgb(173, 216, 230)', 'stop': 75},
        {'color': 'rgb(255, 255, 255)', 'stop': 82},
        {'color': 'rgb(173, 216, 230)', 'stop': 88},
        {'color': 'rgb(135, 206, 235)', 'stop': 94},
      ],
    },
    {
      'id': 8,
      'name': 'Lava',
      'description': 'Dark red, yellow and bright white.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(128, 0, 0)', 'stop': 6},
        {'color': 'rgb(0, 0, 0)', 'stop': 13},
        {'color': 'rgb(128, 0, 0)', 'stop': 19},
        {'color': 'rgb(139, 0, 0)', 'stop': 25},
        {'color': 'rgb(139, 0, 0)', 'stop': 31},
        {'color': 'rgb(128, 0, 0)', 'stop': 38},
        {'color': 'rgb(139, 0, 0)', 'stop': 44},
        {'color': 'rgb(139, 0, 0)', 'stop': 50},
        {'color': 'rgb(139, 0, 0)', 'stop': 56},
        {'color': 'rgb(255, 0, 0)', 'stop': 63},
        {'color': 'rgb(255, 165, 0)', 'stop': 69},
        {'color': 'rgb(255, 255, 255)', 'stop': 75},
        {'color': 'rgb(255, 165, 0)', 'stop': 82},
        {'color': 'rgb(255, 0, 0)', 'stop': 88},
        {'color': 'rgb(139, 0, 0)', 'stop': 94},
      ],
    },
    {
      'id': 9,
      'name': 'Ocean',
      'description': 'Blue, teal and white colors.',
      'colors': [
        {'color': 'rgb(25, 25, 112)', 'stop': 0},
        {'color': 'rgb(0, 0, 139)', 'stop': 6},
        {'color': 'rgb(25, 25, 112)', 'stop': 13},
        {'color': 'rgb(0, 0, 128)', 'stop': 19},
        {'color': 'rgb(0, 0, 139)', 'stop': 25},
        {'color': 'rgb(0, 0, 205)', 'stop': 31},
        {'color': 'rgb(46, 139, 87)', 'stop': 38},
        {'color': 'rgb(0, 128, 128)', 'stop': 44},
        {'color': 'rgb(95, 158, 160)', 'stop': 50},
        {'color': 'rgb(0, 0, 255)', 'stop': 56},
        {'color': 'rgb(0, 139, 139)', 'stop': 63},
        {'color': 'rgb(100, 149, 237)', 'stop': 69},
        {'color': 'rgb(127, 255, 212)', 'stop': 75},
        {'color': 'rgb(46, 139, 87)', 'stop': 82},
        {'color': 'rgb(0, 255, 255)', 'stop': 88},
        {'color': 'rgb(135, 206, 250)', 'stop': 94},
      ],
    },
    {
      'id': 10,
      'name': 'Forest',
      'description': 'Yellow and green hues.',
      'colors': [
        {'color': 'rgb(0, 100, 0)', 'stop': 0},
        {'color': 'rgb(0, 100, 0)', 'stop': 6},
        {'color': 'rgb(85, 107, 47)', 'stop': 13},
        {'color': 'rgb(0, 100, 0)', 'stop': 19},
        {'color': 'rgb(0, 128, 0)', 'stop': 25},
        {'color': 'rgb(34, 139, 34)', 'stop': 31},
        {'color': 'rgb(107, 142, 35)', 'stop': 38},
        {'color': 'rgb(0, 128, 0)', 'stop': 44},
        {'color': 'rgb(46, 139, 87)', 'stop': 50},
        {'color': 'rgb(102, 205, 170)', 'stop': 56},
        {'color': 'rgb(50, 205, 50)', 'stop': 63},
        {'color': 'rgb(154, 205, 50)', 'stop': 69},
        {'color': 'rgb(144, 238, 144)', 'stop': 75},
        {'color': 'rgb(124, 252, 0)', 'stop': 82},
        {'color': 'rgb(102, 205, 170)', 'stop': 88},
        {'color': 'rgb(34, 139, 34)', 'stop': 94},
      ],
    },
    {
      'id': 11,
      'name': 'Rainbow',
      'description': 'Every hue.',
      'colors': [
        {'color': 'rgb(255, 0, 0)', 'stop': 0},
        {'color': 'rgb(213, 42, 0)', 'stop': 6},
        {'color': 'rgb(171, 85, 0)', 'stop': 13},
        {'color': 'rgb(171, 127, 0)', 'stop': 19},
        {'color': 'rgb(171, 171, 0)', 'stop': 25},
        {'color': 'rgb(86, 213, 0)', 'stop': 31},
        {'color': 'rgb(0, 255, 0)', 'stop': 38},
        {'color': 'rgb(0, 213, 42)', 'stop': 44},
        {'color': 'rgb(0, 171, 85)', 'stop': 50},
        {'color': 'rgb(0, 86, 170)', 'stop': 56},
        {'color': 'rgb(0, 0, 255)', 'stop': 63},
        {'color': 'rgb(42, 0, 213)', 'stop': 69},
        {'color': 'rgb(85, 0, 171)', 'stop': 75},
        {'color': 'rgb(127, 0, 129)', 'stop': 82},
        {'color': 'rgb(171, 0, 85)', 'stop': 88},
        {'color': 'rgb(213, 0, 43)', 'stop': 94},
      ],
    },
    {
      'id': 12,
      'name': 'Rainbow Bands',
      'description': 'Rainbow colors with black spots in-between.',
      'colors': [
        {'color': 'rgb(255, 0, 0)', 'stop': 0},
        {'color': 'rgb(0, 0, 0)', 'stop': 6},
        {'color': 'rgb(171, 85, 0)', 'stop': 13},
        {'color': 'rgb(0, 0, 0)', 'stop': 19},
        {'color': 'rgb(171, 171, 0)', 'stop': 25},
        {'color': 'rgb(0, 0, 0)', 'stop': 31},
        {'color': 'rgb(0, 255, 0)', 'stop': 38},
        {'color': 'rgb(0, 0, 0)', 'stop': 44},
        {'color': 'rgb(0, 171, 85)', 'stop': 50},
        {'color': 'rgb(0, 0, 0)', 'stop': 56},
        {'color': 'rgb(0, 0, 255)', 'stop': 63},
        {'color': 'rgb(0, 0, 0)', 'stop': 69},
        {'color': 'rgb(85, 0, 171)', 'stop': 75},
        {'color': 'rgb(0, 0, 0)', 'stop': 82},
        {'color': 'rgb(171, 0, 85)', 'stop': 88},
        {'color': 'rgb(0, 0, 0)', 'stop': 94},
      ],
    },
    {
      'id': 13,
      'name': 'Sunset',
      'description': 'Dark blue with purple, red and yellow hues.',
      'colors': [
        {'color': 'rgb(120, 0, 0)', 'stop': 0},
        {'color': 'rgb(179, 22, 0)', 'stop': 9},
        {'color': 'rgb(255, 104, 0)', 'stop': 20},
        {'color': 'rgb(167, 22, 18)', 'stop': 33},
        {'color': 'rgb(100, 0, 103)', 'stop': 53},
        {'color': 'rgb(16, 0, 130)', 'stop': 78},
        {'color': 'rgb(0, 0, 160)', 'stop': 100},
      ],
    },
    {
      'id': 14,
      'name': 'Rivendell',
      'description': 'Desaturated greens.',
      'colors': [
        {'color': 'rgb(1, 14, 5)', 'stop': 0},
        {'color': 'rgb(16, 36, 14)', 'stop': 40},
        {'color': 'rgb(56, 68, 30)', 'stop': 65},
        {'color': 'rgb(150, 156, 99)', 'stop': 95},
        {'color': 'rgb(150, 156, 99)', 'stop': 100},
      ],
    },
    {
      'id': 15,
      'name': 'Breeze',
      'description': 'Teal colors with varying brightness.',
      'colors': [
        {'color': 'rgb(1, 6, 7)', 'stop': 0},
        {'color': 'rgb(1, 99, 111)', 'stop': 35},
        {'color': 'rgb(144, 209, 255)', 'stop': 60},
        {'color': 'rgb(0, 73, 82)', 'stop': 100},
      ],
    },
    {
      'id': 16,
      'name': 'Red & Blue',
      'description': 'Red running on blue.',
      'colors': [
        {'color': 'rgb(4, 1, 70)', 'stop': 0},
        {'color': 'rgb(55, 1, 30)', 'stop': 12},
        {'color': 'rgb(255, 4, 7)', 'stop': 25},
        {'color': 'rgb(59, 2, 29)', 'stop': 37},
        {'color': 'rgb(11, 3, 50)', 'stop': 50},
        {'color': 'rgb(39, 8, 60)', 'stop': 62},
        {'color': 'rgb(112, 19, 40)', 'stop': 75},
        {'color': 'rgb(78, 11, 39)', 'stop': 87},
        {'color': 'rgb(29, 8, 59)', 'stop': 100},
      ],
    },
    {
      'id': 17,
      'name': 'Yellowout',
      'description': 'Yellow, fading out.',
      'colors': [
        {'color': 'rgb(188, 135, 1)', 'stop': 0},
        {'color': 'rgb(46, 7, 1)', 'stop': 100},
      ],
    },
    {
      'id': 18,
      'name': 'Analogous',
      'description': 'Red running on blue.',
      'colors': [
        {'color': 'rgb(3, 0, 255)', 'stop': 0},
        {'color': 'rgb(23, 0, 255)', 'stop': 25},
        {'color': 'rgb(67, 0, 255)', 'stop': 50},
        {'color': 'rgb(142, 0, 45)', 'stop': 75},
        {'color': 'rgb(255, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 19,
      'name': 'Splash',
      'description': 'Vibrant pink and magenta.',
      'colors': [
        {'color': 'rgb(126, 11, 255)', 'stop': 0},
        {'color': 'rgb(197, 1, 22)', 'stop': 50},
        {'color': 'rgb(210, 157, 172)', 'stop': 69},
        {'color': 'rgb(157, 3, 112)', 'stop': 87},
        {'color': 'rgb(157, 3, 112)', 'stop': 100},
      ],
    },
    {
      'id': 20,
      'name': 'Pastel',
      'description': 'Different hues with very little saturation.',
      'colors': [
        {'color': 'rgb(10, 62, 123)', 'stop': 0},
        {'color': 'rgb(56, 130, 103)', 'stop': 14},
        {'color': 'rgb(153, 225, 85)', 'stop': 34},
        {'color': 'rgb(199, 217, 68)', 'stop': 39},
        {'color': 'rgb(255, 207, 54)', 'stop': 42},
        {'color': 'rgb(247, 152, 57)', 'stop': 45},
        {'color': 'rgb(239, 107, 61)', 'stop': 47},
        {'color': 'rgb(247, 152, 57)', 'stop': 50},
        {'color': 'rgb(255, 207, 54)', 'stop': 71},
        {'color': 'rgb(255, 227, 48)', 'stop': 87},
        {'color': 'rgb(255, 248, 42)', 'stop': 100},
      ],
    },
    {
      'id': 21,
      'name': 'Sunset 2',
      'description': 'Yellow and white running on dim blue.',
      'colors': [
        {'color': 'rgb(110, 49, 11)', 'stop': 0},
        {'color': 'rgb(55, 34, 10)', 'stop': 11},
        {'color': 'rgb(22, 22, 9)', 'stop': 27},
        {'color': 'rgb(239, 124, 8)', 'stop': 27},
        {'color': 'rgb(220, 156, 27)', 'stop': 38},
        {'color': 'rgb(203, 193, 61)', 'stop': 49},
        {'color': 'rgb(33, 53, 56)', 'stop': 70},
        {'color': 'rgb(0, 1, 52)', 'stop': 100},
      ],
    },
    {
      'id': 22,
      'name': 'Beach',
      'description': 'Different shades of light blue.',
      'colors': [
        {'color': 'rgb(255, 252, 214)', 'stop': 0},
        {'color': 'rgb(255, 252, 214)', 'stop': 5},
        {'color': 'rgb(255, 252, 214)', 'stop': 9},
        {'color': 'rgb(190, 191, 115)', 'stop': 10},
        {'color': 'rgb(137, 141, 52)', 'stop': 11},
        {'color': 'rgb(112, 255, 205)', 'stop': 11},
        {'color': 'rgb(51, 246, 214)', 'stop': 20},
        {'color': 'rgb(17, 235, 226)', 'stop': 28},
        {'color': 'rgb(2, 193, 199)', 'stop': 36},
        {'color': 'rgb(0, 156, 174)', 'stop': 47},
        {'color': 'rgb(1, 101, 115)', 'stop': 52},
        {'color': 'rgb(1, 59, 71)', 'stop': 53},
        {'color': 'rgb(7, 131, 170)', 'stop': 53},
        {'color': 'rgb(1, 90, 151)', 'stop': 82},
        {'color': 'rgb(0, 56, 133)', 'stop': 100},
      ],
    },
    {
      'id': 23,
      'name': 'Vintage',
      'description': 'Warm white running on very dim red.',
      'colors': [
        {'color': 'rgb(4, 1, 1)', 'stop': 0},
        {'color': 'rgb(16, 0, 1)', 'stop': 20},
        {'color': 'rgb(97, 104, 3)', 'stop': 30},
        {'color': 'rgb(255, 131, 19)', 'stop': 40},
        {'color': 'rgb(67, 9, 4)', 'stop': 50},
        {'color': 'rgb(16, 0, 1)', 'stop': 60},
        {'color': 'rgb(4, 1, 1)', 'stop': 90},
        {'color': 'rgb(4, 1, 1)', 'stop': 100},
      ],
    },
    {
      'id': 24,
      'name': 'Departure',
      'description': 'Greens and white fading out.',
      'colors': [
        {'color': 'rgb(8, 3, 0)', 'stop': 0},
        {'color': 'rgb(23, 7, 0)', 'stop': 16},
        {'color': 'rgb(75, 38, 6)', 'stop': 25},
        {'color': 'rgb(169, 99, 38)', 'stop': 33},
        {'color': 'rgb(213, 169, 119)', 'stop': 42},
        {'color': 'rgb(255, 255, 255)', 'stop': 45},
        {'color': 'rgb(135, 255, 138)', 'stop': 54},
        {'color': 'rgb(22, 255, 24)', 'stop': 58},
        {'color': 'rgb(0, 255, 0)', 'stop': 67},
        {'color': 'rgb(0, 136, 0)', 'stop': 75},
        {'color': 'rgb(0, 55, 0)', 'stop': 83},
        {'color': 'rgb(0, 55, 0)', 'stop': 100},
      ],
    },
    {
      'id': 25,
      'name': 'Landscape',
      'description': 'Blue, white and green gradient.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(2, 25, 1)', 'stop': 15},
        {'color': 'rgb(15, 115, 5)', 'stop': 30},
        {'color': 'rgb(79, 213, 1)', 'stop': 50},
        {'color': 'rgb(126, 211, 47)', 'stop': 50},
        {'color': 'rgb(188, 209, 247)', 'stop': 51},
        {'color': 'rgb(144, 182, 205)', 'stop': 60},
        {'color': 'rgb(59, 117, 250)', 'stop': 80},
        {'color': 'rgb(1, 37, 192)', 'stop': 100},
      ],
    },
    {
      'id': 26,
      'name': 'Beech',
      'description': 'Teal and yellow gradient fading out.',
      'colors': [
        {'color': 'rgb(1, 5, 0)', 'stop': 0},
        {'color': 'rgb(32, 23, 1)', 'stop': 7},
        {'color': 'rgb(161, 55, 1)', 'stop': 15},
        {'color': 'rgb(229, 144, 1)', 'stop': 25},
        {'color': 'rgb(39, 142, 74)', 'stop': 26},
        {'color': 'rgb(1, 4, 1)', 'stop': 100},
      ],
    },
    {
      'id': 27,
      'name': 'Sherbet',
      'description': 'Bright white, pink and mint colors.',
      'colors': [
        {'color': 'rgb(255, 33, 4)', 'stop': 0},
        {'color': 'rgb(255, 68, 25)', 'stop': 17},
        {'color': 'rgb(255, 7, 25)', 'stop': 34},
        {'color': 'rgb(255, 82, 103)', 'stop': 50},
        {'color': 'rgb(255, 255, 242)', 'stop': 67},
        {'color': 'rgb(42, 255, 22)', 'stop': 82},
        {'color': 'rgb(87, 255, 65)', 'stop': 100},
      ],
    },
    {
      'id': 28,
      'name': 'Hult',
      'description': 'White, magenta and teal.',
      'colors': [
        {'color': 'rgb(247, 176, 247)', 'stop': 0},
        {'color': 'rgb(255, 136, 255)', 'stop': 19},
        {'color': 'rgb(220, 29, 226)', 'stop': 35},
        {'color': 'rgb(7, 82, 178)', 'stop': 63},
        {'color': 'rgb(1, 124, 109)', 'stop': 85},
        {'color': 'rgb(1, 124, 109)', 'stop': 100},
      ],
    },
    {
      'id': 29,
      'name': 'Hult 64',
      'description': 'Teal and yellow hues.',
      'colors': [
        {'color': 'rgb(1, 124, 109)', 'stop': 0},
        {'color': 'rgb(1, 93, 79)', 'stop': 26},
        {'color': 'rgb(52, 65, 1)', 'stop': 41},
        {'color': 'rgb(115, 127, 1)', 'stop': 51},
        {'color': 'rgb(52, 65, 1)', 'stop': 59},
        {'color': 'rgb(1, 86, 72)', 'stop': 79},
        {'color': 'rgb(0, 55, 45)', 'stop': 94},
        {'color': 'rgb(0, 55, 45)', 'stop': 100},
      ],
    },
    {
      'id': 30,
      'name': 'Drywet',
      'description': 'Blue and yellow gradient.',
      'colors': [
        {'color': 'rgb(47, 30, 2)', 'stop': 0},
        {'color': 'rgb(213, 147, 24)', 'stop': 16},
        {'color': 'rgb(103, 219, 52)', 'stop': 33},
        {'color': 'rgb(3, 219, 207)', 'stop': 50},
        {'color': 'rgb(1, 48, 214)', 'stop': 67},
        {'color': 'rgb(1, 1, 111)', 'stop': 83},
        {'color': 'rgb(1, 7, 33)', 'stop': 100},
      ],
    },
    {
      'id': 31,
      'name': 'Jul',
      'description': 'Pastel green and red.',
      'colors': [
        {'color': 'rgb(194, 1, 1)', 'stop': 0},
        {'color': 'rgb(1, 29, 18)', 'stop': 37},
        {'color': 'rgb(57, 131, 28)', 'stop': 52},
        {'color': 'rgb(113, 1, 1)', 'stop': 100},
      ],
    },
    {
      'id': 32,
      'name': 'Grintage',
      'description': 'Yellow fading out.',
      'colors': [
        {'color': 'rgb(2, 1, 1)', 'stop': 0},
        {'color': 'rgb(18, 1, 0)', 'stop': 21},
        {'color': 'rgb(69, 29, 1)', 'stop': 41},
        {'color': 'rgb(167, 135, 10)', 'stop': 60},
        {'color': 'rgb(46, 56, 4)', 'stop': 100},
      ],
    },
    {
      'id': 33,
      'name': 'Rewhi',
      'description': 'Bright orange on desaturated purple.',
      'colors': [
        {'color': 'rgb(113, 91, 147)', 'stop': 0},
        {'color': 'rgb(157, 88, 78)', 'stop': 28},
        {'color': 'rgb(208, 85, 33)', 'stop': 35},
        {'color': 'rgb(255, 29, 11)', 'stop': 42},
        {'color': 'rgb(137, 31, 39)', 'stop': 55},
        {'color': 'rgb(59, 33, 89)', 'stop': 100},
      ],
    },
    {
      'id': 34,
      'name': 'Tertiary',
      'description': 'Red, green and blue gradient.',
      'colors': [
        {'color': 'rgb(0, 1, 255)', 'stop': 0},
        {'color': 'rgb(3, 68, 45)', 'stop': 25},
        {'color': 'rgb(23, 255, 0)', 'stop': 50},
        {'color': 'rgb(100, 68, 1)', 'stop': 75},
        {'color': 'rgb(255, 1, 4)', 'stop': 100},
      ],
    },
    {
      'id': 35,
      'name': 'Fire',
      'description': 'White, yellow and fading red gradient.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(18, 0, 0)', 'stop': 18},
        {'color': 'rgb(113, 0, 0)', 'stop': 38},
        {'color': 'rgb(142, 3, 1)', 'stop': 42},
        {'color': 'rgb(175, 17, 1)', 'stop': 47},
        {'color': 'rgb(213, 44, 2)', 'stop': 57},
        {'color': 'rgb(255, 82, 4)', 'stop': 68},
        {'color': 'rgb(255, 115, 4)', 'stop': 74},
        {'color': 'rgb(255, 156, 4)', 'stop': 79},
        {'color': 'rgb(255, 203, 4)', 'stop': 85},
        {'color': 'rgb(255, 255, 4)', 'stop': 92},
        {'color': 'rgb(255, 255, 71)', 'stop': 96},
        {'color': 'rgb(255, 255, 255)', 'stop': 100},
      ],
    },
    {
      'id': 36,
      'name': 'Icefire',
      'description': 'Same as Fire, but with blue colors.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(0, 9, 45)', 'stop': 23},
        {'color': 'rgb(0, 38, 255)', 'stop': 47},
        {'color': 'rgb(3, 100, 255)', 'stop': 58},
        {'color': 'rgb(23, 199, 255)', 'stop': 71},
        {'color': 'rgb(100, 235, 255)', 'stop': 85},
        {'color': 'rgb(255, 255, 255)', 'stop': 100},
      ],
    },
    {
      'id': 37,
      'name': 'Cyane',
      'description': 'Desaturated pastel colors.',
      'colors': [
        {'color': 'rgb(10, 85, 5)', 'stop': 0},
        {'color': 'rgb(29, 109, 18)', 'stop': 10},
        {'color': 'rgb(59, 138, 42)', 'stop': 24},
        {'color': 'rgb(83, 99, 52)', 'stop': 36},
        {'color': 'rgb(110, 66, 64)', 'stop': 42},
        {'color': 'rgb(123, 49, 65)', 'stop': 43},
        {'color': 'rgb(139, 35, 66)', 'stop': 44},
        {'color': 'rgb(192, 117, 98)', 'stop': 45},
        {'color': 'rgb(255, 255, 137)', 'stop': 49},
        {'color': 'rgb(100, 180, 155)', 'stop': 66},
        {'color': 'rgb(22, 121, 174)', 'stop': 100},
      ],
    },
    {
      'id': 38,
      'name': 'Light Pink',
      'description': 'Desaturated purple hues.',
      'colors': [
        {'color': 'rgb(19, 2, 39)', 'stop': 0},
        {'color': 'rgb(26, 4, 45)', 'stop': 10},
        {'color': 'rgb(33, 6, 52)', 'stop': 20},
        {'color': 'rgb(68, 62, 125)', 'stop': 30},
        {'color': 'rgb(118, 187, 240)', 'stop': 40},
        {'color': 'rgb(163, 215, 247)', 'stop': 43},
        {'color': 'rgb(217, 244, 255)', 'stop': 45},
        {'color': 'rgb(159, 149, 221)', 'stop': 48},
        {'color': 'rgb(113, 78, 188)', 'stop': 58},
        {'color': 'rgb(128, 57, 155)', 'stop': 72},
        {'color': 'rgb(146, 40, 123)', 'stop': 100},
      ],
    },
    {
      'id': 39,
      'name': 'Autumn',
      'description': 'Three white fields surrounded by yellow and dim red.',
      'colors': [
        {'color': 'rgb(26, 1, 1)', 'stop': 0},
        {'color': 'rgb(67, 4, 1)', 'stop': 20},
        {'color': 'rgb(118, 14, 1)', 'stop': 33},
        {'color': 'rgb(137, 152, 52)', 'stop': 41},
        {'color': 'rgb(113, 65, 1)', 'stop': 44},
        {'color': 'rgb(133, 149, 59)', 'stop': 48},
        {'color': 'rgb(137, 152, 52)', 'stop': 49},
        {'color': 'rgb(113, 65, 1)', 'stop': 53},
        {'color': 'rgb(139, 154, 46)', 'stop': 56},
        {'color': 'rgb(113, 13, 1)', 'stop': 64},
        {'color': 'rgb(55, 3, 1)', 'stop': 80},
        {'color': 'rgb(17, 1, 1)', 'stop': 98},
        {'color': 'rgb(17, 1, 1)', 'stop': 100},
      ],
    },
    {
      'id': 40,
      'name': 'Magenta',
      'description': 'White with magenta and blue.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(0, 0, 45)', 'stop': 16},
        {'color': 'rgb(0, 0, 255)', 'stop': 33},
        {'color': 'rgb(42, 0, 255)', 'stop': 50},
        {'color': 'rgb(255, 0, 255)', 'stop': 67},
        {'color': 'rgb(255, 55, 255)', 'stop': 83},
        {'color': 'rgb(255, 255, 255)', 'stop': 100},
      ],
    },
    {
      'id': 41,
      'name': 'Magred',
      'description': 'Magenta and red hues.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(42, 0, 45)', 'stop': 25},
        {'color': 'rgb(255, 0, 255)', 'stop': 50},
        {'color': 'rgb(255, 0, 45)', 'stop': 75},
        {'color': 'rgb(255, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 42,
      'name': 'Yelmag',
      'description': 'Magenta and red hues with a yellow.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(42, 0, 0)', 'stop': 16},
        {'color': 'rgb(255, 0, 0)', 'stop': 33},
        {'color': 'rgb(255, 0, 45)', 'stop': 50},
        {'color': 'rgb(255, 0, 255)', 'stop': 67},
        {'color': 'rgb(255, 55, 45)', 'stop': 83},
        {'color': 'rgb(255, 255, 0)', 'stop': 100},
      ],
    },
    {
      'id': 43,
      'name': 'Yelblu',
      'description': 'Blue with a little yellow.',
      'colors': [
        {'color': 'rgb(0, 0, 255)', 'stop': 0},
        {'color': 'rgb(0, 55, 255)', 'stop': 25},
        {'color': 'rgb(0, 255, 255)', 'stop': 50},
        {'color': 'rgb(42, 255, 45)', 'stop': 75},
        {'color': 'rgb(255, 255, 0)', 'stop': 100},
      ],
    },
    {
      'id': 44,
      'name': 'Orange & Teal',
      'description': 'An Orange - Gray - Teal gradient.',
      'colors': [
        {'color': 'rgb(0, 150, 92)', 'stop': 0},
        {'color': 'rgb(0, 150, 92)', 'stop': 22},
        {'color': 'rgb(255, 72, 0)', 'stop': 78},
        {'color': 'rgb(255, 72, 0)', 'stop': 100},
      ],
    },
    {
      'id': 45,
      'name': 'Tiamat',
      'description': 'A bright meteor with blue, teal and magenta hues.',
      'colors': [
        {'color': 'rgb(1, 2, 14)', 'stop': 0},
        {'color': 'rgb(2, 5, 35)', 'stop': 13},
        {'color': 'rgb(13, 135, 92)', 'stop': 39},
        {'color': 'rgb(43, 255, 193)', 'stop': 47},
        {'color': 'rgb(247, 7, 249)', 'stop': 55},
        {'color': 'rgb(193, 17, 208)', 'stop': 63},
        {'color': 'rgb(39, 255, 154)', 'stop': 71},
        {'color': 'rgb(4, 213, 236)', 'stop': 78},
        {'color': 'rgb(39, 252, 135)', 'stop': 86},
        {'color': 'rgb(193, 213, 253)', 'stop': 94},
        {'color': 'rgb(255, 249, 255)', 'stop': 100},
      ],
    },
    {
      'id': 46,
      'name': 'April Night',
      'description': 'Dark blue background with colorful snowflakes.',
      'colors': [
        {'color': 'rgb(1, 5, 45)', 'stop': 0},
        {'color': 'rgb(1, 5, 45)', 'stop': 4},
        {'color': 'rgb(5, 169, 175)', 'stop': 10},
        {'color': 'rgb(1, 5, 45)', 'stop': 16},
        {'color': 'rgb(1, 5, 45)', 'stop': 24},
        {'color': 'rgb(45, 175, 31)', 'stop': 30},
        {'color': 'rgb(1, 5, 45)', 'stop': 36},
        {'color': 'rgb(1, 5, 45)', 'stop': 44},
        {'color': 'rgb(249, 150, 5)', 'stop': 50},
        {'color': 'rgb(1, 5, 45)', 'stop': 56},
        {'color': 'rgb(1, 5, 45)', 'stop': 64},
        {'color': 'rgb(255, 92, 0)', 'stop': 70},
        {'color': 'rgb(1, 5, 45)', 'stop': 76},
        {'color': 'rgb(1, 5, 45)', 'stop': 84},
        {'color': 'rgb(223, 45, 72)', 'stop': 90},
        {'color': 'rgb(1, 5, 45)', 'stop': 96},
        {'color': 'rgb(1, 5, 45)', 'stop': 100},
      ],
    },
    {
      'id': 47,
      'name': 'Orangery',
      'description': 'Orange and yellow tones.',
      'colors': [
        {'color': 'rgb(255, 95, 23)', 'stop': 0},
        {'color': 'rgb(255, 82, 0)', 'stop': 12},
        {'color': 'rgb(223, 13, 8)', 'stop': 24},
        {'color': 'rgb(144, 44, 2)', 'stop': 35},
        {'color': 'rgb(255, 110, 17)', 'stop': 47},
        {'color': 'rgb(255, 69, 0)', 'stop': 59},
        {'color': 'rgb(158, 13, 11)', 'stop': 71},
        {'color': 'rgb(241, 82, 17)', 'stop': 82},
        {'color': 'rgb(213, 37, 4)', 'stop': 100},
      ],
    },
    {
      'id': 48,
      'name': 'C9',
      'description': 'Christmas lights palette. Red - amber - green - blue.',
      'colors': [
        {'color': 'rgb(184, 4, 0)', 'stop': 0},
        {'color': 'rgb(184, 4, 0)', 'stop': 24},
        {'color': 'rgb(144, 44, 2)', 'stop': 25},
        {'color': 'rgb(144, 44, 2)', 'stop': 49},
        {'color': 'rgb(4, 96, 2)', 'stop': 51},
        {'color': 'rgb(4, 96, 2)', 'stop': 75},
        {'color': 'rgb(7, 7, 88)', 'stop': 76},
        {'color': 'rgb(7, 7, 88)', 'stop': 100},
      ],
    },
    {
      'id': 49,
      'name': 'Sakura',
      'description': 'Pink and rose tones.',
      'colors': [
        {'color': 'rgb(196, 19, 10)', 'stop': 0},
        {'color': 'rgb(255, 69, 45)', 'stop': 25},
        {'color': 'rgb(223, 45, 72)', 'stop': 51},
        {'color': 'rgb(255, 82, 103)', 'stop': 76},
        {'color': 'rgb(223, 13, 17)', 'stop': 100},
      ],
    },
    {
      'id': 50,
      'name': 'Aurora',
      'description': 'Greens on dark blue.',
      'colors': [
        {'color': 'rgb(1, 5, 45)', 'stop': 0},
        {'color': 'rgb(0, 200, 23)', 'stop': 25},
        {'color': 'rgb(0, 255, 0)', 'stop': 50},
        {'color': 'rgb(0, 243, 45)', 'stop': 67},
        {'color': 'rgb(0, 135, 7)', 'stop': 78},
        {'color': 'rgb(1, 5, 45)', 'stop': 100},
      ],
    },
    {
      'id': 51,
      'name': 'Atlantica',
      'description': 'Greens & Blues of the ocean.',
      'colors': [
        {'color': 'rgb(0, 28, 112)', 'stop': 0},
        {'color': 'rgb(32, 96, 255)', 'stop': 20},
        {'color': 'rgb(0, 243, 45)', 'stop': 39},
        {'color': 'rgb(12, 95, 82)', 'stop': 59},
        {'color': 'rgb(25, 190, 95)', 'stop': 78},
        {'color': 'rgb(40, 170, 80)', 'stop': 100},
      ],
    },
    {
      'id': 52,
      'name': 'C9 2',
      'description': 'C9 plus yellow.',
      'colors': [
        {'color': 'rgb(6, 126, 2)', 'stop': 0},
        {'color': 'rgb(6, 126, 2)', 'stop': 18},
        {'color': 'rgb(4, 30, 114)', 'stop': 18},
        {'color': 'rgb(4, 30, 114)', 'stop': 35},
        {'color': 'rgb(255, 5, 0)', 'stop': 35},
        {'color': 'rgb(255, 5, 0)', 'stop': 53},
        {'color': 'rgb(196, 57, 2)', 'stop': 53},
        {'color': 'rgb(196, 57, 2)', 'stop': 71},
        {'color': 'rgb(137, 85, 2)', 'stop': 71},
        {'color': 'rgb(137, 85, 2)', 'stop': 100},
      ],
    },
    {
      'id': 53,
      'name': 'C9 New',
      'description': 'C9, but brighter and with a less purple blue.',
      'colors': [
        {'color': 'rgb(255, 5, 0)', 'stop': 0},
        {'color': 'rgb(255, 5, 0)', 'stop': 24},
        {'color': 'rgb(196, 57, 2)', 'stop': 24},
        {'color': 'rgb(196, 57, 2)', 'stop': 47},
        {'color': 'rgb(6, 126, 2)', 'stop': 47},
        {'color': 'rgb(6, 126, 2)', 'stop': 71},
        {'color': 'rgb(4, 30, 114)', 'stop': 71},
        {'color': 'rgb(4, 30, 114)', 'stop': 100},
      ],
    },
    {
      'id': 54,
      'name': 'Temperature',
      'description': 'Temperature mapping.',
      'colors': [
        {'color': 'rgb(1, 27, 105)', 'stop': 0},
        {'color': 'rgb(1, 40, 127)', 'stop': 5},
        {'color': 'rgb(1, 70, 168)', 'stop': 11},
        {'color': 'rgb(1, 92, 197)', 'stop': 16},
        {'color': 'rgb(1, 119, 221)', 'stop': 22},
        {'color': 'rgb(3, 130, 151)', 'stop': 27},
        {'color': 'rgb(23, 156, 149)', 'stop': 33},
        {'color': 'rgb(67, 182, 112)', 'stop': 39},
        {'color': 'rgb(121, 201, 52)', 'stop': 44},
        {'color': 'rgb(142, 203, 11)', 'stop': 50},
        {'color': 'rgb(224, 223, 1)', 'stop': 55},
        {'color': 'rgb(252, 187, 2)', 'stop': 61},
        {'color': 'rgb(247, 147, 1)', 'stop': 67},
        {'color': 'rgb(237, 87, 1)', 'stop': 72},
        {'color': 'rgb(229, 43, 1)', 'stop': 78},
        {'color': 'rgb(171, 2, 2)', 'stop': 89},
        {'color': 'rgb(80, 3, 3)', 'stop': 94},
        {'color': 'rgb(80, 3, 3)', 'stop': 100},
      ],
    },
    {
      'id': 55,
      'name': 'Aurora 2',
      'description': 'Aurora with some pinks & blue.',
      'colors': [
        {'color': 'rgb(17, 177, 13)', 'stop': 0},
        {'color': 'rgb(121, 242, 5)', 'stop': 25},
        {'color': 'rgb(25, 173, 121)', 'stop': 50},
        {'color': 'rgb(250, 77, 127)', 'stop': 75},
        {'color': 'rgb(171, 101, 221)', 'stop': 100},
      ],
    },
    {
      'id': 56,
      'name': 'Retro Clown',
      'description': 'Yellow to purple gradient.',
      'colors': [
        {'color': 'rgb(227, 101, 3)', 'stop': 0},
        {'color': 'rgb(194, 18, 19)', 'stop': 46},
        {'color': 'rgb(92, 8, 192)', 'stop': 100},
      ],
    },
    {
      'id': 57,
      'name': 'Candy',
      'description': 'Vivid yellows, magenta, salmon and blues.',
      'colors': [
        {'color': 'rgb(229, 227, 1)', 'stop': 0},
        {'color': 'rgb(227, 101, 3)', 'stop': 6},
        {'color': 'rgb(40, 1, 80)', 'stop': 56},
        {'color': 'rgb(17, 1, 79)', 'stop': 78},
        {'color': 'rgb(0, 0, 45)', 'stop': 100},
      ],
    },
    {
      'id': 58,
      'name': 'Toxy Reaf',
      'description': 'Vivid aqua to purple gradient.',
      'colors': [
        {'color': 'rgb(1, 221, 53)', 'stop': 0},
        {'color': 'rgb(73, 3, 178)', 'stop': 100},
      ],
    },
    {
      'id': 59,
      'name': 'Fairy Reaf',
      'description': 'Bright aqua to purple gradient.',
      'colors': [
        {'color': 'rgb(184, 1, 128)', 'stop': 0},
        {'color': 'rgb(1, 193, 182)', 'stop': 63},
        {'color': 'rgb(153, 227, 190)', 'stop': 86},
        {'color': 'rgb(255, 255, 255)', 'stop': 100},
      ],
    },
    {
      'id': 60,
      'name': 'Semi Blue',
      'description': 'Dark blues with a bright blue burst.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(1, 1, 3)', 'stop': 5},
        {'color': 'rgb(8, 1, 22)', 'stop': 21},
        {'color': 'rgb(4, 6, 89)', 'stop': 31},
        {'color': 'rgb(2, 25, 216)', 'stop': 47},
        {'color': 'rgb(7, 10, 99)', 'stop': 57},
        {'color': 'rgb(15, 2, 31)', 'stop': 73},
        {'color': 'rgb(2, 1, 5)', 'stop': 91},
        {'color': 'rgb(0, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 61,
      'name': 'Pink Candy',
      'description': 'White, pinks and purple',
      'colors': [
        {'color': 'rgb(255, 255, 255)', 'stop': 0},
        {'color': 'rgb(7, 12, 255)', 'stop': 18},
        {'color': 'rgb(227, 1, 127)', 'stop': 44},
        {'color': 'rgb(227, 1, 127)', 'stop': 44},
        {'color': 'rgb(255, 255, 255)', 'stop': 55},
        {'color': 'rgb(227, 1, 127)', 'stop': 61},
        {'color': 'rgb(45, 1, 99)', 'stop': 77},
        {'color': 'rgb(255, 255, 255)', 'stop': 100},
      ],
    },
    {
      'id': 62,
      'name': 'Red Reaf',
      'description': 'A deep blue gradient transitioning to bright red through a sky-blue phase, fading to near black.',
      'colors': [
        {'color': 'rgb(3, 13, 43)', 'stop': 0},
        {'color': 'rgb(78, 141, 240)', 'stop': 41},
        {'color': 'rgb(255, 0, 0)', 'stop': 74},
        {'color': 'rgb(28, 1, 1)', 'stop': 100},
      ],
    },
    {
      'id': 63,
      'name': 'Aqua Flash',
      'description': 'A striking palette starting dark, bursting into aqua and bright yellow, peaking at white, then fading back through aqua to black.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(57, 227, 233)', 'stop': 26},
        {'color': 'rgb(255, 255, 8)', 'stop': 38},
        {'color': 'rgb(255, 255, 255)', 'stop': 49},
        {'color': 'rgb(255, 255, 8)', 'stop': 60},
        {'color': 'rgb(57, 227, 233)', 'stop': 74},
        {'color': 'rgb(0, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 64,
      'name': 'Yelblu Hot',
      'description': 'A dark palette moving from deep blue and purple to warm reds and oranges, ending in a vivid yellow.',
      'colors': [
        {'color': 'rgb(4, 2, 9)', 'stop': 0},
        {'color': 'rgb(16, 0, 47)', 'stop': 23},
        {'color': 'rgb(24, 0, 16)', 'stop': 48},
        {'color': 'rgb(144, 9, 1)', 'stop': 62},
        {'color': 'rgb(179, 45, 1)', 'stop': 72},
        {'color': 'rgb(220, 114, 2)', 'stop': 86},
        {'color': 'rgb(234, 237, 1)', 'stop': 100},
      ],
    },
    {
      'id': 65,
      'name': 'Lite Light',
      'description': 'A subtle gradient from black through faint grays and purples, returning to black, creating a soft, dim glow.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(1, 1, 1)', 'stop': 4},
        {'color': 'rgb(5, 5, 6)', 'stop': 16},
        {'color': 'rgb(5, 5, 6)', 'stop': 26},
        {'color': 'rgb(10, 1, 12)', 'stop': 40},
        {'color': 'rgb(0, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 66,
      'name': 'Red Flash',
      'description': 'A bold transition from black to vivid red, peaking with a golden flash, then returning to red and fading to black.',
      'colors': [
        {'color': 'rgb(0, 0, 0)', 'stop': 0},
        {'color': 'rgb(227, 1, 1)', 'stop': 39},
        {'color': 'rgb(249, 199, 95)', 'stop': 51},
        {'color': 'rgb(227, 1, 1)', 'stop': 61},
        {'color': 'rgb(0, 0, 0)', 'stop': 100},
      ],
    },
    {
      'id': 67,
      'name': 'Blink Red',
      'description': 'A dynamic palette shifting from dark tones through reds and pinks, with hints of purple and blue, ending in a muted purple.',
      'colors': [
        {'color': 'rgb(1, 1, 1)', 'stop': 0},
        {'color': 'rgb(4, 1, 11)', 'stop': 17},
        {'color': 'rgb(10, 1, 3)', 'stop': 30},
        {'color': 'rgb(161, 4, 29)', 'stop': 43},
        {'color': 'rgb(255, 86, 123)', 'stop': 50},
        {'color': 'rgb(125, 16, 160)', 'stop': 65},
        {'color': 'rgb(35, 13, 223)', 'stop': 80},
        {'color': 'rgb(18, 2, 18)', 'stop': 100},
      ],
    },
    {
      'id': 68,
      'name': 'Red Shift',
      'description': 'A gradient from deep reddish-purples to bright oranges and reds, fading back to a dark maroon.',
      'colors': [
        {'color': 'rgb(31, 1, 27)', 'stop': 0},
        {'color': 'rgb(34, 1, 16)', 'stop': 18},
        {'color': 'rgb(137, 5, 9)', 'stop': 39},
        {'color': 'rgb(213, 128, 10)', 'stop': 52},
        {'color': 'rgb(199, 22, 1)', 'stop': 69},
        {'color': 'rgb(199, 9, 6)', 'stop': 79},
        {'color': 'rgb(1, 0, 1)', 'stop': 100},
      ],
    },
    {
      'id': 69,
      'name': 'Red Tide',
      'description': 'A vibrant mix of bright reds and oranges, interspersed with golden yellows, fading to a deep red.',
      'colors': [
        {'color': 'rgb(247, 5, 0)', 'stop': 0},
        {'color': 'rgb(255, 67, 1)', 'stop': 11},
        {'color': 'rgb(234, 88, 11)', 'stop': 17},
        {'color': 'rgb(234, 176, 51)', 'stop': 23},
        {'color': 'rgb(229, 28, 1)', 'stop': 33},
        {'color': 'rgb(113, 12, 1)', 'stop': 45},
        {'color': 'rgb(255, 225, 44)', 'stop': 55},
        {'color': 'rgb(113, 12, 1)', 'stop': 66},
        {'color': 'rgb(244, 209, 88)', 'stop': 77},
        {'color': 'rgb(255, 28, 1)', 'stop': 85},
        {'color': 'rgb(53, 1, 1)', 'stop': 100},
      ],
    },
    {
      'id': 70,
      'name': 'Candy2',
      'description': 'Faded gradient of yellow, salmon and blue',
      'colors': [
        {'color': 'rgb(39, 33, 34)', 'stop': 0},
        {'color': 'rgb(4, 6, 15)', 'stop': 10},
        {'color': 'rgb(49, 29, 22)', 'stop': 19},
        {'color': 'rgb(224, 173, 1)', 'stop': 29},
        {'color': 'rgb(177, 35, 5)', 'stop': 35},
        {'color': 'rgb(4, 6, 15)', 'stop': 51},
        {'color': 'rgb(255, 114, 6)', 'stop': 64},
        {'color': 'rgb(224, 173, 1)', 'stop': 73},
        {'color': 'rgb(39, 33, 34)', 'stop': 83},
        {'color': 'rgb(1, 1, 1)', 'stop': 100},
      ],
    },
  ];

  static int getPaletteId(String paletteName) {
    final palette = palettesDatabase.firstWhere(
      (p) => p['name'].toString().toLowerCase() == paletteName.toLowerCase(),
      orElse: () => {'id': 0}, // Default to 'Default' (ID 0) if not found
    );
    return palette['id'] as int;
  }

  static List<Map<String, dynamic>> updatePalettesWithSelectedColors(List<dynamic> selectedColors) {
    // Create a deep copy of the PalettesDatabase to modify
    List<Map<String, dynamic>> updatedPalettes = palettesDatabase.map((palette) {
      return Map<String, dynamic>.from(palette);
    }).toList();

    // Ensure selectedColors has at least 3 entries
    List<List<dynamic>> paddedColors = List.from(selectedColors);
    while (paddedColors.length < 3) {
      paddedColors.add([0, 0, 0]); // Default to black if not enough colors
    }

    // Convert selectedColors to the gradient format
    List<Map<String, dynamic>> gradientColors = [];
    for (int i = 0; i < paddedColors.length; i++) {
      final color = paddedColors[i];
      gradientColors.add({
        'color': 'rgb(${color[0]},${color[1]},${color[2]})',
        'stop': i == 0 ? 0 : (i == paddedColors.length - 1 ? 100 : (i / (paddedColors.length - 1) * 100)),
      });
    }

    // Update palettes 0-5 based on selected colors
    for (int i = 0; i <= 5; i++) {
      final palette = updatedPalettes[i];
      switch (i) {
        case 0: // Default: Primary color
          palette['colors'] = [
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 0},
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 100},
          ];
          break;
        case 1: // Random Cycle: Use selected colors as a base gradient
          palette['colors'] = gradientColors.isNotEmpty
              ? gradientColors
              : [
                  {'color': 'rgb(156,112,171)', 'stop': 0},
                  {'color': 'rgb(5,123,189)', 'stop': 25},
                  {'color': 'rgb(221,125,219)', 'stop': 50},
                  {'color': 'rgb(92,242,235)', 'stop': 75},
                ];
          break;
        case 2: // Color 1: Primary color
          palette['colors'] = [
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 0},
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 100},
          ];
          break;
        case 3: // Colors 1&2: Primary and secondary
          palette['colors'] = [
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 0},
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 25},
            {
              'color': gradientColors.length > 1 ? gradientColors[1]['color'] : 'rgb(8,255,0)',
              'stop': 50
            },
            {
              'color': gradientColors.length > 1 ? gradientColors[1]['color'] : 'rgb(8,255,0)',
              'stop': 75
            },
          ];
          break;
        case 4: // Color Gradient: Gradient of all segment colors
          palette['colors'] = gradientColors.isNotEmpty
              ? gradientColors
              : [
                  {'color': 'rgb(0,0,255)', 'stop': 0},
                  {'color': 'rgb(8,255,0)', 'stop': 33},
                  {'color': 'rgb(255,0,0)', 'stop': 67},
                ];
          break;
        case 5: // Colors Only: Primary, secondary, tertiary
          palette['colors'] = [
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 0},
            {'color': gradientColors.isNotEmpty ? gradientColors[0]['color'] : 'rgb(255,0,0)', 'stop': 25},
            {
              'color': gradientColors.length > 1 ? gradientColors[1]['color'] : 'rgb(8,255,0)',
              'stop': 50
            },
            {
              'color': gradientColors.length > 1 ? gradientColors[1]['color'] : 'rgb(8,255,0)',
              'stop': 75
            },
            {
              'color': gradientColors.length > 2 ? gradientColors[2]['color'] : 'rgb(0,0,255)',
              'stop': 100
            },
          ];
          break;
      }
    }

    return updatedPalettes;
  }

  static List<int> colorToRgb(Color color) {
    // ignore: deprecated_member_use
    return [color.red, color.green, color.blue];
  }

  static Future<Color?> showColorPicker(BuildContext context, Color initialColor) async {
    Color? selectedColor = initialColor;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) {
              selectedColor = color;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return selectedColor;
  }
}