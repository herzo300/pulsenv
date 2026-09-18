import 'package:flutter/material.dart';
import '../../../services/uk_fallback_data.dart';

import '../../../theme/pulse_categories.dart';
import '../../../theme/pulse_colors.dart';
import '../../../data/district_data.dart';
import 'map_glass_panel.dart';

/// Compact map filter: category dropdown + optional day chips + house search.
class MapFilterPanel extends StatefulWidget {
  final int? selectedDaysFilter;
  final List<String> selectedCategories;
  final List<String> selectedDistricts;
  final int totalComplaints;
  final Map<String, int> categoryCounts;
  final Color uiTextPrimary;
  final Color uiTextSecondary;
  final Color uiPanelFill;
  final Color uiGlow;
  final Color uiAccent;
  final bool isNightMode;
  final bool showDaysFilter;
  final List<DistrictData> districts;
  final List<Map<String, dynamic>> allSignals;
  final ValueChanged<int?> onDaysFilterChanged;
  final ValueChanged<List<String>> onCategoriesChanged;
  final ValueChanged<List<String>> onDistrictsChanged;
  final ValueChanged<String> onAddressSelected;
  final ValueChanged<String>? onAddressTyped;

  const MapFilterPanel({
    super.key,
    required this.selectedDaysFilter,
    required this.selectedCategories,
    required this.selectedDistricts,
    required this.totalComplaints,
    required this.categoryCounts,
    required this.uiTextPrimary,
    required this.uiTextSecondary,
    required this.uiPanelFill,
    required this.uiGlow,
    required this.uiAccent,
    required this.isNightMode,
    required this.districts,
    required this.allSignals,
    this.showDaysFilter = true,
    required this.onDaysFilterChanged,
    required this.onCategoriesChanged,
    required this.onDistrictsChanged,
    required this.onAddressSelected,
    this.onAddressTyped,
  });

  @override
  State<MapFilterPanel> createState() => _MapFilterPanelState();
}

class _MapFilterPanelState extends State<MapFilterPanel> {
  bool _isExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  List<String> _suggestions = [];
  List<String> _allCityHouses = [];

  static const _timeFilters = <({int? days, String label})>[
    (days: null, label: 'Все'),
    (days: 1, label: '1д'),
    (days: 7, label: '7д'),
    (days: 30, label: '30д'),
  ];

  @override
  void initState() {
    super.initState();
    _initCityHouses();
  }

