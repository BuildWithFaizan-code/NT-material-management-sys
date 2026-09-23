import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // MFA challenge state
  bool _isMfaStep = false;
  String? _mfaChallengeToken;
  final _mfaCodeController = TextEditingController();

  // Forced password change state
  bool _isChangePasswordStep = false;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (AuthService.instance.mustChangePassword) {
      _isChangePasswordStep = true;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    final result = await AuthService.instance.login(username, password);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    if (result.requiresMfa && result.mfaChallengeToken != null) {
      setState(() {
        _isMfaStep = true;
        _mfaChallengeToken = result.mfaChallengeToken;
        _errorMessage = null;
      });
      return;
    }

    if (result.mustChangePassword) {
      setState(() {
        _isChangePasswordStep = true;
        _currentPasswordController.text = password;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleMfaVerify() async {
    final code = _mfaCodeController.text.trim();
    if (code.length < 6 || _mfaChallengeToken == null) {
      setState(() {
        _errorMessage = 'Please enter a valid 6-digit code.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.instance.verifyMfaLogin(_mfaChallengeToken!, code);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (!result.success) {
      setState(() {
        _errorMessage = result.message;
      });
      return;
    }

    if (result.mustChangePassword) {
      setState(() {
        _isChangePasswordStep = true;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleChangePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 10) {
      setState(() {
        _errorMessage = 'New password must be at least 10 characters long.';
      });
      return;
    }

    if (int.tryParse(newPassword) != null) {
      setState(() {
        _errorMessage = 'New password cannot be purely numeric.';
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'New passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.instance.changePassword(currentPassword, newPassword);
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully.'),
            backgroundColor: AppColors.primaryColor,
          ),
        );
        setState(() {
          _isChangePasswordStep = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 960;

            if (!isDesktop) {
              return _buildMobileLayout(constraints);
            }

            return _buildDualPanelLayout(constraints);
          },
        ),
      ),
    );
  }

  /// Desktop / Tablet Wide Dual Panel Layout
  Widget _buildDualPanelLayout(BoxConstraints constraints) {
    return Row(
      children: [
        // Left Pane: 3D Model & Brand Header
        Expanded(
          flex: 5,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Header: Logo Badge + "NewTech" (Sharp, No subtitle, on left)
                _buildBrandHeader(center: false),
                const SizedBox(height: 16),

                // 3D Lottie Animation: Big, Centered, High Performance & Paced Cycle
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      child: _Paced3DLottieModel(
                        maxWidth: 620,
                        maxHeight: constraints.maxHeight * 0.64,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                // Left Pane Footer Badges
                Center(child: _buildLeftPaneFooter()),
              ],
            ),
          ),
        ),

        // Center Divider: Cloudy and Fluid Border
        const FluidWaveDivider(),

        // Right Pane: Blue Gradient Background matching reference image + Floating Modern White Login Box
        Expanded(
          flex: 5,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_blue_gradient_bg.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
            child: Stack(
              children: [
                // Subtle ambient glow & gradient overlay to match theme perfectly
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFCFA7FB).withValues(alpha: 0.12),
                          Colors.transparent,
                          const Color(0xFF1E3A8A).withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Center Scrollable Content: White Modern Login Box
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 38),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.22),
                                  blurRadius: 40,
                                  offset: const Offset(0, 18),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _buildContent(),
                          ),
                        ),
                        // Bottom margin so box doesn't overlap footer
                        const SizedBox(height: 36),
                      ],
                    ),
                  ),
                ),

                // Right Pane Bottom Footer: Translucent White Links & Moon Toggle (matches reference image)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Footer Navigation Links in soft translucent white
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _buildRightPaneFooterLink('Integrations'),
                          _buildRightPaneFooterLink('License'),
                          _buildRightPaneFooterLink('Terms of Use'),
                          _buildRightPaneFooterLink('Privacy'),
                        ],
                      ),
                      // Moon / Night Mode Circular Glass Button (as shown in reference image)
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.nightlight_round,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Compact Mobile / Narrow Screen Layout
  Widget _buildMobileLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                _buildBrandHeader(center: true),
                const SizedBox(height: 16),
                RepaintBoundary(
                  child: SizedBox(
                    height: 220,
                    child: _Paced3DLottieModel(
                      maxHeight: 220,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Mobile Blue Gradient Container with Floating Modern White Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_blue_gradient_bg.jpg'),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                          blurRadius: 28,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: _buildContent(),
                  ),
                ),
                const SizedBox(height: 24),
                _buildMobileRightPaneFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sharp Brand Header: Logo Badge + "NewTech" (Sharp Italic, Enlarged 'N' and 'T')
  Widget _buildBrandHeader({bool center = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand Gold Medal Badge Logo with Long X-Forming Ribbon
        Image.asset(
          'assets/images/newtech_logo_badge.png',
          height: 60,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        const SizedBox(width: 14),
        // Sharp "NewTech" Italic Typography with Specifically Enlarged 'N' and 'T'
        RichText(
          text: TextSpan(
            children: [
              // Large Sharp 'N'
              TextSpan(
                text: 'N',
                style: GoogleFonts.kanit(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1D5CFF),
                  letterSpacing: -1.0,
                ),
              ),
              // Sharp 'ew'
              TextSpan(
                text: 'ew',
                style: GoogleFonts.kanit(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1D5CFF),
                  letterSpacing: -0.5,
                ),
              ),
              // Large Sharp 'T'
              TextSpan(
                text: 'T',
                style: GoogleFonts.kanit(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFF6400),
                  letterSpacing: -1.0,
                ),
              ),
              // Sharp 'ech'
              TextSpan(
                text: 'ech',
                style: GoogleFonts.kanit(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFF6400),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Reassurance badges at bottom of left pane
  Widget _buildLeftPaneFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        _buildPillBadge(Icons.cloud_done_rounded, 'Cloud Synchronized'),
        _buildPillBadge(Icons.shield_outlined, '2FA Protected'),
        _buildPillBadge(Icons.inventory_2_outlined, 'Live Material Flow'),
      ],
    );
  }

  Widget _buildPillBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.brandBlue),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPaneFooterLink(String label) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _buildMobileRightPaneFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 4,
      children: [
        _buildRightPaneFooterLink('Integrations'),
        _buildRightPaneFooterLink('License'),
        _buildRightPaneFooterLink('Terms of Use'),
        _buildRightPaneFooterLink('Privacy'),
      ],
    );
  }

  Widget _buildContent() {
    if (_isChangePasswordStep) {
      return _buildChangePasswordView();
    }
    if (_isMfaStep) {
      return _buildMfaView();
    }
    return _buildLoginView();
  }

  Widget _buildLoginView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Capsule Security Indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brandBlue.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_outlined, size: 13, color: AppColors.brandBlue),
                    const SizedBox(width: 5),
                    Text(
                      'Secure Enterprise Portal',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Greeting Title
          Text(
            'Sign In to Your Workspace',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: AppColors.neutralDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your credentials to access your workspace.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // Error Message Banner
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMd),
                border: Border.all(color: AppColors.errorBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.errorDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Username Field
          Text(
            'Username or Email',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.neutralDark,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your username or email',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.black38),
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Username is required';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Password Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Password',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutralDark,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact your system administrator to reset credentials.'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: GoogleFonts.poppins(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.black38),
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 26),

          // Primary Sign In Button
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 2,
                shadowColor: AppColors.brandBlue.withValues(alpha: 0.35),
              ),
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Text(
                      'Sign In to Workspace',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMfaView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.security_rounded, color: AppColors.info, size: 28),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Two-Factor Authentication',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code generated by your Authenticator app.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMd),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.errorDark, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],

        TextFormField(
          controller: _mfaCodeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: '000000',
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onFieldSubmitted: (_) => _handleMfaVerify(),
        ),
        const SizedBox(height: 22),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleMfaVerify,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Text('Verify & Continue', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 14),
        TextButton(
          onPressed: () {
            setState(() {
              _isMfaStep = false;
              _mfaChallengeToken = null;
              _mfaCodeController.clear();
              _errorMessage = null;
            });
          },
          child: Text('Back to Login', style: GoogleFonts.poppins(color: AppColors.neutralDark, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildChangePasswordView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.key_rounded, color: AppColors.warning, size: 28),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Password Update Required',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.neutralDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your account requires a new password before continuing (minimum 10 characters, cannot be purely numeric).',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
        ),
        const SizedBox(height: 24),

        if (_errorMessage != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusMd),
              border: Border.all(color: AppColors.errorBorder),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.errorDark, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
        ],

        Text('Current Password', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _currentPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        Text('New Password (min 10 characters)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        Text('Confirm New Password', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: _obscureNewPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading ? null : _handleChangePassword,
            child: _isLoading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                : Text('Update Password & Enter', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }
}

/// Cloudy and Fluid Wave Divider separating Left and Right Panes
class FluidWaveDivider extends StatelessWidget {
  const FluidWaveDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: double.infinity,
      child: CustomPaint(
        painter: _CloudyFluidWavePainter(),
      ),
    );
  }
}

