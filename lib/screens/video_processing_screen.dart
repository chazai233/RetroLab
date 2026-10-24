library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import '../core/constants.dart';
import '../core/hive_boxes.dart';
import '../core/zh.dart';
import '../models/retro_video.dart';
import '../utils/video_processor.dart';

class VideoProcessingScreen extends StatefulWidget {
  final File rawFile;
  final String videoId;
  final VideoEffectSettings settings;

  const VideoProcessingScreen({
    super.key,
    required this.rawFile,
    required this.videoId,
    required this.settings,
  });

  @override
  State<VideoProcessingScreen> createState() => _VideoProcessingScreenState();
}

class _VideoProcessingScreenState extends State<VideoProcessingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
    _process();
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Future<void> _process() async {
    try {
      final result = await VideoProcessor.processVideo(
        widget.rawFile,
        outputId: widget.videoId,
        settings: widget.settings,
      );
      await Gal.putVideo(
        result.processedFile.path,
        album: RetroStrings.appName,
      );
      final video = RetroVideo(
        id: widget.videoId,
        rawPath: widget.rawFile.path,
        processedPath: result.processedFile.path,
        thumbnailPath: result.thumbnailFile.path,
        filmStockId: widget.settings.stock.id,
        capturedAt: DateTime.now(),
        durationMs: result.durationMs,
        grain: widget.settings.grain,
        leakStrength: widget.settings.leakStrength,
        dustStrength: widget.settings.dustStrength,
        lightLeakIndex: widget.settings.lightLeakIndex,
        saturation: widget.settings.saturation,
        vignette: widget.settings.vignette,
        scratchLevel: widget.settings.scratchLevel,
      );
      await HiveService.videosBox.put(video.id, video.toMap());
      if (widget.rawFile.existsSync()) {
        await widget.rawFile.delete();
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final retry = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1814),
            title: const Text('视频没处理好', style: TextStyle(color: Colors.white)),
            content: const Text(
              '可以再试一次，或者丢掉这段。',
              style: TextStyle(color: Color(0xFFC8BBA8)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('丢掉'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('再试'),
              ),
            ],
          );
        },
      );
      if (retry == true) {
        _process();
        return;
      }
      if (widget.rawFile.existsSync()) {
        await widget.rawFile.delete();
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
    final caption = stockTitle(widget.settings.stock);

    return Scaffold(
      backgroundColor: const Color(0xFF100E0C),
      body: Center(
        child: SlideTransition(
          position: slide,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF6F3EC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1.15,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E1D6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.movie_creation_outlined,
                            color: Color(0xFF8A8174),
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: Color(0xFF6E675C),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '视频出片中',
                      style: TextStyle(
                        color: Color(0xFF1A1814),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0xFFE4DDD2),
                        color: Color(0xFFC4A574),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
