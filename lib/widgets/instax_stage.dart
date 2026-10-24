import 'dart:io';

import 'package:flutter/material.dart';

/// White instant-film frame. The live preview sits in the window; the lip
/// under it carries the counter and a small set of marks, like a print.
class InstaxFrame extends StatefulWidget {
  final Widget child;
  final String title;
  final int shotsLeft;

  const InstaxFrame({
    super.key,
    required this.child,
    required this.title,
    required this.shotsLeft,
  });

  @override
  State<InstaxFrame> createState() => _InstaxFrameState();
}

class _InstaxFrameState extends State<InstaxFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blink;

  @override
  void initState() {
    super.initState();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3EC),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(color: Colors.black, child: widget.child),
              ),
            ),
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  _counter(widget.shotsLeft),
                  const SizedBox(width: 10),
                  FadeTransition(
                    opacity: Tween<double>(begin: 0.35, end: 1).animate(_blink),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE23B32),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'sans-serif',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E675C),
                    ),
                  ),
                  const Spacer(),
                  const _Mark(color: Color(0xFFE07A3D)),
                  const SizedBox(width: 5),
                  const _Mark(color: Color(0xFF3D8B7A)),
                  const SizedBox(width: 5),
                  const _Mark(color: Color(0xFF3A6EA5)),
                  const SizedBox(width: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _counter(int left) {
    return Container(
      width: 46,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1814),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        left.toString().padLeft(2, '0'),
        style: const TextStyle(
          fontFamily: 'sans-serif',
          color: Color(0xFFF2C14E),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  final Color color;
  const _Mark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Chunky launcher-style icon. Scales down and springs back on tap.
class BounceIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool active;

  const BounceIcon({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.active = false,
  });

  @override
  State<BounceIcon> createState() => _BounceIconState();
}

class _BounceIconState extends State<BounceIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    if (widget.onTap == null) return;
    await _press.forward(from: 0);
    await _press.reverse();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween<double>(begin: 1, end: 0.86).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
    return GestureDetector(
      onTap: widget.onTap == null ? null : _tap,
      child: ScaleTransition(
        scale: scale,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.active ? Colors.white : const Color(0x33FFFFFF),
                  width: widget.active ? 2 : 1,
                ),
              ),
              child: Icon(widget.icon, color: const Color(0xFF1A140F), size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: const TextStyle(
                fontFamily: 'sans-serif',
                fontSize: 10,
                color: Color(0xFFC8BBA8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// After the shutter: a blank print slides out, then the picture develops.
/// Stays on screen until the parent removes it — there is no second animation.
class FilmEjectOverlay extends StatefulWidget {
  final File image;
  final String caption;

  /// Width / height of the photo window, same ratio as the viewfinder.
  final double imageAspect;

  /// When true, the white sheet fades and the photo comes up.
  final bool revealed;

  const FilmEjectOverlay({
    super.key,
    required this.image,
    required this.caption,
    required this.imageAspect,
    required this.revealed,
  });

  @override
  State<FilmEjectOverlay> createState() => _FilmEjectOverlayState();
}

class _FilmEjectOverlayState extends State<FilmEjectOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _develop;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _develop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.revealed) _develop.forward();
  }

  @override
  void didUpdateWidget(FilmEjectOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.revealed && !oldWidget.revealed && !_develop.isAnimating) {
      _develop.forward();
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    _develop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flash = Tween<double>(begin: 0.9, end: 0).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    final slide = Tween<Offset>(begin: const Offset(0, -0.45), end: Offset.zero).animate(
      CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic),
    );

    final size = MediaQuery.sizeOf(context);
    final maxW = size.width - 64;
    final maxH = size.height * 0.78;
    const pad = 14.0;
    const lip = 44.0;
    var imageW = maxW - pad * 2;
    var imageH = imageW / widget.imageAspect;
    if (imageH + lip + pad > maxH) {
      imageH = maxH - lip - pad;
      imageW = imageH * widget.imageAspect;
    }

    return ColoredBox(
      color: const Color(0xCC100E0C),
      child: Stack(
        children: [
          Center(
            child: SlideTransition(
              position: slide,
              child: SizedBox(
                width: imageW + pad * 2,
                height: imageH + pad + lip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F3EC),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(pad, pad, pad, 0),
                    child: Column(
                      children: [
                        SizedBox(
                          width: imageW,
                          height: imageH,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  widget.image,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                  filterQuality: FilterQuality.low,
                                  cacheWidth: 720,
                                ),
                                AnimatedBuilder(
                                  animation: _develop,
                                  builder: (context, _) {
                                    return ColoredBox(
                                      color: Colors.white.withValues(
                                        alpha: 1 - _develop.value,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          height: lip,
                          child: Center(
                            child: Text(
                              widget.caption,
                              style: const TextStyle(
                                fontFamily: 'sans-serif',
                                color: Color(0xFF8A8174),
                                fontSize: 13,
                              ),
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
          IgnorePointer(
            child: AnimatedBuilder(
              animation: flash,
              builder: (context, _) {
                return ColoredBox(
                  color: Colors.white.withValues(alpha: flash.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
