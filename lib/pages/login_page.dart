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
        Container(
          width: 1.2,
          height: constraints.maxHeight,
          color: const Color(0xFFE2E8F0),
        ),

        // Right Pane: Dedicated Full-Height Modern Sidebar
        Container(
          width: 480,
          height: constraints.maxHeight,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 20,
                offset: const Offset(-4, 0),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.8),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: AppColors.brandBlue.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildContent(),
                ),
              ),
            ),
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.divider.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
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
            children: [
              // Large Sharp 'N'
              TextSpan(
                text: 'N',
                style: GoogleFonts.kanit(
                  fontSize: 48,
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
                  fontSize: 34,
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
                  fontSize: 48,
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
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFFFF6400),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
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
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// AI Button: Curvy round shape circle with AI logo and distinct "AI" mark written on it
  Widget _buildAiButton(BuildContext context) {
    return Tooltip(
      message: 'NewTech AI Assistant',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAiAssistantDialog(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFF1D5CFF).withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1D5CFF).withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF1D5CFF),
                  size: 20,
                ),
                // Prominent "AI" text mark written directly on the button
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D5CFF),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Customer Care Button: Curvy round shape circle with customer care headset icon
  Widget _buildCustomerCareButton(BuildContext context) {
    return Tooltip(
      message: 'Customer Care & Support',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCustomerCareDialog(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  /// About App Button: Curvy round shape circle with about/info icon
  Widget _buildAboutAppButton(BuildContext context) {
    return Tooltip(
      message: 'About NewTech MMS',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAboutAppDialog(context),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF475569),
              size: 21,
            ),
          ),
        ),
      ),
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
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF1D5CFF), size: 22),
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
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF1D5CFF))),
          ),
        ],
      ),
    );
  }

  Widget _buildAiFeatureRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF1D5CFF)),
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
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Color(0xFF16A34A), size: 22),
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
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF16A34A))),
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
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Color(0xFFFF6400), size: 22),
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
                  const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
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
            child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFFFF6400))),
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
          // Greeting Title
          Text(
            'WELCOME BACK!',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.neutralDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your credentials to access your workspace.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.neutralDark.withValues(alpha: 0.65),
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

