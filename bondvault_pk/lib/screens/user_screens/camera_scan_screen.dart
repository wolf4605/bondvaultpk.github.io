import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../utils/api_service.dart';
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
  static const _green = Color(0xFF012F21);

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
        ResolutionPreset.medium,
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
      _scanStatus = 'Capturing and analyzing image...';
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
          _scanStatus = 'No valid bond number found. Try aligning clearly.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No bond numbers detected. Please align the 6-digit serial inside the frame.',
            ),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully added $addedCount bond(s)!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Detected bonds were already added.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _scanStatus = 'Capture failed: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process captured image: $error')),
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
          title: const Text('Correct scanned bond'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Six-digit serial number',
                  errorText: numberError,
                ),
                onChanged: (_) => setDialogState(() => numberError = null),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(denomination),
                initialValue: denomination,
                decoration: const InputDecoration(
                  labelText: 'Denomination',
                  border: OutlineInputBorder(),
                ),
                items: BondOcrParser.denominations
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('Rs. $value'),
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
            ElevatedButton(
              onPressed: () {
                final number = numberController.text.trim();
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
              child: const Text('Save'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That bond is already in the scan list.')),
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
    final numbers = _manualEntryController.text
        .split(',')
        .map((number) => number.trim())
        .toList();
    if (numbers.isEmpty ||
        numbers.any(
          (number) =>
              !RegExp(r'^\d{6}$').hasMatch(number) || number == '000000',
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid six-digit bond numbers, separated by commas.',
          ),
        ),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('No bonds scanned yet.')));
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                savedCount > 0
                    ? 'Saved $savedCount bonds. Rs. $denomination failed: ${_responseDetail(response.body)}'
                    : 'Rs. $denomination failed: ${_responseDetail(response.body)}',
              ),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully added $savedCount bonds!')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit scanned bonds: $error')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Prize Bonds'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _cameraPreview(),
          if (_scanStatus.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _scanStatus,
                style: const TextStyle(
                  color: Color(0xFF012F21),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: DropdownButtonFormField<int>(
              key: ValueKey(_selectedDenomination),
              initialValue: _selectedDenomination,
              decoration: const InputDecoration(
                labelText: 'Detected denomination (tap to correct)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: BondOcrParser.denominations
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('Rs. $value'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDenomination = value);
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualEntryController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Manual serial number(s)',
                      hintText: '123456, 654321',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addManualBond,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scanned Bonds (${_scannedBonds.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (_scannedBonds.isNotEmpty)
                  TextButton(
                    onPressed: _clearAllBonds,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _scannedBonds.isEmpty
                ? const Center(
                    child: Text(
                      'Point the camera at the bond serial number.\nDetected bonds will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _scannedBonds.length,
                    itemBuilder: (context, index) {
                      final bond = _scannedBonds[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: _green,
                            child: Icon(
                              Icons.confirmation_number,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            bond.number,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Rs. ${bond.denomination}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Correct bond',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editBond(index),
                              ),
                              IconButton(
                                tooltip: 'Remove bond',
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeBond(index),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSubmitting || _scannedBonds.isEmpty
                          ? null
                          : _submitScannedBonds,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text('Save (${_scannedBonds.length})'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: FloatingActionButton(
                    onPressed: _isProcessingFrame
                        ? null
                        : _captureAndProcessImage,
                    backgroundColor: Colors.teal.shade800,
                    foregroundColor: Colors.white,
                    tooltip: 'Capture Bond',
                    elevation: 2,
                    child: _isProcessingFrame
                        ? const SizedBox(
                            width: 24,
                            height: 24,
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
        ],
      ),
    );
  }

  Widget _cameraPreview() {
    if (_cameraError != null) {
      return Container(
        height: 320,
        width: double.infinity,
        color: Colors.black,
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
        height: 320,
        width: double.infinity,
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 320,
      child: CameraPreview(_controller!),
    );
  }
}
