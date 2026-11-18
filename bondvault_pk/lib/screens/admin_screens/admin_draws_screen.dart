import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../config/responsive.dart';
import '../../utils/api_service.dart';
import '../../utils/app_utils.dart';
import '../../widgets/widgets.dart';
import '../user_screens/draw_detail_screen.dart';

class AdminDrawsScreen extends StatefulWidget {
  final String accessToken;

  const AdminDrawsScreen({super.key, required this.accessToken});

  @override
  State<AdminDrawsScreen> createState() => _AdminDrawsScreenState();
}

class _AdminDrawsScreenState extends State<AdminDrawsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  List<dynamic> _drawlists = [];
  List<dynamic> _schedules = [];

  String _drawsFilter = 'All';
  final _drawsSearchController = TextEditingController();
  String _drawsSearchQuery = '';

  String? _deletingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _drawsSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Fetch imported drawlists
      final res = await http.get(
        Uri.parse('${AppConfig.baseUrl}/drawlists'),
        headers: {'Authorization': 'Bearer ${widget.accessToken}'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        if (data is List) {
          _drawlists = data;
        }
      }

      // 2. Fetch upcoming schedules
      final scheduleData = await ApiService.fetchDrawSchedule(
        accessToken: widget.accessToken,
        isAdmin: true,
      );
      if (scheduleData != null && mounted) {
        _schedules = scheduleData;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDrawlist(
    String drawId,
    int denomination,
    String date,
  ) async {
    showAppNotificationSheet(
      context: context,
      title: 'Delete Gazette Drawlist',
      message:
          'Are you sure you want to permanently delete the Rs. $denomination ($date) official gazette drawlist and all its winning bond records?',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Delete',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          Navigator.pop(context);
          setState(() => _deletingId = drawId);
          try {
            final res = await ApiService.deleteDrawlist(
              accessToken: widget.accessToken,
              drawId: drawId,
            );
            if (res.statusCode == 200) {
              _fetchData();
              if (!mounted) return;
              showAppNotificationSheet(
                context: context,
                title: 'Drawlist Deleted',
                message:
                    'Rs. $denomination ($date) official gazette and winning records deleted successfully.',
                type: AppNotificationType.success,
              );
            } else {
              if (!mounted) return;
              showAppToast(
                context,
                'Failed to delete drawlist.',
                type: AppNotificationType.error,
              );
            }
          } catch (_) {
          } finally {
            if (mounted) setState(() => _deletingId = null);
          }
        },
      ),
    );
  }

  Future<void> _deleteSchedule(int denomination, String drawDate) async {
    showAppNotificationSheet(
      context: context,
      title: 'Delete Scheduled Draw',
      message:
          'Remove Rs. $denomination draw scheduled for $drawDate from system schedule?',
      type: AppNotificationType.error,
      dismissLabel: 'Cancel',
      customAction: AppButton(
        label: 'Confirm Remove',
        variant: AppButtonVariant.danger,
        onPressed: () async {
          Navigator.pop(context);
          setState(() => _deletingId = '$denomination-$drawDate');
          try {
            final res = await ApiService.deleteDrawSchedule(
              accessToken: widget.accessToken,
              denomination: denomination,
              drawDate: drawDate,
            );
            if (res.statusCode == 200) {
              _fetchData();
              if (!mounted) return;
              showAppNotificationSheet(
                context: context,
                title: 'Schedule Removed',
                message:
                    'Rs. $denomination draw ($drawDate) removed from system schedule.',
                type: AppNotificationType.success,
              );
            } else {
              if (!mounted) return;
              showAppToast(
                context,
                'Failed to remove schedule.',
                type: AppNotificationType.error,
              );
            }
          } catch (_) {
          } finally {
            if (mounted) setState(() => _deletingId = null);
          }
        },
      ),
    );
  }

  int _getDefaultPrize(int denomination, int position) {
    switch (denomination) {
      case 100:
        return position == 1 ? 700000 : (position == 2 ? 200000 : 1000);
      case 200:
        return position == 1 ? 750000 : (position == 2 ? 250000 : 1250);
      case 750:
        return position == 1 ? 1500000 : (position == 2 ? 500000 : 9300);
      case 1500:
        return position == 1 ? 3000000 : (position == 2 ? 1000000 : 18500);
      case 25000:
        return position == 1 ? 30000000 : (position == 2 ? 10000000 : 300000);
      case 40000:
        return position == 1 ? 80000000 : (position == 2 ? 30000000 : 500000);
      default:
        return position == 1 ? 1500000 : (position == 2 ? 500000 : 9300);
    }
  }

  Future<void> _showImportGazetteDialog() async {
    int selectedDenom = 750;
    final dateCtrl = TextEditingController(
      text: DateTime.now().toString().substring(0, 10),
    );
    final firstPrizeCtrl = TextEditingController();
    final secondPrizeCtrl = TextEditingController();
    final thirdPrizeCtrl = TextEditingController();

    final firstPrizeAmountCtrl = TextEditingController(text: '1500000');
    final secondPrizeAmountCtrl = TextEditingController(text: '500000');
    final thirdPrizeAmountCtrl = TextEditingController(text: '9300');

    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    List<String> parseBonds(String raw) {
      return raw
          .replaceAll('\n', ',')
          .replaceAll(' ', ',')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((s) => s.padLeft(6, '0'))
          .toList();
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF003527), Color(0xFF064E3B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.note_add_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Import Gazette Drawlist',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Upload official prize draw results data',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DENOMINATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDenom,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.money),
                            ),
                            items: AppDenominations.dropdownItems(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() {
                                  selectedDenom = v;
                                  firstPrizeAmountCtrl.text = _getDefaultPrize(
                                    v,
                                    1,
                                  ).toString();
                                  secondPrizeAmountCtrl.text = _getDefaultPrize(
                                    v,
                                    2,
                                  ).toString();
                                  thirdPrizeAmountCtrl.text = _getDefaultPrize(
                                    v,
                                    3,
                                  ).toString();
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            'DRAW DATE (YYYY-MM-DD)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: dateCtrl,
                            labelText: 'Draw Date (e.g. 2026-11-15)',
                            prefixIcon: const Icon(
                              Icons.calendar_today_outlined,
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 10)
                                ? 'Valid date YYYY-MM-DD required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            '1ST PRIZE DETAILS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppTextField(
                                  controller: firstPrizeCtrl,
                                  labelText: '1st Prize bond #',
                                  prefixIcon: const Icon(
                                    Icons.emoji_events_outlined,
                                  ),
                                  validator: (v) =>
                                      (v == null || parseBonds(v).isEmpty)
                                      ? 'Bond #'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: firstPrizeAmountCtrl,
                                  keyboardType: TextInputType.number,
                                  labelText: '1st Amount (Rs.)',
                                  prefixIcon: const Icon(Icons.money),
                                  validator: (v) =>
                                      (v == null ||
                                          int.tryParse(v.trim()) == null)
                                      ? 'Amount'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            '2ND PRIZE DETAILS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: AppTextField(
                                  controller: secondPrizeCtrl,
                                  labelText:
                                      '2nd Prize bond #s (comma separated)',
                                  prefixIcon: const Icon(
                                    Icons.emoji_events_outlined,
                                  ),
                                  validator: (v) =>
                                      (v == null || parseBonds(v).isEmpty)
                                      ? 'Bond #s'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: AppTextField(
                                  controller: secondPrizeAmountCtrl,
                                  keyboardType: TextInputType.number,
                                  labelText: '2nd Amount (Rs.)',
                                  prefixIcon: const Icon(Icons.money),
                                  validator: (v) =>
                                      (v == null ||
                                          int.tryParse(v.trim()) == null)
                                      ? 'Amount'
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          const Text(
                            '3RD PRIZE DETAILS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: thirdPrizeAmountCtrl,
                            keyboardType: TextInputType.number,
                            labelText: '3rd Prize Amount per bond (Rs.)',
                            prefixIcon: const Icon(Icons.money),
                            validator: (v) =>
                                (v == null || int.tryParse(v.trim()) == null)
                                ? 'Amount'
                                : null,
                          ),
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: thirdPrizeCtrl,
                            labelText: '3rd Prize bond numbers (comma/space separated)',
                            prefixIcon: const Icon(Icons.emoji_events_outlined),
                            maxLines: 3,
                            validator: (v) =>
                                (v == null || parseBonds(v).isEmpty)
                                ? 'At least one 3rd prize bond required'
                                : null,
                          ),
                          const SizedBox(height: 24),

                          AppButton(
                            label: 'Import & Save Gazette',
                            isLoading: isSubmitting,
                            icon: const Icon(
                              Icons.upload_file_outlined,
                              size: 18,
                            ),
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() => isSubmitting = true);

                              final firsts = parseBonds(firstPrizeCtrl.text);
                              final seconds = parseBonds(secondPrizeCtrl.text);
                              final thirds = parseBonds(thirdPrizeCtrl.text);

                              try {
                                final res = await ApiService.importDrawlist(
                                  accessToken: widget.accessToken,
                                  denomination: selectedDenom,
                                  drawDate: dateCtrl.text.trim(),
                                  firstPrizeBonds: firsts,
                                  secondPrizeBonds: seconds,
                                  thirdPrizeBonds: thirds,
                                );

                                if (res.statusCode == 201 ||
                                    res.statusCode == 200) {
                                  _fetchData();
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (mounted) {
                                    showAppNotificationSheet(
                                      context: this.context,
                                      title: 'Gazette Imported Successfully',
                                      message:
                                          'Rs. $selectedDenom gazette drawlist dated ${dateCtrl.text.trim()} imported with ${firsts.length + seconds.length + thirds.length} winning bonds.',
                                      type: AppNotificationType.success,
                                    );
                                  }
                                } else {
                                  final data = jsonDecode(res.body);
                                  if (dialogContext.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                    showAppToast(
                                      dialogContext,
                                      data['detail'] ??
                                          'Failed to import gazette.',
                                      type: AppNotificationType.error,
                                    );
                                  }
                                }
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                  showAppToast(
                                    dialogContext,
                                    'Error: $e',
                                    type: AppNotificationType.error,
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      dateCtrl.dispose();
      firstPrizeCtrl.dispose();
      secondPrizeCtrl.dispose();
      thirdPrizeCtrl.dispose();
    });
  }

  Future<void> _showAddScheduleDialog() async {
    int selectedDenom = 750;
    DateTime? selectedDate = DateTime.now().add(const Duration(days: 30));
    final locationController = TextEditingController(
      text: 'State Bank of Pakistan (SBP)',
    );
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: Responsive.maxContentWidth(context),
              maxHeight: MediaQuery.sizeOf(context).height * 0.85,
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Schedule Draw Entry',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Set prize bond draw date and SBP venue location',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DENOMINATION (PKR)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<int>(
                            initialValue: selectedDenom,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.money),
                            ),
                            items: AppDenominations.dropdownItems(),
                            onChanged: (v) {
                              if (v != null) {
                                setDialogState(() => selectedDenom = v);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'DRAW DATE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    selectedDate ??
                                    DateTime.now().add(
                                      const Duration(days: 30),
                                    ),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 1095),
                                ),
                              );
                              if (picked != null) {
                                setDialogState(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    selectedDate != null
                                        ? '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                                        : 'Select Draw Date',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.event,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'DRAW LOCATION / VENUE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: locationController,
                            labelText: 'e.g. SBP Lahore or Rawalpindi',
                            hintText: 'State Bank of Pakistan (SBP)',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Draw location is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          AppButton(
                            label: 'Publish Draw Schedule',
                            isLoading: isSubmitting,
                            icon: const Icon(Icons.calendar_today, size: 18),
                            onPressed: () async {
                              if (!formKey.currentState!.validate() ||
                                  selectedDate == null) {
                                if (selectedDate == null) {
                                  showAppToast(
                                    dialogContext,
                                    'Please select a draw date.',
                                    type: AppNotificationType.warning,
                                  );
                                }
                                return;
                              }
                              setDialogState(() => isSubmitting = true);
                              try {
                                final dateStr =
                                    '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
                                final res = await ApiService.addDrawSchedule(
                                  accessToken: widget.accessToken,
                                  denomination: selectedDenom,
                                  drawDate: dateStr,
                                  location: locationController.text.trim(),
                                );

                                if (res.statusCode == 201 ||
                                    res.statusCode == 200) {
                                  _fetchData();
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  if (mounted) {
                                    showAppNotificationSheet(
                                      context: this.context,
                                      title: 'Draw Scheduled',
                                      message:
                                          'Rs. $selectedDenom draw scheduled for $dateStr at ${locationController.text.trim()}.',
                                      type: AppNotificationType.success,
                                    );
                                  }
                                } else {
                                  final data = jsonDecode(res.body);
                                  if (dialogContext.mounted) {
                                    setDialogState(() => isSubmitting = false);
                                    showAppToast(
                                      dialogContext,
                                      data['detail'] ??
                                          'Failed to schedule draw.',
                                      type: AppNotificationType.error,
                                    );
                                  }
                                }
                              } catch (e) {
                                if (dialogContext.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                  showAppToast(
                                    dialogContext,
                                    'Error: $e',
                                    type: AppNotificationType.error,
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      locationController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Draws & Schedules',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(
              icon: const Icon(Icons.description_outlined),
              text: 'Gazette Drawlists (${_drawlists.length})',
            ),
            Tab(
              icon: const Icon(Icons.calendar_month_outlined),
              text: 'Schedules (${_schedules.length})',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDrawlistsTab(), _buildSchedulesTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _tabController.index == 0
            ? _showImportGazetteDialog
            : _showAddScheduleDialog,
        icon: Icon(
          _tabController.index == 0
              ? Icons.note_add_outlined
              : Icons.add_circle_outline,
        ),
        label: Text(
          _tabController.index == 0 ? 'Import Gazette' : 'Add Schedule',
        ),
      ),
    );
  }

  Widget _buildDrawlistsTab() {
    final filtered = _drawlists.where((item) {
      final denomination = item['denomination']?.toString() ?? '';
      final drawDate = item['draw_date']?.toString() ?? '';

      bool matchesDenom = _drawsFilter == 'All' || denomination == _drawsFilter;
      bool matchesSearch =
          _drawsSearchQuery.isEmpty ||
          denomination.contains(_drawsSearchQuery) ||
          drawDate.contains(_drawsSearchQuery);

      return matchesDenom && matchesSearch;
    }).toList();

    return _isLoading
        ? const AppLoadingIndicator(
            message: 'Loading official gazette drawlists...',
          )
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 12),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(
                        title: 'Imported Gazette Results',
                        tagline: 'OFFICIAL RECORD',
                      ),
                      const SizedBox(height: 8),

                      AppTextField(
                        controller: _drawsSearchController,
                        labelText: 'Search Gazette Drawlists',
                        hintText: 'e.g. 750 or 2026-11-15',
                        prefixIcon: const Icon(Icons.search),
                        onChanged: (v) => setState(() => _drawsSearchQuery = v),
                      ),
                      const SizedBox(height: 12),

                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'All',
                              '100',
                              '200',
                              '750',
                              '1500',
                              '7500',
                              '15000',
                              '25000',
                              '40000',
                            ].map((denom) {
                              final isSelected = _drawsFilter == denom;
                              return ChoiceChip(
                                label: Text(
                                  denom == 'All' ? 'All Denoms' : 'Rs. $denom',
                                ),
                                selected: isSelected,
                                selectedColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                                onSelected: (s) {
                                  if (s) setState(() => _drawsFilter = denom);
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),

                      filtered.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.subtitles_off_outlined,
                              title: 'No Gazette Drawlists Found',
                              message: 'No imported drawlists match your selected filter.',
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                final drawId =
                                    item['draw_id']?.toString() ?? '';
                                final denomination =
                                    item['denomination'] as int? ?? 750;
                                final drawDate =
                                    item['draw_date']?.toString() ?? '';
                                final winnerCount =
                                    item['winner_count'] as int? ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AppCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    AppColors.primary,
                                                    AppColors.primaryContainer,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                '$denomination',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Rs. ${formatNumber(denomination)} Gazette',
                                                        style: TextStyle(
                                                          fontSize: 15,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                        ),
                                                      ),
                                                      AppBadge(
                                                        label:
                                                            '${formatNumber(winnerCount)} Winners',
                                                        type: AppBadgeType
                                                            .warning,
                                                        isSmall: true,
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Draw Date: $drawDate',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primary,
                                                foregroundColor: Colors.white,
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DrawDetailScreen(
                                                          drawId: drawId,
                                                          denomination:
                                                              denomination,
                                                          drawDate: drawDate,
                                                          winnerCount:
                                                              winnerCount,
                                                          accessToken: widget
                                                              .accessToken,
                                                          isAdmin: true,
                                                        ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(
                                                Icons.visibility_outlined,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'View Gazette',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            SizedBox(
                                              height: 36,
                                              child: IconButton(
                                                icon: _deletingId == drawId
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : const Icon(
                                                        Icons.delete_outline,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                onPressed: () =>
                                                    _deleteDrawlist(
                                                      drawId,
                                                      denomination,
                                                      drawDate,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }

  Widget _buildSchedulesTab() {
    return _isLoading
        ? const AppLoadingIndicator(
            message: 'Loading upcoming draw schedules...',
          )
        : RefreshIndicator(
            onRefresh: _fetchData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 12),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionHeader(
                        title: 'Scheduled Future Draws',
                        tagline: 'STATE BANK SCHEDULE',
                      ),
                      const SizedBox(height: 12),

                      _schedules.isEmpty
                          ? const AppEmptyState(
                              icon: Icons.event_busy,
                              title: 'No Upcoming Schedules',
                              message: 'Tap + Add Schedule to publish a future State Bank draw schedule.',
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _schedules.length,
                              itemBuilder: (context, index) {
                                final item = _schedules[index];
                                final denomination =
                                    item['denomination'] as int? ?? 1500;
                                final drawDate =
                                    item['draw_date']?.toString() ?? 'Upcoming';
                                final location =
                                    item['location']?.toString() ?? 'SBP';
                                final idKey = '$denomination-$drawDate';

                                final now = DateTime.now();
                                final today = DateTime(
                                  now.year,
                                  now.month,
                                  now.day,
                                );
                                bool isPast = false;
                                try {
                                  final dt = DateTime.parse(
                                    drawDate.toString(),
                                  );
                                  final drawDay = DateTime(
                                    dt.year,
                                    dt.month,
                                    dt.day,
                                  );
                                  isPast = drawDay.isBefore(today);
                                } catch (_) {}

                                final badgeLabel = isPast ? 'PAST' : 'UPCOMING';
                                final badgeType = isPast
                                    ? AppBadgeType.warning
                                    : AppBadgeType.info;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AppCard(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.event,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      'Rs. ${formatNumber(denomination)} Draw',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurface,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  AppBadge(
                                                    label: badgeLabel,
                                                    type: badgeType,
                                                    isSmall: true,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Date: $drawDate • $location',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _deletingId == idKey
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                onPressed: () =>
                                                    _deleteSchedule(
                                                      denomination,
                                                      drawDate,
                                                    ),
                                              ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}
