import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

Future<void> applyAndroidEdgeToEdge() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
  }
}

@Deprecated('Use applyAndroidEdgeToEdge() instead.')
Future<void> applyAndroidImmersiveSticky() async {
  await applyAndroidEdgeToEdge();
}
