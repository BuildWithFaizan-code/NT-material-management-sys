import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../bom_models.dart';

/// Reusable ERP Animated Success Button with pulsing glow effect,
/// ripple bursts, bouncing checkmark, and sparkle particles matching
/// the exact Project Master success strategy.
class BomAnimatedSuccessButton extends StatefulWidget {
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

  const BomAnimatedSuccessButton({
    super.key,
    required this.status,
    required this.onPressed,
    required this.idleText,
    this.loadingText = 'Saving...',
    this.successText = 'Saved!',
    this.errorText = 'Failed',
    this.idleIcon = Icons.save_rounded,
    this.idleBackgroundColor = const Color(0xFF0C3B2E),
    this.successBackgroundColor = const Color(0xFF10B981),
    this.errorBackgroundColor = const Color(0xFFEF4444),
    this.height = 36,
    this.width,
    this.fontSize = 11.5,
    this.borderRadius,
  });

  @override
  State<BomAnimatedSuccessButton> createState() => _BomAnimatedSuccessButtonState();
}

class _BomAnimatedSuccessButtonState extends State<BomAnimatedSuccessButton>
    with TickerProviderStateMixin {
  late AnimationController _checkController;
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rippleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _bounceAnimation;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeOut));

    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _checkController, curve: Curves.easeInOut));

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 60),
    ]).animate(CurvedAnimation(parent: _glowController, curve: Curves.easeOut));

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    if (widget.status == ButtonStatus.success) {
      _triggerSuccess();
    } else if (widget.status == ButtonStatus.error) {
      _shakeController.forward(from: 0.0);
    }
  }

  void _triggerSuccess() {
    _checkController.forward(from: 0.0);
    _rippleController.forward(from: 0.0);
    _glowController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant BomAnimatedSuccessButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == ButtonStatus.success && oldWidget.status != ButtonStatus.success) {
      _triggerSuccess();
    } else if (widget.status != ButtonStatus.success && oldWidget.status == ButtonStatus.success) {
      _checkController.reset();
      _rippleController.reset();
      _glowController.stop();
      _glowController.reset();
    }

    if (widget.status == ButtonStatus.error && oldWidget.status != ButtonStatus.error) {
      _shakeController.forward(from: 0.0);
    } else if (widget.status != ButtonStatus.error && oldWidget.status == ButtonStatus.error) {
      _shakeController.reset();
    }
  }

  @override
  void dispose() {
    _checkController.dispose();
    _rippleController.dispose();
    _glowController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;
    final bool isLoading = widget.status == ButtonStatus.loading;
    final bool isSuccess = widget.status == ButtonStatus.success;
    final bool isError = widget.status == ButtonStatus.error;
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(9);

    final Color bgColor = !isEnabled
        ? const Color(0xFF94A3B8)
        : (isSuccess
            ? widget.successBackgroundColor
            : (isError
                ? widget.errorBackgroundColor
                : (isLoading ? widget.idleBackgroundColor.withValues(alpha: 0.85) : widget.idleBackgroundColor)));

    return AnimatedBuilder(
      animation: Listenable.merge([_checkController, _rippleController, _glowController, _shakeController]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0.0),
          child: Transform.scale(
            scale: isSuccess ? _bounceAnimation.value : 1.0,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Ripple burst ring
                  if (isSuccess)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                          duration: const Duration(milliseconds: 100),
                          child: Transform.scale(
                            scale: 1.0 + (_rippleAnimation.value * 0.25),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: effectiveRadius,
                                border: Border.all(
                                  color: widget.successBackgroundColor.withValues(alpha: 0.6),
                                  width: 2.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Main button body
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: widget.height,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: effectiveRadius,
                      border: isSuccess
                          ? Border.all(color: const Color(0xFF34D399), width: 1.5)
                          : (isError ? Border.all(color: const Color(0xFFFCA5A5), width: 1.5) : null),
                      boxShadow: [
                        if (isSuccess)
                          BoxShadow(
                            color: widget.successBackgroundColor.withValues(alpha: 0.35 + (_glowAnimation.value * 0.4)),
                            blurRadius: 8 + (_glowAnimation.value * 14),
                            spreadRadius: 1.5 + (_glowAnimation.value * 2.5),
                            offset: const Offset(0, 2),
                          )
                        else if (isError)
                          BoxShadow(
                            color: widget.errorBackgroundColor.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 1.0,
                            offset: const Offset(0, 2),
                          )
                        else if (isEnabled)
                          BoxShadow(
                            color: bgColor.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (!isEnabled || isLoading || isSuccess || isError) ? null : widget.onPressed,
                        borderRadius: effectiveRadius,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLoading)
                                  const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                else if (isSuccess)
                                  ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                  )
                                else if (isError)
                                  const Icon(Icons.error_outline_rounded, size: 16, color: Colors.white)
                                else
                                  Icon(widget.idleIcon, size: 15, color: Colors.white),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, animation) {
                                      return FadeTransition(
                                        opacity: animation,
                                        child: SlideTransition(
                                          position: Tween<Offset>(
                                            begin: const Offset(0, 0.25),
                                            end: Offset.zero,
                                          ).animate(animation),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: Text(
                                      isLoading
                                          ? widget.loadingText
                                          : (isSuccess
                                              ? widget.successText
                                              : (isError ? widget.errorText : widget.idleText)),
                                      key: ValueKey<String>(
                                        isLoading
                                            ? 'loading'
                                            : (isSuccess
                                                ? widget.successText
                                                : (isError ? widget.errorText : widget.idleText)),
                                      ),
                                      style: TextStyle(
                                        fontSize: widget.fontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Sparkle particles
                if (isSuccess)
                  ...List.generate(6, (i) {
                    final angle = (i * 60.0) * (math.pi / 180.0);
                    final distance = 14.0 + (_rippleAnimation.value * 18.0);
                    return Positioned(
                      left: (widget.height / 2) - 2.5 + (distance * math.cos(angle)),
                      top: (widget.height / 2) - 2.5 + (distance * math.sin(angle)),
                      child: AnimatedOpacity(
                        opacity: (1.0 - _rippleAnimation.value).clamp(0.0, 1.0),
                        duration: const Duration(milliseconds: 100),
                        child: Container(
                          width: 4.5,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: i.isEven
                                ? Colors.white
                                : widget.successBackgroundColor.withValues(alpha: 0.8),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.successBackgroundColor.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    },
  );
  }
}
