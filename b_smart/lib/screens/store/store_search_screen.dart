import 'package:flutter/material.dart';

import 'store_theme.dart';

class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({super.key});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  late final TextEditingController _controller;
  bool _loadedInitialQuery = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedInitialQuery) return;
    _loadedInitialQuery = true;
    final initial = ModalRoute.of(context)?.settings.arguments;
    if (initial is String) {
      _controller.text = initial;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StorePalette.paleBlue,
      appBar: AppBar(
        title: const Text('Search Store'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              cursorColor: StorePalette.blue,
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Search products',
                hintStyle: const TextStyle(color: Colors.black54),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  onPressed: _controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                hoverColor: Colors.white,
                focusColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: StorePalette.blue),
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Search results will appear here',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
