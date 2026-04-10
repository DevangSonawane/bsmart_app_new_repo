import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ExternalLinkScreen extends StatefulWidget {
  final String url;
  final String title;

  const ExternalLinkScreen({
    super.key,
    required this.url,
    this.title = 'Link',
  });

  @override
  State<ExternalLinkScreen> createState() => _ExternalLinkScreenState();
}

class _ExternalLinkScreenState extends State<ExternalLinkScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = value.clamp(0, 100));
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() => _failed = true);
          },
        ),
      );

    final uri = Uri.tryParse(widget.url.trim());
    if (uri == null) {
      _failed = true;
      return;
    }
    _controller.loadRequest(uri);
  }

  @override
  Widget build(BuildContext context) {
    final safeTitle = widget.title.trim().isEmpty ? 'Link' : widget.title.trim();
    return Scaffold(
      appBar: AppBar(
        title: Text(safeTitle),
        actions: [
          IconButton(
            onPressed: _failed ? null : () => _controller.reload(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 100 && !_failed)
            LinearProgressIndicator(value: _progress / 100.0),
          Expanded(
            child: _failed
                ? const Center(child: Text('Failed to load link'))
                : WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