  void _initCityHouses() {
    final set = <String>{};
    try {
      for (final company in UkFallbackData.companies) {
        final mkdList = company['mkd'] as List<dynamic>?;
        if (mkdList == null) continue;
        for (final mkd in mkdList) {
          final street = mkd['street']?.toString() ?? '';
          final buildings = mkd['buildings'] as List<dynamic>?;
          if (buildings == null) continue;
          for (final b in buildings) {
            final bStr = b.toString();
            var cleanStreet = street;
            if (cleanStreet.startsWith('улица ')) {
              cleanStreet = 'ул. ' + cleanStreet.substring(6);
            } else if (cleanStreet.startsWith('проспект ')) {
              cleanStreet = 'пр. ' + cleanStreet.substring(9);
            } else if (cleanStreet.startsWith('переулок ')) {
              cleanStreet = 'пер. ' + cleanStreet.substring(9);
            }
            set.add('$cleanStreet, $bStr, Нижневартовск');
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting city houses: $e');
    }

    for (final sig in widget.allSignals) {
      final addr = sig['address']?.toString();
      if (addr != null && addr.trim().isNotEmpty) {
        set.add(addr.trim());
      }
    }

    _allCityHouses = set.toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: widget.isNightMode ? Colors.white.withAlpha(10) : Colors.black.withAlpha(12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isNightMode ? Colors.white.withAlpha(20) : Colors.black.withAlpha(18),
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.search_rounded,
                  color: widget.isNightMode ? Colors.white54 : const Color(0xFF64748B),
                  size: 18,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(
                    color: widget.isNightMode ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Поиск по адресу дома...',
                    hintStyle: TextStyle(
                      color: widget.isNightMode ? Colors.white38 : const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (val) {
                    final query = val.trim().toLowerCase();
                    if (query.isEmpty) return;
                    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
                    if (tokens.isEmpty) return;
                    
                    String? bestMatch;
                    for (final addr in _allCityHouses) {
                      final addrLower = addr.toLowerCase();
                      bool matchesAll = true;
                      for (final token in tokens) {
                        if (!addrLower.contains(token)) {
                          matchesAll = false;
                          break;
                        }
                      }
                      if (matchesAll) {
                        bestMatch = addr;
                        break;
                      }
                    }
                    if (bestMatch != null) {
                      FocusScope.of(context).unfocus();
                      widget.onAddressSelected(bestMatch);
                    }
                  },
                  onChanged: (val) {
                    final query = val.trim().toLowerCase();
                    if (query.isEmpty) {
                      setState(() {
                        _suggestions = [];
                      });
                      widget.onAddressTyped?.call('');
                      return;
                    }
                    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
                    if (tokens.isEmpty) {
                      setState(() {
                        _suggestions = [];
                      });
                      widget.onAddressTyped?.call('');
                      return;
                    }

                    final matches = <String>[];
                    for (final addr in _allCityHouses) {
                      final addrLower = addr.toLowerCase();
                      bool matchesAll = true;
                      for (final token in tokens) {
                        if (!addrLower.contains(token)) {
                          matchesAll = false;
                          break;
                        }
                      }
                      if (matchesAll) {
                        matches.add(addr);
                      }
                    }

                    setState(() {
                      _suggestions = [];
                    });

                    if (matches.isNotEmpty) {
                      widget.onAddressTyped?.call(matches.first);
                    }
                  },
                ),
              ),
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: widget.isNightMode ? Colors.white54 : const Color(0xFF64748B),
                    size: 16,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions = [];
                    });
                    widget.onAddressTyped?.call('');
                  },
                ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: widget.isNightMode ? const Color(0xFA1E293B) : const Color(0xFAF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isNightMode ? Colors.white.withAlpha(20) : Colors.black.withAlpha(20),
              ),
            ),
            child: Column(
              children: _suggestions.map((addr) {
                return InkWell(
                  onTap: () {
                    _searchController.clear();
                    setState(() {
                      _suggestions = [];
                    });
                    FocusScope.of(context).unfocus();
                    widget.onAddressSelected(addr);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Text(
                      addr,
                      style: TextStyle(
                        color: widget.isNightMode ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.selectedCategories.isNotEmpty
        ? widget.uiAccent.withAlpha(widget.isNightMode ? 150 : 110)
        : widget.uiGlow.withAlpha(widget.isNightMode ? 90 : 60);

    final categories = PulseCategories.mapFilterOptions;

    return MapGlassPanel(
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      fillColor: widget.uiPanelFill,
      blurSigma: 20,
      borderColors: [
        borderColor,
        borderColor.withAlpha(48),
        Colors.transparent,
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(),
          const SizedBox(height: 8),
          
          // Categories Row / Wrap based on _isExpanded
          // Two rows of scrollable category buttons fitting all 16 categories
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAllButton(),
                const SizedBox(width: 8),
                for (int i = 0; i < 8 && i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryButton(categories[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (int i = 8; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryButton(categories[i]),
                  ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 12, thickness: 0.5),

          // Days + Districts Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.showDaysFilter)
                Row(
                  children: _timeFilters.map((tf) {
                    final isSel = widget.selectedDaysFilter == tf.days;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: MapDayChip(
                        days: tf.days,
                        label: tf.label,
                        selected: isSel,
                        uiTextPrimary: widget.uiTextPrimary,
                        uiAccent: widget.uiAccent,
                        isNightMode: widget.isNightMode,
                        onSelected: () => widget.onDaysFilterChanged(tf.days),
                      ),
                    );
                  }).toList(),
                )
              else
                const Spacer(),

              // District filter dropdown trigger
              _buildDistrictDropdownTrigger(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllButton() {
    final isSelected = widget.selectedCategories.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onCategoriesChanged([]);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? widget.uiAccent.withAlpha(45)
                : (widget.isNightMode ? Colors.white.withAlpha(8) : Colors.black.withAlpha(8)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? widget.uiAccent.withAlpha(120)
                  : (widget.isNightMode ? Colors.transparent : Colors.black.withAlpha(12)),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apps_rounded,
                size: 14,
                color: isSelected ? widget.uiAccent : (widget.isNightMode ? Colors.white60 : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                'Все',
                style: TextStyle(
                  color: isSelected ? widget.uiTextPrimary : widget.uiTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryButton((String, IconData, Color) cat) {
    final name = cat.$1;
    final icon = cat.$2;
    final color = cat.$3;
    final isSelected = widget.selectedCategories.contains(name);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          final list = List<String>.from(widget.selectedCategories);
          if (list.contains(name)) {
            list.remove(name);
          } else {
            list.add(name);
          }
          widget.onCategoriesChanged(list);
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withAlpha(45)
                : (widget.isNightMode ? Colors.white.withAlpha(8) : Colors.black.withAlpha(8)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withAlpha(120)
                  : (widget.isNightMode ? Colors.transparent : Colors.black.withAlpha(12)),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : (widget.isNightMode ? Colors.white60 : color),
              ),
              const SizedBox(width: 4),
              Text(
                name,
                style: TextStyle(
                  color: isSelected ? widget.uiTextPrimary : widget.uiTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictDropdownTrigger() {
    return PopupMenuButton<String>(
      constraints: const BoxConstraints(maxHeight: 250.0),
      color: widget.isNightMode ? const Color(0xFF1E293B) : Colors.white,
      onSelected: (dist) {
        if (dist == 'all') {
          widget.onDistrictsChanged([]);
          return;
        }
        final list = List<String>.from(widget.selectedDistricts);
        if (list.contains(dist)) {
          list.remove(dist);
        } else {
          list.add(dist);
        }
        widget.onDistrictsChanged(list);
      },
      itemBuilder: (ctx) {
        final List<PopupMenuEntry<String>> menuItems = [];
        
        // Add "Все" option
        final isAllSelected = widget.selectedDistricts.isEmpty;
        menuItems.add(
          PopupMenuItem<String>(
            value: 'all',
            height: 34,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: isAllSelected,
                      onChanged: null,
                      activeColor: widget.uiAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Все микрорайоны',
                  style: TextStyle(
                    color: widget.isNightMode ? Colors.white : Colors.black87,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
        
        // Add individual districts
        menuItems.addAll(widget.districts.map((d) {
          final isSel = widget.selectedDistricts.contains(d.id);
          return PopupMenuItem<String>(
            value: d.id,
            height: 34,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Transform.scale(
                    scale: 0.8,
                    child: Checkbox(
                      value: isSel,
                      onChanged: null,
                      activeColor: widget.uiAccent,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  d.name,
                  style: TextStyle(
                    color: widget.isNightMode ? Colors.white : Colors.black87,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }).toList());
        
        return menuItems;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.map_outlined, size: 14, color: widget.uiAccent),
            const SizedBox(width: 4),
            Text(
              widget.selectedDistricts.isEmpty
                  ? 'Все районы'
                  : 'Районы (${widget.selectedDistricts.length})',
              style: TextStyle(
                color: widget.uiTextPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.arrow_drop_down, size: 16, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class MapDayChip extends StatelessWidget {
  const MapDayChip({
    super.key,
    required this.days,
    required this.label,
    required this.selected,
    required this.uiTextPrimary,
    required this.uiAccent,
    required this.isNightMode,
    required this.onSelected,
  });

  final int? days;
  final String label;
  final bool selected;
  final Color uiTextPrimary;
  final Color uiAccent;
  final bool isNightMode;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected
                ? uiAccent
                : (isNightMode
                    ? PulseColors.surfaceSoft.withAlpha(180)
                    : Colors.white.withAlpha(220)),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? uiAccent
                  : (isNightMode
                      ? Colors.white.withAlpha(80)
                      : const Color(0xFF7DD3FC).withAlpha(180)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? (isNightMode ? Colors.black : Colors.white)
                  : uiTextPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
