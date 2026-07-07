import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/config/app_theme.dart';
import '../data/auth_repository.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _passwordStrengthText = '';
  double _passwordStrengthVal = 0.0;

  late AnimationController _staggerController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // Dashboard-matching colors
  static const Color _bgColor = Color(0xFFE8EDDF);
  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _accentGreenLight = Color(0xFF95D5B2);
  static const Color _accentGreenSoft = Color(0xFFD8F3DC);
  static const Color _accentGold = Color(0xFFD4A843);
  static const Color _accentGoldLight = Color(0xFFF0DCA0);
  static const Color _textPrimary = Color(0xFF1B1B1B);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _dividerColor = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _staggerController.forward();

    _passwordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _staggerController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Animation<double> _createStaggerAnimation(double begin, double end) {
    return Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      ),
    );
  }

  void _updatePasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrengthText = '';
        _passwordStrengthVal = 0.0;
      });
      return;
    }

    double strength = 0.0;
    if (password.length >= 6) strength += 0.2;
    if (password.length >= 10) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[a-zA-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~]').hasMatch(password)) strength += 0.2;

    String label = 'Weak';
    if (strength > 0.4 && strength <= 0.7) {
      label = 'Medium';
    } else if (strength > 0.7) {
      label = 'Strong';
    }

    setState(() {
      _passwordStrengthVal = strength;
      _passwordStrengthText = label;
    });
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Passwords do not match!'),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
      );
      ref.read(currentUserProvider.notifier).state = user;

      if (mounted) {
        context.go('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signup failed: $e'),
            backgroundColor: AppColors.expense,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: _bgColor,
      body: Stack(
        children: [
          // Animated floating shapes
          _buildFloatingShapes(screenWidth, screenHeight),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with back button
                _buildTopBar(),

                // Scrollable form content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 10),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          // Brand header (smaller for signup)
                          _buildAnimatedChild(
                            0.0,
                            0.25,
                            child: _buildBrandHeader(),
                          ),
                          const SizedBox(height: 28),

                          // Signup Card
                          _buildAnimatedChild(
                            0.1,
                            0.5,
                            child: _buildSignupCard(),
                          ),
                          const SizedBox(height: 24),

                          // Sign In CTA
                          _buildAnimatedChild(
                            0.5,
                            0.8,
                            child: _buildSignInCta(),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _dividerColor,
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: _textPrimary,
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: _accentGreenSoft.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  height: 6,
                  width: 6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Step 1 of 2',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accentGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedChild(double begin, double end,
      {required Widget child}) {
    final fadeAnim = _createStaggerAnimation(begin, end);
    return AnimatedBuilder(
      animation: fadeAnim,
      builder: (context, _) {
        return Opacity(
          opacity: fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - fadeAnim.value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFloatingShapes(double width, double height) {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        final val = _floatController.value;
        return Stack(
          children: [
            // Top-left gold circle
            Positioned(
              left: -50 + cos(val * 2 * pi) * 15,
              top: height * 0.05 + sin(val * 2 * pi) * 20,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentGoldLight.withOpacity(0.4),
                      _accentGoldLight.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom-right green circle
            Positioned(
              right: -40 + sin(val * 2 * pi) * 20,
              bottom: height * 0.08 + cos(val * 2 * pi) * 25,
              child: Container(
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _accentGreenSoft.withOpacity(0.5),
                      _accentGreenSoft.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Small dots
            Positioned(
              left: width * 0.8 + sin(val * 3 * pi) * 8,
              top: height * 0.35 + cos(val * 2 * pi) * 10,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentGold.withOpacity(0.25),
                ),
              ),
            ),
            Positioned(
              left: width * 0.15 + cos(val * 2 * pi) * 6,
              top: height * 0.65 + sin(val * 3 * pi) * 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accentGreen.withOpacity(0.15),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Small logo
        AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    _accentGold,
                    _accentGold.withOpacity(0.85),
                    _accentGoldLight,
                    _accentGold,
                  ],
                  stops: [
                    0.0,
                    (_shimmerController.value - 0.1).clamp(0.0, 1.0),
                    _shimmerController.value,
                    (_shimmerController.value + 0.1).clamp(0.0, 1.0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accentGold.withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Create Account',
          style: GoogleFonts.fraunces(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Join Expenses Tracker and take control of your finances',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSignupCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: _accentGreen.withOpacity(0.03),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card header with icon
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: _accentGreenSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: _accentGreen,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Your Details',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Full Name
              _DashboardStyleInput(
                controller: _nameController,
                focusNode: _nameFocusNode,
                label: 'Full Name',
                hint: 'John Doe',
                prefixIcon: Icons.person_outline_rounded,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Please enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email Address
              _DashboardStyleInput(
                controller: _emailController,
                focusNode: _emailFocusNode,
                label: 'Email Address',
                hint: 'you@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty || !val.contains('@')) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password
              _DashboardStyleInput(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outlined,
                obscureText: _obscurePassword,
                suffixIcon: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _textSecondary,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty || val.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),

              // Password Strength Indicator
              if (_passwordController.text.isNotEmpty) ...[
                const SizedBox(height: 10),
                _PasswordStrengthBar(
                  val: _passwordStrengthVal,
                  label: _passwordStrengthText,
                ),
              ],
              const SizedBox(height: 16),

              // Confirm Password
              _DashboardStyleInput(
                controller: _confirmPasswordController,
                focusNode: _confirmPasswordFocusNode,
                label: 'Confirm Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_clock_outlined,
                obscureText: _obscureConfirmPassword,
                suffixIcon: GestureDetector(
                  onTap: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword),
                  child: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _textSecondary,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please confirm your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // Create Account Button
              _DashboardButton(
                text: 'Create Account',
                isLoading: _isLoading,
                onTap: _handleSignup,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCta() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _dividerColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _accentGreenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Sign In',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _accentGreen,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard-Style Input Field ──────────────────────────────────────

class _DashboardStyleInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DashboardStyleInput({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  State<_DashboardStyleInput> createState() => _DashboardStyleInputState();
}

class _DashboardStyleInputState extends State<_DashboardStyleInput> {
  bool _isFocused = false;

  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _accentGreenSoft = Color(0xFFD8F3DC);
  static const Color _textPrimary = Color(0xFF1B1B1B);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _inputBg = Color(0xFFF9FAF7);
  static const Color _inputBorder = Color(0xFFD9D5CD);

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _isFocused ? _accentGreen : _textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _isFocused ? _accentGreenSoft.withOpacity(0.3) : _inputBg,
            border: Border.all(
              color: _isFocused ? _accentGreen : _inputBorder,
              width: _isFocused ? 1.8 : 1.2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: _accentGreen.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                fontSize: 14,
                color: _textSecondary.withOpacity(0.5),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  widget.prefixIcon,
                  color: _isFocused ? _accentGreen : _textSecondary,
                  size: 20,
                ),
              ),
              prefixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: widget.suffixIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: widget.suffixIcon,
                    )
                  : null,
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.expense,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dashboard Green Button ───────────────────────────────────────────

class _DashboardButton extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool isLoading;

  const _DashboardButton({
    required this.text,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  State<_DashboardButton> createState() => _DashboardButtonState();
}

class _DashboardButtonState extends State<_DashboardButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _accentGreenLight = Color(0xFF40916C);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          if (!widget.isLoading) widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [_accentGreen, _accentGreenLight],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _accentGreen.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Password Strength Indicator ──────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final double val;
  final String label;

  static const Color _accentGreen = Color(0xFF2D6A4F);
  static const Color _textSecondary = Color(0xFF6B7280);

  const _PasswordStrengthBar({required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    double progress;

    if (val <= 0.3) {
      color = AppColors.expense;
      progress = 0.33;
    } else if (val <= 0.6) {
      color = AppColors.warning;
      progress = 0.66;
    } else {
      color = _accentGreen;
      progress = 1.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password strength',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(3, (index) {
            final active = progress >= ((index + 1) / 3.0) - 0.05;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 4,
                margin: EdgeInsets.only(right: index < 2 ? 6.0 : 0.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: active
                      ? color
                      : const Color(0xFFE5E7EB),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
