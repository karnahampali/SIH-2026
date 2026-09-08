import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/pramaan_theme.dart';

enum LivenessState {
  searching, // Looking for a face
  eyesOpen,  // Face found, waiting for eyes to be clearly open
  blinked,   // Eyes closed detected (blink)
  success    // Eyes opened again after blink
}

class CheckpointFaceScreen extends StatefulWidget {
  final String documentId;
  final String ocrText;
  final String docPhotoPath;
  final String docunetResult;

  const CheckpointFaceScreen({
    super.key,
    required this.documentId,
    this.ocrText = '',
    this.docPhotoPath = '',
    this.docunetResult = '',
  });

  @override
  State<CheckpointFaceScreen> createState() => _CheckpointFaceScreenState();
}

class _CheckpointFaceScreenState extends State<CheckpointFaceScreen> with SingleTickerProviderStateMixin {
  CameraController? _camCtrl;
  bool _camReady = false;
  String? _camError;

  LivenessState _livenessState = LivenessState.searching;
  String _instructionText = "Position your face in the oval";
  bool _isProcessingFrame = false;
  
  String? _capturedFacePath;
  CameraLensDirection _cameraDirection = CameraLensDirection.front;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast, // fast for real-time
    ),
  );

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.1).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    
    // Crucial: Wait for the previous screen's back camera to fully release its hardware lock
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _initCamera();
    });
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _camError = 'Camera permission denied.');
      return;
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _camError = 'No cameras found.');
        return;
      }
      
      // Try to get front camera, fallback to back
      final cam = cameras.firstWhere(
        (c) => c.lensDirection == _cameraDirection,
        orElse: () => cameras.first,
      );

      final ctrl = CameraController(
        cam, 
        ResolutionPreset.medium, 
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      
      setState(() {
        _camCtrl = ctrl;
        _camReady = true;
        _camError = null;
      });

      // Start live processing
      _camCtrl!.startImageStream((CameraImage image) {
        if (!_isProcessingFrame && _livenessState != LivenessState.success) {
          _processFrame(image, cam.sensorOrientation);
        }
      });

    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  void _switchCamera() async {
    if (_camCtrl == null) return;
    _cameraDirection = _cameraDirection == CameraLensDirection.front 
        ? CameraLensDirection.back 
        : CameraLensDirection.front;
    
    await _camCtrl?.stopImageStream();
    await _camCtrl?.dispose();
    setState(() {
      _camReady = false;
      _camCtrl = null;
    });
    
    // Crucial: Wait for the hardware lens to fully release before requesting the other one
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _initCamera();
    });
  }

  Future<void> _processFrame(CameraImage image, int sensorOrientation) async {
    _isProcessingFrame = true;
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation0deg;
      final inputImageFormat = InputImageFormatValue.fromRawValue(image.format.raw) ?? InputImageFormat.nv21;

      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.isNotEmpty ? image.planes[0].bytesPerRow : 0,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
      final faces = await _faceDetector.processImage(inputImage);

      if (!mounted) return;

      if (faces.isEmpty) {
        if (_livenessState != LivenessState.searching) {
          setState(() {
            _livenessState = LivenessState.searching;
            _instructionText = "Face lost. Please position your face in the oval.";
          });
        }
      } else {
        final face = faces.first;
        final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
        final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
        
        // Ensure face is somewhat straight
        final rotY = face.headEulerAngleY ?? 0;
        final rotZ = face.headEulerAngleZ ?? 0;
        
        if (rotY.abs() > 15 || rotZ.abs() > 15) {
          setState(() {
            _instructionText = "Please look straight ahead.";
          });
          _isProcessingFrame = false;
          return;
        }

        switch (_livenessState) {
          case LivenessState.searching:
            // Face found, wait for eyes open
            if (leftEyeOpen > 0.7 && rightEyeOpen > 0.7) {
              setState(() {
                _livenessState = LivenessState.eyesOpen;
                _instructionText = "Blink to verify liveness";
              });
              HapticFeedback.lightImpact();
            } else {
              setState(() => _instructionText = "Please open your eyes clearly");
            }
            break;
            
          case LivenessState.eyesOpen:
            // Waiting for blink (eyes closed)
            if (leftEyeOpen < 0.2 && rightEyeOpen < 0.2) {
              setState(() {
                _livenessState = LivenessState.blinked;
                _instructionText = "Blink detected!";
              });
            }
            break;
            
          case LivenessState.blinked:
            // Eyes opened again -> Success!
            if (leftEyeOpen > 0.7 && rightEyeOpen > 0.7) {
              setState(() {
                _livenessState = LivenessState.success;
                _instructionText = "Liveness Verified!";
              });
              HapticFeedback.heavyImpact();
              _onSuccess();
            }
            break;
            
          case LivenessState.success:
            break;
        }
      }
    } catch (e) {
      debugPrint("Frame processing error: $e");
    } finally {
      if (mounted) _isProcessingFrame = false;
    }
  }

  Future<void> _onSuccess() async {
    try {
      await _camCtrl?.stopImageStream();
      // Take a high quality picture now that liveness is verified
      final xfile = await _camCtrl!.takePicture();
      _capturedFacePath = xfile.path;
    } catch (e) {
      debugPrint("Error taking final picture: $e");
    }
    
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    
    context.pushReplacementNamed(
      'checkpoint-progress',
      queryParameters: {
        'docId': widget.documentId,
        'livePhoto': _capturedFacePath ?? '',
        'ocrText': widget.ocrText,
        'docPhoto': widget.docPhotoPath,
        'docunetResult': widget.docunetResult,
      },
    );
  }

  @override
  void dispose() {
    try {
      if (_camCtrl != null && _camCtrl!.value.isStreamingImages) {
        _camCtrl!.stopImageStream();
      }
    } catch (_) {}
    _camCtrl?.dispose();
    _faceDetector.close();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview
          if (_camReady && _camCtrl != null)
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 100,
                height: 100 * _camCtrl!.value.aspectRatio,
                child: CameraPreview(_camCtrl!),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: PramaanColors.primaryLight)),

          // 2. Glassmorphic Cutout Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 280,
                    height: 380,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(150),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Glowing Border around the oval
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) {
                Color glowColor = _livenessState == LivenessState.success 
                    ? PramaanColors.pass 
                    : PramaanColors.primaryLight;
                
                return Transform.scale(
                  scale: _livenessState == LivenessState.success ? 1.0 : _pulseAnim.value,
                  child: Container(
                    width: 280,
                    height: 380,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(150),
                      border: Border.all(
                        color: glowColor.withOpacity(0.8),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        )
                      ]
                    ),
                  ),
                );
              }
            ),
          ),

          // 4. Modern Glassmorphic Bottom Panel
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.black.withOpacity(0.8),
                      ]
                    ),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.2))),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _livenessState == LivenessState.success 
                            ? Icons.check_circle 
                            : Icons.face_retouching_natural,
                        color: _livenessState == LivenessState.success 
                            ? PramaanColors.pass 
                            : Colors.white,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _instructionText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.rajdhani(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _livenessState == LivenessState.success 
                              ? PramaanColors.pass 
                              : Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _livenessState == LivenessState.success 
                            ? "Processing verification..."
                            : "Liveness Check (Automatic)",
                        style: GoogleFonts.roboto(
                          color: Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 5. Top Bar with Camera Switch
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.go('/checkpoint'),
                    ),
                    Text(
                      'BIOMETRIC CAPTURE',
                      style: GoogleFonts.rajdhani(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 17,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch, color: Colors.white),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Error State
          if (_camError != null)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: PramaanColors.riskHigh, size: 48),
                        const SizedBox(height: 16),
                        Text(_camError!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
