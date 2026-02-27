import 'package:flutter/material.dart';

class MediaPickerScreen extends StatefulWidget {
  const MediaPickerScreen({super.key});

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  final List<ImageProvider> _items = List.generate(
    50,
    (i) => NetworkImage('https://picsum.photos/seed/$i/200/200'),
  );
  final Set<int> _selected = {};
  final List<int> _selectedOrder = [];
  bool _multiSelect = false;

  void _toggleSelect(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
        _selectedOrder.remove(index);
      } else {
        if (_selected.length >= 10) {
          final removed = _selectedOrder.isNotEmpty ? _selectedOrder.removeAt(0) : null;
          if (removed != null) {
            _selected.remove(removed);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You can only select up to 10 photos or videos')),
          );
        }
        _selected.add(index);
        _selectedOrder.add(index);
      }
    });
  }

  void _confirm() {
    final List<ImageProvider> result = _selected.isEmpty
        ? <ImageProvider>[]
        : _selected.map((i) => _items[i]).toList();
    Navigator.of(context).pop<List<ImageProvider>>(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop<List<ImageProvider>>(<ImageProvider>[]),
        ),
        title: Text(_multiSelect ? 'Select Multiple' : 'Recent'),
        actions: [
          TextButton(
            onPressed: _selected.isEmpty ? null : _confirm,
            child: const Text('Next'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 12),
                _tab('Recent'),
                _tab('Camera'),
                _tab('Videos'),
                _tab('Gallery Albums'),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(4),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final img = _items[index];
                final selected = _selected.contains(index);
                final badge = selected ? _selectedOrder.indexOf(index) + 1 : null;
                return GestureDetector(
                  onTap: () {
                    if (_multiSelect) {
                      _toggleSelect(index);
                    } else {
                      Navigator.of(context).pop<List<ImageProvider>>([img]);
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      _multiSelect = true;
                    });
                    _toggleSelect(index);
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image(image: img, fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: selected ? Colors.blue : Colors.white70,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              selected ? '$badge' : '',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text('${_selected.length} selected'),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty ? null : _confirm,
                    child: const Text('Add to Story'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(label),
    );
  }
}
