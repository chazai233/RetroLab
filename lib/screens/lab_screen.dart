library;

import 'dart:io';
import '../core/design/prism_theme.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/retro_photo.dart';
import '../models/retro_video.dart';
import '../utils/image_processor.dart';
import '../widgets/grain_overlay.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class LabScreen extends StatefulWidget {
  final int initialTab;

  const LabScreen({super.key, this.initialTab = 0});

  @override
  State<LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen>
    with SingleTickerProviderStateMixin {
  PrismPalette get p => context.prism;

  late final TabController _tabController;
  List<RetroPhoto> _photos = [];
  List<RetroVideo> _videos = [];
  String? _filterStockId;
  bool _isFilmStripView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadMedia() {
    if (!mounted) return;
    final photos = <RetroPhoto>[];
    final videos = <RetroVideo>[];

    for (int i = 0; i < HiveService.photosBox.length; i++) {
      final map = HiveService.photosBox.getAt(i);
      if (map != null) {
        final photo = RetroPhoto.fromMap(Map<String, dynamic>.from(map));
        // Checked once here instead of on every grid cell per scroll frame.
        if (File(photo.processedPath).existsSync()) photos.add(photo);
      }
    }
    for (int i = 0; i < HiveService.videosBox.length; i++) {
      final map = HiveService.videosBox.getAt(i);
      if (map != null) {
        final video = RetroVideo.fromMap(Map<String, dynamic>.from(map));
        if (File(video.processedPath).existsSync()) videos.add(video);
      }
    }

    photos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    videos.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    setState(() {
      _photos = photos;
      _videos = videos;
      _applyFilter();
    });
  }

  // Cached: these used to be getters allocating a new filtered list on every
  // access, including inside itemBuilder — O(n) per cell, O(n²) per grid.
  List<RetroPhoto> _filteredPhotos = [];
  List<RetroVideo> _filteredVideos = [];

  void _applyFilter() {
    final id = _filterStockId;
    _filteredPhotos =
        id == null
            ? _photos
            : _photos.where((p) => p.filmStockId == id).toList();
    _filteredVideos =
        id == null
            ? _videos
            : _videos.where((v) => v.filmStockId == id).toList();
  }

  String get _activeFilterLabel {
    if (_filterStockId == null) return '全部';
    return FilmStocks.getById(_filterStockId!).name.toUpperCase();
  }

  Future<void> _exportAsFilmStrip() async {
    final files =
        _filteredPhotos.map((p) => File(p.processedPath)).take(12).toList();
    if (files.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可以导出的照片')),
      );
      return;
    }
    final stripFile = await ImageProcessor.createFilmStrip(files);
    Share.shareXFiles([XFile(stripFile.path)], text: RetroStrings.watermark);
  }

  Future<void> _deletePhoto(RetroPhoto photo) async {
    final confirmed = await _confirmDelete('照片');
    if (confirmed != true) return;
    await HiveService.photosBox.delete(photo.id);
    final file = File(photo.processedPath);
    if (file.existsSync()) {
      await file.delete();
    }
    _loadMedia();
  }

  Future<void> _deleteVideo(RetroVideo video) async {
    final confirmed = await _confirmDelete('视频');
    if (confirmed != true) return;
    await HiveService.videosBox.delete(video.id);
    for (final path in [video.processedPath, video.thumbnailPath]) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _loadMedia();
  }

  Future<bool?> _confirmDelete(String kind) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: p.surface,
          title: Text(
            '删除$kind',
            style: GoogleFonts.spaceMono(color: p.textPrimary),
          ),
          content: Text(
            '删了就找不回来。',
            style: GoogleFonts.inter(color: p.textMuted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                '删除',
                style: GoogleFonts.spaceMono(color: p.error),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        // Short enough to sit beside four action icons without ellipsing.
        title: const Text('相册'),
        actions: [
          // Hidden rather than greyed out on the video tab: a visible dead
          // control makes you wonder what you did wrong.
          if (_tabController.index == 0) ...[
            IconButton(
              icon: Icon(
                _isFilmStripView
                    ? Icons.grid_view_rounded
                    : Icons.view_column_rounded,
              ),
              tooltip: _isFilmStripView ? '网格' : '胶片条',
              onPressed:
                  () => setState(() => _isFilmStripView = !_isFilmStripView),
            ),
            IconButton(
              icon: const Icon(Icons.movie_filter),
              tooltip: '导出样片条',
              onPressed: _exportAsFilmStrip,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: '统计',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.02)),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _buildLabHero(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.surface.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                      border: Border.all(
                        color: p.hairline,
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      onTap: (_) => setState(() {}),
                      indicator: BoxDecoration(
                        color: p.amber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(
                          RetroDimens.radiusMd,
                        ),
                      ),
                      dividerColor: Colors.transparent,
                      labelColor: p.amber,
                      unselectedLabelColor: p.textMuted,
                      labelStyle: GoogleFonts.spaceMono(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                      tabs: const [Tab(text: '照片'), Tab(text: '视频')],
                    ),
                  ),
                ),
              ),
              _buildFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _filteredPhotos.isEmpty
                        ? _buildEmptyState('还没有照片')
                        : _isFilmStripView
                        ? _buildFilmStripView()
                        : _buildPhotoGrid(),
                    _filteredVideos.isEmpty
                        ? _buildEmptyState('还没有视频')
                        : _buildVideoGrid(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLabHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.surfaceHigh, p.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '冲洗完成的',
            style: GoogleFonts.spaceMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '这卷里洗出来的照片和视频都在这里。',
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: p.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('${_photos.length} FOTOS', p.amber),
              _summaryChip('${_videos.length} VIDEOS', p.dateYellow),
              _summaryChip(_activeFilterLabel, p.textMuted),
              if (_tabController.index == 0)
                _summaryChip(
                  _isFilmStripView ? '胶片条' : '网格',
                  p.amber,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _filterChip(null, '全部'),
            ...FilmStocks.all.map(
              (stock) =>
                  _filterChip(stock.id, stock.shortName, p.stockInk(stock.badgeColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String? stockId, String label, [Color? color]) {
    final isSelected = _filterStockId == stockId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap:
            () => setState(() {
              _filterStockId = stockId;
              _applyFilter();
            }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? (color ?? p.amber).withValues(alpha: 0.2)
                    : p.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  isSelected
                      ? (color ?? p.amber)
                      : p.hairline,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceMono(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color:
                  isSelected
                      ? (color ?? p.amber)
                      : p.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 3
                : 2;
        return GridView.builder(
          padding: const EdgeInsets.all(RetroDimens.paddingMd),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.82,
          ),
          itemCount: _filteredPhotos.length,
          itemBuilder: (context, index) {
            final photo = _filteredPhotos[index];
            final stock = FilmStocks.getById(photo.filmStockId);
            final file = File(photo.processedPath);
            return GestureDetector(
              onTap: () => _openPhotoDetail(photo),
              onLongPress: () => _deletePhoto(photo),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                  border: Border.all(
                    color: p.hairline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(RetroDimens.radiusMd),
                            ),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              cacheWidth: 500,
                            ),
                          ),
                          _stockBadge(stock.shortName, stock.badgeColor),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stock.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.spaceMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: p.stockInk(stock.badgeColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCapturedAt(photo.capturedAt),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(RetroDimens.paddingMd),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.74,
      ),
      itemCount: _filteredVideos.length,
      itemBuilder: (context, index) {
        final video = _filteredVideos[index];
        final stock = FilmStocks.getById(video.filmStockId);
        final thumb = File(video.thumbnailPath);
        return GestureDetector(
          onTap: () => _openVideoDetail(video),
          onLongPress: () => _deleteVideo(video),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(RetroDimens.radiusMd),
                        ),
                        child:
                            thumb.existsSync()
                                ? Image.file(
                                  thumb,
                                  fit: BoxFit.cover,
                                  cacheWidth: 500,
                                )
                                : Container(color: p.surfaceHigh),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white70,
                          size: 56,
                        ),
                      ),
                      _stockBadge(stock.shortName, stock.badgeColor),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stock.shortName,
                        style: GoogleFonts.spaceMono(
                          fontSize: 10,
                          color: p.stockInk(stock.badgeColor),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_formatDuration(video.durationMs)} · ${_formatCapturedAt(video.capturedAt)}',
                        style: GoogleFonts.spaceMono(
                          fontSize: 9,
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilmStripView() {
    return Container(
      color: const Color(0xFF1A1510),
      child: Column(
        children: [
          _buildSprocketRow(),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: _filteredPhotos.length,
              itemBuilder: (context, index) {
                final photo = _filteredPhotos[index];
                final file = File(photo.processedPath);
                return GestureDetector(
                  onTap: () => _openPhotoDetail(photo),
                  child: Container(
                    width: 220,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                      border: Border.all(
                        color: const Color(0xFF3D3530),
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        RetroDimens.radiusSm,
                      ),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        cacheHeight: 420,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildSprocketRow(),
        ],
      ),
    );
  }

  Widget _buildSprocketRow() {
    return SizedBox(
      height: 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 50,
        itemBuilder:
            (_, __) => Container(
              width: 10,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0A08),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
      ),
    );
  }

  Widget _buildEmptyState(String title) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
          border: Border.all(color: p.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.camera_roll_outlined,
              size: 72,
              color: p.textMuted.withValues(alpha: 0.42),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.spaceMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: p.textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '拍一张值得留的，就会出现在这里。',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: p.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            // Only in the empty state — the back arrow already means "camera"
            // everywhere else, so a permanent button would be noise.
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.photo_camera),
              label: const Text('去拍摄'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(String label, Color color) {
    return Positioned(
      top: 4,
      left: 4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: GoogleFonts.spaceMono(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _openPhotoDetail(RetroPhoto photo) async {
    final file = File(photo.processedPath);
    if (!file.existsSync()) return;
    final stock = FilmStocks.getById(photo.filmStockId);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
              border: Border.all(color: p.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child: Image.file(
                      file,
                      fit: BoxFit.contain,
                      cacheWidth: 1080,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name,
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: p.stockInk(stock.badgeColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCapturedAt(photo.capturedAt),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _metadataPill(stock.processLabel),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _detailAction(
                          Icons.share,
                          '分享',
                          p.amber,
                          () {
                            Share.shareXFiles([XFile(photo.processedPath)]);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _detailAction(
                          Icons.delete_outline,
                          '删除',
                          p.error,
                          () async {
                            Navigator.pop(ctx);
                            await _deletePhoto(photo);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        // Replaces "Cerrar", which duplicated the back gesture
                        // and the barrier tap. The Editor had no entry point
                        // outside the seconds right after a shot.
                        child: _detailAction(
                          Icons.tune,
                          '再冲洗',
                          p.dateYellow,
                          () async {
                            Navigator.pop(ctx);
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditorScreen(photo: photo),
                              ),
                            );
                            _loadMedia();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    // Covers delete, edit, and whatever the dialog grows later.
    _loadMedia();
  }

  Future<void> _openVideoDetail(RetroVideo video) async {
    await showDialog<void>(
      context: context,
      builder:
          (_) => _VideoDialog(
            video: video,
            onDelete: () async {
              Navigator.of(context).pop();
              await _deleteVideo(video);
            },
          ),
    );
  }

  Widget _metadataPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.hairline),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: p.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _detailAction(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _VideoDialog extends StatefulWidget {
  final RetroVideo video;
  final Future<void> Function() onDelete;

  const _VideoDialog({required this.video, required this.onDelete});

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
  PrismPalette get p => context.prism;

  late final VideoPlayerController _controller;
  Future<void>? _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.video.processedPath));
    _initFuture = _controller.initialize().then((_) {
      _controller.setLooping(true);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(int durationMs) {
    final totalSeconds = (durationMs / 1000).round();
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatCapturedAt(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Widget _metadataPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: p.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.hairline),
      ),
      child: Text(
        label,
        style: GoogleFonts.spaceMono(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: p.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = FilmStocks.getById(widget.video.filmStockId);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          return Container(
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
              border: Border.all(color: p.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
                    child:
                        _controller.value.isInitialized
                            ? AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  VideoPlayer(_controller),
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.42,
                                      ),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.14,
                                        ),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          if (_controller.value.isPlaying) {
                                            _controller.pause();
                                          } else {
                                            _controller.play();
                                          }
                                        });
                                      },
                                      icon: Icon(
                                        _controller.value.isPlaying
                                            ? Icons.pause_circle_filled
                                            : Icons.play_circle_fill,
                                        color: Colors.white70,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            : Container(
                              height: 320,
                              color: p.surface,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stock.name,
                              style: GoogleFonts.spaceMono(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: p.stockInk(stock.badgeColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatDuration(widget.video.durationMs)} · ${_formatCapturedAt(widget.video.capturedAt)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: p.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _metadataPill(stock.processLabel),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _action(
                          Icons.share,
                          '分享',
                          p.amber,
                          () {
                            Share.shareXFiles([
                              XFile(widget.video.processedPath),
                            ]);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          Icons.delete_outline,
                          '删除',
                          p.error,
                          widget.onDelete,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _action(
                          Icons.close,
                          'Cerrar',
                          p.textMuted,
                          () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _action(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
