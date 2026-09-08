import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers.dart';
import '../../widgets/pramaan_theme.dart';
import '../../services/api_service.dart';

class CheckpointScanScreen extends ConsumerStatefulWidget {
  const CheckpointScanScreen({super.key});

  @override
  ConsumerState<CheckpointScanScreen> createState() =>
      _CheckpointScanScreenState();
}

class _CheckpointScanScreenState extends ConsumerState<CheckpointScanScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _camCtrl;
  bool _camReady = false;
  String? _camError;

  bool _isProcessing = false;
  String? _statusMsg;
  bool _isError = false;
  bool _matched = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _isSendingFrame = false;
  
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  bool _isScanningText = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    
    _initCamera();
  }

  void _handleDocuNetResult(Map<String, dynamic> response) async {
    if (response['success'] == true) {
      final parsedDoc = response['document'];
      final fullText = parsedDoc?['raw_text'] ?? '';
      
      setState(() { _statusMsg = 'Scan complete — proceeding'; _isProcessing = false; _matched = true; });

      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;

      final docId = 'scan_${DateTime.now().millisecondsSinceEpoch}';
      _goFace(docId, fullText, '', json.encode(response));
    } else {
      setState(() {
        _statusMsg = 'DocuNet failed: ${response['error_message'] ?? 'Unknown error'}';
        _isError = true;
        _isProcessing = false;
      });
      // Restart processing after a delay
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _isProcessing = false);
    }
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
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      // Medium resolution looks good enough without being too huge for ML kit
      final ctrl = CameraController(
        back, 
        ResolutionPreset.medium, 
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _camCtrl = ctrl; _camReady = true; _camError = null; });
      
      // Start live text detection stream
      _camCtrl!.startImageStream((CameraImage image) {
        if (!_isProcessing && !_isSendingFrame && !_matched && !_isScanningText) {
          _scanForDocument(image, back.sensorOrientation);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _camError = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    try {
      if (_camCtrl != null && _camCtrl!.value.isStreamingImages) {
        _camCtrl!.stopImageStream();
      }
    } catch (_) {}
    _textRecognizer.close();
    _camCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanForDocument(CameraImage image, int sensorOrientation) async {
    _isScanningText = true;
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
      final recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      // If we see at least 5 blocks of text, it's highly likely a document
      if (recognizedText.blocks.length >= 5) {
        setState(() {
          _statusMsg = "Document Detected. Capturing...";
        });
        HapticFeedback.selectionClick();
        _captureAndVerify();
      } else {
        if (_statusMsg != "Hold steady for automatic capture") {
          setState(() {
             _statusMsg = "No Document Detected";
             _isError = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Live scan error: $e");
    } finally {
      if (mounted) _isScanningText = false;
    }
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || _camCtrl == null || !_camReady || _isSendingFrame || _matched) return;
    
    _isSendingFrame = true;
    try {
      // Must stop stream before taking a high-res picture
      await _camCtrl!.stopImageStream();
      
      // Samsung devices take 2-4 seconds to execute takePicture
      final xfile = await _camCtrl!.takePicture().timeout(const Duration(seconds: 5));
      
      final api = ApiService();
      // Generous timeout to allow for model inference on first run
      final response = await api.verifyDocument(xfile.path).timeout(const Duration(seconds: 15));
      
      File(xfile.path).delete().ignore();

      if (response['success'] == true) {
         _handleDocuNetResult(response);
      } else {
         if (mounted) {
           setState(() {
             _isError = true;
             _statusMsg = response['error_message'] ?? 'Adjust document...';
           });
         }
      }
    } on TimeoutException {
      if (mounted) setState(() { _isError = true; _statusMsg = "Connection or Camera timeout"; });
      _resumeStream();
    } catch (e) {
      if (mounted) setState(() { _isError = true; _statusMsg = "Backend Error: Server overloaded"; });
      _resumeStream();
    } finally {
      if (mounted) _isSendingFrame = false;
    }
  }

  void _resumeStream() async {
    if (!mounted || _camCtrl == null || _matched) return;
    try {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      final back = (await availableCameras()).firstWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camCtrl!.startImageStream((CameraImage image) {
        if (!_isProcessing && !_isSendingFrame && !_matched && !_isScanningText) {
          _scanForDocument(image, back.sensorOrientation);
        }
      });
    } catch (e) {
      debugPrint("Could not resume stream: $e");
    }
  }

  void _goFace(String docId, String ocrText, String docImagePath, [String docunetResult = '']) {
    context.pushReplacementNamed('checkpoint-face', queryParameters: {
      'docId': docId, 'ocrText': ocrText, 'docPhoto': docImagePath, 'docunetResult': docunetResult
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildCamera(),
    );
  }

  Widget _buildCamera() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_camReady && _camCtrl != null)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 100,
              height: 100 * _camCtrl!.value.aspectRatio,
              child: CameraPreview(_camCtrl!),
            ),
          )
        else if (_camError != null)
          Container(
            color: const Color(0xFF0A0E1A),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.no_photography, color: Colors.white38, size: 56),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(_camError!, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () { setState(() => _camError = null); _initCamera(); },
                  child: const Text('Retry'),
                ),
              ]),
            ),
          )
        else
          const Center(child: CircularProgressIndicator(color: PramaanColors.primaryLight)),

        // Glassmorphic Cutout Overlay
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
                  width: MediaQuery.of(context).size.width - 40,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Glowing Bracket Reticle
        Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) {
              Color glowColor = _matched 
                  ? PramaanColors.pass 
                  : _isError 
                      ? PramaanColors.riskHigh 
                      : PramaanColors.primaryLight;
                      
              return Transform.scale(
                scale: (_isProcessing || _matched || _isError) ? 1.0 : _pulseAnim.value,
                child: Container(
                  width: MediaQuery.of(context).size.width - 40,
                  height: 240,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: glowColor.withOpacity(0.8),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  ),
                  child: Stack(children: [
                    _corner(Alignment.topLeft, glowColor), 
                    _corner(Alignment.topRight, glowColor),
                    _corner(Alignment.bottomLeft, glowColor), 
                    _corner(Alignment.bottomRight, glowColor),
                  ]),
                ),
              );
            }
          ),
        ),

        // Bottom Panel
        Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
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
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.flashlight_on, color: Colors.white),
                            onPressed: () => _camCtrl?.setFlashMode(FlashMode.torch),
                          ),
                          Expanded(
                            child: Text(
                              _statusMsg ?? 'Scanning Document...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.rajdhani(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: _isError ? PramaanColors.riskHigh : _matched ? PramaanColors.pass : Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.flashlight_off, color: Colors.white),
                            onPressed: () => _camCtrl?.setFlashMode(FlashMode.off),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isProcessing ? "Processing via DocuNet..." : "Hold steady for automatic capture",
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
        ),

        // Top Bar
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => context.go('/'),
                ),
                Text('DOCUMENT SCANNER', style: GoogleFonts.rajdhani(
                    fontWeight: FontWeight.w700, color: Colors.white, fontSize: 17, letterSpacing: 1.5)),
                const SizedBox(width: 48), // Padding equivalent to icon
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _corner(Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 30, height: 30,
        child: CustomPaint(painter: _CornerPainter(alignment, color, 4)),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double thickness;
  _CornerPainter(this.alignment, this.color, this.thickness);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = thickness..style = PaintingStyle.stroke;
    final l = size.width;
    if (alignment == Alignment.topLeft) {
      canvas.drawLine(Offset.zero, Offset(l, 0), p);
      canvas.drawLine(Offset.zero, Offset(0, l), p);
    } else if (alignment == Alignment.topRight) {
      canvas.drawLine(const Offset(0, 0), Offset(l, 0), p);
      canvas.drawLine(Offset(l, 0), Offset(l, l), p);
    } else if (alignment == Alignment.bottomLeft) {
      canvas.drawLine(Offset(0, l), Offset(l, l), p);
      canvas.drawLine(const Offset(0, 0), Offset(0, l), p);
    } else {
      canvas.drawLine(Offset(0, l), Offset(l, l), p);
      canvas.drawLine(Offset(l, 0), Offset(l, l), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
