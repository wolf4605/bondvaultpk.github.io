import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/app_utils.dart';
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
  String? _message;
  bool _isError = false;

  String _passwordStrength = 'Weak';
  double _passwordStrengthValue = 0.2;
  Color _passwordStrengthColor = Colors.red;

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
        _passwordStrengthColor = Colors.red;
      } else if (score <= 2) {
        _passwordStrength = 'Weak';
        _passwordStrengthValue = 0.33;
        _passwordStrengthColor = Colors.red;
      } else if (score <= 4) {
        _passwordStrength = 'Medium';
        _passwordStrengthValue = 0.66;
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrength = 'Strong';
        _passwordStrengthValue = 1.0;
        _passwordStrengthColor = Colors.green;
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
      setState(() {
        _message = 'Please enter a valid email address first.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isSendingCode = true;
      _message = null;
      _isError = false;
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
        setState(() {
          _message = 'Verification code sent to your email.';
          _isError = false;
        });
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _message = data['detail'] ?? 'Failed to send verification code.';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Connection error while sending code.';
        _isError = true;
      });
    } finally {
      setState(() {
        _isSendingCode = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    if (email.isEmpty || code.length != 6) {
      setState(() {
        _message = 'Please enter the 6-digit verification code.';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _message = null;
      _isError = false;
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
            _message = 'Email verified successfully!';
            _isError = false;
          });
        } else {
          setState(() {
            _message = 'Invalid verification code.';
            _isError = true;
          });
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _message = data['detail'] ?? 'Verification failed.';
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Connection error during verification.';
        _isError = true;
      });
    } finally {
      setState(() {
        _isVerifyingCode = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isEmailVerified = true;
      _agreeToTerms = true;
      _isRegistering = true;
      _message = null;
      _isError = false;
    });

    try {
      final uri = Uri.parse(
        '${AppConfig.baseUrl}${AppConfig.registerEndpoint}',
      );
      final payload = {
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password_hash': _passwordController.text,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'contact': _contactController.text.trim(),
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
        final data = jsonDecode(response.body);
        final errMsg = data['detail'] ?? 'Registration failed.';
        if (!mounted) return;
        showErrorBottomSheet(
          context: context,
          title: 'Registration Error',
          message: errMsg,
          onDismiss: () {},
        );
      }
    } catch (e) {
      if (!mounted) return;
      showErrorBottomSheet(
        context: context,
        title: 'Connection Error',
        message:
            'Connection error during registration. Please check your network.',
        onDismiss: () {},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRegistering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFF),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF131B2E)),
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
                    color: Color(0xFF003527),
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
                        color: const Color(0xFF064E3B).withValues(alpha: 0.18),
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
                    color: Color(0xFF003527),
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
                      color: Color(0xFF404944),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_message != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isError
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isError
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      _message!,
                      style: TextStyle(
                        color: _isError
                            ? Colors.red.shade800
                            : Colors.green.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Section 1: Personal Details Card
                _buildSectionCard(
                  title: 'Personal Details',
                  icon: Icons.person_outline,
                  children: [
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Username *',
                        hintText: 'user12345',
                        prefixText: '@ ',
                        prefixStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003527),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                                    ? Colors.green
                                    : Colors.red,
                              ),
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
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name *',
                              hintText: 'Awais',
                              filled: true,
                              fillColor: const Color(0xFFF2F3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name *',
                              hintText: 'Bilal',
                              filled: true,
                              fillColor: const Color(0xFFF2F3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
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
                    TextFormField(
                      controller: _contactController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Contact Number *',
                        hintText: '300 1234567',
                        prefixText: '🇵🇰 +92 ',
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                                    ? Colors.green
                                    : Colors.red,
                              ),
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
                          child: TextFormField(
                            controller: _emailController,
                            enabled: !_isEmailVerified,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email Address *',
                              hintText: 'abc@example.com',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: const Color(0xFFF2F3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
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
                                          ? Colors.green
                                          : Colors.red,
                                    ),
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
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003527),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                (_isEmailValid &&
                                    !_emailTaken &&
                                    !_isEmailVerified &&
                                    !_isSendingCode)
                                ? _sendVerificationCode
                                : null,
                            child: _isSendingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isEmailVerified ? 'Verified' : 'Send Code',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (!_isEmailVerified) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _codeController,
                              maxLength: 6,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Email Verification Code *',
                                hintText: '6-digit code',
                                prefixIcon: const Icon(Icons.pin_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF2F3FF),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                counterText: '',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFE932C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _isVerifyingCode ? null : _verifyCode,
                              child: _isVerifyingCode
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Verify',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
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
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        hintText: 'At least 6 characters',
                        prefixIcon: const Icon(Icons.key_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                                  color: Color(0xFF404944),
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
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.password_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
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
                    TextFormField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'City *',
                        hintText: 'Select Your City',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'City is required' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address *',
                        hintText: 'House #, Street, Sector / Area',
                        prefixIcon: const Icon(Icons.home_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF2F3FF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
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
                          child: TextFormField(
                            controller: _appPinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: InputDecoration(
                              labelText: '4-Digit MPIN',
                              hintText: '••••',
                              prefixIcon: const Icon(Icons.dialpad),
                              filled: true,
                              fillColor: const Color(0xFFF2F3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              counterText: '',
                            ),
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
                          child: TextFormField(
                            controller: _confirmAppPinController,
                            obscureText: _obscurePin,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            decoration: InputDecoration(
                              labelText: 'Confirm MPIN',
                              hintText: '••••',
                              prefixIcon: const Icon(
                                Icons.check_circle_outline,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF2F3FF),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              counterText: '',
                            ),
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
                      activeColor: const Color(0xFF003527),
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
                              color: Color(0xFF404944),
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003527),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _isRegistering ? null : _register,
                    child: _isRegistering
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.lock_open, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Footer Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an Account? ',
                      style: TextStyle(fontSize: 13, color: Color(0xFF404944)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'Sign In →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003527),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF064E3B).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: const Color(0xFF003527), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF131B2E),
                    ),
                  ),
                ],
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E7FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003527),
                    ),
                  ),
                ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 42.0),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFF404944)),
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
