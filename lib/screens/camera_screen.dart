/// ─────────────────────────────────────────────────────────────────────────────
/// RetroLab — Camera Screen (v2 — Live FX Preview)
///
/// Changes over v1:
///   • _buildColorFilter now accepts all slider overrides (_saturation,
///     _vignette etc.) — previously it only read the film stock defaults,
///     so slider changes had zero effect on the live preview.
///   • GrainOverlay driven by _grain slider (was hardcoded to stock.baseGrain).
///   • Light leak preview overlay added — _leakStrength now visually affects
///     the live preview with an animated warm/cool color wash.
///   • Scratch overlay added as scanline noise, driven by _scratchLevel.
///   • Vignette gradient already used _vignette — kept, but alpha formula
///     tightened so it matches the processor's 0.4-radius rolloff.
/// ─────────────────────────────────────────────────────────────────────────────
library;

import 'dart:async';
import '../core/design/prism_theme.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../core/film_stocks.dart';
import '../core/hive_boxes.dart';
import '../core/zh.dart';
import '../models/film_roll.dart';
import '../models/retro_photo.dart';
import '../utils/image_processor.dart';
import '../utils/video_processor.dart';
import '../widgets/film_canister.dart';
import '../widgets/film_preview.dart';
import '../widgets/instax_stage.dart';
import '../widgets/retro_slider.dart';
import '../widgets/shutter_button.dart';
import '../widgets/viewfinder_overlay.dart';
import 'lab_screen.dart';
import 'preview_screen.dart';
import 'settings_screen.dart';
import 'video_processing_screen.dart';

