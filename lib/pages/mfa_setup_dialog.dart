import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../design/app_colors.dart';
import '../design/app_dimensions.dart';
import '../services/auth_service.dart';

class MfaSetupDialog extends StatefulWidget {
  const MfaSetupDialog({super.key});

  @override
  State<MfaSetupDialog> createState() => _MfaSetupDialogState();
}

class _MfaSetupDialogState extends State<MfaSetupDialog> {
  bool _isLoading = true;
  String _secretKey = '';
  String _otpAuthUri = '';
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSetupKey();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _fetchSetupKey() async {
    try {
      final setupData = await AuthService.instance.setupMfa();
      if (!mounted) return;
      setState(() {
        _secretKey = setupData['secretKey'] ?? '';
        _otpAuthUri = setupData['otpAuthUri'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate MFA secret: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleConfirm() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() {
        _errorMessage = 'Please enter a 6-digit confirmation code.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.instance.verifyAndEnableMfa(_secretKey, code);
      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Two-Factor Authentication successfully enabled!'),
            backgroundColor: AppColors.primaryColor,
          ),
        );
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Invalid code. Please ensure your device clock is synchronized and try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = 'Verification error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusLg)),
      backgroundColor: AppColors.surfaceColor,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(28),
        child: _isLoading
            ? const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.security_rounded, color: AppColors.primaryColor, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Set Up Two-Factor (MFA)',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan this QR code with Google Authenticator, Authy, or Microsoft Authenticator.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                    const SizedBox(height: 20),

                    // QR Code
                    if (_otpAuthUri.isNotEmpty)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: QrImageView(
                            data: _otpAuthUri,
                            version: QrVersions.auto,
                            size: 160.0,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Manual Entry Secret Key
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MANUAL ENTRY SECRET',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  _secretKey,
                                  style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Copy Secret',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _secretKey));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Secret copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'Enter the 6-digit confirmation code from your app:',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, letterSpacing: 6, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: '000000',
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _isSubmitting ? null : _handleConfirm,
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Confirm & Activate MFA', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
