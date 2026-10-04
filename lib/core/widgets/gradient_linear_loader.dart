import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// A sleek linear loader featuring a primary-color gradient.
///
/// Supports both indeterminate animated loading (smooth gradient beam)
/// and determinate progress (when byte progress is provided by network stream).
/// Adaptively sizes itself to look sharp in both small avatars and large gallery cards.
class GradientLinearLoader extends StatefulWidget {
  /// Determined progress from 0.0 to 1.0, or null for indeterminate animation.
  final double? progress;

  /// Primary theme color to generate the gradient from.
  /// Falls back to [AppColors.roleGymOwner] or [AppColors.primary].
  final Color? primaryColor;

  /// Custom linear gradient override if specific colors are desired.
  final LinearGradient? gradient;

  /// Height of the linear bar track.
  final double height;

  /// Optional fixed width for the loader bar.
  final double? width;

  /// Background color of the image container backdrop.
  final Color? backgroundColor;

  /// Track background color (behind the moving gradient bar).
  final Color? trackColor;

  /// Border radius of the progress bar.
  final BorderRadius? borderRadius;

  /// Force repeating animation even in test environments
  final bool forceAnimate;

  const GradientLinearLoader({
    super.key,
    this.progress,
    this.primaryColor,
    this.gradient,
    this.height = 3.5,
    this.width,
    this.backgroundColor,
    this.trackColor,
    this.borderRadius,
    this.forceAnimate = false,
  });

  @override
  State<GradientLinearLoader> createState() => _GradientLinearLoaderState();
}

class _GradientLinearLoaderState extends State<GradientLinearLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool get _isTest =>
      !widget.forceAnimate &&
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    if (widget.progress == null && !_isTest) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GradientLinearLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.progress != null && _controller.isAnimating) {
      _controller.stop();
    } else if (widget.progress == null && !_controller.isAnimating && !_isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectivePrimary = widget.primaryColor ??
        Theme.of(context).primaryColor;
    final accentColor = Color.lerp(effectivePrimary, Colors.white, 0.4) ??
        effectivePrimary;

    final effectiveGradient = widget.gradient ??
        LinearGradient(
          colors: [
            effectivePrimary,
            accentColor,
            effectivePrimary,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );

    final effectiveTrack = widget.trackColor ??
        effectivePrimary.withValues(alpha: 0.16);

    return Container(
      color: widget.backgroundColor ?? const Color(0xFF111724),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 120.0;
          final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 120.0;

          final barWidth = widget.width ??
              (maxW * 0.65).clamp(18.0, 160.0);
          final barHeight = maxH < 44 ? 2.5 : widget.height;
          final radius = widget.borderRadius ?? BorderRadius.circular(barHeight);

          return Center(
            child: SizedBox(
              width: barWidth,
              height: barHeight,
              child: ClipRRect(
                borderRadius: radius,
                child: Container(
                  color: effectiveTrack,
                  child: widget.progress != null
                      ? FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: widget.progress!.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: effectiveGradient,
                              borderRadius: radius,
                            ),
                          ),
                        )
                      : AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return FractionallySizedBox(
                              alignment: Alignment(
                                (_controller.value * 2.6) - 1.3,
                                0.0,
                              ),
                              widthFactor: 0.45,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      effectivePrimary.withValues(alpha: 0.0),
                                      effectivePrimary,
                                      accentColor,
                                      effectivePrimary.withValues(alpha: 0.0),
                                    ],
                                  ),
                                  borderRadius: radius,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
