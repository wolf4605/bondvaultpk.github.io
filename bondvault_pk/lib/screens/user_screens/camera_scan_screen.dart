import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/widgets.dart';
import 'bond_ocr_parser.dart';

class _ScannedBond {
  final String number;
  final int denomination;

  const _ScannedBond(this.number, this.denomination);
}

class CameraScanScreen extends StatefulWidget {
  final String accessToken;
  final VoidCallback onBondsAdded;

  const CameraScanScreen({
    super.key,
    required this.accessToken,
    required this.onBondsAdded,
  });

  @override
  State<CameraScanScreen> createState() => _CameraScanScreenState();
}

class _CameraScanScreenState extends State<CameraScanScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  final List<_ScannedBond> _scannedBonds = [];
  final Set<String> _processedBondKeys = {};
  final TextEditingController _manualEntryController = TextEditingController();

  late final TextRecognizer _textRecognizer;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;
  bool _isSubmitting = false;
  int _selectedDenomination = 750;
  String? _cameraError;
  String _scanStatus = 'Align a bond number inside the frame.';

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(
            () => _cameraError = 'No camera is available on this device.',
          );
        }
        return;
      }

      final camera = _cameras.firstWhere(
        (description) => description.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      _controller = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _cameraError = 'Could not start camera: $error';
        });
      }
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_isProcessingFrame ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return;
    }
    setState(() {
      _isProcessingFrame = true;
      _scanStatus = 'Analyzing prize bond text & serials...';
    });

    try {
      final picture = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(picture.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      final denomination = BondOcrParser.detectDenomination(
        recognizedText.text,
      );
      final numbers = BondOcrParser.findBondNumbers(recognizedText.text);

      if (!mounted) return;

      final bondDenomination = denomination ?? _selectedDenomination;
      if (denomination != null) {
        setState(() => _selectedDenomination = denomination);
      }

      if (numbers.isEmpty) {
        setState(() {
          _scanStatus = 'No 6-digit serial found. Please align clearly.';
        });
        showAppToast(
          context,
          'No bond numbers detected. Align the 6-digit serial inside the frame.',
          type: AppNotificationType.warning,
        );
        return;
      }

      var addedCount = 0;
      for (final number in numbers.reversed) {
        final key = '$bondDenomination:$number';
        final exists = _scannedBonds.any(
          (b) => b.number == number && b.denomination == bondDenomination,
        );
        if (!exists && _processedBondKeys.add(key)) {
          _scannedBonds.insert(0, _ScannedBond(number, bondDenomination));
          addedCount++;
        }
      }

      setState(() {
        _scanStatus = addedCount > 0
            ? 'Added $addedCount bond(s): ${numbers.join(', ')}'
            : 'Detected bonds already in list.';
      });

      if (addedCount > 0) {
        showAppToast(
          context,
          'Added $addedCount bond(s) to scan list!',
          type: AppNotificationType.success,
        );
      } else {
        showAppToast(
          context,
          'Detected bonds were already added.',
          type: AppNotificationType.info,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _scanStatus = 'Capture error: $error');
        showAppToast(
          context,
          'Could not process captured image: $error',
          type: AppNotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingFrame = false);
      }
    }
  }

  void _addBond(String number, int denomination) {
    final key = '$denomination:$number';
    final exists = _scannedBonds.any(
      (b) => b.number == number && b.denomination == denomination,
    );
    if (!exists && _processedBondKeys.add(key)) {
      _scannedBonds.insert(0, _ScannedBond(number, denomination));
    }
  }

  void _removeBond(int index) {
    final bond = _scannedBonds[index];
    setState(() {
      _processedBondKeys.remove('${bond.denomination}:${bond.number}');
      _scannedBonds.removeAt(index);
    });
  }

  void _clearAllBonds() {
    setState(() {
      _scannedBonds.clear();
      _processedBondKeys.clear();
    });
  }

  Future<void> _editBond(int index) async {
    final bond = _scannedBonds[index];
    final numberController = TextEditingController(text: bond.number);
    var denomination = bond.denomination;
    String? numberError;

    final correctedBond = await showDialog<_ScannedBond>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Correct Scanned Bond'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Six-Digit Serial Number',
                  errorText: numberError,
                  prefixIcon: const Icon(Icons.numbers),
                ),
                onChanged: (_) => setDialogState(() => numberError = null),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(denomination),
                initialValue: denomination,
                decoration: const InputDecoration(
                  labelText: 'Denomination',
                  prefixIcon: Icon(Icons.currency_exchange),
                  border: OutlineInputBorder(),
                ),
                items: BondOcrParser.denominations
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Rs. ${formatNumber(value)}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => denomination = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Save Changes',
              fullWidth: false,
              onPressed: () {
                final number = numberController.text.trim().padLeft(6, '0');
                if (!RegExp(r'^\d{6}$').hasMatch(number) ||
                    number == '000000') {
                  setDialogState(
                    () => numberError = 'Enter a valid six-digit number.',
                  );
                  return;
                }
                Navigator.pop(
                  dialogContext,
                  _ScannedBond(number, denomination),
                );
              },
            ),
          ],
        ),
      ),
    );
    numberController.dispose();

    if (!mounted || correctedBond == null) return;
    final correctedKey =
        '${correctedBond.denomination}:${correctedBond.number}';
    final alreadyAdded = _scannedBonds.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.number == correctedBond.number &&
          entry.value.denomination == correctedBond.denomination,
    );
    if (alreadyAdded) {
      showAppToast(
        context,
        'That bond is already in the scan list.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() {
      _processedBondKeys.remove('${bond.denomination}:${bond.number}');
      _scannedBonds[index] = correctedBond;
      _processedBondKeys.add(correctedKey);
    });
  }

  void _addManualBond() {
    final rawText = _manualEntryController.text.trim();
    if (rawText.isEmpty) {
      showAppToast(
        context,
        'Please enter a bond number.',
        type: AppNotificationType.warning,
      );
      return;
    }
    final numbers = rawText
        .split(',')
        .map((number) => number.trim().padLeft(6, '0'))
        .toList();
    if (numbers.isEmpty ||
        numbers.any(
          (number) =>
              !RegExp(r'^\d{6}$').hasMatch(number) || number == '000000',
        )) {
      showAppToast(
        context,
        'Enter valid six-digit bond numbers separated by commas.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() {
      for (final number in numbers) {
        _addBond(number, _selectedDenomination);
      }
      _manualEntryController.clear();
    });
  }

  Future<void> _submitScannedBonds() async {
    if (_scannedBonds.isEmpty) {
      showAppToast(
        context,
        'No bonds scanned yet.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    var savedCount = 0;
    try {
      final denominations = _scannedBonds
          .map((bond) => bond.denomination)
          .toSet();

      for (final denomination in denominations) {
        final group = _scannedBonds
            .where((bond) => bond.denomination == denomination)
            .toList();
        final response = await ApiService.addBonds(
          accessToken: widget.accessToken,
          denomination: denomination,
          bonds: group.map((bond) => bond.number).toList(),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          if (!mounted) return;
          if (savedCount > 0) widget.onBondsAdded();
          showAppNotificationSheet(
            context: context,
            title: 'Partial Registration Error',
            message:
                'Saved $savedCount bonds. Rs. $denomination failed: ${_responseDetail(response.body)}',
            type: AppNotificationType.error,
          );
          return;
        }

        savedCount += group.length;
        if (mounted) {
          setState(() {
            _scannedBonds.removeWhere(
              (bond) => bond.denomination == denomination,
            );
          });
        }
      }

      if (!mounted) return;
      widget.onBondsAdded();
      showAppNotificationSheet(
        context: context,
        title: 'Bonds Registered',
        message:
            'Successfully registered $savedCount prize bonds to portfolio!',
        type: AppNotificationType.success,
        onDismiss: () => Navigator.pop(context),
      );
    } catch (error) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Submission Error',
        message: 'Could not submit scanned bonds: $error',
        type: AppNotificationType.error,
      );
      if (savedCount > 0) widget.onBondsAdded();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _responseDetail(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic> && data['detail'] != null) {
        return data['detail'].toString();
      }
    } on FormatException {
      return 'The server returned an invalid response.';
    }
    return 'Request failed.';
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    final controller = _controller;
    if (controller != null) {
      controller.dispose();
    }
    _textRecognizer.close();
    _manualEntryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Prize Bond Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
            ),
            child: Column(
              children: [
                // Camera Framing Box
                _buildCameraPreview(),

                if (_scanStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF064E3B)
                            : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _scanStatus,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // Controls Section Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Denomination & Manual Add',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          key: ValueKey(_selectedDenomination),
                          initialValue: _selectedDenomination,
                          decoration: const InputDecoration(
                            labelText: 'Selected Denomination',
                            prefixIcon: Icon(Icons.currency_exchange),
                          ),
                          items: BondOcrParser.denominations
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text('Rs. ${formatNumber(value)}'),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedDenomination = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _manualEntryController,
                                keyboardType: TextInputType.number,
                                labelText: 'Manual serial number(s)',
                                hintText: '123456, 654321',
                                prefixIcon: const Icon(Icons.pin),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AppButton(
                              label: '+ Add',
                              fullWidth: false,
                              height: 48,
                              onPressed: _addManualBond,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Scanned Bonds List Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Scanned Bonds List (${_scannedBonds.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (_scannedBonds.isNotEmpty)
                        TextButton.icon(
                          onPressed: _clearAllBonds,
                          icon: const Icon(
                            Icons.delete_sweep,
                            color: Colors.red,
                            size: 18,
                          ),
                          label: const Text(
                            'Clear All',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Scanned Items List
                _scannedBonds.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: AppEmptyState(
                          icon: Icons.document_scanner_outlined,
                          title: 'No Scanned Bonds Yet',
                          message: 'Align the camera at a prize bond serial number and tap the camera button to capture.',
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _scannedBonds.length,
                        itemBuilder: (context, index) {
                          final bond = _scannedBonds[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.confirmation_number,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bond.number,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.onSurface,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${formatNumber(bond.denomination)}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    onPressed: () => _editBond(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeBond(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 20),

                // Submit Action Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppButton(
                    label: 'Register Scanned Bonds (${_scannedBonds.length})',
                    isLoading: _isSubmitting,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    onPressed: _isSubmitting || _scannedBonds.isEmpty
                        ? null
                        : _submitScannedBonds,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_cameraError != null) {
      return Container(
        height: 260,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _cameraError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    if (!_isCameraInitialized || _controller == null) {
      return Container(
        height: 260,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.secondary),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      height: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CameraPreview(_controller!),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
              ),
              child: Center(
                child: Container(
                  width: 280,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.secondaryContainer,
                      width: 3,
                    ),
                  ),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'ALIGN SERIAL NUMBER HERE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'camera_capture_btn',
                onPressed: _isProcessingFrame ? null : _captureAndProcessImage,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                child: _isProcessingFrame
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.camera_alt),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
