import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../config/app_theme.dart';
import '../widgets/widgets.dart';
import 'user_screens/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _appPinController = TextEditingController();
  final _confirmAppPinController = TextEditingController();

  Timer? _usernameDebounce;
  Timer? _emailDebounce;
  Timer? _contactDebounce;

  bool _isCheckingUsername = false;
  bool _usernameTaken = false;
  bool _isUsernameValid = false;

  bool _isCheckingEmail = false;
  bool _emailTaken = false;
  bool _isEmailValid = false;

  bool _isCheckingContact = false;
  bool _contactTaken = false;
  bool _isContactValid = false;

  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  bool _isEmailVerified = false;
  bool _isRegistering = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final bool _obscurePin = true;
  bool _agreeToTerms = false;

  String _passwordStrength = 'Weak';
  double _passwordStrengthValue = 0.2;
  Color _passwordStrengthColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_onUsernameChanged);
    _emailController.addListener(_onEmailChanged);
    _contactController.addListener(_onContactChanged);
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _emailDebounce?.cancel();
    _contactDebounce?.cancel();
    _passwordController.removeListener(_onPasswordChanged);
    _usernameController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _appPinController.dispose();
    _confirmAppPinController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    final password = _passwordController.text;
    int score = 0;
    if (password.length >= 6) score++;
    if (password.length >= 10) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) score++;

    setState(() {
      if (password.isEmpty) {
        _passwordStrength = 'Weak';
        _passwordStrengthValue = 0.2;
        _passwordStrengthColor = AppColors.error;
      } else if (score <= 2) {
        _passwordStrength = 'Weak';
        _passwordStrengthValue = 0.33;
        _passwordStrengthColor = AppColors.error;
      } else if (score <= 4) {
        _passwordStrength = 'Medium';
        _passwordStrengthValue = 0.66;
        _passwordStrengthColor = AppColors.warning;
      } else {
        _passwordStrength = 'Strong';
        _passwordStrengthValue = 1.0;
        _passwordStrengthColor = AppColors.success;
      }
    });
  }

  void _onUsernameChanged() {
    final text = _usernameController.text.trim();
    _usernameDebounce?.cancel();
    if (text.length < 3 || !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(text)) {
      setState(() {
        _isCheckingUsername = false;
        _usernameTaken = false;
        _isUsernameValid = false;
      });
      return;
    }
    setState(() => _isCheckingUsername = true);
    _usernameDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _fetchAvailability(username: text);
    });
  }

  void _onEmailChanged() {
    final text = _emailController.text.trim();
    _emailDebounce?.cancel();
    final emailRegex = RegExp(r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(text)) {
      setState(() {
        _isCheckingEmail = false;
        _emailTaken = false;
        _isEmailValid = false;
      });
      return;
    }
    setState(() => _isCheckingEmail = true);
    _emailDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _fetchAvailability(email: text);
    });
  }

  void _onContactChanged() {
    final text = _contactController.text.trim();
    _contactDebounce?.cancel();
    final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(text)) {
      setState(() {
        _isCheckingContact = false;
        _contactTaken = false;
        _isContactValid = false;
      });
      return;
    }
    setState(() => _isCheckingContact = true);
    _contactDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _fetchAvailability(contact: text);
    });
  }

  Future<void> _fetchAvailability({
    String? username,
    String? email,
    String? contact,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (username != null) queryParams['username'] = username;
      if (email != null) queryParams['email'] = email;
      if (contact != null) queryParams['contact'] = contact;

      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.checkAvailabilityEndpoint}',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          if (username != null) {
            _usernameTaken = data['username_taken'] == true;
            _isUsernameValid = !_usernameTaken;
            _isCheckingUsername = false;
          }
          if (email != null) {
            _emailTaken = data['email_taken'] == true;
            _isEmailValid = !_emailTaken;
            _isCheckingEmail = false;
          }
          if (contact != null) {
            _contactTaken = data['contact_taken'] == true;
            _isContactValid = !_contactTaken;
            _isCheckingContact = false;
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          if (username != null) _isCheckingUsername = false;
          if (email != null) _isCheckingEmail = false;
          if (contact != null) _isCheckingContact = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (username != null) _isCheckingUsername = false;
        if (email != null) _isCheckingEmail = false;
        if (contact != null) _isCheckingContact = false;
      });
    }
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty || !emailRegex.hasMatch(email)) {
      showAppToast(
        context,
        'Please enter a valid email address first.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.sendVerificationEndpoint}',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode == 202 || response.statusCode == 200) {
        if (!mounted) return;
        showAppToast(
          context,
          'Verification code sent to your email.',
          type: AppNotificationType.success,
        );
      } else {
        final data = jsonDecode(response.body);
        final msg = data['detail'] ?? 'Failed to send verification code.';
        if (!mounted) return;
        showAppNotificationSheet(
          context: context,
          title: 'Verification Error',
          message: msg,
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not reach server to send verification code.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.length != 6) {
      showAppToast(
        context,
        'Please enter the 6-digit verification code.',
        type: AppNotificationType.warning,
      );
      return;
    }

    setState(() {
      _isVerifyingCode = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.verifyCodeEndpoint}',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': code}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['verified'] == true) {
          setState(() {
            _isEmailVerified = true;
          });
          if (!mounted) return;
          showAppToast(
            context,
            'Email verified successfully!',
            type: AppNotificationType.success,
          );
        } else {
          if (!mounted) return;
          showAppNotificationSheet(
            context: context,
            title: 'Verification Failed',
            message: 'Invalid verification code. Please check and try again.',
            type: AppNotificationType.error,
          );
        }
      } else {
        final data = jsonDecode(response.body);
        final msg = data['detail'] ?? 'Verification failed.';
        if (!mounted) return;
        showAppNotificationSheet(
          context: context,
          title: 'Verification Failed',
          message: msg,
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Could not reach server to verify code.',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingCode = false;
        });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEmailVerified = true;
      _agreeToTerms = true;
      _isRegistering = true;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.registerEndpoint}',
      );
      String contactText = _contactController.text.trim();
      if (contactText.startsWith('03') && contactText.length == 11) {
        contactText = contactText.replaceFirst('0', '+92');
      } else if (contactText.startsWith('3') && contactText.length == 10) {
        contactText = '+92$contactText';
      }

      final payload = {
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password_hash': _passwordController.text,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'contact': contactText,
        'city': _cityController.text.trim(),
        'address': _addressController.text.trim(),
      };

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'saved_username',
          _usernameController.text.trim(),
        );
        await prefs.setString('saved_password', _passwordController.text);

        final appPin = _appPinController.text.trim();
        if (appPin.isNotEmpty) {
          await prefs.setString('app_pin', appPin);
        } else {
          await prefs.remove('app_pin');
        }

        final loginUri = Uri.parse(
          '${AppConfig.baseUrl}${AppConfig.loginEndpoint}',
        );
        final loginResponse = await http.post(
          loginUri,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'username': _usernameController.text.trim(),
            'password': _passwordController.text,
          },
        );

        if (loginResponse.statusCode == 200) {
          final loginData = jsonDecode(loginResponse.body);
          final accessToken = loginData['access_token'];
          final userInfo = loginData['payload'];

          await prefs.setString('cached_access_token', accessToken);
          await prefs.setString('cached_user_info', jsonEncode(userInfo));

          if (!mounted) return;
          showAppToast(
            context,
            'Account registered successfully!',
            type: AppNotificationType.success,
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomeScreen(accessToken: accessToken, userInfo: userInfo),
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.pop(context);
        }
      } else {
        String errMsg = 'Registration failed.';
        try {
          final data = jsonDecode(response.body);
          errMsg = _parseErrorDetail(data['detail']);
        } catch (_) {
          errMsg = 'Registration failed with status ${response.statusCode}.';
        }
        if (!mounted) return;
        showAppNotificationSheet(
          context: context,
          title: 'Registration Error',
          message: errMsg,
          type: AppNotificationType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppNotificationSheet(
        context: context,
        title: 'Connection Error',
        message: 'Connection error during registration: $e',
        type: AppNotificationType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  String _parseErrorDetail(dynamic detail) {
    if (detail is String) return detail;
    if (detail is List) {
      return detail
          .map((err) {
            if (err is Map) {
              final loc = err['loc'] is List
                  ? (err['loc'] as List).last
                  : 'Field';
              final msg = err['msg'] ?? 'Invalid value';
              return '$loc: $msg';
            }
            return err.toString();
          })
          .join('\n');
    }
    return detail?.toString() ?? 'Registration failed.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Image.asset('assets/logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'BondVault PK',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Prize Bond Portfolio',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Logo Pod & Hero Header
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.18,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Securely register to manage your Pakistan prize bonds, automated draw audits & instant prize claims.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 1: Personal Details Card
                _buildSectionCard(
                  title: 'Personal Details',
                  icon: Icons.person_outline,
                  children: [
                    AppTextField(
                      controller: _usernameController,
                      labelText: 'Username *',
                      hintText: 'user12345',
                      prefixIcon: const Icon(Icons.alternate_email, size: 18),
                      suffixIcon: _isCheckingUsername
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Icon(
                              _isUsernameValid
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _isUsernameValid
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Username is required';
                        }
                        if (v.length < 3) return 'At least 3 characters';
                        final usernameRegex = RegExp(r'^[a-zA-Z0-9_.-]+$');
                        if (!usernameRegex.hasMatch(v)) {
                          return 'Only letters, numbers, _, ., -';
                        }
                        if (_usernameTaken) {
                          return 'Username is taken or blacklisted';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _firstNameController,
                            labelText: 'First Name *',
                            hintText: 'Awais',
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _lastNameController,
                            labelText: 'Last Name *',
                            hintText: 'Bilal',
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 2: Contact & Verification Card
                _buildSectionCard(
                  title: 'Contact & Verification',
                  icon: Icons.mark_email_read_outlined,
                  children: [
                    AppTextField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      labelText: 'Contact Number *',
                      hintText: '300 1234567',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      suffixIcon: _isCheckingContact
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : Icon(
                              _isContactValid
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: _isContactValid
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Contact is required';
                        }
                        final phoneRegex = RegExp(r'^\+?[0-9]{10,15}$');
                        if (!phoneRegex.hasMatch(v)) {
                          return 'Enter 10-15 digits';
                        }
                        if (_contactTaken) {
                          return 'Contact taken or blacklisted';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _emailController,
                            enabled: !_isEmailVerified,
                            keyboardType: TextInputType.emailAddress,
                            labelText: 'Email Address *',
                            hintText: 'abc@example.com',
                            prefixIcon: const Icon(Icons.email_outlined),
                            suffixIcon: _isCheckingEmail
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    _isEmailValid
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    color: _isEmailValid
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Email required';
                              }
                              final emailRegex = RegExp(
                                r'^[\w-]+@([\w-]+\.)+[\w-]{2,4}$',
                              );
                              if (!emailRegex.hasMatch(v)) {
                                return 'Invalid email';
                              }
                              if (_emailTaken) {
                                return 'Email taken or blacklisted';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppButton(
                          label: _isEmailVerified ? 'Verified' : 'Send Code',
                          isLoading: _isSendingCode,
                          fullWidth: false,
                          height: 54,
                          onPressed:
                              (_isEmailValid &&
                                  !_emailTaken &&
                                  !_isEmailVerified &&
                                  !_isSendingCode)
                              ? _sendVerificationCode
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_isEmailVerified) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _codeController,
                              maxLength: 6,
                              keyboardType: TextInputType.number,
                              labelText: 'Email Verification Code *',
                              hintText: '6-digit code',
                              prefixIcon: const Icon(Icons.pin_outlined),
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppButton(
                            label: 'Verify',
                            variant: AppButtonVariant.secondary,
                            isLoading: _isVerifyingCode,
                            fullWidth: false,
                            height: 54,
                            onPressed: _isVerifyingCode ? null : _verifyCode,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // Section 3: Password Card
                _buildSectionCard(
                  title: 'Password',
                  icon: Icons.lock_outline,
                  children: [
                    AppTextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      labelText: 'Password *',
                      hintText: 'At least 6 characters',
                      prefixIcon: const Icon(Icons.key_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (v) => v == null || v.length < 6
                          ? 'Password must be at least 6 chars'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Password Strength',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                _passwordStrength,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _passwordStrengthColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _passwordStrengthValue,
                              backgroundColor: const Color(0xFFE2E7FF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _passwordStrengthColor,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      labelText: 'Confirm Password *',
                      hintText: 'Re-enter password',
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Confirm password';
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 4: Residential Address Card
                _buildSectionCard(
                  title: 'Residential Address',
                  icon: Icons.location_on_outlined,
                  children: [
                    AppTextField(
                      controller: _cityController,
                      labelText: 'City *',
                      hintText: 'Select Your City',
                      prefixIcon: const Icon(Icons.location_city_outlined),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'City is required' : null,
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _addressController,
                      labelText: 'Address *',
                      hintText: 'House #, Street, Sector / Area',
                      prefixIcon: const Icon(Icons.home_outlined),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Address is required' : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Section 5: Quick Access MPIN (Optional) Card
                _buildSectionCard(
                  title: 'Quick Access MPIN',
                  icon: Icons.pin_outlined,
                  badge: 'OPTIONAL',
                  subtitle: 'Fast 4-digit unlock for daily bond checking',
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _appPinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            labelText: '4-Digit MPIN',
                            hintText: '••••',
                            prefixIcon: const Icon(Icons.dialpad),
                            validator: (v) {
                              if (v != null && v.isNotEmpty) {
                                if (v.length != 4 ||
                                    !RegExp(r'^[0-9]+$').hasMatch(v)) {
                                  return 'Must be 4 digits';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppTextField(
                            controller: _confirmAppPinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            labelText: 'Confirm MPIN',
                            hintText: '••••',
                            prefixIcon: const Icon(Icons.check_circle_outline),
                            validator: (v) {
                              if (_appPinController.text.isNotEmpty) {
                                if (v == null || v.isEmpty) {
                                  return 'Confirm MPIN';
                                }
                                if (v != _appPinController.text) {
                                  return 'MPINs do not match';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Terms Authorization Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      activeColor: AppColors.primary,
                      onChanged: (val) =>
                          setState(() => _agreeToTerms = val ?? true),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _agreeToTerms = !_agreeToTerms),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 10.0),
                          child: Text(
                            'By registering, you authorize automated draw tracking against official State Bank of Pakistan Prize Bond gazettes.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Register Button
                AppButton(
                  label: 'Register Account',
                  isLoading: _isRegistering,
                  icon: const Icon(Icons.lock_open, size: 20),
                  onPressed: _register,
                ),
                const SizedBox(height: 20),

                // Footer Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an Account? ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? badge,
    String? subtitle,
    required List<Widget> children,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              if (badge != null)
                AppBadge(
                  label: badge,
                  type: AppBadgeType.neutral,
                  isSmall: true,
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 42.0),
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
