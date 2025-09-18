import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const QrScannerApp());
}

class QrScannerApp extends StatelessWidget {
  const QrScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const BlankCameraPage(),
    );
  }
}

class BlankCameraPage extends StatefulWidget {
  const BlankCameraPage({super.key});

  @override
  State<BlankCameraPage> createState() => _BlankCameraPageState();
}

class _BlankCameraPageState extends State<BlankCameraPage> {
  bool _showPreview = false;
  late final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  // Removed unused _scannerStopped; toggle is based on _showPreview
  String? _scannedText;
  final ImagePicker _picker = ImagePicker();

  Future<void> _onCameraTap() async {
    if (!_showPreview) {
      final bool granted = await _ensureCameraPermission();
      if (!mounted) return;
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')),
        );
        return;
      }
      // Turn preview ON
      _scannedText = null; // clear any text panel
      setState(() {
        _showPreview = true;
      });
      await _scannerController.start();
    } else {
      // Turn preview OFF
      await _scannerController.stop();
      if (!mounted) return;
      setState(() {
        _showPreview = false;
      });
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  Future<bool> _ensureGalleryPermission() async {
    // For Android 13+ READ_MEDIA_IMAGES, for older READ_EXTERNAL_STORAGE handled by image_picker
    var status = await Permission.photos.status;
    if (status.isGranted) return true;
    status = await Permission.photos.request();
    return status.isGranted;
  }

  Future<void> _onGalleryTap() async {
    final allowed = await _ensureGalleryPermission();
    if (!allowed) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gallery permission denied')),
      );
      return;
    }
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    // Analyze the selected image with mobile_scanner
    try {
      final BarcodeCapture? capture = await _scannerController.analyzeImage(file.path);
      if (capture == null || capture.barcodes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No QR/Barcode found in image')),
        );
        return;
      }
      final String? raw = capture.barcodes.first.rawValue;
      if (raw == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No readable data in code')),
        );
        return;
      }
      final String? normalized = _normalizeUrlIfLikely(raw);
      if (normalized != null) {
        HapticFeedback.mediumImpact();
        final Uri uri = Uri.parse(normalized);
        final bool can = await canLaunchUrl(uri);
        await (can
            ? launchUrl(uri, mode: LaunchMode.externalApplication)
            : launchUrl(uri, mode: LaunchMode.externalApplication));
        if (!mounted) return;
        return;
      }
      // Non-URL text -> show grey panel with text
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _showPreview = false;
        _scannedText = raw;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to scan image: $e')),
      );
    }
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    HapticFeedback.mediumImpact();
    await _scannerController.stop();
    // Decide whether it's a URL or plain text
    if (capture.barcodes.isNotEmpty) {
      final String? raw = capture.barcodes.first.rawValue;
      if (raw != null) {
        final String? normalized = _normalizeUrlIfLikely(raw);
        if (normalized != null) {
          final Uri uri = Uri.parse(normalized);
          final bool can = await canLaunchUrl(uri);
          await (can
              ? launchUrl(uri, mode: LaunchMode.externalApplication)
              : launchUrl(uri, mode: LaunchMode.externalApplication));
          if (!mounted) return;
          return;
        }
        // Not a URL → show text panel instead of scanner
        if (!mounted) return;
        setState(() {
          _showPreview = false;
          _scannedText = raw;
        });
        return;
      }
    }
    if (!mounted) return;
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double threeQuarterHeight = constraints.maxHeight * 0.75;
          final double containerSize = 160; // increase overall container size here
          return Stack(
            children: [
              // Centered at 3/4 screen height (split screen, then split bottom half again)
              Positioned(
                top: threeQuarterHeight - (containerSize / 2),
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _onCameraTap,
                        child: _RoundIcon(
                          size: containerSize,
                          child: _SvgOrPng(size: containerSize * 0.8),
                        ),
                      ),
                      const SizedBox(width: 24),
                      GestureDetector(
                        onTap: _onGalleryTap,
                        child: _RoundIcon(
                          size: containerSize,
                          child: SvgPicture.asset(
                            'assets/images/gallery.svg',
                            width: containerSize * 0.8,
                            height: containerSize * 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_showPreview && _scannedText == null)
                Positioned(
                  left: 24,
                  right: 24,
                  top: 96,
                  bottom: (constraints.maxHeight * 0.4) ,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        MobileScanner(
                          controller: _scannerController,
                          onDetect: _handleDetect,
                        ),
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _CornerOverlayPainter(
                              color: Colors.white,
                              strokeWidth: 4,
                              cornerLength: 28,
                              inset: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_scannedText != null)
                Positioned(
                  left: 24,
                  right: 24,
                  top: 96,
                  bottom: (constraints.maxHeight * 0.4) ,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: const Color(0xFFF0F0F0),
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Text(
                          _scannedText!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}


class _RoundIcon extends StatelessWidget {
  final double size;
  final Widget child;

  const _RoundIcon({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFEFEFEF),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _SvgOrPng extends StatelessWidget {
  final double size;

  const _SvgOrPng({required this.size});

  @override
  Widget build(BuildContext context) {
    // Try SVG first; if it fails, fallback to PNG or icon
    return SvgPicture.asset(
      'assets/images/camera.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Image.asset(
            'assets/images/camera.png',
            width: size,
            height: size,
            errorBuilder: (context, error, stack) => const Icon(
              Icons.camera_alt_outlined,
              size: 96,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerOverlayPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double cornerLength;
  final double inset;

  _CornerOverlayPainter({
    required this.color,
    required this.strokeWidth,
    required this.cornerLength,
    required this.inset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final Rect r = Rect.fromLTWH(inset, inset, size.width - inset * 2, size.height - inset * 2);

    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(r.topLeft, r.topLeft + Offset(0, cornerLength), paint);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(r.topRight, r.topRight + Offset(0, cornerLength), paint);
    // Bottom-left
    canvas.drawLine(r.bottomLeft, r.bottomLeft + Offset(cornerLength, 0), paint);
    canvas.drawLine(r.bottomLeft, r.bottomLeft - Offset(0, cornerLength), paint);
    // Bottom-right
    canvas.drawLine(r.bottomRight, r.bottomRight - Offset(cornerLength, 0), paint);
    canvas.drawLine(r.bottomRight, r.bottomRight - Offset(0, cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant _CornerOverlayPainter oldDelegate) {
    return color != oldDelegate.color ||
        strokeWidth != oldDelegate.strokeWidth ||
        cornerLength != oldDelegate.cornerLength ||
        inset != oldDelegate.inset;
  }
}

String? _normalizeUrlIfLikely(String data) {
  final String trimmed = data.trim();
  if (trimmed.isEmpty) return null;

  // If already a valid http(s) URL, return as-is
  final Uri? parsed = Uri.tryParse(trimmed);
  if (parsed != null && parsed.hasScheme && (parsed.scheme == 'http' || parsed.scheme == 'https')) {
    return trimmed;
  }

  // Domain-like without scheme (e.g., example.com or www.example.com/path)
  final RegExp domainLike = RegExp(r'^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:[:/][^\s]*)?$', caseSensitive: false);
  if (trimmed.startsWith('www.') || domainLike.hasMatch(trimmed)) {
    return 'https://$trimmed';
  }

  return null;
}

 

