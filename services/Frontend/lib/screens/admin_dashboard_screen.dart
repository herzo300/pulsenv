import 'dart:async';

import 'package:flutter/material.dart';

import '../services/admin_dashboard_service.dart';
import '../services/device_identity_service.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.initialTwoFactorCode,
  });

  final String initialTwoFactorCode;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminDashboardService _adminService = AdminDashboardService.instance;
  Timer? _refreshTimer;

  Map<String, dynamic>? _metrics;
  List<Map<String, dynamic>> _cameras = const <Map<String, dynamic>>[];
  bool _loading = true;
  bool _claimingSession = true;
  bool _recheckingCameras = false;
  String? _error;
  String? _busyDeviceId;
  String? _busyCameraId;
  String? _localDeviceId;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalDeviceId());
    _bootstrap();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refresh(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _adminService.releaseSession();
    super.dispose();
  }

  Future<void> _loadLocalDeviceId() async {
    final id = await DeviceIdentityService.instance.getCurrentDeviceIdOrNull();
    if (!mounted) {
      return;
    }
    setState(() {
      _localDeviceId = id;
    });
  }

  Future<void> _bootstrap() async {
    try {
      await _adminService.ensureSession(
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _claimingSession = false;
      });
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _claimingSession = false;
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait<dynamic>([
        _adminService.fetchMetrics(twoFactorCode: widget.initialTwoFactorCode),
        _adminService.fetchCameras(twoFactorCode: widget.initialTwoFactorCode),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _metrics = (results[0] as Map<String, dynamic>);
        _cameras = (results[1] as List<Map<String, dynamic>>);
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _updatePolicy({
    required Map<String, dynamic> device,
    bool? mapAccess,
    bool? cameraAccess,
    bool? freeAccess,
  }) async {
    final deviceId = device['device_id']?.toString().trim() ?? '';
    if (deviceId.isEmpty) {
      return;
    }

    setState(() {
      _busyDeviceId = deviceId;
    });

    try {
      await _adminService.updateDevicePolicy(
        deviceId: deviceId,
        mapAccess: mapAccess,
        cameraAccess: cameraAccess,
        freeAccess: freeAccess,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Policy update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceId = null;
        });
      }
    }
  }

  Future<void> _recheckCameras() async {
    if (_recheckingCameras) {
      return;
    }
    setState(() {
      _recheckingCameras = true;
    });
    try {
      final report = await _adminService.recheckCameras(
        twoFactorCode: widget.initialTwoFactorCode,
      );
      if (!mounted) {
        return;
      }
      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Camera check: ${report['streamable'] ?? 0}/${report['total'] ?? 0} streamable',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera recheck failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _recheckingCameras = false;
        });
      }
    }
  }

  Future<void> _toggleCameraVisibility({
    required String cameraId,
    required bool hiddenByAdmin,
  }) async {
    if (cameraId.isEmpty) {
      return;
    }
    setState(() {
      _busyCameraId = cameraId;
    });
    try {
      await _adminService.setCameraVisibility(
        cameraId: cameraId,
        hiddenByAdmin: hiddenByAdmin,
        twoFactorCode: widget.initialTwoFactorCode,
      );
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera visibility update failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyCameraId = null;
        });
      }
    }
  }

  Future<void> _unbindDevice({
    required String deviceId,
    required bool currentDevice,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF0B1324),
        title: const Text('Unbind device', style: TextStyle(color: Colors.white)),
        content: Text(
          currentDevice
              ? 'Unbind this device from admin panel and rotate local device ID?'
              : 'Remove this device from admin registry?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Unbind'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _busyDeviceId = deviceId;
    });
    try {
      await _adminService.unbindDevice(
        deviceId: deviceId,
        twoFactorCode: widget.initialTwoFactorCode,
      );

      if (currentDevice) {
        await _adminService.releaseSession();
        await DeviceIdentityService.instance.regenerateDeviceId();
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Current device unbound and rotated.')),
        );
        Navigator.of(context).pop();
        return;
      }

      await _refresh();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device unbound')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Device unbind failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyDeviceId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF091628),
        elevation: 0,
        title: const Text(
          'ADMIN CONTROL',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            fontSize: 14,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
          if ((_localDeviceId ?? '').isNotEmpty)
            IconButton(
              onPressed: _busyDeviceId == _localDeviceId
                  ? null
                  : () => _unbindDevice(
                        deviceId: _localDeviceId!,
                        currentDevice: true,
                      ),
              tooltip: 'Unbind this device',
              icon: const Icon(Icons.link_off_rounded, color: Colors.white),
            ),
        ],
      ),
      body: _claimingSession
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _buildErrorState()
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          _buildHeroCard(),
                          const SizedBox(height: 16),
                          _buildSummaryGrid(),
                          const SizedBox(height: 16),
                          _buildTrafficCard(),
                          const SizedBox(height: 16),
                          _buildRealtimeGroups(),
                          const SizedBox(height: 16),
                          _buildTopRoutesCard(),
                          const SizedBox(height: 16),
                          _buildCamerasCard(),
                          const SizedBox(height: 16),
                          _buildSentryTestCard(),
                          const SizedBox(height: 16),
                          _buildDevicesCard(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_person_rounded, size: 44, color: Colors.white54),
            const SizedBox(height: 12),
            const Text(
              'Admin session unavailable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _bootstrap,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF102744), Color(0xFF0B1626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFF6EE7F9)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Supabase-backed runtime control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Last activity: ${_readString('last_activity_at', fallback: 'n/a')}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Active window: ${_readInt('active_window_seconds')}s',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Uptime: ${_readString('uptime_human', fallback: '-')}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Storage: ${_readString('storage_mode', fallback: 'unknown')}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if ((_localDeviceId ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Current device: $_localDeviceId',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    final items = <_MetricTileData>[
      _MetricTileData('App opens', _readInt('app_launches_total').toString(), const Color(0xFF6EE7B7), Icons.play_circle_fill_rounded),
      _MetricTileData('Unique users', _readInt('total_unique_users').toString(), const Color(0xFF60A5FA), Icons.people_alt_rounded),
      _MetricTileData('Online now', _readInt('online_users').toString(), const Color(0xFF22D3EE), Icons.radar_rounded),
      _MetricTileData('Peak online', _readInt('peak_active_unique_users').toString(), const Color(0xFFF59E0B), Icons.show_chart_rounded),
      _MetricTileData('Requests', _readInt('total_requests').toString(), const Color(0xFFF472B6), Icons.sync_alt_rounded),
      _MetricTileData('Heartbeats', _readInt('total_heartbeats').toString(), const Color(0xFFA78BFA), Icons.favorite_rounded),
      _MetricTileData('Cameras', _readInt('cameras_total').toString(), const Color(0xFF22C55E), Icons.videocam_rounded),
      _MetricTileData('Hidden cams', _readInt('cameras_hidden').toString(), const Color(0xFFF97316), Icons.visibility_off_rounded),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1726),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: item.accent.withOpacity(0.22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: item.accent, size: 22),
              const Spacer(),
              Text(
                item.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrafficCard() {
    return _SectionCard(
      title: 'Traffic',
      icon: Icons.hub_rounded,
      child: Column(
        children: [
          _buildTrafficRow('Server traffic total', _formatBytes(_readInt('total_traffic_bytes'))),
          _buildTrafficRow('Server traffic 1h', _formatBytes(_readInt('traffic_last_hour_bytes'))),
          _buildTrafficRow('Server traffic 24h', _formatBytes(_readInt('traffic_last_24_hours_bytes'))),
          _buildTrafficRow('Server traffic 7d', _formatBytes(_readInt('traffic_last_7_days_bytes'))),
        ],
      ),
    );
  }

  Widget _buildSentryTestCard() {
    return _SectionCard(
      title: 'Diagnostics & Monitoring',
      icon: Icons.bug_report_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Use this to verify Sentry and error-monitoring agent integration. It will trigger a deliberate runtime exception.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              // Trigger a synthetic exception
              try {
                throw Exception('Test Sentry Exception from Admin Dashboard');
              } catch (exception, stackTrace) {
                await Sentry.captureException(
                  exception,
                  stackTrace: stackTrace,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test exception sent to Sentry!')),
                  );
                }
              }
            },
            icon: const Icon(Icons.flash_on_rounded, color: Colors.orange),
            label: const Text('Send Test Crash to Sentry', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orange, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRealtimeGroups() {
    return Column(
      children: [
        _buildKeyValueCard(
          title: 'Platforms online',
          icon: Icons.devices_rounded,
          values: _readMap('active_platforms'),
        ),
        const SizedBox(height: 16),
        _buildKeyValueCard(
          title: 'App versions online',
          icon: Icons.system_update_alt_rounded,
          values: _readMap('active_app_versions'),
        ),
        const SizedBox(height: 16),
        _buildKeyValueCard(
          title: 'Screens online',
          icon: Icons.space_dashboard_rounded,
          values: _readMap('active_screens'),
        ),
      ],
    );
  }

  Widget _buildKeyValueCard({
    required String title,
    required IconData icon,
    required Map<String, dynamic> values,
  }) {
    return _SectionCard(
      title: title,
      icon: icon,
      child: values.isEmpty
          ? const Text(
              'No active data',
              style: TextStyle(color: Colors.white54),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values.entries
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildTopRoutesCard() {
    final routes = (_metrics?['top_routes'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((route) => route.map((key, value) => MapEntry(key.toString(), value)))
        .toList();

    return _SectionCard(
      title: 'Top backend routes',
      icon: Icons.route_rounded,
      child: routes.isEmpty
          ? const Text('No route data yet', style: TextStyle(color: Colors.white54))
          : Column(
              children: routes
                  .map(
                    (route) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              route['path']?.toString() ?? '-',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                          Text(
                            route['hits']?.toString() ?? '0',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildCamerasCard() {
    return _SectionCard(
      title: 'City cameras',
      icon: Icons.videocam_rounded,
      action: TextButton.icon(
        onPressed: _recheckingCameras ? null : _recheckCameras,
        icon: _recheckingCameras
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync_rounded, size: 16),
        label: const Text('Recheck'),
      ),
      child: _cameras.isEmpty
          ? const Text('No cameras in catalog', style: TextStyle(color: Colors.white54))
          : Column(
              children: _cameras.map(_buildCameraTile).toList(),
            ),
    );
  }

  Widget _buildCameraTile(Map<String, dynamic> camera) {
    final cameraId = camera['camera_id']?.toString() ?? '';
    final name = camera['name']?.toString() ?? 'Camera';
    final streamable = _readBool(camera['streamable'], fallback: false);
    final hiddenByAdmin = _readBool(camera['hidden_by_admin'], fallback: false);
    final hiddenDueToOffline = _readBool(camera['hidden_due_to_offline'], fallback: false);
    final hiddenInMap = _readBool(camera['hidden_in_map'], fallback: true);
    final busy = _busyCameraId == cameraId;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            streamable ? 'Stream: OK' : 'Stream: OFFLINE',
            style: TextStyle(
              color: streamable ? const Color(0xFF34D399) : const Color(0xFFF87171),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hidden: ${hiddenInMap ? 'yes' : 'no'} · '
            'manual=${hiddenByAdmin ? '1' : '0'} · offline=${hiddenDueToOffline ? '1' : '0'}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: hiddenByAdmin,
            onChanged: busy
                ? null
                : (value) => _toggleCameraVisibility(
                      cameraId: cameraId,
                      hiddenByAdmin: value,
                    ),
            title: const Text(
              'Hide on map (admin)',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesCard() {
    final devices = (_metrics?['devices'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((device) => device.map((key, value) => MapEntry(key.toString(), value)))
        .toList();

    return _SectionCard(
      title: 'Devices and access policies',
      icon: Icons.admin_panel_settings_rounded,
      child: devices.isEmpty
          ? const Text('No devices registered yet', style: TextStyle(color: Colors.white54))
          : Column(
              children: devices.map(_buildDeviceTile).toList(),
            ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    final policy = _readInlineMap(device['policy']);
    final deviceId = device['device_id']?.toString() ?? '';
    final busy = _busyDeviceId == deviceId;
    final isCurrentDevice = (_localDeviceId ?? '') == deviceId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  deviceId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isCurrentDevice)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22D3EE).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'THIS DEVICE',
                    style: TextStyle(
                      color: Color(0xFF67E8F9),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy
                    ? null
                    : () => _unbindDevice(
                          deviceId: deviceId,
                          currentDevice: isCurrentDevice,
                        ),
                icon: const Icon(Icons.link_off_rounded, color: Colors.white70, size: 20),
                tooltip: 'Unbind device',
              ),
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${device['platform'] ?? 'unknown'} · ${device['app_version'] ?? 'unknown'}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Last seen: ${device['last_seen_at'] ?? 'n/a'}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['map_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, mapAccess: value),
            title: const Text('Map access', style: TextStyle(color: Colors.white)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['camera_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, cameraAccess: value),
            title: const Text('Camera access', style: TextStyle(color: Colors.white)),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _readBool(policy['free_access'], fallback: true),
            onChanged: busy
                ? null
                : (value) => _updatePolicy(device: device, freeAccess: value),
            title: const Text('Free access', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _readMap(String key) {
    return _readInlineMap(_metrics?[key]);
  }

  Map<String, dynamic> _readInlineMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  int _readInt(String key) {
    final value = _metrics?[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) {
      return value;
    }
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true') {
      return true;
    }
    if (text == 'false') {
      return false;
    }
    return fallback;
  }

  String _readString(String key, {required String fallback}) {
    final value = _metrics?[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    final fixed = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed ${units[unitIndex]}';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1726),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF6EE7F9), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricTileData {
  const _MetricTileData(this.label, this.value, this.accent, this.icon);

  final String label;
  final String value;
  final Color accent;
  final IconData icon;
}
