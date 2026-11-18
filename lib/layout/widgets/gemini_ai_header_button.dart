import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/layout_state.dart';

class GeminiAiHeaderButton extends StatefulWidget {
  final LayoutState? layoutState;
  const GeminiAiHeaderButton({super.key, this.layoutState});

  @override
  State<GeminiAiHeaderButton> createState() => _GeminiAiHeaderButtonState();
}

class _GeminiAiHeaderButtonState extends State<GeminiAiHeaderButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    LayoutState? layoutState = widget.layoutState;
    if (layoutState == null) {
      try {
        layoutState = Provider.of<LayoutState>(context);
      } catch (_) {}
    }
    final isOpen = layoutState?.isAiPanelOpen ?? false;

    return Tooltip(
      message: 'Ask Gemini AI Copilot',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            layoutState?.toggleAiPanel();
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isHovered ? 1.08 : (isOpen ? 1.04 : 1.0),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: isOpen
                          ? const [Color(0xFF4285F4), Color(0xFF9B72CB)]
                          : (_isHovered
                              ? const [Color(0xFFEEF2FF), Color(0xFFFDF2F8)]
                              : const [Color(0xFFF8FAFC), Color(0xFFF1F5F9)]),
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      width: isOpen ? 1.8 : 1.4,
                      color: isOpen
                          ? Colors.transparent
                          : (_isHovered
                              ? const Color(0xFF9B72CB)
                              : const Color(0xFFCBD5E1)),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isOpen
                            ? const Color(0xFF9B72CB).withOpacity(0.4)
                            : (_isHovered
                                ? const Color(0xFF4285F4).withOpacity(0.25)
                                : Colors.black.withOpacity(0.04)),
                        blurRadius: isOpen || _isHovered ? 12 : 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Multi-color Gemini Sparkle Icon
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Color(0xFF4285F4), // Google Blue
                            Color(0xFF9B72CB), // Gemini Purple
                            Color(0xFFD96570), // Gemini Coral
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                          size: 19,
                          color: isOpen ? Colors.white : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Gemini AI',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOpen
                              ? Colors.white
                              : (_isHovered
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFF334155)),
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Glowing status dot
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen
                              ? const Color(0xFF34D399) // emerald green
                              : const Color(0xFF818CF8), // indigo
                          boxShadow: [
                            BoxShadow(
                              color: (isOpen
                                      ? const Color(0xFF34D399)
                                      : const Color(0xFF818CF8))
                                  .withOpacity(0.8),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
