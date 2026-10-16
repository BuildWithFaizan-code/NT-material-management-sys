import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../design/app_colors.dart';
import '../sales_order_models.dart';

class SoAnimatedSuccessButton extends StatefulWidget {
  final ButtonStatus status;
  final VoidCallback? onPressed;
  final String idleText;
  final String loadingText;
  final String successText;
  final String errorText;
  final IconData idleIcon;
  final Color idleBackgroundColor;
  final Color successBackgroundColor;
  final Color errorBackgroundColor;
  final double height;
  final double? width;
  final double fontSize;
  final BorderRadius? borderRadius;

  const SoAnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Saving...',
    this.successText = 'Saved!',
    this.errorText = 'Failed',
    this.idleIcon = Icons.save_rounded,
    this.idleBackgroundColor = AppColors.primaryColor,
    this.successBackgroundColor = AppColors.success,
    this.errorBackgroundColor = AppColors.error,
    this.height = 36,
    this.width,
    this.fontSize = 11.5,
    this.borderRadius,
  });

  @override
  State<SoAnimatedSuccessButton> createState() => _SoAnimatedSuccessButtonState();
}

class _SoAnimatedSuccessButtonState extends State<SoAnimatedSuccessButton>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _glowController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _checkController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
      ),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _shakeController,
        curve: Curves.easeInOut,
      ),
    );

    _handleStatusChange(ButtonStatus.idle, widget.status);
  }

  @override
  void didUpdateWidget(SoAnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      _handleStatusChange(oldWidget.status, widget.status);
    }
  }

  void _handleStatusChange(ButtonStatus oldStatus, ButtonStatus newStatus) {
    if (newStatus == ButtonStatus.success) {
      _checkController.forward(from: 0.0);
      _glowController.repeat(reverse: true);
    } else if (newStatus == ButtonStatus.error) {
      _shakeController.forward(from: 0.0);
      _glowController.stop();
      _checkController.reset();
    } else {
      _glowController.stop();
      _glowController.reset();
      _checkController.reset();
      _shakeController.reset();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _glowController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(6.0);

    return AnimatedBuilder(
      animation: Listenable.merge([
        _checkController,
        _glowController,
        _shakeController,
      ]),
      builder: (context, child) {
        Color bgColor;
        switch (widget.status) {
          case ButtonStatus.success:
            bgColor = widget.successBackgroundColor;
            break;
          case ButtonStatus.error:
            bgColor = widget.errorBackgroundColor;
            break;
          case ButtonStatus.loading:
          case ButtonStatus.idle:
            bgColor = widget.idleBackgroundColor;
            break;
        }

        final double shakeOffset = widget.status == ButtonStatus.error
            ? math.sin(_shakeAnimation.value * math.pi * 4) * 6
            : 0.0;

        final double glowRadius = widget.status == ButtonStatus.success
            ? 8.0 + (_glowAnimation.value * 8.0)
            : 0.0;

        return Transform.translate(
          offset: Offset(shakeOffset, 0),
          child: Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: effectiveBorderRadius,
              boxShadow: widget.status == ButtonStatus.success
                  ? [
                      BoxShadow(
                        color: widget.successBackgroundColor.withValues(alpha: 0.5 * (1.0 - _glowAnimation.value * 0.3)),
                        blurRadius: glowRadius,
                        spreadRadius: 2.0,
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: bgColor,
              borderRadius: effectiveBorderRadius,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.status == ButtonStatus.loading ? null : widget.onPressed,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildIcon(),
                      const SizedBox(width: 6),
                      Text(
                        _getText(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    switch (widget.status) {
      case ButtonStatus.loading:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case ButtonStatus.success:
        return Transform.scale(
          scale: _scaleAnimation.value * _bounceAnimation.value,
          child: const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 16,
          ),
        );
      case ButtonStatus.error:
        return const Icon(
          Icons.error_outline_rounded,
          color: Colors.white,
          size: 16,
        );
      case ButtonStatus.idle:
        return Icon(
          widget.idleIcon,
          color: Colors.white,
          size: 16,
        );
    }
  }

  String _getText() {
    switch (widget.status) {
      case ButtonStatus.loading:
        return widget.loadingText;
      case ButtonStatus.success:
        return widget.successText;
      case ButtonStatus.error:
        return widget.errorText;
      case ButtonStatus.idle:
        return widget.idleText;
    }
  }
}