class _CloudyFluidWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fill left side with pure white (matching Left Pane)
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), whitePaint);

    // Layer 1: Soft shadow aura
    final shadowPaint = Paint()
      ..color = const Color(0xFF1E40AF).withValues(alpha: 0.12)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final auraPath = Path();
    auraPath.moveTo(w * 0.45, 0);
    auraPath.cubicTo(w * 0.9, h * 0.18, w * 0.1, h * 0.45, w * 0.8, h * 0.72);
    auraPath.cubicTo(w * 0.95, h * 0.86, w * 0.2, h * 0.94, w * 0.45, h);
    auraPath.lineTo(w, h);
    auraPath.lineTo(w, 0);
    auraPath.close();
    canvas.drawPath(auraPath, shadowPaint);

    // Layer 2: Deep vibrant blue gradient matching the Right Pane background
    final wavePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2563EB),
          Color(0xFF1D4ED8),
          Color(0xFF1E40AF),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final cloudPath = Path();
    cloudPath.moveTo(w * 0.45, 0);
    cloudPath.cubicTo(w * 0.88, h * 0.18, w * 0.12, h * 0.44, w * 0.78, h * 0.7);
    cloudPath.cubicTo(w * 0.92, h * 0.84, w * 0.22, h * 0.94, w * 0.45, h);
    cloudPath.lineTo(w, h);
    cloudPath.lineTo(w, 0);
    cloudPath.close();
    canvas.drawPath(cloudPath, wavePaint);

    // Layer 3: Vibrant fluid contour line with glowing electric cyan/sky blue gradient
    final strokePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF93C5FD),
          Color(0xFF38BDF8),
          Color(0xFF60A5FA),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    final linePath = Path();
    linePath.moveTo(w * 0.45, 0);
    linePath.cubicTo(w * 0.88, h * 0.18, w * 0.12, h * 0.44, w * 0.78, h * 0.7);
    linePath.cubicTo(w * 0.92, h * 0.84, w * 0.22, h * 0.94, w * 0.45, h);
    canvas.drawPath(linePath, strokePaint);

    // Subtle glowing droplets along the wave curve
    final dotPaint = Paint()..color = const Color(0xFF60A5FA).withValues(alpha: 0.6);
    canvas.drawCircle(Offset(w * 0.74, h * 0.21), 3.2, dotPaint);
    canvas.drawCircle(Offset(w * 0.24, h * 0.46), 2.6, dotPaint);
    canvas.drawCircle(Offset(w * 0.69, h * 0.73), 3.4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// High-performance 3D Lottie animation with controlled cycle pacing and hold interval.
/// Showcases the complete model on screen by pausing at full completion before restarting.
class _Paced3DLottieModel extends StatefulWidget {
  final double? maxHeight;
  final double? maxWidth;

  const _Paced3DLottieModel({
    this.maxHeight,
    this.maxWidth,
  });

  @override
  State<_Paced3DLottieModel> createState() => _Paced3DLottieModelState();
}

class _Paced3DLottieModelState extends State<_Paced3DLottieModel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _opacity = 1.0;
  bool _isDisposed = false;
  bool _hasStarted = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _onCompositionLoaded(LottieComposition composition) {
    if (_hasStarted || _isDisposed || !mounted) return;
    _hasStarted = true;
    // Set a steady, majestic pace (6.8s) for the complete assembly animation
    _controller.duration = const Duration(milliseconds: 6800);
    _runPacedAnimationCycle();
  }

  Future<void> _runPacedAnimationCycle() async {
    // Normalization bounds based on composition frame counts:
    // Frame 110: Scene is 100% assembled; team discussion/gesture loop starts
    // Frame 170: Team discussion/gesture loop completes with identical resting poses
    const double idleStart = 110.0 / 171.0;
    const double idleEnd = 170.0 / 171.0;
    const int idleLoopDurationMs = 2000;

    while (!_isDisposed && mounted) {
      if (mounted) setState(() => _opacity = 1.0);

      // 1. Initial Assembly: Build up all elements from frame 0 to frame 170
      _controller.value = 0.0;
      try {
        await _controller.animateTo(
          idleEnd,
          duration: const Duration(milliseconds: 6200),
          curve: Curves.linear,
        ).orCancel;
      } catch (_) {
        break; // Cancelled if widget is disposed
      }

      if (_isDisposed || !mounted) break;

      // 2. Active Hold Interval: Continue the live animation loop of the complete 3D model
      // Run the seamless 110-170 frame gesture cycle 3 times (~6.0s total).
      // Keeps the complete model actively gesturing, pointing at charts, and nodding without pausing!
      for (int i = 0; i < 3; i++) {
        if (_isDisposed || !mounted) break;
        _controller.value = idleStart;
        try {
          await _controller.animateTo(
            idleEnd,
            duration: const Duration(milliseconds: idleLoopDurationMs),
            curve: Curves.linear,
          ).orCancel;
        } catch (_) {
          break;
        }
      }

      if (_isDisposed || !mounted) break;

      // 3. Gentle crossfade transition before starting the next full assembly cycle
      if (mounted) {
        setState(() => _opacity = 0.0);
      }
      await Future.delayed(const Duration(milliseconds: 350));

      if (_isDisposed || !mounted) break;

      _controller.value = 0.0;
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: widget.maxWidth ?? double.infinity,
          maxHeight: widget.maxHeight ?? double.infinity,
        ),
        child: Lottie.asset(
          'assets/animations/business_analysis_3d.json',
          controller: _controller,
          onLoaded: _onCompositionLoaded,
          fit: BoxFit.contain,
          frameRate: FrameRate.max,
          options: LottieOptions(enableMergePaths: true),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

