library;

import 'dart:io';
import '../core/design/prism_theme.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'editor_screen.dart';

class PreviewScreen extends StatefulWidget {
  final RetroPhoto photo;
  final Uint8List processedBytes;

  /// Whether the photo reached the device gallery. Required so both callers
  /// have to answer it — a silent save is worse than a visible failure.
  final bool savedToGallery;

  const PreviewScreen({
    super.key,
    required this.photo,
    required this.processedBytes,
    required this.savedToGallery,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  PrismPalette get p => context.prism;

  late AnimationController _fadeController;
  bool _showActions = true;
  late bool _saved = widget.savedToGallery;

  Future<void> _retrySave() async {
    try {
      await Gal.putImage(widget.photo.processedPath);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没能存进相册：$e')),
      );
    }
  }

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} · $hour:$minute';
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _shareImage() {
    Share.shareXFiles([
      XFile(widget.photo.processedPath),
    ], text: RetroStrings.watermark);
  }

  Future<void> _shareAsPolaroid() async {
    try {
      final filmStock = FilmStocks.getById(widget.photo.filmStockId);
      final polaroidFile = await ImageProcessor.createPolaroidFrame(
        File(widget.photo.processedPath),
        filterName: filmStock.name,
      );
      Share.shareXFiles([
        XFile(polaroidFile.path),
      ], text: RetroStrings.watermark);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('拍立得做不出来：$e')));
    }
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditorScreen(photo: widget.photo)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filmStock = FilmStocks.getById(widget.photo.filmStockId);

    return Scaffold(
      backgroundColor: p.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.03)),
          if (p.isDark)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.46),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.0, 0.18, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _showActions = !_showActions),
            child: Center(
              child: FadeTransition(
                opacity: _fadeController,
                child: Hero(
                  tag: 'photo_${widget.photo.id}',
                  child: Container(
                    margin: const EdgeInsets.all(RetroDimens.paddingMd),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      border: Border.all(
                        color: p.hairline,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      child: Image.memory(
                        widget.processedBytes,
                        fit: BoxFit.contain,
                        // Processed frames are up to 2400px; the view is
                        // screen-sized. Decode to fit, not to source.
                        cacheWidth: 1080,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_showActions)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _topButton(
                            icon: Icons.close,
                            // Preview always sits exactly one route above its
                            // origin, so pop returns where you came from —
                            // the camera after a shoot, the Lab after an edit.
                            onTap: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                          _topButton(
                            icon: Icons.visibility_off_outlined,
                            onTap: () => setState(() => _showActions = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(RetroDimens.paddingMd),
                        decoration: BoxDecoration(
                          color: p.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(
                            RetroDimens.radiusLg,
                          ),
                          border: Border.all(
                            color: p.hairline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    filmStock.name,
                                    style: GoogleFonts.spaceMono(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: p.textPrimary,
                                    ),
                                  ),
                                ),
                                _metadataPill(
                                  filmStock.shortName,
                                  filmStock.badgeColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatCapturedAt(widget.photo.capturedAt),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: p.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                GestureDetector(
                                  onTap: _saved ? null : _retrySave,
                                  child: _metadataPill(
                                    _saved
                                        ? '已存相册'
                                        : '没存上 · 再试',
                                    _saved
                                        ? p.success
                                        : p.error,
                                  ),
                                ),
                                _metadataPill(
                                  widget.photo.isImported
                                      ? '导入的'
                                      : '实拍',
                                  p.amber,
                                ),
                                _metadataPill(
                                  widget.photo.dateStampEnabled
                                      ? '有日期'
                                      : '无日期',
                                  p.dateYellow,
                                ),
                                _metadataPill(
                                  'GRANO ${(widget.photo.grain * 100).round()}%',
                                  p.textMuted,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showActions)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(RetroDimens.paddingMd),
                  child: Container(
                    padding: const EdgeInsets.all(RetroDimens.paddingMd),
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                      border: Border.all(
                        color: p.hairline,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '接下来',
                                style: GoogleFonts.spaceMono(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: p.amber,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                            Text(
                              '点照片可以收起按钮',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                Icons.edit_outlined,
                                '再冲洗',
                                '换一卷的样子',
                                _openEditor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                Icons.ios_share_outlined,
                                '分享',
                                '冲洗好的文件',
                                _shareImage,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _actionButton(
                                Icons.photo_size_select_actual_outlined,
                                '拍立得',
                                '带白边',
                                _shareAsPolaroid,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _actionButton(
                                Icons.check_circle_outline,
                                '完成',
                                '返回',
                                () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_showActions)
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _topButton(
                    icon: Icons.visibility_outlined,
                    onTap: () => setState(() => _showActions = true),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _topButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
            border: Border.all(color: p.hairline),
          ),
          child: Icon(icon, color: p.textPrimary),
        ),
      ),
    );
  }

  Widget _metadataPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String label,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.background.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
            border: Border.all(
              color: p.surfaceHigh.withValues(alpha: 0.9),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: p.textPrimary),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.spaceMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: p.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
