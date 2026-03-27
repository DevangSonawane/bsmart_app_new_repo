import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../api/api.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'color_picker_strip.dart';
import 'draggable_text_overlay.dart';
import 'instagram_text_result.dart';
import 'text_style_selector.dart';

class InstagramTextEditor extends StatefulWidget {
  final ImageProvider backgroundImage;
  final String? initialText;
  final String initialFont;
  final Color initialColor;
  final TextAlign initialAlignment;
  final BackgroundStyle initialBackgroundStyle;
  final double initialScale;
  final double initialRotation;
  final Offset? initialPosition;
  final double initialFontSize;

  const InstagramTextEditor({
    super.key,
    required this.backgroundImage,
    this.initialText,
    this.initialFont = 'Modern',
    this.initialColor = Colors.white,
    this.initialAlignment = TextAlign.center,
    this.initialBackgroundStyle = BackgroundStyle.none,
    this.initialScale = 1.0,
    this.initialRotation = 0.0,
    this.initialPosition,
    this.initialFontSize = 32.0,
  });

  static Future<InstagramTextResult?> open(
    BuildContext context, {
    required ImageProvider backgroundImage,
    String? initialText,
    String initialFont = 'Modern',
    Color initialColor = Colors.white,
    TextAlign initialAlignment = TextAlign.center,
    BackgroundStyle initialBackgroundStyle = BackgroundStyle.none,
    double initialScale = 1.0,
    double initialRotation = 0.0,
    Offset? initialPosition,
    double initialFontSize = 32.0,
  }) {
    return Navigator.of(context).push<InstagramTextResult>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, __, ___) => InstagramTextEditor(
          backgroundImage: backgroundImage,
          initialText: initialText,
          initialFont: initialFont,
          initialColor: initialColor,
          initialAlignment: initialAlignment,
          initialBackgroundStyle: initialBackgroundStyle,
          initialScale: initialScale,
          initialRotation: initialRotation,
          initialPosition: initialPosition,
          initialFontSize: initialFontSize,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.98, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<InstagramTextEditor> createState() => _InstagramTextEditorState();
}

class _InstagramTextEditorState extends State<InstagramTextEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  ImageStream? _bgStream;
  ImageStreamListener? _bgListener;
  Size? _bgImageSize;
  Rect _imageRect = Rect.zero;

  final List<String> _fontOptions = const [
    'Modern',
    'Classic',
    'Signature',
    'Neon',
    'Contour',
  ];

