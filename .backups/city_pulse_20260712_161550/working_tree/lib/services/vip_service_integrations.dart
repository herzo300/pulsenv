import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:rive/rive.dart';

import '../config/theme.dart';

/// 🔒 1. Local Biometric Auth Service (VIP Folder Protection)
class VipLocalAuth {
  static final _auth = LocalAuthentication();

  static Future<bool> canAuthenticate() async {
    final isSupported = await _auth.isDeviceSupported();
    final canCheck = await _auth.canCheckBiometrics;
    return isSupported && canCheck;
  }

  static Future<bool> authenticate({required String reason}) async {
    try {
      if (!await canAuthenticate()) return false;
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      debugPrint("Biometric auth error: $e");
      return false;
    }
  }
}

/// 📱 2. Nearby Mesh Network Service (P2P geosharing for all users)
class NearbyMeshService {
  static const String strategyName = "P2P_MESH_SOS";
  static final Strategy strategy = Strategy.P2P_CLUSTER;

  static Future<bool> startSharing({
    required String username,
    required String encryptedCoords,
    required Function(String payload) onReceived,
  }) async {
    try {
      // Check permissions first
      bool locationGranted = await Nearby().checkLocationPermission();
      if (!locationGranted) {
        await Nearby().askLocationPermission();
      }

      // Start Advertising (broadcasting location)
      await Nearby().startAdvertising(
        username,
        strategy,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(id, onPayLoadRecieved: (endpointId, payload) {
            if (payload.type == PayloadType.BYTES && payload.bytes != null) {
              final text = String.fromCharCodes(payload.bytes!);
              onReceived(text);
            }
          });
        },
        onConnectionResult: (id, status) {
          debugPrint("Mesh connection status: $status");
        },
        onDisconnected: (id) {
          debugPrint("Mesh disconnected from: $id");
        },
      );

      // Start Discovery (receiving locations)
      await Nearby().startDiscovery(
        username,
        strategy,
        onEndpointFound: (id, name, serviceId) async {
          // Auto-request connection to exchange coordinates
          await Nearby().requestConnection(
            username,
            id,
            onConnectionInitiated: (connId, info) async {
              await Nearby().acceptConnection(connId, onPayLoadRecieved: (endpointId, payload) {
                if (payload.type == PayloadType.BYTES && payload.bytes != null) {
                  final text = String.fromCharCodes(payload.bytes!);
                  onReceived(text);
                }
              });
            },
            onConnectionResult: (connId, status) {
              if (status == Status.CONNECTED) {
                // Send our coordinates
                Nearby().sendBytesPayload(connId, Uint8List.fromList(encryptedCoords.codeUnits));
              }
            },
            onDisconnected: (connId) {},
          );
        },
        onEndpointLost: (id) {},
      );

      return true;
    } catch (e) {
      debugPrint("Mesh network error: $e");
      return false;
    }
  }

  static Future<void> stopSharing() async {
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
  }
}

/// 📝 3. Offline OCR Scanner Service (VIP ЖКХ Audit)
class VipOcrScanner {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static Future<Map<String, dynamic>> parseReceipt(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      String text = recognizedText.text;
      debugPrint("OCR recognized text length: ${text.length}");

      // Extract values using simple regex
      double totalAmount = 0.0;
      double heatingTariff = 0.0;

      final totalMatch = RegExp(r'(?:итого|к оплате|сумма)\s*:?\s*(\d+[\.,]\d{2})', caseSensitive: false).firstMatch(text);
      if (totalMatch != null) {
        totalAmount = double.tryParse(totalMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      final heatingMatch = RegExp(r'(?:отоплен|тепло)\s*:?\s*(\d+[\.,]\d{2})', caseSensitive: false).firstMatch(text);
      if (heatingMatch != null) {
        heatingTariff = double.tryParse(heatingMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      }

      return {
        "success": true,
        "raw_text": text,
        "total_amount": totalAmount,
        "heating_tariff": heatingTariff,
      };
    } catch (e) {
      debugPrint("OCR parsing error: $e");
      return {"success": false, "error": e.toString()};
    }
  }
}

/// 📹 4. VIP RTSP Video Camera Player Widget
class VipCameraPlayer extends StatefulWidget {
  final String rtspUrl;

  const VipCameraPlayer({super.key, required this.rtspUrl});

  @override
  State<VipCameraPlayer> createState() => _VipCameraPlayerState();
}

class _VipCameraPlayerState extends State<VipCameraPlayer> {
  late final Player _player;
  late final VideoController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    MediaKit.ensureInitialized();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.rtspUrl)).then((_) {
      if (mounted) {
        setState(() => _initialized = true);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.amber),
      );
    }
    return Video(
      controller: _controller,
      controls: NoVideoControls,
    );
  }
}

/// 🎨 5. VIP Rive HUD Animation Player
class VipRiveWidget extends StatelessWidget {
  final String animationPath;

  const VipRiveWidget({super.key, required this.animationPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: PulseColors.surfaceGlass,
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: RiveAnimation.asset(
          animationPath,
          fit: BoxFit.cover,
          animations: const ['idle', 'active'],
          placeHolder: const Center(
            child: CircularProgressIndicator(color: Colors.amber),
          ),
        ),
      ),
    );
  }
}
