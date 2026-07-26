import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../map/map_config.dart' show MapConfig, kMapCenterDefault;
import '../../../theme/pulse_colors.dart';
import '../../../utils/offline_tiles_service.dart';

/// Interactive mini-map widget for the complaint form.
///
/// Shows a small map with a draggable pin. When the user taps on the map,
/// coordinates are updated and passed back via [onLocationChanged].
class GpsLocationWidget extends StatefulWidget {
  const GpsLocationWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.isGpsLocation,
    this.onLocationChanged,
  });

  final double? latitude;
  final double? longitude;
  final bool isGpsLocation;
  final void Function(double lat, double lng)? onLocationChanged;

  @override
  State<GpsLocationWidget> createState() => _GpsLocationWidgetState();
}

class _GpsLocationWidgetState extends State<GpsLocationWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  LatLng get _center {
    if (widget.latitude != null && widget.longitude != null) {
      return LatLng(widget.latitude!, widget.longitude!);
    }
    return kMapCenterDefault;
  }

  bool get _hasCoords => widget.latitude != null && widget.longitude != null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Coordinate label
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 6),
          child: Row(
            children: [
              Icon(
                _hasCoords
                    ? (widget.isGpsLocation
                        ? Icons.gps_fixed_rounded
                        : Icons.touch_app_rounded)
                    : Icons.gps_not_fixed_rounded,
                size: 14,
                color: _hasCoords
                    ? (widget.isGpsLocation
                        ? PulseColors.success
                        : PulseColors.primary)
                    : PulseColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _hasCoords
                      ? (widget.isGpsLocation
                          ? 'GPS: ${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)}'
                          : '${widget.latitude!.toStringAsFixed(5)}, ${widget.longitude!.toStringAsFixed(5)} — нажмите на карту для изменения')
                      : 'Нажмите на карту, чтобы указать место',
                  style: TextStyle(
                    color: _hasCoords
                        ? (widget.isGpsLocation
                            ? PulseColors.success
                            : PulseColors.textPrimary)
                        : PulseColors.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        widget.isGpsLocation ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Interactive mini-map
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 180,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _hasCoords ? (widget.isGpsLocation ? 17.5 : 16) : 13,
                    minZoom: 10,
                    maxZoom: 18,
                    onTap: (tapPosition, point) {
                      widget.onLocationChanged?.call(
                        point.latitude,
                        point.longitude,
                      );
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    OfflineTilesService.instance.getTileLayer(MapConfig.tileUrl),
                    if (_hasCoords)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _center,
                            width: widget.isGpsLocation ? 50 : 40,
                            height: widget.isGpsLocation ? 50 : 40,
                            child: widget.isGpsLocation
                                ? const _HumanMarker()
                                : const _PinMarker(),
                          ),
                        ],
                      ),
                  ],
                ),
                // Crosshair overlay when no coords
                if (!_hasCoords)
                  Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 28,
                      color: PulseColors.primary,
                    ),
                  ),
                // Border overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: PulseColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(GpsLocationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Move map to new coordinates when they change externally (e.g. GPS)
    if (widget.latitude != oldWidget.latitude ||
        widget.longitude != oldWidget.longitude) {
      if (_hasCoords) {
        _mapController.move(_center, widget.isGpsLocation ? 17.5 : 16);
      }
    }
  }
}

/// Animated pin marker for the mini-map.
class _PinMarker extends StatelessWidget {
  const _PinMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: PulseColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: PulseColors.primary.withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.place_rounded, color: Colors.white, size: 16),
        ),
        // Pin shadow dot
        Container(
          width: 6,
          height: 3,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}

/// Custom green human figure marker for GPS location.
class _HumanMarker extends StatelessWidget {
  const _HumanMarker();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: PulseColors.success,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: PulseColors.success.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.accessibility_new_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        // Pin shadow dot
        Container(
          width: 8,
          height: 4,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
