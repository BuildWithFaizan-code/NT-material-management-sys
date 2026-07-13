import 'package:flutter/material.dart';
import '../state/layout_state.dart';
import '../state/status_state.dart';
import 'layout_large.dart';
import 'layout_small.dart';

class AppShell extends StatefulWidget {
  final LayoutState layoutState;
  final StatusState statusState;

  const AppShell({
    super.key,
    required this.layoutState,
    required this.statusState,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late LayoutState _layout;

  @override
  void initState() {
    super.initState();
    _layout = widget.layoutState;
    _layout.addListener(_onLayoutChanged);
  }

  @override
  void dispose() {
    _layout.removeListener(_onLayoutChanged);
    super.dispose();
  }

  void _onLayoutChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _layout.onResize(width);

        if (_layout.isLarge) {
          return LargeScreenLayout(
            layoutState: _layout,
            statusState: widget.statusState,
          );
        }

        return SmallScreenLayout(
          layoutState: _layout,
          statusState: widget.statusState,
        );
      },
    );
  }
}
