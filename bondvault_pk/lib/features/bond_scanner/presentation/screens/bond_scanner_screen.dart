import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../widgets/widgets.dart';
import '../../data/services/camera_service.dart';
import 'scan_result_screen.dart';

class BondScannerScreen extends StatefulWidget {
  final String accessToken;

  const BondScannerScreen({super.key, required this.accessToken});

  @override
  State<BondScannerScreen> createState() => _BondScannerScreenState();
}

class _BondScannerScreenState extends State<BondScannerScreen> {
  final CameraService _cameraService = CameraService();
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    final success = await _cameraService.initialize();
    if (!mounted) return;
    setState(() {
      _isInitializing = false;
      if (!success) {
        _errorMessage = 'Unable to initialize device camera. Please check camera permissions.';
      }
    });
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_cameraService.isInitialized) return;

    setState(() => _isCapturing = true);
    try {
      final File? photoFile = await _cameraService.takePicture();
      if (!mounted) return;
      setState(() => _isCapturing = false);

      if (photoFile != null) {
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => ScanResultScreen(
              imageFile: photoFile,
              accessToken: widget.accessToken,
            ),
          ),
        );
        if (result == true && mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Prize Bond Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isInitializing
          ? const AppLoadingIndicator(message: 'Initializing camera...')
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_enhance_outlined,
                      size: 64,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _initCamera,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Camera'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera Viewport
                CameraPreview(_cameraService.controller!),

                // Framing Overlay Guide
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.88,
                          height: MediaQuery.of(context).size.width * 0.55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.secondary,
                              width: 3,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ALIGN PRIZE BOND HERE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Hold steady under good lighting.\nEnsure serial number and denomination are clear.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Capture FAB
                Positioned(
                  bottom: 36,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      backgroundColor: AppColors.primary,
                      onPressed: _isCapturing ? null : _capturePhoto,
                      child: _isCapturing
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Icon(
                              Icons.camera_alt,
                              size: 36,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
