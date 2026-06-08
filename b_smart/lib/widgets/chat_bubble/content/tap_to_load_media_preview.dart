import 'package:flutter/material.dart';

class TapToLoadMediaPreview extends StatefulWidget {
  final Widget loadedChild;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool initiallyLoaded;

  const TapToLoadMediaPreview({
    super.key,
    required this.loadedChild,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.initiallyLoaded = false,
  });

  @override
  State<TapToLoadMediaPreview> createState() => _TapToLoadMediaPreviewState();
}

class _TapToLoadMediaPreviewState extends State<TapToLoadMediaPreview> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loaded = widget.initiallyLoaded;
  }

  @override
  void didUpdateWidget(covariant TapToLoadMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initiallyLoaded != widget.initiallyLoaded &&
        widget.initiallyLoaded) {
      _loaded = true;
    }
  }

  void _reveal() {
    if (_loaded) return;
    setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.loadedChild;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
      child: InkWell(
        onTap: _reveal,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap to load',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
