import 'package:flutter/material.dart';
import '../../../widgets/premium/pulse_liquid_glass.dart';

class MapFloatingControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onLocationTap;
  final VoidCallback onLayerToggle;
  final bool isSatellite;

  const MapFloatingControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocationTap,
    required this.onLayerToggle,
    this.isSatellite = false,
  });

  @override
  Widget build(BuildContext context) {
    return PulseLiquidControls(
      direction: Axis.vertical,
      children: [
        IconButton(
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          onPressed: onZoomIn,
        ),
        const Divider(color: Colors.white24, height: 1),
        IconButton(
          icon: const Icon(Icons.remove_rounded, color: Colors.white),
          onPressed: onZoomOut,
        ),
        const Divider(color: Colors.white24, height: 1),
        IconButton(
          icon: const Icon(Icons.my_location_rounded, color: Color(0xFF00F0FF)),
          onPressed: onLocationTap,
        ),
        const Divider(color: Colors.white24, height: 1),
        IconButton(
          icon: Icon(
            isSatellite ? Icons.map_rounded : Icons.layers_rounded,
            color: Colors.white,
          ),
          onPressed: onLayerToggle,
        ),
      ],
    );
  }
}
