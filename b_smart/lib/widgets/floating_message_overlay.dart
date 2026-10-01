import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../services/chat_unread_service.dart';
import '../services/ui_prefs.dart';
import 'draggable_floating_bubble.dart';

/// Draggable messenger bubble shown over the home and wallet screens.
///
/// Drag it anywhere; drop it on the trash zone to hide it. The position and the
/// hidden state persist across restarts. Re-enable it from Settings >
/// Messaging > Floating Messages.
class FloatingMessageOverlay extends StatefulWidget {
  final VoidCallback? onTap;
  final bool enabled;

  const FloatingMessageOverlay({
    super.key,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<FloatingMessageOverlay> createState() => _FloatingMessageOverlayState();
}

class _FloatingMessageOverlayState extends State<FloatingMessageOverlay> {
  @override
  void initState() {
    super.initState();
    ChatUnreadService().startPolling();
  }

  @override
  void dispose() {
    ChatUnreadService().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DraggableFloatingBubble(
      visible: UiPrefs.showFloatingMessage,
      persistenceKey: 'floating_message',
      onTap: widget.onTap,
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.white,
      foregroundColor: isDark ? Colors.white : const Color(0xFF111827),
      icon: const Icon(LucideIcons.messageCircle),
      badge: ValueListenableBuilder<bool>(
        valueListenable: ChatUnreadService().hasUnread,
        builder: (context, hasUnread, _) {
          if (!hasUnread) return const SizedBox.shrink();
          return Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF111827) : Colors.white,
                  width: 2,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}