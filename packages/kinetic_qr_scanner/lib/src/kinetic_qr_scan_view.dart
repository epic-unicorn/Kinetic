import 'package:flutter/material.dart';
import 'package:zxing_barcode_scanner/zxing_barcode_scanner.dart';

/// Full-screen QR scanner using ZXing-C++ (F-Droid compatible; no ML Kit).
class KineticQrScanView extends StatefulWidget {
  const KineticQrScanView({
    super.key,
    required this.onDetect,
    this.enabled = true,
    this.hint,
    this.frameColor = Colors.white70,
    this.frameSize = 240,
    this.showTorch = false,
  });

  final ValueChanged<String> onDetect;
  final bool enabled;
  final String? hint;
  final Color frameColor;
  final double frameSize;
  final bool showTorch;

  @override
  State<KineticQrScanView> createState() => _KineticQrScanViewState();
}

class _KineticQrScanViewState extends State<KineticQrScanView> {
  final ZxingBarcodeScannerController _controller =
      ZxingBarcodeScannerController();
  bool _torchOn = false;

  void _onScan(List<BarcodeResult> results) {
    if (!widget.enabled) return;
    for (final result in results) {
      final text = result.text;
      if (text != null && text.isNotEmpty) {
        widget.onDetect(text);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      final on = await _controller.toggleFlash();
      if (mounted) setState(() => _torchOn = on);
    } catch (_) {}
  }

  Widget _buildOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: widget.frameSize,
            height: widget.frameSize,
            decoration: BoxDecoration(
              border: Border.all(color: widget.frameColor, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(150),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.hint!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ZxingBarcodeScanner(
          onScan: _onScan,
          onError: (error) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error.message ?? 'Camera unavailable',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          config: const ScannerConfig(
            resolution: Resolution.hd720p,
            zxingOptions: ZxingOptions(
              tryRotate: true,
              tryInvert: true,
              tryHarder: true,
              tryDownscale: false,
              binarizer: Binarizer.localAverage,
            ),
          ),
          overlay: _buildOverlay(),
        ),
        if (widget.showTorch)
          Positioned(
            bottom: 40,
            right: 24,
            child: FloatingActionButton.small(
              onPressed: _toggleTorch,
              child: Icon(
                _torchOn ? Icons.flashlight_off : Icons.flashlight_on,
              ),
            ),
          ),
      ],
    );
  }
}
