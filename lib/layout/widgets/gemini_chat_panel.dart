import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/gemini_ai_service.dart';
import '../../state/layout_state.dart';

class GeminiChatPanel extends StatefulWidget {
  final LayoutState? layoutState;
  const GeminiChatPanel({super.key, this.layoutState});

  @override
  State<GeminiChatPanel> createState() => _GeminiChatPanelState();
}

class _GeminiChatPanelState extends State<GeminiChatPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;

  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasInputText = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(1.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = CurvedAnimation(
      parent: _slideCtrl,
      curve: Curves.easeOut,
    );

    _promptController.addListener(() {
      final hasText = _promptController.text.trim().isNotEmpty;
      if (hasText != _hasInputText) {
        setState(() => _hasInputText = hasText);
      }
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _promptController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? prefilledText]) {
    final text = prefilledText ?? _promptController.text;
    if (text.trim().isEmpty) return;

    final aiService = GeminiAiService();
    aiService.sendMessage(text);

    if (prefilledText == null) {
      _promptController.clear();
    }
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _showApiKeyDialog(BuildContext context) {
    final aiService = GeminiAiService();
    final keyController = TextEditingController(text: aiService.customApiKey ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF9B72CB)],
              ).createShader(bounds),
              child: const Icon(Icons.key_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Gemini API Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The system already provides built-in enterprise knowledge. You can optionally supply your own Google Gemini API key for live multimodal responses:',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyController,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Enter AIzaSy... key',
                labelText: 'Google Gemini API Key',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Leave empty to use the server-side default or built-in copilot.',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              keyController.clear();
              aiService.setCustomApiKey(null);
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              aiService.setCustomApiKey(keyController.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Gemini API key updated successfully!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Save Key'),
          ),
        ],
      ),
    );
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

    if (isOpen) {
      _slideCtrl.forward();
    } else {
      _slideCtrl.reverse();
    }

    return AnimatedBuilder(
      animation: _slideCtrl,
      builder: (context, child) {
        if (_slideCtrl.value == 0) return const SizedBox.shrink();

        final screenWidth = MediaQuery.of(context).size.width;
        final panelWidth = screenWidth < 500 ? screenWidth : 440.0;

        return Stack(
          children: [
            // Backdrop Scrim for mobile or clean dismissal
            if (screenWidth < 768)
              GestureDetector(
                onTap: () => layoutState?.setAiPanelOpen(false),
                child: Container(
                  color: Colors.black.withOpacity(0.35 * _fadeAnim.value),
                ),
              ),

            // Slide-out Drawer Panel
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: panelWidth,
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4285F4).withOpacity(0.12),
                          blurRadius: 32,
                          offset: const Offset(-8, 0),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          _buildHeader(context, layoutState),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(child: _buildMessagesArea(context)),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          _buildInputBar(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, LayoutState? layoutState) {
    final aiService = GeminiAiService();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAFC),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // Gemini Sparkle Logo with Gradient Ring
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF4285F4), // Blue
                  Color(0xFF9B72CB), // Purple
                  Color(0xFFD96570), // Coral
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF9B72CB).withOpacity(0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle with Gemini Gradient Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF1E293B),
                          Color(0xFF4285F4),
                          Color(0xFF9B72CB),
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'Gemini AI',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'COPILOT',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF38BDF8),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'NT-MMS Intelligent Assistant',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Action 1: Settings / API Key
          IconButton(
            icon: const Icon(Icons.tune_rounded, size: 18),
            color: const Color(0xFF64748B),
            tooltip: 'Gemini Settings & API Key',
            onPressed: () => _showApiKeyDialog(context),
          ),

          // Action 2: Clear Conversation
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 18),
            color: const Color(0xFF64748B),
            tooltip: 'New Conversation',
            onPressed: () => aiService.clearConversation(),
          ),

          // Action 3: Close Panel
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF475569),
            tooltip: 'Close Panel',
            onPressed: () => layoutState?.setAiPanelOpen(false),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    return AnimatedBuilder(
      animation: GeminiAiService(),
      builder: (context, _) {
        final aiService = GeminiAiService();
        final messages = aiService.messages;
        final isLoading = aiService.isLoading;

        if (messages.length <= 1) {
          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHero(),
                const SizedBox(height: 24),
                _buildSuggestedPromptCards(),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          itemCount: messages.length + (isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == messages.length && isLoading) {
              return _buildThinkingIndicator();
            }
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildWelcomeHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8FAFC), Color(0xFFEEF2FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF9B72CB),
                    Color(0xFFD96570),
                  ],
                ).createShader(bounds),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Hello, Admin!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'How can I help you manage your enterprise today? Ask me about bill of materials, stock transfers, purchase orders, or master setups.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF475569),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedPromptCards() {
    final suggestions = [
      {
        'icon': Icons.account_tree_outlined,
        'title': 'How do I create a Bill of Materials (BOM)?',
        'desc': 'Formulas, raw material calculations & BOM closing',
      },
      {
        'icon': Icons.shopping_cart_outlined,
        'title': 'Explain Purchase Order approval process',
        'desc': 'Vendor rates, authorization & advance entries',
      },
      {
        'icon': Icons.swap_horiz_rounded,
        'title': 'How does Stock Transfer work across stores?',
        'desc': 'Warehouse ledger, locking dates & requisitions',
      },
      {
        'icon': Icons.security_rounded,
        'title': 'How are User Roles & Permissions assigned?',
        'desc': 'View, Add, Update & Delete action matrix',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'POPULAR TOPICS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 12),
        ...suggestions.map(
          (s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _sendMessage(s['title'] as String),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: const Color(0xFF4285F4),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['title'] as String,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s['desc'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF4285F4),
                    Color(0xFF9B72CB),
                    Color(0xFFD96570),
                  ],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0F172A) // Dark Slate
                    : (message.isError
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFF8FAFC)),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser
                      ? Colors.transparent
                      : (message.isError
                          ? const Color(0xFFFECACA)
                          : const Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formatMessageContent(message.content, isUser),
                  if (!isUser) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 14),
                          color: const Color(0xFF94A3B8),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Copy response',
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: message.content),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Copied response to clipboard!'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _formatMessageContent(String raw, bool isUser) {
    if (isUser) {
      return Text(
        raw,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          height: 1.45,
        ),
      );
    }

    final lines = raw.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(
            trimmed.replaceFirst('### ', ''),
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ));
      } else if (trimmed.startsWith('• ') || trimmed.startsWith('- ')) {
        final bulletText = trimmed.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('• ',
                  style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              Expanded(
                child: _buildRichInlineText(
                  bulletText,
                  const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ));
      } else if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildRichInlineText(
            trimmed,
            const TextStyle(
              color: Color(0xFF334155),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildRichInlineText(String text, TextStyle defaultStyle) {
    final spans = <InlineSpan>[];
    final parts = text.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(TextSpan(
          text: parts[i],
          style: defaultStyle.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ));
      } else {
        final codeParts = parts[i].split('`');
        for (int j = 0; j < codeParts.length; j++) {
          if (j % 2 == 1) {
            spans.add(TextSpan(
              text: codeParts[j],
              style: defaultStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: 11.5,
                backgroundColor: const Color(0xFFE2E8F0),
                color: const Color(0xFF1E293B),
              ),
            ));
          } else {
            spans.add(TextSpan(text: codeParts[j], style: defaultStyle));
          }
        }
      }
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildThinkingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  Color(0xFF4285F4),
                  Color(0xFF9B72CB),
                  Color(0xFFD96570),
                ],
              ),
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBouncingDot(const Color(0xFF4285F4), 0),
                const SizedBox(width: 5),
                _buildBouncingDot(const Color(0xFF9B72CB), 150),
                const SizedBox(width: 5),
                _buildBouncingDot(const Color(0xFFD96570), 300),
                const SizedBox(width: 8),
                const Text(
                  'Gemini is thinking...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBouncingDot(Color color, int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: -4),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final aiService = GeminiAiService();
    final isLoading = aiService.isLoading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: const Color(0xFFF8FAFC),
          border: Border.all(
            color: _focusNode.hasFocus
                ? const Color(0xFF9B72CB)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: _focusNode.hasFocus
              ? [
                  BoxShadow(
                    color: const Color(0xFF9B72CB).withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _promptController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Ask Gemini anything about MMS...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _hasInputText && !isLoading
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF4285F4),
                            Color(0xFF9B72CB),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: _hasInputText && !isLoading
                      ? null
                      : const Color(0xFFE2E8F0),
                ),
                child: IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF4285F4),
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          size: 18,
                          color: _hasInputText ? Colors.white : const Color(0xFF94A3B8),
                        ),
                  onPressed: _hasInputText && !isLoading ? _sendMessage : null,
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
