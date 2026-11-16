import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../config/responsive.dart';
import '../widgets/widgets.dart';
import 'login_screen.dart';

class EditProfileScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> profileData;
  final bool isAdmin;
  final VoidCallback? onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.accessToken,
    required this.profileData,
    this.isAdmin = false,
    this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _addressCtrl;

  late String _initialUsername;
  late String _initialEmail;
  late String _initialFirstName;
  late String _initialLastName;
  late String _initialContact;
  late String _initialCity;
  late String _initialAddress;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profileData;
    _initialUsername = p['username']?.toString().trim() ?? '';
    _initialEmail = p['email']?.toString().trim() ?? '';
    _initialFirstName = p['first_name']?.toString().trim() ?? '';
    _initialLastName = p['last_name']?.toString().trim() ?? '';
    _initialContact = p['contact']?.toString().trim() ?? '';
    _initialCity = p['city']?.toString().trim() ?? '';
    _initialAddress = p['address']?.toString().trim() ?? '';

    _usernameCtrl = TextEditingController(text: _initialUsername);
    _emailCtrl = TextEditingController(text: _initialEmail);
    _firstNameCtrl = TextEditingController(text: _initialFirstName);
    _lastNameCtrl = TextEditingController(text: _initialLastName);
    _contactCtrl = TextEditingController(text: _initialContact);
    _cityCtrl = TextEditingController(text: _initialCity);
    _addressCtrl = TextEditingController(text: _initialAddress);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _contactCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    String currentContact = _contactCtrl.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (currentContact.startsWith('03') && currentContact.length == 11) {
      currentContact = '+92${currentContact.substring(1)}';
    }

    if (_usernameCtrl.text.trim().toLowerCase() !=
        _initialUsername.toLowerCase()) {
      return true;
    }
    if (_emailCtrl.text.trim().toLowerCase() != _initialEmail.toLowerCase()) {
      return true;
    }
    if (_firstNameCtrl.text.trim() != _initialFirstName) return true;
    if (_lastNameCtrl.text.trim() != _initialLastName) return true;
    if (currentContact != _initialContact) return true;
    if (!widget.isAdmin) {
      if (_cityCtrl.text.trim() != _initialCity) return true;
      if (_addressCtrl.text.trim() != _initialAddress) return true;
    }
    return false;
  }

  String _parseErrorMessage(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        final lower = detail.toLowerCase();
        if (lower.contains('username') &&
            (lower.contains('taken') ||
                lower.contains('exists') ||
                lower.contains('conflict'))) {
          return 'This username is already taken by another account. Please choose a different username.';
        }
        if (lower.contains('email') &&
            (lower.contains('exists') ||
                lower.contains('taken') ||
                lower.contains('conflict'))) {
          return 'An account with this email address already exists.';
        }
        if (lower.contains('contact') &&
            (lower.contains('registered') ||
                lower.contains('taken') ||
                lower.contains('exists'))) {
          return 'This contact number is already registered to another account.';
        }
        if (lower.contains('blacklisted') || lower.contains('blacklist')) {
          return 'The requested email address or contact number is blacklisted and cannot be used.';
        }
        return detail;
      }
      if (detail is List && detail.isNotEmpty) {
        final first = detail[0];
        if (first is Map) {
          final loc = first['loc'] is List ? (first['loc'] as List) : [];
          final field = loc.isNotEmpty ? loc.last.toString() : '';
          if (field == 'email') return 'Please enter a valid email address.';
          if (field == 'username') return 'Please enter a valid username.';
          if (field == 'contact') return 'Please enter a valid contact number.';
          return first['msg']?.toString() ?? 'Invalid field input.';
        }
      }
    }

    if (statusCode == 409) {
      return 'The entered username, email, or contact number is already registered to another account.';
    }
    if (statusCode == 403) {
      return 'The requested email or contact number is blacklisted and cannot be used.';
    }
    if (statusCode == 400) {
      return 'Please verify all fields contain valid information and try again.';
    }

    return 'Unable to update profile. Please try again later.';
  }

  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate() || !_hasChanges) return;

    setState(() => _isSubmitting = true);
    final endpoint = widget.isAdmin ? '/admins/profile' : '/user';

    String contactVal = _contactCtrl.text
        .trim()
        .replaceAll(' ', '')
        .replaceAll('-', '');
    if (contactVal.startsWith('03') && contactVal.length == 11) {
      contactVal = '+92${contactVal.substring(1)}';
    }

    final bodyPayload = <String, dynamic>{
      'username': _usernameCtrl.text.trim().toLowerCase(),
      'email': _emailCtrl.text.trim().toLowerCase(),
      'first_name': _firstNameCtrl.text.trim(),
      'last_name': _lastNameCtrl.text.trim(),
      'contact': contactVal,
    };

    if (!widget.isAdmin) {
      if (_cityCtrl.text.trim().isNotEmpty) {
        bodyPayload['city'] = _cityCtrl.text.trim();
      }
      if (_addressCtrl.text.trim().isNotEmpty) {
        bodyPayload['address'] = _addressCtrl.text.trim();
      }
    }

    try {
      final res = await http.patch(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyPayload),
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        widget.onProfileUpdated?.call();
        showAppNotificationSheet(
          context: context,
          title: 'Profile Updated',
          message: 'Your profile details have been updated successfully. Please sign in again to reflect your changes.',
          type: AppNotificationType.success,
          dismissLabel: 'Sign In Again',
          onDismiss: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
        );
      } else {
        dynamic data;
        try {
          data = jsonDecode(res.body);
        } catch (_) {}

        final msg = _parseErrorMessage(data, res.statusCode);
        showAppNotificationSheet(
          context: context,
          title: 'Profile Update Failed',
          message: msg,
          type: AppNotificationType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppToast(
        context,
        'Network error. Please check your internet connection and try again.',
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
        title: Text(
          widget.isAdmin ? 'Edit Admin Profile' : 'Edit Profile',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: Responsive.w(context, 16),
          vertical: Responsive.h(context, 16),
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
                  // Banner Header Card
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    borderRadius: 20,
                    gradient: LinearGradient(
                      colors: widget.isAdmin
                          ? const [Color(0xFF0F5132), Color(0xFF022C22)]
                          : const [Color(0xFF003527), Color(0xFF064E3B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.edit_note,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isAdmin
                                    ? 'Administrator Profile'
                                    : 'Personal Account Profile',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Update contact details, names, city, and address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form Container
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'USERNAME',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: _usernameCtrl,
                          labelText: 'Username',
                          prefixIcon: const Icon(Icons.person_outline),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Username is required';
                            }
                            if (v.trim().length < 3) {
                              return 'Username must be at least 3 characters';
                            }
                            if (!RegExp(r'^[a-zA-Z0-9_.-]+$')
                                .hasMatch(v.trim())) {
                              return 'Username can only contain letters, numbers, _, ., -';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'EMAIL ADDRESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email_outlined),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email address is required';
                            }
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(v.trim())) {
                              return 'Please enter a valid email address (e.g. user@example.com)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'FIRST NAME',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AppTextField(
                                    controller: _firstNameCtrl,
                                    labelText: 'First Name',
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LAST NAME',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  AppTextField(
                                    controller: _lastNameCtrl,
                                    labelText: 'Last Name',
                                    prefixIcon: const Icon(
                                      Icons.badge_outlined,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'CONTACT NUMBER',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        AppTextField(
                          controller: _contactCtrl,
                          keyboardType: TextInputType.phone,
                          labelText:
                              'Contact (e.g. 03001234567 or +923001234567)',
                          prefixIcon: const Icon(Icons.phone_outlined),
                          onChanged: (_) => setState(() {}),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Contact number is required';
                            }
                            final cleaned = v
                                .trim()
                                .replaceAll(' ', '')
                                .replaceAll('-', '');
                            if (cleaned.startsWith('03') &&
                                cleaned.length == 11 &&
                                RegExp(r'^[0-9]+$').hasMatch(cleaned)) {
                              return null;
                            }
                            if (cleaned.startsWith('+923') &&
                                cleaned.length == 13 &&
                                RegExp(r'^\+92[0-9]+$').hasMatch(cleaned)) {
                              return null;
                            }
                            return 'Invalid contact. Use 03001234567 or +923001234567';
                          },
                        ),
                        if (!widget.isAdmin) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'CITY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: _cityCtrl,
                            labelText: 'City (e.g. Lahore, Islamabad)',
                            prefixIcon: const Icon(
                              Icons.location_city_outlined,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'POSTAL ADDRESS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          AppTextField(
                            controller: _addressCtrl,
                            labelText: 'House, Street, Area / Sector',
                            prefixIcon: const Icon(Icons.home_outlined),
                            maxLines: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                        ],
                        const SizedBox(height: 24),

                        AppButton(
                          label: 'Save Profile Changes',
                          isLoading: _isSubmitting,
                          icon: const Icon(Icons.save_outlined, size: 18),
                          onPressed: _hasChanges && !_isSubmitting
                              ? _handleSaveProfile
                              : null,
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
