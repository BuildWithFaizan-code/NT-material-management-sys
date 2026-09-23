import 'dart:ui';
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
  bool _rememberMe = true;
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
        // Left Pane: Shifted to Left Corner Brand Header & Centered 3D Model Showcase
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row: Brand Identity on Left, Utility Buttons on the Empty Right Space
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildBrandHeader(center: false),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAiButton(context),
                        const SizedBox(width: 12),
                        _buildCustomerCareButton(context),
                        const SizedBox(width: 12),
                        _buildAboutAppButton(context),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 3D Lottie Animation: Big, Perfectly Centered
                Expanded(
                  child: Center(
                    child: RepaintBoundary(
                      child: _Paced3DLottieModel(
                        maxWidth: 740,
                        maxHeight: constraints.maxHeight * 0.74,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                // Left Pane Footer Badges (Centered)
                Center(child: _buildLeftPaneFooter()),
              ],
            ),
          ),
        ),

        // Split Screen Dividing Line
        // Right Pane: Dedicated Full-Height Modern Sidebar with Glassmorphism, Scenic City Illustration & Header Clouds
        SizedBox(
          width: 480,
          height: constraints.maxHeight,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // 1. Soft Sky Tint Background Gradient matching illustration
              Container(
                width: 480,
                height: constraints.maxHeight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFEFF6FF), // soft airy sky tint at top
                      Color(0xFFF8FAFC), // clean neutral center
                      Color(0xFFE0F2FE), // light sky blue near bottom matching illustration
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),

              // 2. Ambient Luminous Gradient Orbs for Glass Refraction
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF38BDF8).withValues(alpha: 0.16),
                        const Color(0xFF60A5FA).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 80,
                left: -30,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF06B6D4).withValues(alpha: 0.12),
                        const Color(0xFF38BDF8).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Frosted Glassmorphism Layer
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 480,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      border: const Border(
                        left: BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Header Clouds (floating softly at the top of the right pane to match the bottom scenery)
              Positioned(
                top: 22,
                left: 32,
                child: _buildHeaderCloud(width: 86, height: 32, opacity: 0.8),
              ),
              Positioned(
                top: 38,
                right: 36,
                child: _buildHeaderCloud(width: 112, height: 42, opacity: 0.75),
              ),
              Positioned(
                top: 86,
                left: 110,
                child: _buildHeaderCloud(width: 60, height: 24, opacity: 0.5),
              ),

              // 5. Bottom Cityscape Illustration (High-resolution corporate vector art)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                        ],
                        stops: [0.0, 0.16, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Opacity(
                      opacity: 0.95,
                      child: Image.asset(
                        'assets/images/login_city_illustration.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.bottomCenter,
                        height: 225,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ),

              // 6. Centered Elevated Login Card
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 404),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Compact Mobile / Narrow Screen Layout
  Widget _buildMobileLayout(BoxConstraints constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBrandHeader(center: false),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAiButton(context),
                  const SizedBox(width: 8),
                  _buildCustomerCareButton(context),
                  const SizedBox(width: 8),
                  _buildAboutAppButton(context),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Compact Paced 3D Animation for Mobile
          Center(
            child: RepaintBoundary(
              child: SizedBox(
                height: 220,
                child: _Paced3DLottieModel(
                  maxHeight: 220,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Centered Form Card
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.brandBlue.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Professional Brand Header: Left Corner, No Logo Badge, with Material Management System subtext
  Widget _buildBrandHeader({bool center = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Sharp "NewTech" Italic Typography with Specifically Enlarged 'N' and 'T'
        RichText(
          text: TextSpan(
            style: const TextStyle(height: 1.0),
            children: [
              // Large Sharp 'N'
              TextSpan(
                text: 'N',
                style: GoogleFonts.kanit(
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1D5CFF),
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              // Sharp 'ew'
              TextSpan(
                text: 'ew',
                style: GoogleFonts.kanit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF1D5CFF),
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
              // Large Sharp 'T'
              TextSpan(
                text: 'T',
                style: GoogleFonts.kanit(
                  fontSize: 60,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFF6400),
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              ),
              // Sharp 'ech'
              TextSpan(
                text: 'ech',
                style: GoogleFonts.kanit(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFF6400),
                  letterSpacing: -0.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        // Professional Structured Subtext
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 11,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1D5CFF),
                    Color(0xFFFF6400),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'MATERIAL MANAGEMENT SYSTEM',
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.2,
                color: const Color(0xFF64748B),
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// AI Button: Pink robot with hover animation and AI badge mark
  Widget _buildAiButton(BuildContext context) {
    return _HeaderHoverActionButton(
      tooltip: 'NewTech AI Assistant',
      icon: Icons.smart_toy_rounded,
      primaryColor: const Color(0xFFF43F5E),
      darkIconColor: const Color(0xFFE11D48),
      lightBgColor: const Color(0xFFFFF1F2),
      borderColor: const Color(0xFFFDA4AF),
      animType: _HoverAnimType.robotWiggle,
      onTap: () => _showAiAssistantDialog(context),
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE11D48).withValues(alpha: 0.40),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'AI',
          style: TextStyle(
            color: Colors.white,
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// Customer Care Button: Yellow/Amber support agent headset with attentive nodding hover animation
  Widget _buildCustomerCareButton(BuildContext context) {
    return _HeaderHoverActionButton(
      tooltip: 'Customer Care & Support',
      icon: Icons.support_agent_rounded,
      primaryColor: const Color(0xFFF59E0B),
      darkIconColor: const Color(0xFFD97706),
      lightBgColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFFCD34D),
      animType: _HoverAnimType.headsetNod,
      onTap: () => _showCustomerCareDialog(context),
    );
  }

  /// About App Button: Green solid badge logo with dynamic tilt hover animation
  Widget _buildAboutAppButton(BuildContext context) {
    return _HeaderHoverActionButton(
      tooltip: 'About NewTech MMS',
      icon: Icons.info_outline_rounded,
      primaryColor: const Color(0xFF10B981),
      darkIconColor: const Color(0xFF059669),
      lightBgColor: const Color(0xFFECFDF5),
      borderColor: const Color(0xFF6EE7B7),
      animType: _HoverAnimType.badgeTilt,
      onTap: () => _showAboutAppDialog(context),
    );
  }

  void _showAiAssistantDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2F8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFEC4899), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'NewTech AI Assistant',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Powered by Intelligent Material Intelligence:',
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
            ),
            const SizedBox(height: 12),
            _buildAiFeatureRow(Icons.trending_up_rounded, 'Predictive Stock Reordering', 'Automated purchase triggers based on consumption velocity.'),
            const SizedBox(height: 10),
            _buildAiFeatureRow(Icons.analytics_outlined, 'Anomaly & Cost Variance Detection', 'Real-time alert on abnormal material costing and consumption.'),
            const SizedBox(height: 10),
            _buildAiFeatureRow(Icons.inventory_2_outlined, 'Smart Warehouse Optimization', 'Dynamic allocation of bin and location storage efficiency.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFFEC4899))),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFeatureRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFEC4899)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
              Text(desc, style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    );
  }

  void _showCustomerCareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFCE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'Customer Care & Support',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Need help with your workspace or login credentials?',
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 16),
            _buildContactRow(Icons.email_outlined, 'Email Support', 'support@newtechinfosol.com'),
            const SizedBox(height: 10),
            _buildContactRow(Icons.phone_in_talk_outlined, 'Helpline', '+91 (0) 800-NEWTECH'),
            const SizedBox(height: 10),
            _buildContactRow(Icons.schedule_outlined, 'Hours', 'Mon - Sat, 9:00 AM - 7:00 PM IST'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFFD97706))),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
            Text(value, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
          ],
        ),
      ],
    );
  }

  void _showAboutAppDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_rounded, color: Color(0xFF059669), size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              'About NewTech MMS',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NewTech Material Management System',
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(height: 4),
            Text(
              'Version 1.0.0 Enterprise Build',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            Text(
              'Enterprise-grade inventory, multi-tier procurement workflows, costing master controls, department tracking, and automated stock reconciliation for manufacturing facilities.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF334155), height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    '256-bit AES Encrypted • MFA Enforced',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF475569)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
          ),
        ],
      ),
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

  /// Aesthetic stylized cloud matching the cityscape illustration header
  Widget _buildHeaderCloud({
    required double width,
    required double height,
    double opacity = 0.7,
  }) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Base rounded pill
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: height * 0.65,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(height * 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            // Left circular puff
            Positioned(
              bottom: height * 0.12,
              left: width * 0.16,
              child: Container(
                width: height * 0.72,
                height: height * 0.72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ),
            // Center-right higher puff
            Positioned(
              bottom: height * 0.2,
              right: width * 0.25,
              child: Container(
                width: height * 0.86,
                height: height * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.96),
                ),
              ),
            ),
          ],
        ),
      ),
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
          // Greeting Title with refined, clean typography
          Text(
            'Welcome Back',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue to your workspace.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),

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
            const SizedBox(height: 20),
          ],

          // Username Field
          Text(
            'Username or Email',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error, width: 1.6),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Username or email is required';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Password Field
          Text(
            'Password',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleLogin(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              suffixIcon: IconButton(
                splashRadius: 18,
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 18,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.brandBlue, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.error, width: 1.6),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Password is required';
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Remember Me Checkbox
          InkWell(
            onTap: () => setState(() => _rememberMe = !_rememberMe),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                      activeColor: AppColors.brandBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember device',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Action Buttons: Clear & Sign In (Classy & Small)
          Row(
            children: [
              // Clear Fields Button
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            _usernameController.clear();
                            _passwordController.clear();
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                            _formKey.currentState?.reset();
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 15,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Clear',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Sign In Button
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 40,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: _isLoading
                          ? null
                          : const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color: _isLoading ? const Color(0xFF93C5FD) : null,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _isLoading ? null : _handleLogin,
                        child: Center(
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sign In',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 15,
                                      color: Colors.white,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),

          // Security Trust Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_rounded,
                size: 12,
                color: Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                '256-bit TLS Encrypted Session',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
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

        Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _isLoading ? const Color(0xFF93C5FD) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isLoading ? null : _handleMfaVerify,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(
                        'Verify & Continue',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
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

        Container(
          height: 50,
          decoration: BoxDecoration(
            gradient: _isLoading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _isLoading ? const Color(0xFF93C5FD) : null,
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isLoading
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isLoading ? null : _handleChangePassword,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : Text(
                        'Update Password & Enter',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
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

enum _HoverAnimType {
  robotWiggle,
  headsetNod,
  badgeTilt,
}

/// Interactive Header Action Bubble with hover transitions and custom icon animations
class _HeaderHoverActionButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color primaryColor;
  final Color darkIconColor;
  final Color lightBgColor;
  final Color borderColor;
  final Widget? badge;
  final _HoverAnimType animType;
  final VoidCallback onTap;

  const _HeaderHoverActionButton({
    required this.tooltip,
    required this.icon,
    required this.primaryColor,
    required this.darkIconColor,
    required this.lightBgColor,
    required this.borderColor,
    this.badge,
    required this.animType,
    required this.onTap,
  });

  @override
  State<_HeaderHoverActionButton> createState() => _HeaderHoverActionButtonState();
}

class _HeaderHoverActionButtonState extends State<_HeaderHoverActionButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(dynamic _) {
    setState(() => _isHovered = true);
    _controller.repeat(reverse: true);
  }

  void _onExit(dynamic _) {
    setState(() => _isHovered = false);
    _controller.stop();
    _controller.animateTo(0.0, duration: const Duration(milliseconds: 180));
  }

  Widget _buildAnimatedIcon() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        if (!_isHovered) return child!;
        switch (widget.animType) {
          case _HoverAnimType.robotWiggle:
            // Lively robot head wiggle + cute bounce
            final angle = (_controller.value - 0.5) * 0.38;
            final offsetY = -2.5 * _controller.value;
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.rotate(
                angle: angle,
                child: child,
              ),
            );
          case _HoverAnimType.headsetNod:
            // Attentive support agent nod & slight pulse
            final offsetY = (_controller.value - 0.5) * 3.5;
            final scale = 1.0 + (_controller.value * 0.08);
            return Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
          case _HoverAnimType.badgeTilt:
            // Dynamic badge tilt & scale
            final angle = (_controller.value - 0.5) * 0.40;
            final scale = 1.0 + (_controller.value * 0.10);
            return Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: child,
              ),
            );
        }
      },
      child: Icon(
        widget.icon,
        color: _isHovered ? widget.darkIconColor : widget.darkIconColor.withValues(alpha: 0.90),
        size: 19,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 100),
      showDuration: const Duration(milliseconds: 2500),
      verticalOffset: 28,
      preferBelow: true,
      decoration: ShapeDecoration(
        color: Colors.white,
        shadows: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
        shape: const _TooltipBubbleBorder(
          arrowWidth: 12,
          arrowHeight: 6,
          borderRadius: 10,
          borderColor: Color(0xFFE2E8F0),
          borderWidth: 1.0,
          arrowOnTop: true,
        ),
      ),
      textStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF1E293B),
        letterSpacing: 0.2,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: MouseRegion(
        onEnter: _onEnter,
        onExit: _onExit,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _isHovered ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(0.0, _isHovered ? -2.5 : 0.0, 0.0),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isHovered
                      ? [
                          widget.lightBgColor,
                          widget.primaryColor.withValues(alpha: 0.22),
                        ]
                      : [
                          widget.lightBgColor.withValues(alpha: 0.65),
                          widget.lightBgColor,
                        ],
                ),
                border: Border.all(
                  color: _isHovered ? widget.primaryColor : widget.borderColor,
                  width: _isHovered ? 1.8 : 1.3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: widget.primaryColor.withValues(alpha: _isHovered ? 0.35 : 0.12),
                    blurRadius: _isHovered ? 14 : 7,
                    offset: Offset(0, _isHovered ? 4 : 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Inner Glassmorphic Floating Lens
                  Container(
                    width: 31,
                    height: 31,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.88),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.90),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.primaryColor.withValues(alpha: 0.08),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildAnimatedIcon(),
                    ),
                  ),
                  if (widget.badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: widget.badge!,
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

/// Elegant Speech Bubble ShapeBorder with a centered caret/notch pointer
class _TooltipBubbleBorder extends ShapeBorder {
  final double arrowWidth;
  final double arrowHeight;
  final double borderRadius;
  final Color borderColor;
  final double borderWidth;
  final bool arrowOnTop;

  const _TooltipBubbleBorder({
    this.arrowWidth = 12.0,
    this.arrowHeight = 6.0,
    this.borderRadius = 10.0,
    this.borderColor = const Color(0xFFE2E8F0),
    this.borderWidth = 1.0,
    this.arrowOnTop = true,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(
        top: arrowOnTop ? arrowHeight : 0,
        bottom: arrowOnTop ? 0 : arrowHeight,
      );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final r = borderRadius;
    final path = Path();
    final arrowH = arrowHeight;
    final arrowW = arrowWidth;
    final midX = rect.center.dx;

    if (arrowOnTop) {
      final top = rect.top + arrowH;
      path.moveTo(rect.left + r, top);
      // Top edge with upward pointing arrow notch
      path.lineTo(midX - arrowW / 2, top);
      path.lineTo(midX, rect.top);
      path.lineTo(midX + arrowW / 2, top);
      path.lineTo(rect.right - r, top);
      path.quadraticBezierTo(rect.right, top, rect.right, top + r);
      // Right edge
      path.lineTo(rect.right, rect.bottom - r);
      path.quadraticBezierTo(rect.right, rect.bottom, rect.right - r, rect.bottom);
      // Bottom edge
      path.lineTo(rect.left + r, rect.bottom);
      path.quadraticBezierTo(rect.left, rect.bottom, rect.left, rect.bottom - r);
      // Left edge
      path.lineTo(rect.left, top + r);
      path.quadraticBezierTo(rect.left, top, rect.left + r, top);
    } else {
      final bottom = rect.bottom - arrowH;
      path.moveTo(rect.left + r, rect.top);
      // Top edge
      path.lineTo(rect.right - r, rect.top);
      path.quadraticBezierTo(rect.right, rect.top, rect.right, rect.top + r);
      // Right edge
      path.lineTo(rect.right, bottom - r);
      path.quadraticBezierTo(rect.right, bottom, rect.right - r, bottom);
      // Bottom edge with downward pointing arrow notch
      path.lineTo(midX + arrowW / 2, bottom);
      path.lineTo(midX, rect.bottom);
      path.lineTo(midX - arrowW / 2, bottom);
      path.lineTo(rect.left + r, bottom);
      path.quadraticBezierTo(rect.left, bottom, rect.left, bottom - r);
      // Left edge
      path.lineTo(rect.left, rect.top + r);
      path.quadraticBezierTo(rect.left, rect.top, rect.left + r, rect.top);
    }
    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (borderWidth <= 0) return;
    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}


