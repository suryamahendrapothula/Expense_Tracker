import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import '../../../app/config/app_theme.dart';
import '../../../core/widgets/glass_card.dart';
import '../data/auth_repository.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isVerification; // true = unlock, false = register new PIN

  const PinScreen({
    super.key,
    required this.isVerification,
  });

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final List<int> _pin = [];
  final _localAuth = LocalAuthentication();
  String _statusText = '';

  @override
  void initState() {
    super.initState();
    _statusText = widget.isVerification ? 'Enter PIN to unlock' : 'Create a 4-digit App PIN';
    if (widget.isVerification) {
      _checkBiometrics();
    }
  }

  Future<void> _checkBiometrics() async {
    final repo = ref.read(authRepositoryProvider);
    final bioEnabled = await repo.isBiometricsEnabled();
    if (bioEnabled) {
      final canAuthenticate = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canAuthenticate) {
        _authenticateBiometric();
      }
    }
  }

  Future<void> _authenticateBiometric() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock Antigravity Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
      if (authenticated && mounted) {
        context.go('/dashboard');
      }
    } catch (_) {}
  }

  void _keyPress(int key) {
    if (_pin.length < 4) {
      setState(() {
        _pin.add(key);
      });
      if (_pin.length == 4) {
        _submitPin();
      }
    }
  }

  void _backspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  Future<void> _submitPin() async {
    final enteredPin = _pin.join();
    final repo = ref.read(authRepositoryProvider);

    if (widget.isVerification) {
      final success = await repo.verifyPin(enteredPin);
      if (success) {
        if (mounted) context.go('/dashboard');
      } else {
        setState(() {
          _pin.clear();
          _statusText = 'Incorrect PIN. Try again.';
        });
      }
    } else {
      // Setup PIN
      await repo.savePin(enteredPin);
      // Ask if they want biometric enabled
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (canCheck && mounted) {
        _showBiometricOfferDialog();
      } else {
        if (mounted) context.go('/dashboard');
      }
    }
  }

  void _showBiometricOfferDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometrics'),
        content: const Text('Would you like to unlock the app using Fingerprint / Face ID?'),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.go('/dashboard');
            },
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              final repo = ref.read(authRepositoryProvider);
              await repo.setBiometricsEnabled(true);
              if (context.mounted) {
                context.pop();
                context.go('/dashboard');
              }
            },
            child: const Text('Yes, Enable'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.darkBackground, Color(0xFF0F101A)]
                : [AppColors.lightBackground, Color(0xFFEDF2F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  // App Icon / Logo
                  Container(
                    height: 56,
                    width: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _statusText,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 30),
                  
                  // Pin Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      final active = index < _pin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        height: 16,
                        width: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? AppColors.primary : Colors.transparent,
                          border: Border.all(
                            color: active ? AppColors.primary : (isDark ? Colors.white30 : Colors.black26),
                            width: 2,
                          ),
                          boxShadow: active ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ] : null,
                        ),
                      );
                    }),
                  ),
                ],
              ),
              
              // Number Pad Grid
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    for (var r = 0; r < 3; r++) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (var c = 1; c <= 3; c++)
                            _PinButton(
                              value: (r * 3 + c).toString(),
                              onTap: () => _keyPress(r * 3 + c),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Biometrics trigger
                        widget.isVerification 
                            ? InkWell(
                                onTap: _authenticateBiometric,
                                borderRadius: BorderRadius.circular(50),
                                child: Container(
                                  height: 72,
                                  width: 72,
                                  decoration: const BoxDecoration(shape: BoxShape.circle),
                                  child: const Icon(Icons.fingerprint_rounded, size: 36, color: AppColors.accent),
                                ),
                              )
                            : const SizedBox(height: 72, width: 72),
                        _PinButton(
                          value: '0',
                          onTap: () => _keyPress(0),
                        ),
                        // Backspace
                        InkWell(
                          onTap: _backspace,
                          borderRadius: BorderRadius.circular(50),
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: const BoxDecoration(shape: BoxShape.circle),
                            child: const Icon(Icons.backspace_outlined, size: 26),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinButton extends StatelessWidget {
  final String value;
  final VoidCallback onTap;

  const _PinButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
