import 'package:flutter/material.dart';

/// A lightweight, performance-optimized deferred widget loader designed for Flutter Web.
/// 
/// Downloads module code chunks on-demand and renders zero-overhead placeholder states
/// to prevent full-canvas invalidations in low-resource and Windows RDP environments.
class DeferredWidget extends StatefulWidget {
  final Future<dynamic> Function() loader;
  final Widget Function() builder;
  final Widget? placeholder;

  const DeferredWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.placeholder,
  });

  @override
  State<DeferredWidget> createState() => _DeferredWidgetState();
}

class _DeferredWidgetState extends State<DeferredWidget> {
  Future<dynamic>? _future;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = widget.loader().then((_) {
        if (mounted) {
          setState(() {
            _hasLoaded = true;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasLoaded) {
      return widget.builder();
    }

    return FutureBuilder<dynamic>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Color(0xFFDC2626), size: 36),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load module',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry Loading'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0C3B2E),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return widget.builder();
        }

        return widget.placeholder ??
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0C3B2E)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading module...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
      },
    );
  }
}
