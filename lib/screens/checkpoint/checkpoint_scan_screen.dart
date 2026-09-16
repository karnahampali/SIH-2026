import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../widgets/pramaan_theme.dart';
import '../../services/api_service.dart';
import 'checkpoint_face_screen.dart';

class CheckpointScanScreen extends ConsumerStatefulWidget {
  final String mode; // 'register' or 'verify'
  const CheckpointScanScreen({super.key, this.mode = 'verify'});

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

  Future<void> _handleDocuNetResult(Map<String, dynamic> response, String imagePath) async {
    if (response['success'] == true) {
      final parsedDoc = response['document'];
      final fullText = parsedDoc is Map ? (parsedDoc['raw_text'] ?? '').toString() : '';

      if (widget.mode == 'register') {
        // REGISTRATION: send image to backend so the SAME OCR pipeline
        // computes the hash — guarantees matching during verification.
        try {
          setState(() { _statusMsg = 'Registering to Blockchain...'; });
          final aadhaarValue = ((response['document'] as Map?)?['fields'] as Map?)?['aadhaar_number'];
          final identityKey = aadhaarValue is Map
              ? (aadhaarValue['value']?.toString() ?? '').replaceAll(RegExp(r'\D'), '')
              : '';
          final regResp = await ApiService().registerFromImage(
            imagePath,
            identityKey: identityKey,
          );
          if (mounted) {
            final alreadyExisted = regResp['already_existed'] == true;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(alreadyExisted
                  ? '⚠️ This ID is already in the Blockchain Ledger!'
                  : '✅ Identity registered to Blockchain!'),
              backgroundColor: alreadyExisted ? Colors.orange : PramaanColors.pass,
            ));
            context.go('/');
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('❌ Registration failed: $e'),
              backgroundColor: PramaanColors.riskHigh,
            ));
            context.go('/');
          }
        }
        return;
      } else {
        // VERIFICATION: The backend verify_from_image endpoint already computes the pHash 
        // and checks the ledger. We just pass the response through.
        setState(() { _statusMsg = 'Scan complete — proceeding'; _isProcessing = false; _matched = true; });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;

        final docId = 'scan_${DateTime.now().millisecondsSinceEpoch}';
        final stableImagePath = '${Directory.systemTemp.path}/pramaan_$docId.jpg';
        await File(imagePath).copy(stableImagePath);
        VerificationSession.start(
          id: docId,
          text: fullText,
          photoPath: stableImagePath,
          report: response,
        );
        debugPrint('DocuNet response accepted; opening liveness screen');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CheckpointFaceScreen(
              documentId: docId,
              ocrText: fullText,
              docPhotoPath: stableImagePath,
              docunetResult: response,
            ),
          ),
        );
      }
    } else {
      setState(() {
        _statusMsg = 'DocuNet failed: ${response['error_message'] ?? 'Unknown error'}';
        _isError = true;
        _isProcessing = false;
      });
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
      // Use a high-resolution still capture so Aadhaar text survives cropping/OCR.
      final ctrl = CameraController(
        back, 
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );
      await ctrl.initialize();
      if (!mounted) { ctrl.dispose(); return; }
      setState(() { _camCtrl = ctrl; _camReady = true; _camError = null; });
      try {
        await ctrl.setFocusMode(FocusMode.auto);
        await ctrl.setExposureMode(ExposureMode.auto);
      } catch (e) {
        debugPrint('Camera auto focus/exposure unavailable: $e');
      }
      
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
    _camCtrl?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerify() async {
    if (_isProcessing || _camCtrl == null || !_camReady || _isSendingFrame || _matched) return;
    
    _isSendingFrame = true;
    String? imagePath;
    try {
      if (_camCtrl!.value.isStreamingImages) {
        await _camCtrl!.stopImageStream();
      }
      final xfile = await _camCtrl!.takePicture().timeout(const Duration(seconds: 5));
      imagePath = xfile.path;
      
      if (mounted) setState(() { _statusMsg = 'Connecting to DocuNet...'; });

      final api = ApiService();
      if (mounted) setState(() { _statusMsg = 'Running OCR and forensic analysis...'; });
      final response = await api.verifyFromImage(imagePath).timeout(const Duration(seconds: 90));
      
      if (response['success'] == true) {
        if (mounted) setState(() { _statusMsg = 'Analysing results...'; });
        await _handleDocuNetResult(response, imagePath);
      } else {
        if (mounted) setState(() {
          _isError = true;
          _statusMsg = _shortStatus(
            response['error_message']?.toString() ?? 'Backend failed. Try again.',
          );
        });
        _deleteCapture(imagePath);
      }
    } on TimeoutException {
      if (mounted) setState(() { _isError = true; _statusMsg = "Timeout — backend too slow. Try again."; });
      _deleteCapture(imagePath);
    } catch (e) {
      debugPrint('Document verification failed: $e');
      if (mounted) {
        setState(() {
          _isError = true;
          _statusMsg = _friendlyVerificationError(e);
        });
      }
      _deleteCapture(imagePath);
    } finally {
      if (mounted) _isSendingFrame = false;
    }
  }

  void _deleteCapture(String? path) {
    if (path == null) return;
    File(path).delete().ignore();
  }

  String _shortStatus(String message) {
    return message;
  }

  String _friendlyVerificationError(Object error) {
    final message = error.toString();
    if (message.contains('Cannot reach backend')) {
      return 'Cannot reach backend. Check USB reverse or API_BASE_URL.';
    }
    if (message.contains('Backend did not respond') ||
        message.contains('TimeoutException')) {
      return 'Backend timed out. Try the scan again.';
    }
    if (message.contains('Server error')) {
      return _shortStatus(message.replaceFirst('Exception: ', ''));
    }
    return _shortStatus(message.replaceFirst('Exception: ', ''));
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
                                maxLines: 10,
                                overflow: TextOverflow.visible,
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
                      if (_isSendingFrame) ...[
                        const SizedBox(height: 4),
                        const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PramaanColors.primaryLight),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        _isSendingFrame
                          ? _statusMsg ?? 'Sending to DocuNet AI...'
                          : _isProcessing ? "Processing via DocuNet..." : "Position the Aadhaar card inside the frame",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: _isSendingFrame ? PramaanColors.primaryLight : Colors.white60,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (!_camReady || _isSendingFrame || _matched)
                              ? null
                              : _captureAndVerify,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: Text(
                            _isSendingFrame ? 'ANALYSING DOCUMENT...' : 'CAPTURE DOCUMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: PramaanColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white24,
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
