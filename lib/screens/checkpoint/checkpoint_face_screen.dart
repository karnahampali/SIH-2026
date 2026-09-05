import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/pramaan_theme.dart';

class CheckpointFaceScreen extends StatefulWidget {
  final String documentId;
  const CheckpointFaceScreen({super.key, required this.documentId});

  @override
  State<CheckpointFaceScreen> createState() => _CheckpointFaceScreenState();
}

class _CheckpointFaceScreenState extends State<CheckpointFaceScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _initialized = false;
  bool _capturing = false;
  bool _livenessComplete = false;
  int _livenessCountdown = 3;
  String _livenessPrompt = 'Look directly at the camera';
  Timer? _livenessTimer;
  String? _capturedPath;
  String? _error;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  static const _livenessPrompts = [
    'Look directly at the camera',
    'Blink slowly',
    'Turn your head slightly right',
    'Look forward again',
  ];
  int _promptIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No camera available');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
      _startLivenessSequence();
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
    }
  }

  void _startLivenessSequence() {
    _livenessTimer = Timer.periodic(const Duration(seconds: 2), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _promptIndex = (_promptIndex + 1) % _livenessPrompts.length;
        _livenessPrompt = _livenessPrompts[_promptIndex];
        if (_livenessCountdown > 0) _livenessCountdown--;
        if (_livenessCountdown == 0 && !_livenessComplete) {
          _livenessComplete = true;
          t.cancel();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _livenessTimer?.cancel();
    _controller?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _capturing = true);
    try {
      final xfile = await _controller!.takePicture();
      setState(() {
        _capturedPath = xfile.path;
        _capturing = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Capture failed: $e';
        _capturing = false;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) setState(() => _capturedPath = picked.path);
  }

  void _proceed() {
    if (_capturedPath == null) return;
    context.pushNamed(
      'checkpoint-progress',
      queryParameters: {
        'docId': widget.documentId,
        'facePhoto': _capturedPath!,
      },
    );
  }

  void _retake() => setState(() {
        _capturedPath = null;
        _livenessComplete = false;
        _livenessCountdown = 3;
        _promptIndex = 0;
        _livenessPrompt = _livenessPrompts[0];
        _startLivenessSequence();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'LIVE FACE CAPTURE',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _capturedPath != null
          ? _ReviewFace(
              path: _capturedPath!,
              onRetake: _retake,
              onProceed: _proceed,
            )
          : _LiveCapture(
              controller: _controller,
              initialized: _initialized,
              capturing: _capturing,
              livenessComplete: _livenessComplete,
              livenessPrompt: _livenessPrompt,
              livenessCountdown: _livenessCountdown,
              pulse: _pulse,
              error: _error,
              onCapture: _capture,
              onGallery: _pickFromGallery,
            ),
    );
  }
}

class _LiveCapture extends StatelessWidget {
  final CameraController? controller;
  final bool initialized;
  final bool capturing;
  final bool livenessComplete;
  final String livenessPrompt;
  final int livenessCountdown;
  final Animation<double> pulse;
  final String? error;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  const _LiveCapture({
    required this.controller,
    required this.initialized,
    required this.capturing,
    required this.livenessComplete,
    required this.livenessPrompt,
    required this.livenessCountdown,
    required this.pulse,
    required this.error,
    required this.onCapture,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_enhance, color: PramaanColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(error!,
                style: GoogleFonts.roboto(color: PramaanColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onGallery,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('PICK FROM GALLERY'),
            ),
          ],
        ),
      );
    }

    if (!initialized) {
      return const Center(
          child: CircularProgressIndicator(color: PramaanColors.steelBlue));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(controller!),
        ),

        // Oval guide with liveness ring
        Center(
          child: AnimatedBuilder(
            animation: pulse,
            builder: (_, child) => Transform.scale(
              scale: livenessComplete ? 1.0 : pulse.value,
              child: child,
            ),
            child: Container(
              width: 230,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(115),
                border: Border.all(
                  color: livenessComplete
                      ? PramaanColors.pass
                      : PramaanColors.steelBlue,
                  width: 3,
                ),
              ),
            ),
          ),
        ),

        // Liveness status
        Positioned(
          top: 24,
          left: 20,
          right: 20,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: livenessComplete
                      ? PramaanColors.pass.withOpacity(0.9)
                      : Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: livenessComplete
                        ? PramaanColors.pass
                        : PramaanColors.steelBlue.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      livenessComplete
                          ? Icons.check_circle
                          : Icons.remove_red_eye_outlined,
                      color: livenessComplete
                          ? Colors.white
                          : PramaanColors.steelBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      livenessComplete ? 'Liveness Confirmed' : livenessPrompt,
                      style: GoogleFonts.roboto(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (!livenessComplete) ...[
                const SizedBox(height: 8),
                Text(
                  'Checking in $livenessCountdown…',
                  style: GoogleFonts.roboto(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Column(
            children: [
              if (!livenessComplete)
                Text(
                  'Complete liveness check before capturing',
                  style: GoogleFonts.roboto(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    onPressed: onGallery,
                    icon: const Icon(Icons.photo_library_outlined,
                        color: Colors.white, size: 32),
                  ),
                  GestureDetector(
                    onTap: (livenessComplete && !capturing) ? onCapture : null,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: livenessComplete
                              ? PramaanColors.pass
                              : Colors.white38,
                          width: 4,
                        ),
                        color: livenessComplete
                            ? PramaanColors.pass.withOpacity(0.2)
                            : Colors.white12,
                      ),
                      child: Center(
                        child: capturing
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Icon(
                                Icons.camera,
                                color: livenessComplete
                                    ? Colors.white
                                    : Colors.white38,
                                size: 36,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewFace extends StatelessWidget {
  final String path;
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _ReviewFace({
    required this.path,
    required this.onRetake,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(path), fit: BoxFit.cover),
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: PramaanColors.pass.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle,
                            color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Liveness Verified',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('RETAKE'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PramaanColors.pass,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: onProceed,
                  icon: const Icon(Icons.security),
                  label: const Text('VERIFY DOCUMENT'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
