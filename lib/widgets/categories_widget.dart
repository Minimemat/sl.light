import 'package:flutter/material.dart';

class CategoriesWidget extends StatefulWidget {
  final String currentCategory;
  final Function(String) onCategoryChanged;
  final bool isSearchExpanded;
  final List<dynamic>? presets;

  const CategoriesWidget({
    super.key,
    required this.currentCategory,
    required this.onCategoryChanged,
    required this.isSearchExpanded,
    this.presets,
  });

  @override
  State<CategoriesWidget> createState() => _CategoriesWidgetState();
}

class _CategoriesWidgetState extends State<CategoriesWidget> {
  bool _isDropdownOpen = false;

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'All',
      'icon': Icons.all_inclusive,
      'index': 0,
      'color': const Color(0xFF666666),
    },
    {
      'name': 'Architectural',
      'icon': Icons.architecture,
      'index': 1,
      'color': const Color(0xFF8b4513),
    },
    {
      'name': 'Canada',
      'icon': Icons.flag,
      'index': 2,
      'color': const Color(0xFFff0000),
    },
    {
      'name': 'Christmas',
      'icon': Icons.local_florist,
      'index': 3,
      'color': const Color(0xFFc41e3a),
    },
    {
      'name': 'Diwali',
      'icon': Icons.lightbulb,
      'index': 4,
      'color': const Color(0xFFffa500),
    },
    {
      'name': 'Easter',
      'icon': Icons.egg,
      'index': 5,
      'color': const Color(0xFFffb6c1),
    },
    {
      'name': 'Events',
      'icon': Icons.celebration,
      'index': 6,
      'color': const Color(0xFF2271b1),
    },
    {
      'name': 'Fall',
      'icon': Icons.park,
      'index': 7,
      'color': const Color(0xFFff8c00),
    },
    {
      'name': 'Halloween',
      'icon': Icons.nights_stay,
      'index': 8,
      'color': const Color(0xFFff6600),
    },
    {
      'name': 'Ramadan',
      'icon': Icons.mosque,
      'index': 9,
      'color': const Color(0xFF228b22),
    },
    {
      'name': 'Spring',
      'icon': Icons.local_florist,
      'index': 10,
      'color': const Color(0xFF90ee90),
    },
    {
      'name': 'Sports',
      'icon': Icons.sports,
      'index': 11,
      'color': const Color(0xFF32cd32),
    },
    {
      'name': 'St. Patrick\'s',
      'icon': Icons.grass,
      'index': 12,
      'color': const Color(0xFF00ff00),
    },
    {
      'name': 'Summer',
      'icon': Icons.wb_sunny,
      'index': 13,
      'color': const Color(0xFFffd700),
    },
    {
      'name': 'Valentines',
      'icon': Icons.favorite,
      'index': 14,
      'color': const Color(0xFFff69b4),
    },
    {
      'name': 'Winter',
      'icon': Icons.ac_unit,
      'index': 15,
      'color': const Color(0xFF87ceeb),
    },
    {
      'name': 'Other',
      'icon': Icons.more_horiz,
      'index': 16,
      'color': const Color(0xFF666666),
    },
  ];

  @override
  Widget build(BuildContext context) {
    // Hide categories completely when search is expanded
    if (widget.isSearchExpanded) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8.0),
      child: AnimatedCrossFade(
        duration: const Duration(milliseconds: 300),
        crossFadeState: _isDropdownOpen
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        firstChild: _buildCompactView(),
        secondChild: _buildExpandedView(),
      ),
    );
  }

  Widget _buildCompactView() {
    final currentCategoryData = _categories.firstWhere(
      (cat) => cat['name'] == widget.currentCategory,
      orElse: () => _categories.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white70),
      ),
      child: InkWell(
        onTap: widget.isSearchExpanded
            ? null
            : () {
                setState(() {
                  _isDropdownOpen = true;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              // Add space for search icon
              const SizedBox(width: 52),
              Icon(
                currentCategoryData['icon'] as IconData,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.currentCategory,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }

  int _getCategoryCount(String categoryName) {
    if (widget.presets == null) return 0;

    if (categoryName == 'All') {
      // For "All", exclude deleted presets
      return widget.presets!.where((preset) {
        return !preset.categories.contains('Deleted');
      }).length;
    }

    if (categoryName == 'Deleted') {
      // Count deleted presets
      return widget.presets!.where((preset) {
        return preset.categories.contains('Deleted');
      }).length;
    }

    // Count presets in this category (excluding deleted ones)
    return widget.presets!.where((preset) {
      return preset.categories.contains(categoryName) &&
          !preset.categories.contains('Deleted');
    }).length;
  }

  Widget _buildExpandedView() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white70),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Close button for expanded view
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  // Add space for search icon
                  const SizedBox(width: 52),
                  const Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () {
                  setState(() {
                    _isDropdownOpen = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grid of category buttons
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected = category['name'] == widget.currentCategory;

              return InkWell(
                onTap: () {
                  widget.onCategoryChanged(category['name'] as String);
                  if (!widget.isSearchExpanded) {
                    setState(() {
                      _isDropdownOpen = false;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (category['color'] as Color).withOpacity(0.3)
                        : (category['color'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? category['color'] as Color
                          : (category['color'] as Color).withOpacity(0.5),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Main content - perfectly centered
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              category['icon'] as IconData,
                              color: isSelected
                                  ? category['color'] as Color
                                  : Colors.white70,
                              size: 24,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              category['name'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? category['color'] as Color
                                    : Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      // Count badge overlay - positioned absolutely
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF666666),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(context).cardColor,
                              width: 1,
                            ),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            '${_getCategoryCount(category['name'] as String)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          // Deleted button at bottom right
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () {
                  widget.onCategoryChanged('Deleted');
                  if (!widget.isSearchExpanded) {
                    setState(() {
                      _isDropdownOpen = false;
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.currentCategory == 'Deleted'
                        ? Colors.red.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.currentCategory == 'Deleted'
                          ? Colors.red
                          : Colors.red.withOpacity(0.5),
                      width: widget.currentCategory == 'Deleted' ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete,
                        color: widget.currentCategory == 'Deleted'
                            ? Colors.red
                            : Colors.red.withOpacity(0.7),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Deleted',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: widget.currentCategory == 'Deleted'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: widget.currentCategory == 'Deleted'
                              ? Colors.red
                              : Colors.red.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
