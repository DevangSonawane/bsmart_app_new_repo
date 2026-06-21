import 'package:flutter/material.dart';

import '../utils/app_navigator.dart';

class UploadProgressOverlay {
  static OverlayEntry? _entry;
  static final ValueNotifier<double?> _progress = ValueNotifier<double?>(0.0);
  static final ValueNotifier<String> _message =
      ValueNotifier<String>('Uploading...');
  static bool _visible = false;

  static void show({
    required String message,
    double? progress,
  }) {
    _message.value = message;
    _progress.value = progress;

    if (_visible) {
      _entry?.markNeedsBuild();
      return;
    }

    final overlay = AppNavigator.state?.overlay;
    if (overlay == null) return;

    _entry = OverlayEntry(
      builder: (context) {
        return ValueListenableBuilder<String>(
          valueListenable: _message,
          builder: (context, messageValue, _) {
            return ValueListenableBuilder<double?>(
              valueListenable: _progress,
              builder: (context, progressValue, __) {
                final isIndeterminate = progressValue == null;
                final value = progressValue?.clamp(0.0, 1.0);
                return Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: IgnorePointer(
                    child: Material(
                      color: Colors.transparent,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 160),
                        opacity: 1,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 24,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF0095F6),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      messageValue,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (!isIndeterminate && value != null)
                                    Text(
                                      '${(value * 100).round()}%',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  minHeight: 6,
                                  value: isIndeterminate ? null : value,
                                  backgroundColor: Colors.white12,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    Color(0xFF0095F6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );

    _visible = true;
    overlay.insert(_entry!);
  }

  static void update({
    String? message,
    double? progress,
  }) {
    if (!_visible) return;
    if (message != null) _message.value = message;
    _progress.value = progress;
    _entry?.markNeedsBuild();
  }

  static Future<void> hide() async {
    if (!_visible) return;
    _visible = false;
    _progress.value = 0.0;
    _message.value = 'Uploading...';
    _entry?.remove();
    _entry = null;
  }
}
