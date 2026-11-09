import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../config/app_theme.dart';
import '../../../../config/responsive.dart';
import '../../../../utils/app_utils.dart';
import '../../../../widgets/widgets.dart';
import '../../data/models/recognition_result.dart';
import '../../data/services/bond_scanner_service.dart';
import '../../data/services/denomination_detector.dart';
import '../../repositories/bond_scan_repository.dart';
import '../widgets/image_preview.dart';
import '../widgets/scan_result_card.dart';

class ScanResultScreen extends StatefulWidget {
  final File imageFile;
  final String accessToken;

  const ScanResultScreen({
    super.key,
    required this.imageFile,
    required this.accessToken,
  });

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  final BondScannerService _scannerService = BondScannerService();
  final _serialController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = true;
  bool _isSubmitting = false;
  RecognitionResult? _result;
  int _selectedDenomination = 750;

  @override
  void initState() {
    super.initState();
    _processPhoto();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _scannerService.dispose();
    super.dispose();
  }

  Future<void> _processPhoto() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _scannerService.scanBond(widget.imageFile);
      if (!mounted) return;
      setState(() {
        _result = res;
        _isProcessing = false;
        if (res.detectedDenomination != null) {
          _selectedDenomination = res.detectedDenomination!;
        }
        if (res.detectedSerial != null) {
          _serialController.text = res.detectedSerial!;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _submitBond() async {
    if (!_formKey.currentState!.validate()) return;
    final serial = _serialController.text.trim().padLeft(6, '0');

    setState(() => _isSubmitting = true);
    try {
      final res = await BondScanRepository.submitScannedBond(
        accessToken: widget.accessToken,
        denomination: _selectedDenomination,
        serialNumber: serial,
      );

      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 201) {
        showAppNotificationSheet(
          context: context,
          title: 'Prize Bond Scanned & Saved!',
          message:
              'Rs. ${formatNumber(_selectedDenomination)} Prize Bond #$serial has been verified and registered to your portfolio successfully.',
          type: AppNotificationType.success,
          onDismiss: () {
            Navigator.pop(context, true);
          },
        );
      } else {
        showAppNotificationSheet(
          context: context,
          title: 'Submission Warning',
          message:
              'Bond #$serial submission response status: ${res.statusCode}. Please verify serial number.',
          type: AppNotificationType.warning,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not submit scanned bond to backend: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Scanned Bond Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isProcessing
          ? const AppLoadingIndicator(
              message: 'Analyzing prize bond colors, patterns & OCR text...',
            )
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 12),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Captured Photo Preview
                        BondImagePreview(
                          imageFile: widget.imageFile,
                          onRetake: () => Navigator.pop(context),
                        ),
                        const SizedBox(height: 16),

                        // OCR Recognition Summary Card
                        if (_result != null)
                          ScanResultCard(
                            result: _result!,
                            onCandidateSelected: (cand) {
                              setState(() {
                                _serialController.text = cand;
                                _result = _result!.copyWith(
                                  detectedSerial: cand,
                                );
                              });
                            },
                          ),
                        const SizedBox(height: 20),

                        // Manual Edit / Review Card
                        const AppSectionHeader(
                          title: 'Review & Confirm Details',
                          tagline: 'MANUAL CORRECTION',
                        ),
                        const SizedBox(height: 8),
                        AppCard(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Select Denomination',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<int>(
                                initialValue: _selectedDenomination,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.currency_exchange),
                                ),
                                items: DenominationDetector.validDenominations
                                    .map(
                                      (d) => DropdownMenuItem(
                                        value: d,
                                        child: Text('Rs. ${formatNumber(d)}'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedDenomination = val);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '6-Digit Serial Number',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              AppTextField(
                                controller: _serialController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                labelText: 'Serial Number (e.g. 084700)',
                                prefixIcon: const Icon(Icons.pin),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Serial number is required';
                                  }
                                  final clean = v.trim().padLeft(6, '0');
                                  if (clean.length != 6 ||
                                      !RegExp(r'^[0-9]+$').hasMatch(clean)) {
                                    return 'Must be a 6-digit number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              AppButton(
                                label: 'Confirm & Register Bond',
                                isLoading: _isSubmitting,
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                onPressed: _submitBond,
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 44,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Retake Photograph'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
