library;

import 'dart:async';
import '../core/design/prism_theme.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../models/film_roll.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import 'preview_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final File originalFile;
  final FilmStock filmStock;
  final FilmRoll roll;
  final String photoId;
  final double grain;
  final double leakStrength;
  final double dustStrength;
  final int lightLeakIndex;
  final double saturation;
  final double vignette;
  final double scratchLevel;
  final bool isImported;

  const ProcessingScreen({
    super.key,
    required this.originalFile,
    required this.filmStock,
    required this.roll,
    required this.photoId,
    this.grain = RetroDefaults.grain,
    this.leakStrength = RetroDefaults.leakStrength,
    this.dustStrength = RetroDefaults.dustStrength,
    this.lightLeakIndex = 0,
    this.saturation = 1.0,
    this.vignette = RetroDefaults.vignette,
    this.scratchLevel = RetroDefaults.scratchLevel,
    this.isImported = false,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  PrismPalette get p => context.prism;

  /// Null while the native GPU backend is running — it is a single opaque call
  /// with no stages, so we show an indeterminate bar rather than invent a
  /// percentage. The Dart pipeline reports real stages and fills this in.
  double? _progressValue;
  String _statusText = RetroStrings.processingStages.first;

  String get _rollSummary =>
      '${widget.roll.usedExposures + 1}/${widget.roll.totalExposures}';

  @override
  void initState() {
    super.initState();
    _startProcessing();
  }

  void _onStage(ProcessingStage stage) {
    if (!mounted) return;
    setState(() {
      _statusText = RetroStrings.processingStages[stage.index];
      _progressValue =
          (stage.index + 1) / (ProcessingStage.values.length + 1);
    });
  }

  Future<void> _startProcessing() async {
    try {
      final capturedAt = DateTime.now();
      final result = await ImageProcessor.processRetroImage(
        widget.originalFile,
        filmStock: widget.filmStock,
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        dustStrength: widget.dustStrength,
        lightLeakIndex: widget.lightLeakIndex,
        saturationOverride: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        analogRandomness: HiveService.analogRandomnessEnabled,
        artifactSeed: widget.photoId.hashCode,
        captureDate: capturedAt,
        dateStampStyle: DateStampStyle.values.firstWhere(
          (s) => s.name == HiveService.dateStampStyle,
          orElse: () => DateStampStyle.classic90s,
        ),
        dateStampPosition: DateStampPosition.values.firstWhere(
          (p) => p.name == HiveService.dateStampPosition,
          orElse: () => DateStampPosition.bottomRight,
        ),
        saveLocationData: HiveService.saveLocationDataEnabled,
        onStage: _onStage,
      );

      final photo = RetroPhoto(
        id: widget.photoId,
        originalPath: widget.originalFile.path,
        processedPath: result.file.path,
        filmStockId: widget.filmStock.id,
        rollId: widget.roll.id,
        capturedAt: capturedAt,
        grain: widget.grain,
        leakStrength: widget.leakStrength,
        dustStrength: widget.dustStrength,
        lightLeakIndex: widget.lightLeakIndex,
        saturation: widget.saturation,
        vignette: widget.vignette,
        scratchLevel: widget.scratchLevel,
        dateStampStyle: HiveService.dateStampStyle,
        dateStampPosition: HiveService.dateStampPosition,
        isImported: widget.isImported,
      );
      await HiveService.photosBox.put(photo.id, photo.toMap());

      if (!mounted) return;

      setState(() {
        _progressValue = 1.0;
        _statusText = RetroStrings.ready;
      });

      // Just long enough to read "¡LISTO!" — the rest of the wait is real work.
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => PreviewScreen(
                photo: photo,
                processedBytes: result.bytes,
                savedToGallery: result.savedToGallery,
              ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('冲洗失败：$e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // The old "冲洗中" reel was removed. This route only exists as a fallback
    // and stays blank while the photo is written.
    return const Scaffold(backgroundColor: Color(0xFF100E0C), body: SizedBox.shrink());
  }
}