  final List<Color> _presetColors = const [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF32D74B),
    Color(0xFF5AC8FA),
    Color(0xFF0A84FF),
    Color(0xFF5856D6),
    Color(0xFFAF52DE),
    Color(0xFFFF2D55),
    Color(0xFFB7FF6B),
    Color(0xFF7DFFEE),
    Color(0xFFFF6B8A),
    Color(0xFFFFD166),
    Color(0xFFA3A3FF),
    // Greyscale set (last page)
    Color(0xFFFFFFFF),
    Color(0xFFF2F2F2),
    Color(0xFFE0E0E0),
    Color(0xFFCCCCCC),
    Color(0xFFB0B0B0),
    Color(0xFF8E8E93),
    Color(0xFF636366),
    Color(0xFF3A3A3C),
    Color(0xFF1C1C1E),
    Color(0xFF000000),
  ];

  late String _selectedFont;
  late TextAlign _alignment;
  late Color _textColor;
  late BackgroundStyle _backgroundStyle;
  bool _showColorStrip = false;
  bool _showFontSelector = true;
  late double _fontSizeValue;

  late Offset _textPosition;
  late double _scale;
  late double _rotation;
  Offset? _pendingInitialPosition;

  Offset _dragStart = Offset.zero;
  double _scaleStart = 1.0;
  double _rotationStart = 0.0;
  bool _positionInitialized = false;
  Size _editorSize = Size.zero;
  bool _showMentionStrip = false;
  bool _mentionLoading = false;
  int? _activeMentionStart;
  String _mentionQuery = '';
  List<Map<String, dynamic>> _mentionResults = [];
  final List<Map<String, String>> _selectedMentions = [];
  Timer? _mentionDebounce;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText ?? '';
    _controller.addListener(_handleTextChange);
    _selectedFont = widget.initialFont;
    _alignment = widget.initialAlignment;
    _textColor = widget.initialColor;
    _backgroundStyle = widget.initialBackgroundStyle;
    _scale = widget.initialScale;
    _rotation = widget.initialRotation;
    if (widget.initialPosition != null) {
      _pendingInitialPosition = widget.initialPosition;
      _textPosition = const Offset(0, 0);
      _positionInitialized = false;
    } else {
      _textPosition = const Offset(0, 0);
      _positionInitialized = false;
    }
    _fontSizeValue = widget.initialFontSize;
    _resolveBackgroundSize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    if (_bgStream != null && _bgListener != null) {
      _bgStream!.removeListener(_bgListener!);
    }
    _mentionDebounce?.cancel();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final selection = _controller.selection;
    if (!selection.isValid) {
      _hideMentions();
      return;
    }
    final cursor = selection.baseOffset;
    if (cursor < 0) {
      _hideMentions();
      return;
    }
    final text = _controller.text;
    final start = _findMentionStart(text, cursor);
    if (start == null) {
      _hideMentions();
      return;
    }
    final query = text.substring(start + 1, cursor);
    _activeMentionStart = start;
    _mentionQuery = query;
    setState(() {
      _showMentionStrip = true;
      _showFontSelector = false;
    });
    _debouncedMentionSearch(query);
  }

  int? _findMentionStart(String text, int cursor) {
    if (cursor == 0) return null;
    for (int i = cursor - 1; i >= 0; i--) {
      final ch = text[i];
      if (ch == '@') return i;
      if (ch == ' ' || ch == '\n' || ch == '\t') return null;
    }
    return null;
  }

  void _hideMentions() {
    if (_showMentionStrip) {
      setState(() => _showMentionStrip = false);
    }
    _activeMentionStart = null;
    _mentionQuery = '';
  }

  void _debouncedMentionSearch(String query) {
    _mentionDebounce?.cancel();
    _mentionDebounce = Timer(const Duration(milliseconds: 200), () {
      _loadMentionResults(query);
    });
  }

  Future<void> _loadMentionResults(String query) async {
    setState(() => _mentionLoading = true);
    try {
      final results = await UsersApi().search(query);
      if (!mounted) return;
      setState(() {
        _mentionResults = results;
        _mentionLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mentionResults = [];
        _mentionLoading = false;
      });
    }
  }

  void _insertMention(String userId, String username) {
    final selection = _controller.selection;
    if (_activeMentionStart == null || !selection.isValid) return;
    final start = _activeMentionStart!;
    final end = selection.baseOffset;
    final text = _controller.text;
    final replacement = '@$username ';
    final newText = text.replaceRange(start, end, replacement);
    final newCursor = start + replacement.length;
    _controller.value = _controller.value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    final exists = _selectedMentions.any((m) => m['user_id'] == userId);
    if (!exists) {
      _selectedMentions.add({
        'user_id': userId,
        'username': username,
      });
    }
    _hideMentions();
  }

  void _resolveBackgroundSize() {
    final stream = widget.backgroundImage.resolve(const ImageConfiguration());
    _bgStream = stream;
    _bgListener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted) {
        setState(() {
          _bgImageSize = size;
        });
      }
    });
    stream.addListener(_bgListener!);
  }

  void _toggleAlignment() {
    setState(() {
      if (_alignment == TextAlign.left) {
        _alignment = TextAlign.center;
      } else if (_alignment == TextAlign.center) {
        _alignment = TextAlign.right;
      } else {
        _alignment = TextAlign.left;
      }
      _showFontSelector = false;
      _showColorStrip = false;
    });
  }

  IconData _alignmentIcon() {
    switch (_alignment) {
      case TextAlign.left:
        return Icons.format_align_left;
      case TextAlign.right:
        return Icons.format_align_right;
      case TextAlign.center:
      default:
        return Icons.format_align_center;
    }
  }

  void _toggleBackgroundStyle() {
    setState(() {
      switch (_backgroundStyle) {
        case BackgroundStyle.none:
          _backgroundStyle = BackgroundStyle.solid;
          break;
        case BackgroundStyle.solid:
          _backgroundStyle = BackgroundStyle.transparent;
          break;
        case BackgroundStyle.transparent:
          _backgroundStyle = BackgroundStyle.perChar;
          break;
        case BackgroundStyle.perChar:
          _backgroundStyle = BackgroundStyle.none;
          break;
      }
      _showFontSelector = false;
      _showColorStrip = false;
    });
  }

  double _fontSize() => _fontSizeValue;

  TextStyle _baseTextStyle() {
    switch (_selectedFont) {
      case 'Classic':
        return GoogleFonts.playfairDisplay(
          fontSize: _fontSize(),
          fontWeight: FontWeight.w600,
        );
      case 'Signature':
        return GoogleFonts.dancingScript(
          fontSize: _fontSize() + 6,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
        );
      case 'Neon':
        return GoogleFonts.lato(
          fontSize: _fontSize(),
          fontWeight: FontWeight.bold,
        );
      case 'Contour':
        return GoogleFonts.lato(
          fontSize: _fontSize(),
          fontWeight: FontWeight.bold,
        );
      case 'Modern':
      default:
        return GoogleFonts.lato(
          fontSize: _fontSize(),
          fontWeight: FontWeight.bold,
        );
    }
  }

  TextStyle _outlinedStyle({required Color strokeColor, double width = 2}) {
    return _baseTextStyle().copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = strokeColor,
    );
  }

  Widget _buildStyledText() {
    final base = _baseTextStyle().copyWith(color: _textColor);
    final text = _controller.text;

    if (_selectedFont == 'Contour') {
      return Text(
        text,
        textAlign: _alignment,
        style: _outlinedStyle(strokeColor: _textColor),
      );
    }

    if (_selectedFont == 'Neon') {
      return Stack(
        children: [
          Text(
            text,
            textAlign: _alignment,
            style: _outlinedStyle(strokeColor: _textColor.withValues(alpha: 0.8), width: 4),
          ),
          Text(
            text,
            textAlign: _alignment,
            style: base.copyWith(
              shadows: [
                Shadow(color: _textColor, blurRadius: 14),
                Shadow(color: _textColor.withValues(alpha: 0.8), blurRadius: 24),
              ],
            ),
          ),
        ],
      );
    }

    return Text(text, textAlign: _alignment, style: base);
  }

  Widget _buildTextWithBackground() {
    final text = _controller.text;
    final baseStyle = _baseTextStyle().copyWith(color: _textColor);
    Widget content = _buildStyledText();
    final align = _alignment == TextAlign.left
        ? Alignment.centerLeft
        : _alignment == TextAlign.right
            ? Alignment.centerRight
            : Alignment.center;

    if (_backgroundStyle == BackgroundStyle.none) {
      return SizedBox(
        width: double.infinity,
        child: Align(
          alignment: align,
          child: content,
        ),
      );
    }

    if (_backgroundStyle == BackgroundStyle.perChar) {
      final spans = text.split('').map((ch) {
        return TextSpan(
          text: ch,
          style: baseStyle.copyWith(
            backgroundColor: _textColor.withValues(alpha: 0.2),
          ),
        );
      }).toList();
      return SizedBox(
        width: double.infinity,
        child: Align(
          alignment: align,
          child: Text.rich(
            TextSpan(children: spans),
            textAlign: _alignment,
          ),
        ),
      );
    }

    final bgColor = _backgroundStyle == BackgroundStyle.solid
        ? _textColor.withValues(alpha: 0.9)
        : _textColor.withValues(alpha: 0.35);
    final fgColor =
        _backgroundStyle == BackgroundStyle.solid ? Colors.black : _textColor;

    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: align,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle.merge(
            style: baseStyle.copyWith(color: fgColor),
            child: content,
          ),
        ),
      ),
    );
  }
  Widget _buildFramedBackground() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: Image(
          image: widget.backgroundImage,
          fit: BoxFit.contain,
          alignment: Alignment.center,
        ),
      ),
    );
  }

  Rect _computeImageRect(Size box) {
    final img = _bgImageSize;
    if (img == null || img.width == 0 || img.height == 0) {
      return Offset.zero & box;
    }
    final scale = math.min(box.width / img.width, box.height / img.height);
    final w = img.width * scale;
    final h = img.height * scale;
    final dx = (box.width - w) / 2;
    final dy = (box.height - h) / 2;
    return Rect.fromLTWH(dx, dy, w, h);
  }

  Size _measureEditorTextSize(double maxWidth) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: _controller.text,
        style: _baseTextStyle().copyWith(color: _textColor),
      ),
      textAlign: _alignment,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final base = textPainter.size;
    if (_backgroundStyle == BackgroundStyle.none ||
        _backgroundStyle == BackgroundStyle.perChar) {
      return base;
    }
    return Size(base.width + 20, base.height + 12);
  }

  Offset _clampToImageRect(Offset pos, double scale) {
    final rect = _imageRect;
    if (rect == Rect.zero) return pos;
    const maxWidth = 320.0;
    final textSize = _measureEditorTextSize(maxWidth);
    final scaled = Size(textSize.width * scale, textSize.height * scale);
    final minX = rect.left;
    final maxX = rect.right - scaled.width;
    final minY = rect.top;
    final maxY = rect.bottom - scaled.height;
    return Offset(
      pos.dx.clamp(minX, maxX),
      pos.dy.clamp(minY, maxY),
    );
  }

  void _openColorPicker() async {
    final picked = await ColorPickerStrip.openFullPicker(context, _textColor);
    if (picked != null && mounted) {
      setState(() {
        _textColor = picked;
      });
    }
  }

  void _onScaleStart(ScaleStartDetails details) {
    _dragStart = details.focalPoint;
    _scaleStart = _scale;
    _rotationStart = _rotation;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_scaleStart * details.scale).clamp(0.5, 4.0);
      _rotation = _normalizeRotation(_rotationStart + details.rotation);
      final next = _textPosition + (details.focalPoint - _dragStart);
      _textPosition = _clampToImageRect(next, _scale);
      _dragStart = details.focalPoint;
    });
  }

  double _normalizeRotation(double radians) {
    final degrees = vmath.degrees(radians);
    final normalized = ((degrees + 180) % 360) - 180;
    return vmath.radians(normalized);
  }

  void _handleDone() {
    final text = _controller.text.trim().isEmpty ? ' ' : _controller.text;
    final style = _baseTextStyle().copyWith(color: _textColor);
    final normalizedPosition = _normalizeToImageRect(_textPosition);
    final filteredMentions = _selectedMentions
        .where((m) => text.contains('@${m['username'] ?? ''}'))
        .toList(growable: false);
    Navigator.of(context).pop(
      InstagramTextResult(
        text: text,
        style: style,
        position: normalizedPosition,
        scale: _scale,
        rotation: _rotation,
        alignment: _alignment,
        textColor: _textColor,
        backgroundStyle: _backgroundStyle,
        fontName: _selectedFont,
        fontSize: _fontSizeValue,
        mentions: filteredMentions,
      ),
    );
  }

  Offset _normalizeToImageRect(Offset absolute) {
    if (_imageRect == Rect.zero ||
        _imageRect.width == 0 ||
        _imageRect.height == 0) {
      return absolute;
    }
    final dx = (absolute.dx - _imageRect.left) / _imageRect.width;
    final dy = (absolute.dy - _imageRect.top) / _imageRect.height;
    return Offset(
      dx.clamp(0.0, 1.0),
      dy.clamp(0.0, 1.0),
    );
  }

  Offset _resolveInitialPosition(Rect rect, Offset initial) {
    if (rect == Rect.zero) return initial;
    final isNormalized = initial.dx >= 0 &&
        initial.dx <= 1 &&
        initial.dy >= 0 &&
        initial.dy <= 1;
    final offset = isNormalized
        ? Offset(initial.dx * rect.width, initial.dy * rect.height)
        : initial;
    return rect.topLeft + offset;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
            _editorSize = constraints.biggest;
            _imageRect = _computeImageRect(_editorSize);
            if (_pendingInitialPosition != null) {
              _textPosition = _clampToImageRect(
                _resolveInitialPosition(_imageRect, _pendingInitialPosition!),
                _scale,
              );
              _pendingInitialPosition = null;
              _positionInitialized = true;
            } else if (!_positionInitialized) {
              const maxTextWidth = 320.0;
              final startX =
                  _imageRect.left + (_imageRect.width - maxTextWidth) / 2;
              final startY = _imageRect.top + (_imageRect.height * 0.2);
              _textPosition = _clampToImageRect(
                Offset(startX.isFinite && startX > 0 ? startX : 16, startY),
                _scale,
              );
              _positionInitialized = true;
            }
            _textPosition = _clampToImageRect(_textPosition, _scale);

            return Stack(
              children: [
                _buildFramedBackground(),
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _focusNode.requestFocus(),
                    child: const SizedBox.shrink(),
                  ),
                ),
                Positioned.fromRect(
                  rect: _imageRect,
                  child: ClipRect(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        DraggableTextOverlay(
                          position: _imageRect == Rect.zero
                              ? _textPosition
                              : _textPosition - _imageRect.topLeft,
                          scale: _scale,
                          rotation: _rotation,
                          onScaleStart: _onScaleStart,
                          onScaleUpdate: _onScaleUpdate,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildTextWithBackground(),
                                Opacity(
                                  opacity: 0.02,
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      autofocus: true,
                                      textAlign: _alignment,
                                      style: _baseTextStyle().copyWith(
                                        color: Colors.transparent,
                                      ),
                                      cursorColor: _textColor,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      enableInteractiveSelection: false,
                                      scrollPhysics: const NeverScrollableScrollPhysics(),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: '',
                                      ),
                                      onChanged: (_) {
                                        _handleTextChange();
                                        setState(() {
                                          _textPosition = _clampToImageRect(
                                              _textPosition, _scale);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: _handleDone,
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showColorStrip)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardInset + 90,
                    child: Center(
                      child: ColorPickerStrip(
                        colors: _presetColors,
                        selected: _textColor,
                        onChanged: (c) => setState(() => _textColor = c),
                        onOpenFullPicker: _openColorPicker,
                      ),
                    ),
                  ),
                if (_showMentionStrip)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardInset + (_showColorStrip ? 140 : 96),
                    child: SizedBox(
                      height: 86,
                      child: _mentionLoading
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                            )
                              : _mentionResults.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No suggestions',
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _mentionResults.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                                  itemBuilder: (context, index) {
                                    final user = _mentionResults[index];
                                    final username = (user['username'] as String?) ?? '';
                                    final userId =
                                        (user['id'] as String?) ?? (user['_id'] as String?) ?? '';
                                    final avatarUrl = user['avatar_url'] as String?;
                                    return GestureDetector(
                                      onTap: username.isEmpty || userId.isEmpty
                                          ? null
                                          : () => _insertMention(userId, username),
                                      child: SizedBox(
                                        width: 70,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircleAvatar(
                                              radius: 24,
                                              backgroundColor: Colors.white24,
                                              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                                                  ? NetworkImage(avatarUrl)
                                                  : null,
                                              child: avatarUrl == null || avatarUrl.isEmpty
                                                  ? Text(
                                                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                                                      style: const TextStyle(color: Colors.white, fontSize: 18),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              username.isEmpty ? 'user' : username,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                if (_showFontSelector && !_showMentionStrip)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: keyboardInset + 80,
                    child: Center(
                      child: TextStyleSelector(
                        options: _fontOptions,
                        selected: _selectedFont,
                        onChanged: (v) {
                          setState(() => _selectedFont = v);
                        },
                      ),
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboardInset + 16,
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A).withValues(alpha: 0.82),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ToolbarIcon(
                                label: 'Aa',
                                onTap: () {
                                  setState(() {
                                    _showFontSelector = !_showFontSelector;
                                    _showColorStrip = false;
                                  });
                                },
                                isActive: _showFontSelector,
                              ),
                              const SizedBox(width: 30),
                              _ToolbarIcon(
                                icon: Icons.color_lens_outlined,
                                onTap: () {
                                  setState(() {
                                    _showColorStrip = !_showColorStrip;
                                    _showFontSelector = false;
                                  });
                                },
                                useColorWheel: true,
                                isActive: _showColorStrip,
                              ),
                              const SizedBox(width: 30),
                              _ToolbarIcon(
                                icon: _alignmentIcon(),
                                onTap: _toggleAlignment,
                                isActive: _alignment != TextAlign.center,
                              ),
                              const SizedBox(width: 30),
                              _ToolbarIcon(
                                label: '[A]',
                                onTap: _toggleBackgroundStyle,
                                isActive: _backgroundStyle != BackgroundStyle.none,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 120,
                  child: SizedBox(
                    height: 180,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: SliderTheme(
                        data: const SliderThemeData(
                          trackHeight: 4,
                          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                          overlayShape: RoundSliderOverlayShape(overlayRadius: 0),
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _fontSizeValue.clamp(18.0, 64.0),
                          min: 18,
                          max: 64,
                          onChanged: (v) => setState(() => _fontSizeValue = v),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final VoidCallback onTap;
  final Color? color;
  final bool useColorWheel;
  final bool isActive;

  const _ToolbarIcon({
    required this.onTap,
    this.icon,
    this.label,
    this.color,
    this.isActive = false,
    this.useColorWheel = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: useColorWheel
                ? Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.yellow,
                          Colors.green,
                          Colors.cyan,
                          Colors.blue,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  )
                : icon != null
                    ? Icon(icon, color: color ?? Colors.white, size: 20)
                    : Text(
                        label ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}

class InstagramTextEditorBackground {
  final ImageProvider imageProvider;

  const InstagramTextEditorBackground._(this.imageProvider);

  factory InstagramTextEditorBackground.file(File file) {
    return InstagramTextEditorBackground._(FileImage(file));
  }

  factory InstagramTextEditorBackground.network(String url) {
    return InstagramTextEditorBackground._(NetworkImage(url));
  }
}