enum CaptureMode { photo, video }

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  PrismPalette get p => context.prism;

  TextStyle _type({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'sans-serif',
      fontSize: fontSize,
      fontWeight: fontWeight ?? FontWeight.w500,
      color: color,
      height: height,
    );
  }

  final GlobalKey _previewKey = GlobalKey();

  // ── Camera ─────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  Future<void> _cameraDisposeFuture = Future<void>.value();
  List<CameraDescription> _cameras = [];
  int _currentCameraIndex = 0;
  bool _isCameraReady = false;
  CaptureMode _captureMode = CaptureMode.photo;
  bool _isRecordingVideo = false;
  bool _isProcessingVideo = false;
  Timer? _recordingTimer;

  // ── Film State ─────────────────────────────────────────────────────────
  FilmStock _selectedStock = FilmStocks.kodakGold200;
  late FilmRoll _currentRoll;
  bool _showControls = false;
  final ScrollController _filmSelectorScrollController = ScrollController();

  // ── Effect Controls ────────────────────────────────────────────────────
  double _grain = RetroDefaults.grain;
  double _leakStrength = RetroDefaults.leakStrength;
  double _dustStrength = RetroDefaults.dustStrength;
  double _saturation = 1.0;
  double _vignette = RetroDefaults.vignette;
  double _scratchLevel = RetroDefaults.scratchLevel;
  int _lightLeakIndex = 0;

  // ── Light Leak Preview Animation ──────────────────────────────────────
  // Animates the leak overlay so it feels alive on the preview, not static.

  // ── Timer & Burst ──────────────────────────────────────────────────────
  ShutterTimer _shutterTimer = ShutterTimer.off;
  bool _isBurstMode = false;
  bool _isCapturing = false;
  int _timerCountdown = 0;

  // ── Audio ──────────────────────────────────────────────────────────────
  Future<AudioPool>? _shutterPoolFuture;

  // ── Grid / Flash ───────────────────────────────────────────────────────
  OverlayMode _overlayMode = OverlayMode.off;
  FlashMode _flashMode = FlashMode.off;
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  double? _pendingExposureOffset;
  bool _isApplyingExposure = false;
  bool _showExposureControl = false;
  bool _doubleExposureEnabled = false;
  File? _pendingDoubleExposureFile;
  bool _permissionBlocked = false;

  /// Hides the controls drawn over the frame — chips, tool rail, readout — so
  /// nothing competes with the image. Composition guides (grid, brackets) and
  /// the date-stamp preview deliberately stay: they are framing aids, and
  /// hiding them is the opposite of what a clean viewfinder is for.
  bool _cleanViewfinder = false;

  /// Newest processed frame, shown in the control row so the last shot is
  /// always one tap from the Lab. Cached — never read Hive from build().
  String? _lastShotPath;
  File? _ejectFile;
  double _ejectAspect = 3 / 4;
  bool _ejectRevealed = false;
  bool _flashing = false;
  final ValueNotifier<int> _captureUi = ValueNotifier(0);

  /// Bumped when an FX slider moves. Only the graded preview and the slider
  /// panel listen, so a drag no longer rebuilds the camera preview, the
  /// viewfinder overlay and the seven-button rail on every frame.
  final ValueNotifier<int> _fxRevision = ValueNotifier<int>(0);

  /// Ticks once a second while recording; only the timecode pill listens.
  final ValueNotifier<int> _recordingSecondsNotifier = ValueNotifier<int>(0);

  void _setFx(VoidCallback mutate) {
    mutate();
    _fxRevision.value++;
  }

  // ── Tap-to-Focus ───────────────────────────────────────────────────────
  Offset? _focusPoint; // Position of the last focus tap (screen coords)
  late final AnimationController _focusAnimController;
  late final Animation<double> _focusScaleAnim;
  late final Animation<double> _focusOpacityAnim;

  // ── Texture Cache (WYSIWYG Preview) ────────────────────────────────────
  // Pre-decoded ui.Image objects for real-time overlay rendering.
  // Stored as ui.Image (not raw bytes) to avoid expensive decoding on every paint.

  bool get _videoSupported => Platform.isAndroid;
  bool get _isVideoMode => _captureMode == CaptureMode.video;
  bool get _isBusy => _isCapturing || _isProcessingVideo;
  bool get _hasPendingDoubleExposure => _pendingDoubleExposureFile != null;
  bool get _hasExposureControl =>
      _maxExposureOffset > _minExposureOffset && _isCameraReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Slow breathing animation for light leak overlay
    // Focus indicator animation (scale + fade out)
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _focusScaleAnim = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );
    _focusOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _focusAnimController, curve: Curves.easeOut),
    );

    _loadOrCreateRoll();
    _initializeEffectsFromFilmStock();
    // The active stock can sit well down a 19-item row; bring it into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedFilm();
      _refreshLastShot();
    });
    _shutterPoolFuture = AudioPool.createFromAsset(
      path: RetroAssets.soundShutter.replaceFirst('assets/', ''),
      minPlayers: 2,
      maxPlayers: 4,
      playerMode: PlayerMode.lowLatency,
    );
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingTimer?.cancel();
    _clearPendingDoubleExposure();
    unawaited(_disposeCameraController());
    unawaited(_disposeShutterPool());
    _focusAnimController.dispose();
    _filmSelectorScrollController.dispose();
    _fxRevision.dispose();
    _recordingSecondsNotifier.dispose();
    _captureUi.dispose();
    super.dispose();
  }

  Future<void> _disposeShutterPool() async {
    final pool = await _shutterPoolFuture;
    await pool?.dispose();
  }

  void _refreshLastShot() {
    final box = HiveService.photosBox;
    String? path;
    DateTime? newest;
    for (int i = 0; i < box.length; i++) {
      final map = box.getAt(i);
      if (map == null) continue;
      final photo = RetroPhoto.fromMap(Map<String, dynamic>.from(map));
      if (newest == null || photo.capturedAt.isAfter(newest)) {
        newest = photo.capturedAt;
        path = photo.processedPath;
      }
    }
    if (mounted && path != _lastShotPath) {
      setState(() => _lastShotPath = path);
    }
  }

  void _scrollToSelectedFilm() {
    final index = FilmStocks.all.indexWhere((s) => s.id == _selectedStock.id);
    if (index >= 0 && _filmSelectorScrollController.hasClients) {
      _filmSelectorScrollController.animateTo(
        index * 95.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // detached/hidden used to fall through here and leak the controller.
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (_cameraController == null ||
            !_cameraController!.value.isInitialized) {
          return;
        }
        _clearPendingDoubleExposure();
        if (_isRecordingVideo) {
          unawaited(_stopVideoRecording(fromLifecycle: true));
        }
        _pendingExposureOffset = null;
        _isApplyingExposure = false;
        unawaited(_disposeCameraController());
      case AppLifecycleState.resumed:
        unawaited(_initCamera());
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (await Permission.camera.isDenied) {
      if (!mounted) return;
      bool? consent = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              backgroundColor: p.surface,
              title: Text(
                '需要相机权限',
                style: _type(color: p.textPrimary),
              ),
              content: Text(
                'RetroLab 要用相机才能取景。照片存在这台手机上，只有打开应用时才会用到相机。',
                style: _type(color: p.textMuted),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    '先不用',
                    style: _type(color: p.textMuted),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.amber,
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    '允许',
                    style: _type(
                      color: p.background,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
      );
      if (consent != true) {
        _showPermissionBlocked();
        return;
      }

      final status = await Permission.camera.request();
      if (!status.isGranted) {
        _showPermissionBlocked(permanent: status.isPermanentlyDenied);
        return;
      }
    }

    try {
      // Cached across resumes — availableCameras() is a platform round-trip
      // and this runs on every app switch.
      if (_cameras.isEmpty) {
        _cameras = await availableCameras();
      }
      if (_cameras.isEmpty) throw Exception('没找到相机');
      await _setupCamera(_cameras[_currentCameraIndex]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机打不开：$e')),
        );
      }
    }
  }

  /// Declining used to leave a permanently dead camera with no way back.
  void _showPermissionBlocked({bool permanent = false}) {
    if (!mounted) return;
    setState(() => _permissionBlocked = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('拍照需要相机权限。'),
        action: SnackBarAction(
          label: permanent ? '设置' : 'REINTENTAR',
          onPressed: () {
            if (permanent) {
              openAppSettings();
            } else {
              setState(() => _permissionBlocked = false);
              unawaited(_initCamera());
            }
          },
        ),
      ),
    );
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    if (mounted) {
      setState(() => _isCameraReady = false);
    }
    await _cameraDisposeFuture;
    _pendingExposureOffset = null;
    _isApplyingExposure = false;
    await _disposeCameraController();
    _cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: _isVideoMode,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);
      await _syncExposureState();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      debugPrint('Camera init error: $e');
    }
  }

  Future<void> _disposeCameraController() {
    final controller = _cameraController;
    _cameraController = null;
    if (controller == null) {
      return _cameraDisposeFuture;
    }
    final disposeFuture = () async {
      try {
        await controller.dispose();
      } catch (error) {
        debugPrint('Camera dispose error: $error');
      }
    }();
    _cameraDisposeFuture = disposeFuture;
    return disposeFuture;
  }

  void _loadOrCreateRoll() {
    final rollsBox = HiveService.rollsBox;
    FilmRoll? activeRoll;
    for (int i = 0; i < rollsBox.length; i++) {
      final map = rollsBox.getAt(i);
      if (map != null) {
        final roll = FilmRoll.fromMap(Map<String, dynamic>.from(map));
        if (!roll.isFinished) {
          activeRoll = roll;
          break;
        }
      }
    }
    if (activeRoll != null) {
      _currentRoll = activeRoll;
      _selectedStock = FilmStocks.getById(activeRoll.filmStockId);
    } else {
      _createNewRoll();
    }
  }

  void _createNewRoll() {
    _currentRoll = FilmRoll(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      filmStockId: _selectedStock.id,
      loadedAt: DateTime.now(),
    );
    HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
    HiveService.incrementRolls();
  }

  void _initializeEffectsFromFilmStock({bool resetTextures = true}) {
    setState(() {
      _vignette = RetroDefaults.vignette;
      _saturation = _selectedStock.saturation;
      if (resetTextures) {
        _grain = RetroDefaults.grain;
        _leakStrength = RetroDefaults.leakStrength;
        _dustStrength = RetroDefaults.dustStrength;
      }
      _scratchLevel = RetroDefaults.scratchLevel;
      _lightLeakIndex = _selectedStock.id.hashCode.abs() % 42;
    });
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('录像需要麦克风权限。'),
        ),
      );
    }
    return false;
  }

  Future<void> _setCaptureMode(CaptureMode mode) async {
    if (!_videoSupported && mode == CaptureMode.video) return;
    if (_captureMode == mode || _isBusy || _isRecordingVideo) return;
    if (_hasPendingDoubleExposure) return;
    if (mode == CaptureMode.video && !await _ensureMicrophonePermission()) {
      return;
    }
    setState(() {
      _captureMode = mode;
      _showControls = false;
      _showExposureControl = false;
      _timerCountdown = 0;
      if (mode == CaptureMode.video) {
        _isBurstMode = false;
        _shutterTimer = ShutterTimer.off;
      }
    });
    if (_cameras.isNotEmpty) {
      await _setupCamera(_cameras[_currentCameraIndex]);
    }
  }

  Future<void> _syncExposureState() async {
    final controller = _cameraController;
    if (controller == null) return;
    try {
      final minOffset = await controller.getMinExposureOffset();
      final maxOffset = await controller.getMaxExposureOffset();
      final clamped = _currentExposureOffset.clamp(minOffset, maxOffset);
      await controller.setExposureOffset(clamped);
      if (!mounted ||
          !identical(controller, _cameraController) ||
          !controller.value.isInitialized) {
        return;
      }
      if (mounted) {
        setState(() {
          _minExposureOffset = minOffset;
          _maxExposureOffset = maxOffset;
          _currentExposureOffset = clamped;
        });
      }
    } on CameraException catch (error) {
      if (_isExpectedExposureCancellation(error)) {
        return;
      }
      debugPrint('Exposure state error: $error');
      if (mounted && identical(controller, _cameraController)) {
        setState(() {
          _minExposureOffset = 0.0;
          _maxExposureOffset = 0.0;
          _currentExposureOffset = 0.0;
        });
      }
    } catch (error) {
      debugPrint('Exposure state error: $error');
      if (mounted) {
        setState(() {
          _minExposureOffset = 0.0;
          _maxExposureOffset = 0.0;
          _currentExposureOffset = 0.0;
        });
      }
    }
  }

  Future<void> _setExposureOffset(double offset) async {
    final controller = _cameraController;
    if (controller == null) return;
    final next =
        offset.clamp(_minExposureOffset, _maxExposureOffset).toDouble();
    _pendingExposureOffset = next;
    if (_isApplyingExposure) return;
    _isApplyingExposure = true;
    try {
      while (identical(controller, _cameraController) &&
          controller.value.isInitialized &&
          _pendingExposureOffset != null) {
        final target = _pendingExposureOffset!;
        _pendingExposureOffset = null;
        await controller.setExposureOffset(target);
      }
    } on CameraException catch (error) {
      if (_isExpectedExposureCancellation(error)) {
        debugPrint('Exposure request canceled: ${error.description}');
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('曝光调不了：$error')),
        );
      }
    } finally {
      if (identical(controller, _cameraController)) {
        _isApplyingExposure = false;
        if (_pendingExposureOffset != null && controller.value.isInitialized) {
          unawaited(_setExposureOffset(_pendingExposureOffset!));
        }
      }
    }
  }

  void _setExposureFromSlider(double sliderValue) {
    final actualOffset =
        sliderValue.clamp(_minExposureOffset, _maxExposureOffset).toDouble();
    setState(() {
      _currentExposureOffset = actualOffset;
    });
    unawaited(_setExposureOffset(actualOffset));
  }

  bool _isExpectedExposureCancellation(CameraException error) {
    return error.code == 'setExposureOffsetFailed' &&
        (error.description?.contains('being closed') == true ||
            error.description?.contains('new request being submitted') == true);
  }

  void _clearPendingDoubleExposure({bool disableMode = true}) {
    final file = _pendingDoubleExposureFile;
    if (file != null && file.existsSync()) {
      file.deleteSync();
    }
    if (mounted) {
      setState(() {
        _pendingDoubleExposureFile = null;
        if (disableMode) {
          _doubleExposureEnabled = false;
        }
      });
    } else {
      _pendingDoubleExposureFile = null;
      if (disableMode) {
        _doubleExposureEnabled = false;
      }
    }
  }

  Future<void> _toggleDoubleExposure() async {
    if (_isVideoMode || _isBusy || _hasPendingDoubleExposure) return;
    if (!_doubleExposureEnabled && _currentRoll.remainingExposures < 2) {
      _showFilmFinishedDialog();
      return;
    }
    setState(() {
      _doubleExposureEnabled = !_doubleExposureEnabled;
      _isBurstMode = false;
      _shutterTimer = ShutterTimer.off;
      _showControls = false;
      _showExposureControl = false;
    });
  }

  void _cycleOverlayMode() {
    const values = OverlayMode.values;
    final next = values[(_overlayMode.index + 1) % values.length];
    setState(() => _overlayMode = next);
  }

  Future<void> _openLab({int initialTab = 0}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LabScreen(initialTab: initialTab)),
    );
    if (mounted) {
      setState(() {});
      _refreshLastShot();
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (mounted) setState(() {});
  }

  /// Handle tap-to-focus on the camera preview.
  /// Sets focus point and shows animated focus indicator.
  Future<void> _handleTapToFocus(TapDownDetails details) async {
    if (!_isCameraReady || _cameraController == null) return;

    // Store the tap position for the focus indicator
    setState(() {
      _focusPoint = details.localPosition;
    });

    // Animate the focus indicator
    _focusAnimController.forward(from: 0.0);

    // Convert screen coordinates to camera coordinates (normalized 0.0-1.0)
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return;
    final RenderBox renderBox = renderObject;
    final size = renderBox.size;
    final previewSize = _cameraController!.value.previewSize;
    final sourceWidth = previewSize?.height ?? size.width;
    final sourceHeight = previewSize?.width ?? size.height;
    final scale = math.max(
      size.width / sourceWidth,
      size.height / sourceHeight,
    );
    final fittedWidth = sourceWidth * scale;
    final fittedHeight = sourceHeight * scale;
    final horizontalInset = (size.width - fittedWidth) / 2;
    final verticalInset = (size.height - fittedHeight) / 2;

    // Calculate normalized coordinates
    final x = ((details.localPosition.dx - horizontalInset) / fittedWidth)
        .clamp(0.0, 1.0);
    final y = ((details.localPosition.dy - verticalInset) / fittedHeight).clamp(
      0.0,
      1.0,
    );

    try {
      // Set focus point (x, y are normalized to 0.0-1.0)
      await _cameraController!.setFocusPoint(Offset(x, y));
      // Optionally also set exposure point to the same location
      await _cameraController!.setExposurePoint(Offset(x, y));

      if (mounted) {
        // Brief haptic feedback
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Focus error: $e');
    }
  }

  // ── Capture Logic ──────────────────────────────────────────────────────

  Future<void> _onShutterPressed() async {
    if (_isBusy) return;
    if (_isVideoMode) {
      if (_isRecordingVideo) {
        await _stopVideoRecording();
      } else {
        await _startVideoRecording();
      }
      return;
    }
    if (_currentRoll.isFinished) {
      _showFilmFinishedDialog();
      return;
    }
    if (_doubleExposureEnabled &&
        !_hasPendingDoubleExposure &&
        _currentRoll.remainingExposures < 2) {
      _showFilmFinishedDialog();
      return;
    }

    if (_shutterTimer != ShutterTimer.off) {
      setState(() => _timerCountdown = _shutterTimer.seconds);
      for (int i = _shutterTimer.seconds; i > 0; i--) {
        if (!mounted) return;
        setState(() => _timerCountdown = i);
        await Future.delayed(const Duration(seconds: 1));
      }
      setState(() => _timerCountdown = 0);
    }

    if (_doubleExposureEnabled || _hasPendingDoubleExposure) {
      await _captureDoubleExposure();
      return;
    }

    if (_isBurstMode) {
      for (int i = 0; i < 3; i++) {
        await _capturePhotoFinal();
        if (i < 2) await Future.delayed(const Duration(milliseconds: 400));
        if (_currentRoll.isFinished) break;
      }
    } else {
      await _capturePhotoFinal();
    }
  }

  Future<void> _startVideoRecording() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() {
      _isRecordingVideo = true;
      _showControls = false;
    });
    try {
      await _cameraController!.startVideoRecording();
      _recordingTimer?.cancel();
      _recordingSecondsNotifier.value = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        final next = _recordingSecondsNotifier.value + 1;
        if (next >= 30) {
          _stopVideoRecording();
          return;
        }
        // Only the timecode pill listens — no full-screen rebuild per second.
        _recordingSecondsNotifier.value = next;
      });
    } catch (e) {
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecordingVideo = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('录像没开始：$e')));
      }
    }
  }

  Future<void> _stopVideoRecording({bool fromLifecycle = false}) async {
    if (_cameraController == null || !_isRecordingVideo) return;
    _recordingTimer?.cancel();
    setState(() {
      _isRecordingVideo = false;
      _isProcessingVideo = !fromLifecycle;
    });
    try {
      final xFile = await _cameraController!.stopVideoRecording();
      if (fromLifecycle || !mounted) return;
      final videoId = DateTime.now().millisecondsSinceEpoch.toString();
      final settings = VideoEffectSettings(
        stock: _selectedStock,
        grain: _grain,
        leakStrength: _leakStrength,
        dustStrength: _dustStrength,
        lightLeakIndex: _lightLeakIndex,
        saturation: _saturation,
        vignette: _vignette,
        scratchLevel: _scratchLevel,
        analogRandomness: HiveService.analogRandomnessEnabled,
        artifactSeed: videoId.hashCode,
      );
      if (!mounted) return;
      await _pausePreview();
      if (!mounted) return;
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) {
            return VideoProcessingScreen(
              rawFile: File(xFile.path),
              videoId: videoId,
              settings: settings,
            );
          },
        ),
      );
      unawaited(_resumePreview());
      if (saved == true && mounted) {
        // Signpost instead of the old forced jump into the Lab.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('视频已放进相册'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () => _openLab(initialTab: 1),
            ),
          ),
        );
      }
    } catch (e) {
      if (!fromLifecycle && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('录像停止失败：$e')));
      }
    } finally {
      if (mounted) {
        _recordingSecondsNotifier.value = 0;
        setState(() => _isProcessingVideo = false);
      }
    }
  }

  double _viewfinderAspect() {
    final box = _previewKey.currentContext?.findRenderObject();
    if (box is RenderBox && box.hasSize && box.size.height > 1) {
      return box.size.width / box.size.height;
    }
    return 3 / 4;
  }

  void _pingCapture() => _captureUi.value++;

  Future<void> _pausePreview() async {
    try {
      await _cameraController?.pausePreview();
    } catch (_) {}
  }

  Future<void> _resumePreview() async {
    try {
      await _cameraController?.resumePreview();
    } catch (_) {}
  }

  /// Grade, crop and frame. Does not touch the print animation.
  Future<({RetroPhoto photo, Uint8List bytes, bool saved, File graded})>
  _processShot(
    File source,
    String photoId, {
    required bool cropToViewfinder,
    required double aspect,
    required bool isImported,
  }) async {
    final working =
        cropToViewfinder ? await ImageProcessor.cropToAspect(source, aspect) : source;
    final capturedAt = DateTime.now();
    final result = await ImageProcessor.processRetroImage(
      working,
      filmStock: _selectedStock,
      grain: _grain,
      leakStrength: _leakStrength,
      dustStrength: _dustStrength,
      lightLeakIndex: _lightLeakIndex,
      saturationOverride: _saturation,
      vignette: _vignette,
      scratchLevel: _scratchLevel,
      analogRandomness: HiveService.analogRandomnessEnabled,
      artifactSeed: photoId.hashCode,
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
      saveToGallery: false,
    );
    final framed = await ImageProcessor.wrapInstaxFrame(
      result.file,
      caption: stockTitle(_selectedStock),
    );
    final saved = await ImageProcessor.saveToGallery(framed);
    final framedBytes = await framed.readAsBytes();
    final photo = RetroPhoto(
      id: photoId,
      originalPath: source.path,
      processedPath: framed.path,
      filmStockId: _selectedStock.id,
      rollId: _currentRoll.id,
      capturedAt: capturedAt,
      grain: _grain,
      leakStrength: _leakStrength,
      dustStrength: _dustStrength,
      lightLeakIndex: _lightLeakIndex,
      saturation: _saturation,
      vignette: _vignette,
      scratchLevel: _scratchLevel,
      dateStampStyle: HiveService.dateStampStyle,
      dateStampPosition: HiveService.dateStampPosition,
      isImported: isImported,
    );
    await HiveService.photosBox.put(photo.id, photo.toMap());
    return (photo: photo, bytes: framedBytes, saved: saved, graded: result.file);
  }

  /// Flash is already up. Show the print immediately, reveal the photo while
  /// the heavy grade runs, then open the result. No second processing screen.
  Future<void> _presentShot(
    File source,
    String photoId, {
    required double aspect,
    bool cropToViewfinder = true,
    bool showEject = true,
    bool isImported = false,
  }) async {
    final shotFuture = _processShot(
      source,
      photoId,
      cropToViewfinder: cropToViewfinder,
      aspect: aspect,
      isImported: isImported,
    );

    if (showEject && mounted) {
      await _pausePreview();
      _flashing = false;
      _ejectFile = source;
      _ejectAspect = aspect;
      _ejectRevealed = false;
      _pingCapture();
      // Short white sheet, then the captured frame itself — not a blank wait.
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) {
        _ejectRevealed = true;
        _pingCapture();
      }
    }

    final revealedAt = DateTime.now();
    final shot = await shotFuture;
    if (showEject) {
      final left = 420 - DateTime.now().difference(revealedAt).inMilliseconds;
      if (left > 0) {
        await Future<void>.delayed(Duration(milliseconds: left));
      }
      if (mounted) {
        _ejectFile = null;
        _ejectRevealed = false;
        _pingCapture();
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => PreviewScreen(
              photo: shot.photo,
              processedBytes: shot.bytes,
              savedToGallery: shot.saved,
            ),
      ),
    );
    _refreshLastShot();
    if (shot.graded.path != shot.photo.processedPath && shot.graded.existsSync()) {
      await shot.graded.delete();
    }
  }

  Future<File> _takeRawPhoto() async {
    if (!_isCameraReady || _cameraController == null) {
      throw StateError('相机还没准备好。');
    }
    _playShutterSound();
    final xFile = await _cameraController!.takePicture();
    return File(xFile.path);
  }

  Future<void> _consumeExposure(String exposureId) async {
    _currentRoll = _currentRoll.withExposureTaken(exposureId);
    await HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
    await HiveService.incrementShots();
    await HiveService.recordStockUsage(_selectedStock.id);
  }

  Future<void> _capturePhotoFinal() async {
    if (!_isCameraReady || _cameraController == null) return;
    final aspect = _viewfinderAspect();
    setState(() => _isCapturing = true);
    _flashing = true;
    _pingCapture();
    ScaffoldMessenger.of(context).clearSnackBars();

    try {
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      final file = await _takeRawPhoto();
      await _consumeExposure(photoId);
      if (!mounted) return;
      await _presentShot(file, photoId, aspect: aspect);
    } catch (e) {
      debugPrint('Capture error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('没拍下来：$e'),
            backgroundColor: p.error,
          ),
        );
      }
    } finally {
      _flashing = false;
      _ejectFile = null;
      _ejectRevealed = false;
      _pingCapture();
      unawaited(_resumePreview());
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _captureDoubleExposure() async {
    if (!_isCameraReady || _cameraController == null) return;
    setState(() => _isCapturing = true);
    File? secondFile;
    try {
      if (!_hasPendingDoubleExposure) {
        final firstId = '${DateTime.now().millisecondsSinceEpoch}_a';
        final file = await _takeRawPhoto();
        await _consumeExposure(firstId);
        if (mounted) {
          setState(() {
            _pendingDoubleExposureFile = file;
            _showControls = false;
            _showExposureControl = false;
          });
        }
        return;
      }

      final secondId = '${DateTime.now().millisecondsSinceEpoch}_b';
      secondFile = await _takeRawPhoto();
      await _consumeExposure(secondId);
      final firstFile = _pendingDoubleExposureFile!;
      final composedFile = await ImageProcessor.composeDoubleExposure(
        firstFile,
        secondFile,
      );
      final photoId = DateTime.now().millisecondsSinceEpoch.toString();
      if (firstFile.existsSync()) {
        await firstFile.delete();
      }
      if (secondFile.existsSync()) {
        await secondFile.delete();
      }
      if (mounted) {
        setState(() => _pendingDoubleExposureFile = null);
      } else {
        _pendingDoubleExposureFile = null;
      }
      if (!mounted) return;
      final aspect = _viewfinderAspect();
      await _presentShot(composedFile, photoId, aspect: aspect);
    } catch (e) {
      if (secondFile != null && secondFile.existsSync()) {
        await secondFile.delete();
      }
      debugPrint('Double exposure error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('双重曝光失败：$e'),
            backgroundColor: p.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _playShutterSound() {
    unawaited(_playShutterSoundAsync());
  }

  Future<void> _playShutterSoundAsync() async {
    try {
      final pool = await _shutterPoolFuture;
      if (pool == null) return;
      final stop = await pool.start(volume: 1.0);
      Future<void>.delayed(const Duration(milliseconds: 700), stop);
    } catch (error) {
      debugPrint('Shutter sound unavailable: $error');
    }
  }

  Future<void> _importFromGallery() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery);
    if (xFile == null) return;

    final file = File(xFile.path);
    final photoId = DateTime.now().millisecondsSinceEpoch.toString();

    if (!mounted) return;
    setState(() => _isCapturing = true);
    try {
      await _presentShot(
        file,
        photoId,
        aspect: 3 / 4,
        cropToViewfinder: false,
        showEject: false,
        isImported: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('没能导入：$e'), backgroundColor: p.error),
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _flipCamera() {
    if (_cameras.length < 2 || _isRecordingVideo || _hasPendingDoubleExposure) {
      return;
    }
    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    _setupCamera(_cameras[_currentCameraIndex]);
  }

  void _cycleFlash() {
    final modes =
        _isVideoMode
            ? [FlashMode.off, FlashMode.torch]
            : [FlashMode.off, FlashMode.auto, FlashMode.always];
    final currentIndex = modes.indexOf(_flashMode);
    _flashMode = modes[(currentIndex + 1) % modes.length];
    _cameraController?.setFlashMode(_flashMode);
    setState(() {});
  }

  void _cycleTimer() {
    if (_isVideoMode || _doubleExposureEnabled || _hasPendingDoubleExposure) {
      return;
    }
    final timers = ShutterTimer.values;
    setState(() {
      _shutterTimer =
          timers[(timers.indexOf(_shutterTimer) + 1) % timers.length];
    });
  }

  void _showFilmFinishedDialog() {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
            ),
            title: Text(
              RetroStrings.filmFinished,
              style: _type(color: p.amber),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_roll,
                  size: 64,
                  color: p.dateYellow,
                ),
                const SizedBox(height: 16),
                Text(
                  '「${stockTitle(_selectedStock)}」这卷已经拍完。\n换一卷再继续。',
                  style: _type(
                    color: p.textMuted,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openLab();
                },
                child: const Text('去相册'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _createNewRoll();
                  setState(() {});
                },
                child: const Text(RetroStrings.loadNewRoll),
              ),
            ],
          ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0B09),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildViewfinderCard()),
              _buildDock(),
            ],
          ),
          // Overlay listens on its own so the camera tree is not rebuilt
          // on every frame of the print animation.
          ValueListenableBuilder<int>(
            valueListenable: _captureUi,
            builder: (context, _, __) {
              return Stack(
                children: [
                  if (_ejectFile != null)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: FilmEjectOverlay(
                          image: _ejectFile!,
                          caption: stockTitle(_selectedStock),
                          imageAspect: _ejectAspect,
                          revealed: _ejectRevealed,
                        ),
                      ),
                    ),
                  if (_flashing)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(color: Color(0xF2FFFFFF)),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDock() {
    return ColoredBox(
      color: const Color(0xFF0C0B09),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_showControls) _buildFxPanel() else _buildFilmRow(),
            _buildControlRow(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.hairline),
            ),
            child: Icon(
              _selectedStock.icon,
              size: 18,
              color: p.amber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stockTitle(_selectedStock),
                  style: _type(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                Text(
                  _isVideoMode ? '录像 · 画面已套胶片' : '拍照 · 画面已套胶片',
                  style: _type(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: p.cyan,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          if (_videoSupported) _buildModeToggle(),
          const SizedBox(width: 8),
          _squareButton(
            icon:
                _cleanViewfinder
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
            tooltip:
                _cleanViewfinder ? '显示按钮' : '只留画面',
            active: _cleanViewfinder,
            onTap:
                () => setState(() => _cleanViewfinder = !_cleanViewfinder),
          ),
          const SizedBox(width: 8),
          _squareButton(
            icon: Icons.add_photo_alternate_outlined,
            tooltip: '从相册导入',
            onTap: _isBusy ? null : _importFromGallery,
          ),
        ],
      ),
    );
  }

  /// FOTO | VIDEO. A segmented pill reads as one choice with two states,
  /// which two separate buttons never quite do.
  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _modeSegment(CaptureMode.photo, '拍照'),
          _modeSegment(CaptureMode.video, '录像'),
        ],
      ),
    );
  }

  Widget _modeSegment(CaptureMode mode, String label) {
    final active = _captureMode == mode;
    return GestureDetector(
      onTap: _isBusy || _isRecordingVideo ? null : () => _setCaptureMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? p.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: _type(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: active ? p.background : p.textMuted,
          ),
        ),
      ),
    );
  }

  // ── Viewfinder ─────────────────────────────────────────────────────────

  Widget _buildViewfinderCard() {
    return ColoredBox(
      color: const Color(0xFF141210),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: InstaxFrame(
            title: stockTitle(_selectedStock),
            shotsLeft: _isVideoMode ? 0 : _currentRoll.remainingExposures,
            child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isCameraReady && _cameraController != null)
                RepaintBoundary(child: _buildPreview())
              else
                _buildPreviewPlaceholder(),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildTopBar(),
              ),

              // Composition guides, brackets and the date-stamp preview.
              // Intentionally NOT gated on _cleanViewfinder — see the field.
              if (_isCameraReady)
                Positioned.fill(
                  child: IgnorePointer(
                    child: RepaintBoundary(
                      child: ViewfinderOverlay(
                        filmStock: _selectedStock,
                        remainingExposures:
                            _isVideoMode ? 0 : _currentRoll.remainingExposures,
                        overlayMode: _overlayMode,
                      ),
                    ),
                  ),
                ),

              // Tap-to-focus indicator. Lives in the preview's own coordinate
              // space, so it must stay inside this Stack.
              if (_focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 50,
                  top: _focusPoint!.dy - 50,
                  child: IgnorePointer(child: _buildFocusIndicator()),
                ),

              if (!_cleanViewfinder)
                Positioned(top: 12, left: 12, child: _buildLensChip()),
              if (_isCameraReady && !_cleanViewfinder)
                Positioned(top: 12, right: 66, child: _buildExposureChip()),

              if (!_cleanViewfinder)
                Positioned(
                  top: 10,
                  right: 10,
                  bottom: 56,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: SingleChildScrollView(child: _buildToolRail()),
                  ),
                ),

              if (_showExposureControl &&
                  _hasExposureControl &&
                  !_cleanViewfinder)
                Positioned(top: 64, right: 72, child: _buildExposureControl()),

              if (_isRecordingVideo)
                Positioned(top: 52, left: 12, child: _buildRecordingPill()),

              if (_hasPendingDoubleExposure)
                Positioned(
                  top: 52,
                  left: 12,
                  child: _buildDoubleExposurePill(),
                ),

              if (!_cleanViewfinder)
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: _buildReadoutStrip(),
                ),

              if (_timerCountdown > 0)
                Positioned.fill(child: _buildCountdownOverlay()),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return GestureDetector(
      key: _previewKey,
      onTapDown: _handleTapToFocus,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize?.height ?? 1,
            height: _cameraController!.value.previewSize?.width ?? 1,
            // Only the graded preview depends on the FX sliders, so it listens
            // instead of the whole screen rebuilding.
            child: ValueListenableBuilder<int>(
              valueListenable: _fxRevision,
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(_cameraController!),
                    if (_hasPendingDoubleExposure)
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0.35,
                          child: Image.file(
                            _pendingDoubleExposureFile!,
                            fit: BoxFit.cover,
                            cacheWidth: 1080,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              builder: (context, _, child) {
                return FilmPreview(
                  stock: _selectedStock,
                  grain: _grain,
                  leakStrength: _leakStrength,
                  dustStrength: _dustStrength,
                  saturation: _saturation,
                  vignette: _vignette,
                  scratchLevel: _scratchLevel,
                  lightLeakIndex: _lightLeakIndex,
                  analogRandomness: HiveService.analogRandomnessEnabled,
                  artifactSeed: _selectedStock.id.hashCode ^ _lightLeakIndex,
                  child: child!,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_permissionBlocked)
            Icon(
              Icons.no_photography_outlined,
              color: p.error,
              size: 40,
            )
          else
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(p.amber),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _permissionBlocked
                ? '没有相机权限'
                : '正在打开相机…',
            style: _type(
              color:
                  _permissionBlocked
                      ? p.error
                      : p.textMuted,
              fontSize: 11,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_permissionBlocked) ...[
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _permissionBlocked = false);
                unawaited(_initCamera());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('允许使用相机'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return ScaleTransition(
      scale: _focusScaleAnim,
      child: FadeTransition(
        opacity: _focusOpacityAnim,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            border: Border.all(color: p.amber, width: 1.5),
            borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
          ),
        ),
      ),
    );
  }

  /// Mirrors the mockup's "35mm f/1.4 RAW+" slug: what film you are shooting.
  Widget _buildLensChip() {
    return _glassChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: p.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _selectedStock.name,
            style: _type(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PrismPalette.onMedia,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _selectedStock.processLabel,
            style: _type(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PrismPalette.dark.cyan,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExposureChip() {
    final ev = _currentExposureOffset;
    return _glassChip(
      child: Text(
        'EV ${ev >= 0 ? '+' : ''}${ev.toStringAsFixed(1)}',
        style: _type(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color:
              _showExposureControl
                  ? PrismPalette.dark.amber
                  : PrismPalette.onMedia,
        ),
      ),
    );
  }

  /// The technical strip along the bottom of the frame. Replaces the floating
  /// summary card — same information, out of the way of the image.
  Widget _buildReadoutStrip() {
    return _glassChip(
      radius: RetroDimens.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _readout('颗粒', '${(_grain * 100).round()}%'),
          _readoutDivider(),
          _readout('漏光', '${(_leakStrength * 100).round()}%'),
          _readoutDivider(),
          _readout(
            _isVideoMode ? 'MAX' : 'EXP',
            _isVideoMode ? '30s' : '${_currentRoll.remainingExposures}',
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _showControls = !_showControls),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color:
                    _showControls
                        ? PrismPalette.dark.amber
                        : Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(RetroDimens.radiusSm),
              ),
              child: Icon(
                Icons.tune,
                size: 15,
                color:
                    _showControls
                        ? const Color(0xFF0A0E13)
                        : PrismPalette.onMedia,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _readout(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: _type(
            fontSize: 9,
            color: PrismPalette.onMediaMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: _type(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: PrismPalette.dark.cyan,
          ),
        ),
      ],
    );
  }

  Widget _readoutDivider() => Container(
    width: 1,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: p.hairline,
  );

  Widget _glassChip({
    required Widget child,
    double radius = RetroDimens.radiusSm,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 6,
    ),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PrismPalette.mediaGlass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }

  Widget _buildRecordingPill() {
    return _glassChip(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: p.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<int>(
            valueListenable: _recordingSecondsNotifier,
            builder: (context, seconds, _) {
              return Text(
                _formatRecordingLabel(seconds),
                style: _type(
                  fontSize: 11,
                  color: PrismPalette.onMedia,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDoubleExposurePill() {
    return GestureDetector(
      onTap: () => _clearPendingDoubleExposure(),
      child: _glassChip(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_2, size: 14, color: p.amber),
            const SizedBox(width: 8),
            Text(
              '取消双重曝光',
              style: _type(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: p.amber,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.center,
        child: Text(
          '$_timerCountdown',
          style: _type(
            fontSize: 96,
            fontWeight: FontWeight.w700,
            color: p.amber,
          ),
        ),
      ),
    );
  }

  Widget _buildToolRail() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
      decoration: BoxDecoration(
        color: PrismPalette.mediaGlass,
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconButton(
            _flashIcon,
            _cycleFlash,
            active: _flashMode != FlashMode.off,
            label: _flashShortLabel,
            tooltip: '闪光灯：$_flashLabel',
          ),
          _iconButton(
            Icons.grid_4x4,
            _cycleOverlayMode,
            active: _overlayMode != OverlayMode.off,
            label: _overlayLabel,
            tooltip: '构图线',
          ),
          _iconButton(
            Icons.exposure,
            () => setState(() => _showExposureControl = !_showExposureControl),
            active: _showExposureControl,
            enabled: _hasExposureControl,
            label: 'EV',
            tooltip: '曝光',
          ),
          _iconButton(
            Icons.filter_2,
            _toggleDoubleExposure,
            active: _doubleExposureEnabled || _hasPendingDoubleExposure,
            enabled: !_isVideoMode && !_hasPendingDoubleExposure,
            label: '2X',
            tooltip: '双重曝光',
          ),
          _iconButton(
            Icons.timer,
            _cycleTimer,
            active: !_isVideoMode && _shutterTimer != ShutterTimer.off,
            label: _shutterTimer.label.toUpperCase(),
            enabled: !_doubleExposureEnabled && !_hasPendingDoubleExposure,
            tooltip: '倒计时',
          ),
        ],
      ),
    );
  }

  /// The Manual tab swaps the film row for the effect sliders, so the live
  /// preview above stays visible while they are dragged.
  Widget _buildFxPanel() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 232),
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: SingleChildScrollView(
        child: Theme(
          data: Theme.of(context).copyWith(
            sliderTheme: Theme.of(context).sliderTheme.copyWith(
              activeTrackColor: p.amber,
              thumbColor: p.amber,
              inactiveTrackColor: p.surfaceHigh,
            ),
          ),
          child: _controlsPanelBody(),
        ),
      ),
    );
  }

  // ── Film row ───────────────────────────────────────────────────────────

  /// Takes the place of the mockup's zoom presets. Always visible, so choosing
  /// a stock no longer means opening a panel that covers the controls.
  Widget _buildFilmRow() {
    return SizedBox(
      height: 112,
      child: ListView.builder(
        controller: _filmSelectorScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        itemCount: FilmStocks.all.length,
        itemBuilder: (context, i) {
          final stock = FilmStocks.all[i];
          final active = stock.id == _selectedStock.id;
          return GestureDetector(
            onTap: () => _selectStock(stock),
            child: SizedBox(
              width: 72,
              child: Column(
                children: [
                  SizedBox(
                    height: 82,
                    width: 56,
                    child: FilmCanister(stock: stock, selected: active),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stockTitle(stock),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _type(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? p.amber : p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _selectStock(FilmStock stock) {
    setState(() {
      _selectedStock = stock;
      _currentRoll = _currentRoll.copyWith(filmStockId: stock.id);
    });
    HiveService.rollsBox.put(_currentRoll.id, _currentRoll.toMap());
    _initializeEffectsFromFilmStock(resetTextures: false);
  }

  // ── Control row ────────────────────────────────────────────────────────

  Widget _buildControlRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BounceIcon(
            icon: _flashIcon,
            label: '闪光',
            color: const Color(0xFFE7B15A),
            active: _flashMode != FlashMode.off,
            onTap: _isBusy ? null : _cycleFlash,
          ),
          BounceIcon(
            icon: Icons.timer_outlined,
            label: _shutterTimer == ShutterTimer.off ? '延时' : _shutterTimer.label,
            color: const Color(0xFF7EB6E0),
            active: _shutterTimer != ShutterTimer.off,
            onTap: (_isVideoMode || _isBusy) ? null : _cycleTimer,
          ),
          ShutterButton(
            onPressed: _onShutterPressed,
            enabled: !_isBusy,
            recording: _isRecordingVideo,
            accent: p.amber,
          ),
          BounceIcon(
            icon: Icons.cameraswitch_outlined,
            label: '镜头',
            color: const Color(0xFF8FCBB8),
            onTap: (_hasPendingDoubleExposure || _isBusy) ? null : _flipCamera,
          ),
          BounceIcon(
            icon: Icons.crop_square_rounded,
            label: '相纸',
            color: const Color(0xFFE09A9A),
            onTap: _openLab,
          ),
        ],
      ),
    );
  }


  Widget _squareButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    double size = 36,
    bool active = false,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color:
                active
                    ? p.amber.withValues(alpha: 0.18)
                    : p.surface,
            borderRadius: BorderRadius.circular(
              size > 40 ? RetroDimens.radiusMd : RetroDimens.radiusSm,
            ),
            border: Border.all(
              color: active ? p.amber : p.hairline,
            ),
          ),
          child: Icon(
            icon,
            size: size > 40 ? 22 : 18,
            color:
                active
                    ? p.amber
                    : (enabled
                        ? p.textPrimary
                        : p.textMuted),
          ),
        ),
      ),
    );
  }

  // ── Bottom nav ─────────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
        border: Border.all(color: p.hairline),
      ),
      child: Row(
        children: [
          _navItem(Icons.photo_camera_outlined, '拍摄', active: true),
          _navItem(Icons.photo_library_outlined, '相册', onTap: _openLab),
          _navItem(
            Icons.tune,
            '调整',
            active: _showControls,
            onTap: () => setState(() => _showControls = !_showControls),
          ),
          _navItem(Icons.settings_outlined, '设置', onTap: _openSettings),
        ],
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    String label, {
    bool active = false,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? p.amber : p.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: _type(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: active ? p.amber : p.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  // ── Widgets ────────────────────────────────────────────────────────────

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.auto => Icons.flash_auto,
    FlashMode.torch => Icons.flashlight_on,
    FlashMode.always => Icons.flash_on,
    _ => Icons.flash_off,
  };

  String get _flashShortLabel => switch (_flashMode) {
    FlashMode.auto => '自动',
    FlashMode.torch => '常亮',
    FlashMode.always => '开',
    _ => '关',
  };

  String get _flashLabel => switch (_flashMode) {
    FlashMode.auto => '自动',
    FlashMode.torch => '常亮',
    FlashMode.always => '每次都闪',
    _ => '关闭',
  };

  String _formatRecordingLabel(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get _overlayLabel => switch (_overlayMode) {
    OverlayMode.off => 'OFF',
    OverlayMode.thirds => '3R',
    OverlayMode.golden => 'PHI',
    OverlayMode.center => 'CTR',
  };

      Widget _iconButton(
    IconData icon,
    VoidCallback onPressed, {
    bool active = false,
    bool enabled = true,
    String? label,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      // An empty Tooltip message renders an empty bubble; skip the wrapper.
      child: Tooltip(
        message: tooltip ?? '',
        triggerMode:
            tooltip == null ? TooltipTriggerMode.manual : TooltipTriggerMode.longPress,
        child: GestureDetector(
          onTap: _isRecordingVideo || !enabled ? null : onPressed,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color:
                  active
                      ? p.amber.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
              border: Border.all(
                color:
                    active
                        ? p.amber
                        : Colors.white.withValues(alpha: 0.10),
                width: active ? 1.5 : 1.0,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color:
                      !enabled
                          ? PrismPalette.onMediaMuted.withValues(alpha: 0.45)
                          : active
                          ? PrismPalette.dark.amber
                          : PrismPalette.onMedia,
                ),
                if (label != null)
                  Positioned(
                    bottom: 5,
                    child: Text(
                      label,
                      style: _type(
                        fontSize: 7,
                        color:
                            enabled
                                ? PrismPalette.dark.amber
                                : PrismPalette.onMediaMuted.withValues(
                                  alpha: 0.45,
                                ),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

    Widget _controlsPanelBody() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RetroDimens.paddingMd),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: p.background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(color: p.surfaceHigh),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: RetroDimens.paddingMd),
                child: Text(
                  '这卷的味道',
                  style: _type(
                    color: p.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: _initializeEffectsFromFilmStock,
                child: Text(
                  '恢复',
                  style: _type(
                    color: p.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RetroSlider(
            label: '颗粒',
            icon: Icons.grain,
            value: _grain,
            onChanged: (v) => _setFx(() => _grain = v),
          ),
          RetroSlider(
            label: '漏光',
            icon: Icons.flare,
            value: _leakStrength,
            onChanged: (v) => _setFx(() => _leakStrength = v),
          ),
          RetroSlider(
            label: '灰尘',
            icon: Icons.blur_on,
            value: _dustStrength,
            onChanged: (v) => _setFx(() => _dustStrength = v),
          ),
          RetroSlider(
            label: '饱和',
            icon: Icons.palette,
            value: _saturation,
            min: 0,
            max: 2.0,
            onChanged: (v) => _setFx(() => _saturation = v),
          ),
          RetroSlider(
            label: '暗角',
            icon: Icons.vignette,
            value: _vignette,
            onChanged: (v) => _setFx(() => _vignette = v),
          ),
          RetroSlider(
            label: '划痕',
            icon: Icons.brush,
            value: _scratchLevel,
            onChanged: (v) => _setFx(() => _scratchLevel = v),
          ),
        ],
      ),
    );
  }

    Widget _buildExposureControl() {
    final hasValidExposureRange = _maxExposureOffset > _minExposureOffset;
    final sliderMin = hasValidExposureRange ? _minExposureOffset : 0.0;
    final sliderMax = hasValidExposureRange ? _maxExposureOffset : 0.0;

    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(RetroDimens.radiusMd),
        border: Border.all(color: p.surfaceHigh),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'EV',
            style: _type(
              color: p.amber,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 120,
              child: Slider(
                value:
                    _currentExposureOffset
                        .clamp(sliderMin, sliderMax)
                        .toDouble(),
                min: sliderMin,
                max: sliderMax,
                onChanged:
                    hasValidExposureRange ? _setExposureFromSlider : null,
                onChangeEnd: null,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _currentExposureOffset.toStringAsFixed(1),
            style: _type(
              color: p.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

}
