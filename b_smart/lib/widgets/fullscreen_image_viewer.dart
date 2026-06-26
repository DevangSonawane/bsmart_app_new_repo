import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

Future<void> showFullscreenImageViewer(
  BuildContext context, {
  required String imageUrl,
  Map<String, String>? httpHeaders,
}) {
  return showDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    barrierColor: Colors.black,
    builder: (dialogContext) {
      return Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      httpHeaders: httpHeaders,
                      fit: BoxFit.contain,
                      placeholder: (context, _) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, _, __) => const Icon(
                        Icons.broken_image,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(dialogContext).maybePop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
