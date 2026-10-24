/// ─────────────────────────────────────────────────────────────────────────────
/// Neumorphism — Core widgets
///
/// Everything composes from [NeuSurface]. Flutter's BoxShadow has no inset
/// mode, so one painter draws both shadow pairs and interpolates between them:
/// depth  1.0 = fully raised (convex), 0.0 = flat, -1.0 = fully inset (concave).
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'package:flutter/material.dart';

import '../core/design/neu_tokens.dart';

/// A soft-3D surface. Give it a [depth] and it does the rest.
class NeuSurface extends StatelessWidget {
  final Widget? child;
  final double depth;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const NeuSurface({
    super.key,
    this.child,
    this.depth = 1.0,
    this.radius = NeuRadius.sm,
    this.color,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = color ??
        (brightness == Brightness.dark
            ? NeuColors.surfaceDark
            : NeuColors.surfaceLight);

    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _NeuPainter(
          depth: depth.clamp(-1.0, 1.0),
          radius: radius,
          surface: surface,
          brightness: brightness,
        ),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class _NeuPainter extends CustomPainter {
  final double depth;
  final double radius;
  final Color surface;
  final Brightness brightness;

  const _NeuPainter({
    required this.depth,
    required this.radius,
    required this.surface,
    required this.brightness,
  });

  bool get _isDark => brightness == Brightness.dark;

  Color get _light =>
      _isDark ? NeuColors.lightShadowOnDark : NeuColors.lightShadowOnLight;
  Color get _dark =>
      _isDark ? NeuColors.darkShadowOnDark : NeuColors.darkShadowOnLight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    const offset = 5.0;
    const blur = 15.0;

    final raised = depth > 0 ? depth : 0.0;
    final inset = depth < 0 ? -depth : 0.0;

    // ── Convex: shadows cast outward, so they must not be clipped ──────────
    if (raised > 0) {
      _dropShadow(canvas, rrect, const Offset(-offset, -offset) * 1.0,
          _light.withValues(alpha: _light.a * raised), blur);
      _dropShadow(canvas, rrect, const Offset(offset, offset) * 1.0,
          _dark.withValues(alpha: _dark.a * raised), blur);
    }

    canvas.drawRRect(rrect, Paint()..color = surface);

    // ── Concave: same pair reversed, clipped inside the shape ─────────────
    if (inset > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      _innerShadow(canvas, rrect, size, const Offset(offset, offset),
          _dark.withValues(alpha: _dark.a * inset), blur);
      _innerShadow(canvas, rrect, size, const Offset(-offset, -offset),
          _light.withValues(alpha: _light.a * inset), blur);
      canvas.restore();
    }
  }

  void _dropShadow(
      Canvas canvas, RRect rrect, Offset delta, Color color, double blur) {
    canvas.drawRRect(
      rrect.shift(delta),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
  }

  /// Inner shadow = everything OUTSIDE the shifted shape, blurred, clipped to
  /// the shape. Subtracting the shifted rrect from a large rect gives that.
  void _innerShadow(Canvas canvas, RRect rrect, Size size, Offset delta,
      Color color, double blur) {
    final outer = Path()
      ..addRect(Rect.fromLTWH(
        -size.width,
        -size.height,
        size.width * 3,
        size.height * 3,
      ));
    final inner = Path()..addRRect(rrect.shift(delta));
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _NeuPainter old) =>
      old.depth != depth ||
      old.radius != radius ||
      old.surface != surface ||
      old.brightness != brightness;
}

// ── Button ───────────────────────────────────────────────────────────────────

/// Primary / ghost button with the tactile press from design.md:
/// raised → inset over 150ms, plus a 1px travel. No outer glows.
class NeuButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool ghost;
  final double radius;
  final EdgeInsetsGeometry padding;
  final Color? accent;

  const NeuButton({
    super.key,
    required this.child,
    this.onPressed,
    this.ghost = false,
    this.radius = NeuRadius.sm,
    this.padding =
        const EdgeInsets.symmetric(horizontal: 20, vertical: NeuSpacing.md),
    this.accent,
  });

  @override
  State<NeuButton> createState() => _NeuButtonState();
}

class _NeuButtonState extends State<NeuButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: NeuMotion.press,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _setPressed(bool down) {
    if (widget.onPressed == null) return;
    down ? _c.forward() : _c.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final brightness = Theme.of(context).brightness;
    final fill = widget.ghost
        ? null
        : (widget.accent ?? NeuColors.accent);
    final labelColor = widget.ghost
        ? (widget.accent ?? NeuColors.accent)
        : Colors.white;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            // Solid rests raised (1.0); ghost is an outline variant so it
            // rests flat (0.0). Both press through to inset (-1.0), with the
            // 1px tactile travel from design.md.
            final restDepth = widget.ghost ? 0.0 : 1.0;
            final depth = restDepth - (_c.value * (restDepth + 1.0));
            return Transform.translate(
              offset: Offset(0, _c.value),
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: NeuSurface(
                  depth: depth,
                  radius: widget.radius,
                  color: fill,
                  padding: widget.padding,
                  child: child,
                ),
              ),
            );
          },
          child: DefaultTextStyle(
            style: NeuType.small.copyWith(
              fontWeight: FontWeight.w600,
              color: labelColor,
            ),
            child: IconTheme(
              data: IconThemeData(color: labelColor, size: 20),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: widget.ghost
                    ? _GhostBorder(
                        radius: widget.radius,
                        color: widget.accent ?? NeuColors.accent,
                        brightness: brightness,
                        child: widget.child,
                      )
                    : widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 1.5px outline for the ghost variant.
class _GhostBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final Brightness brightness;

  const _GhostBorder({
    required this.child,
    required this.radius,
    required this.color,
    required this.brightness,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.55), width: 1.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: child,
      );
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

/// design.md is explicit: shimmer matching component dimensions, never a
/// circular spinner.
class NeuSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const NeuSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.radius = NeuRadius.sm,
  });

  @override
  State<NeuSkeleton> createState() => _NeuSkeletonState();
}

class _NeuSkeletonState extends State<NeuSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? NeuColors.surfaceDark : NeuColors.surfaceLight;
    final highlight = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1.0 - 2.0 * (1 - _c.value), 0),
                end: Alignment(1.0 + 2.0 * (1 - _c.value), 0),
                colors: [base, highlight, base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Entry animation ──────────────────────────────────────────────────────────

/// Fade + translate-Y (16px → 0) over 420ms ease-out, with optional stagger.
/// Only transform and opacity animate — no layout-triggering properties.
class NeuEntrance extends StatefulWidget {
  final Widget child;
  final int index;

  const NeuEntrance({super.key, required this.child, this.index = 0});

  @override
  State<NeuEntrance> createState() => _NeuEntranceState();
}

class _NeuEntranceState extends State<NeuEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: NeuMotion.entry,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(NeuMotion.stagger * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(parent: _c, curve: NeuMotion.curve);
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, NeuMotion.entryOffsetY * (1 - t.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
