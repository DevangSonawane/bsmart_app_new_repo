import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class StoreQrScannerScreen extends StatefulWidget {
  const StoreQrScannerScreen({super.key});

  @override
  State<StoreQrScannerScreen> createState() => _StoreQrScannerScreenState();
}

class _StoreQrScannerScreenState extends State<StoreQrScannerScreen> {
  bool _checkingPlugin = true;
  bool _scannerAvailable = false;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _checkScannerAvailability();
  }

  Future<void> _checkScannerAvailability() async {
    try {
      const channel =
          MethodChannel('dev.steenbakker.mobile_scanner/scanner/method');
      await channel.invokeMethod<Object?>('state');
      if (!mounted) return;
      setState(() {
        _scannerAvailable = true;
        _checkingPlugin = false;
      });
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _scannerAvailable = false;
        _checkingPlugin = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _scannerAvailable = true;
        _checkingPlugin = false;
      });
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_hasScanned) return;
    final value = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (value.isEmpty) return;
    _hasScanned = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _checkingPlugin
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : _scannerAvailable
              ? _buildScanner()
              : const _ScannerUnavailable(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          onDetect: _handleDetection,
          errorBuilder: (context, error) {
            return _ScannerUnavailable(message: error.errorDetails?.message);
          },
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 36,
          child: Text(
            'Point your camera at a QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerUnavailable extends StatelessWidget {
  final String? message;

  const _ScannerUnavailable({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white70, size: 64),
            const SizedBox(height: 18),
            const Text(
              'QR scanner is not ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message?.trim().isNotEmpty == true
                  ? message!
                  : 'Please fully stop and rebuild the app once so the native scanner plugin can register.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      ),
    );
  }
}
