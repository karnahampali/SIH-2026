import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';

class IssuancePhotoScreen extends ConsumerStatefulWidget {
  const IssuancePhotoScreen({super.key});

  @override
  ConsumerState<IssuancePhotoScreen> createState() => _IssuancePhotoScreenState();
}

class _IssuancePhotoScreenState extends ConsumerState<IssuancePhotoScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _initialized = false;
  bool _capturing = false;
  String? _capturedPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = 'No camera available');
        return;
      }
      // Prefer front camera for portrait capture
      final front = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first,
      );
      _controller = CameraController(
        front,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
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
    if (picked != null) {
      setState(() => _capturedPath = picked.path);
    }
  }

  void _retake() => setState(() => _capturedPath = null);

  void _proceed() {
    if (_capturedPath == null) return;
    ref.read(issuanceFormProvider.notifier).update(
      ref.read(issuanceFormProvider).copyWith(photoPath: _capturedPath),
    );
    context.pushNamed('issuance-processing');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          _capturedPath == null ? 'CAPTURE PHOTO' : 'REVIEW PHOTO',
          style: GoogleFonts.rajdhani(
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: _capturedPath != null
          ? _ReviewView(
              path: _capturedPath!,
              onRetake: _retake,
              onProceed: _proceed,
            )
          : _CameraView(
              controller: _controller,
              initialized: _initialized,
              capturing: _capturing,
              error: _error,
              onCapture: _capture,
              onGallery: _pickFromGallery,
            ),
    );
  }
}

class _CameraView extends StatelessWidget {
  final CameraController? controller;
  final bool initialized;
  final bool capturing;
  final String? error;
  final VoidCallback onCapture;
  final VoidCallback onGallery;

  const _CameraView({
    required this.controller,
    required this.initialized,
    required this.capturing,
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
            Text(
              error!,
              style: GoogleFonts.roboto(color: PramaanColors.textMuted),
              textAlign: TextAlign.center,
            ),
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
        child: CircularProgressIndicator(color: PramaanColors.steelBlue),
      );
    }

    return Stack(
      children: [
        // Camera preview
        Positioned.fill(
          child: AspectRatio(
            aspectRatio: controller!.value.aspectRatio,
            child: CameraPreview(controller!),
          ),
        ),

        // Oval face guide
        Center(
          child: Container(
            width: 220,
            height: 290,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(110),
              border: Border.all(
                color: Colors.white.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
        ),

        // Instructions
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Text(
            'Position face within the frame',
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ),

        // Controls
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery
              IconButton(
                onPressed: onGallery,
                icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 32),
              ),
              // Capture button
              GestureDetector(
                onTap: capturing ? null : onCapture,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: capturing
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                  ),
                  child: Center(
                    child: capturing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Container(
                            width: 58,
                            height: 58,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              // Placeholder
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewView extends StatelessWidget {
  final String path;
  final VoidCallback onRetake;
  final VoidCallback onProceed;

  const _ReviewView({
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
              // Check overlay
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: PramaanColors.pass,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 28),
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
                  onPressed: onProceed,
                  icon: const Icon(Icons.check),
                  label: const Text('USE THIS PHOTO'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
