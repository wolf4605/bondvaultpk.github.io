import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../utils/app_utils.dart';
import 'admin_screens/admin_home_screen.dart';
import 'register_screen.dart';
import 'user_screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isAdmin = false;
  bool _isFabOpen = false;
  String? _errorMessage;

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final endpoint = _isAdmin
          ? AppConfig.adminLoginEndpoint
          : AppConfig.loginEndpoint;
      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'];
        final userInfo = data['payload'];

        if (_isAdmin) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('saved_username');
          await prefs.remove('saved_password');

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminHomeScreen(
                accessToken: accessToken,
                adminInfo: userInfo,
              ),
            ),
          );
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'saved_username',
            _usernameController.text.trim(),
          );
          await prefs.setString('saved_password', _passwordController.text);
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
        }
      } else {
        final data = jsonDecode(response.body);
        final errMsg = data['detail'] ?? 'Invalid username or password.';
        if (!mounted) return;
        showErrorBottomSheet(
          context: context,
          title: 'Authentication Error',
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
            'Could not reach backend server. Please check your connection.',
        onDismiss: () {},
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/logo.png'), context);
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Password Recovery'),
        content: const Text(
          'Please enter your registered email address to receive password reset instructions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003527),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recovery code sent to email if registered.'),
                ),
              );
            },
            child: const Text('Send Code'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Pod
                      Container(
                        width: 88,
                        height: 88,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF064E3B)
                                  .withValues(alpha: 0.18),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Title: BondVault PK
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isAdmin ? 'BondVault PK' : 'BondVault ',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF003527),
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (!_isAdmin)
                            const Text(
                              'PK',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD97706),
                                letterSpacing: -0.5,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      if (_isAdmin) ...[
                        Container(
                          margin: const EdgeInsets.only(top: 4, bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: const Text(
                            '● ADMINISTRATOR LOGIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],

                      // Subtitle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _isAdmin
                              ? 'Access administrative controls, user verification audit logs, and security policy overrides.'
                              : 'Enter registered credentials to access bond series, auto-draw matching, and claim reserves.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF404944),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF064E3B)
                                  .withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isAdmin
                                    ? 'Administrator Username or Email'
                                    : 'Username or Email',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF131B2E),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  hintText: 'example@example.com',
                                  prefixIcon: const Icon(
                                    Icons.badge_outlined,
                                    size: 20,
                                  ),
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
                              const SizedBox(height: 16),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Password',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF131B2E),
                                    ),
                                  ),
                                  if (!_isAdmin)
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _showForgotPasswordDialog,
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF904D00),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  hintText: 'Enter your password',
                                  prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 20,
                                  ),
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
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                validator: (v) =>
                                    v == null || v.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 24),

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
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.lock_open,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _isAdmin
                                                  ? 'Admin Sign In →'
                                                  : 'Sign In →',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
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

            // Morphing Floating Action Button (FAB) Menu at bottom right
            Positioned(
              bottom: 24,
              right: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizeTransition(
                    sizeFactor: _fabAnimation,
                    child: FadeTransition(
                      opacity: _fabAnimation,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Option 1: Admin / User Sign In Toggle
                            _buildFabMenuItem(
                              label: _isAdmin
                                  ? 'User Sign In'
                                  : 'Admin Sign In',
                              icon: _isAdmin
                                  ? Icons.person
                                  : Icons.admin_panel_settings,
                              onTap: () {
                                _toggleFab();
                                setState(() => _isAdmin = !_isAdmin);
                              },
                            ),
                            const SizedBox(height: 8),
                            // Option 2: Sign Up
                            if (!_isAdmin)
                              _buildFabMenuItem(
                                label: 'Sign Up',
                                icon: Icons.person_add,
                                onTap: () {
                                  _toggleFab();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                              ),
                            if (!_isAdmin) const SizedBox(height: 8),
                            // Option 3: Recover Password
                            if (!_isAdmin)
                              _buildFabMenuItem(
                                label: 'Recover Password',
                                icon: Icons.key,
                                onTap: () {
                                  _toggleFab();
                                  _showForgotPasswordDialog();
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  FloatingActionButton(
                    backgroundColor: const Color(0xFF003527),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shape: const CircleBorder(),
                    onPressed: _toggleFab,
                    child: RotationTransition(
                      turns: Tween(
                        begin: 0.0,
                        end: 0.25,
                      ).animate(_fabAnimation),
                      child: const Icon(Icons.settings, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFabMenuItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF131B2E),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F3FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: const Color(0xFF003527)),
            ),
          ],
        ),
      ),
    );
  }
}
