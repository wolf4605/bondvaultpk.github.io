import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_utils.dart';
import 'login_screen.dart';
import 'user_screens/home_screen.dart';

class PinUnlockScreen extends StatefulWidget {
  final String accessToken;
  final Map<String, dynamic> userInfo;
  final String correctPin;

  const PinUnlockScreen({
    super.key,
    required this.accessToken,
    required this.userInfo,
    required this.correctPin,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onNumberPressed(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verifyPin() {
    if (_enteredPin == widget.correctPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            accessToken: widget.accessToken,
            userInfo: widget.userInfo,
          ),
        ),
      );
    } else {
      setState(() {
        _enteredPin = '';
      });
      showErrorBottomSheet(
        context: context,
        title: 'Authentication Error',
        message: 'Incorrect MPIN. Please try again.',
        onDismiss: () {},
      );
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_username');
    await prefs.remove('saved_password');
    await prefs.remove('app_pin');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFF),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with Lock Badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF003527)
                                .withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF003527),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'BondVault ',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF003527),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'PK',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD97706),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Enter your 4-digit security MPIN to decrypt\nyour registered prize bonds',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF404944),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),

                // MPIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isFilled
                            ? const Color(0xFF003527)
                            : const Color(0xFFE2E7FF),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                const SizedBox(height: 40),

                // Number Pad
                SizedBox(
                  width: 280,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumButton('1'),
                          _buildNumButton('2'),
                          _buildNumButton('3'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumButton('4'),
                          _buildNumButton('5'),
                          _buildNumButton('6'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNumButton('7'),
                          _buildNumButton('8'),
                          _buildNumButton('9'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 72, height: 72), // Empty space
                          _buildNumButton('0'),
                          _buildDeleteButton(),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Forgot MPIN
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Forgot MPIN?',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003527),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Sign in with Password divider footer
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey.shade300, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: InkWell(
                        onTap: _logout,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: Color(0xFF131B2E),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Sign in with Password',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131B2E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey.shade300, thickness: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumButton(String digit) {
    return SizedBox(
      width: 72,
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003527),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
        ),
        onPressed: () => _onNumberPressed(digit),
        child: Text(
          digit,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return SizedBox(
      width: 72,
      height: 72,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF003527),
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          elevation: 2,
        ),
        onPressed: _onDeletePressed,
        child: const Icon(
          Icons.backspace_outlined,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
