import 'package:flutter/material.dart';

class ReelAudioPickerScreen extends StatefulWidget {
  final String? initialAudioPath;
  final double initialVolume;
  final ValueChanged<({String path, double volume})> onSelect;

  const ReelAudioPickerScreen({
    super.key,
    this.initialAudioPath,
    this.initialVolume = 1.0,
    required this.onSelect,
  });

  @override
  State<ReelAudioPickerScreen> createState() => _ReelAudioPickerScreenState();
}

class _ReelAudioPickerScreenState extends State<ReelAudioPickerScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  final List<_AudioTrack> _tracks = const [
    _AudioTrack(id: 'track_1', title: 'Golden Hour', artist: 'Luna', duration: '0:32'),
    _AudioTrack(id: 'track_2', title: 'Night Drive', artist: 'Echoes', duration: '0:28'),
    _AudioTrack(id: 'track_3', title: 'Soft Breeze', artist: 'Mellow', duration: '0:45'),
    _AudioTrack(id: 'track_4', title: 'Pulse', artist: 'Nova', duration: '0:18'),
    _AudioTrack(id: 'track_5', title: 'Cinematic Rise', artist: 'Orion', duration: '0:52'),
    _AudioTrack(id: 'track_6', title: 'Calm Waters', artist: 'Aster', duration: '0:36'),
    _AudioTrack(id: 'track_7', title: 'Upbeat Pop', artist: 'Vibe', duration: '0:25'),
    _AudioTrack(id: 'track_8', title: 'Ambient Glow', artist: 'Nox', duration: '0:40'),
  ];
  String _activeGenre = 'All';
  _AudioTrack? _selected;
  double _volume = 80;

  @override
  void initState() {
    super.initState();
    _volume = (widget.initialVolume * 100).clamp(0, 100);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text('Music'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildChip('All'),
                _buildChip('Trending'),
                _buildChip('Calm'),
                _buildChip('Upbeat'),
                _buildChip('Cinematic'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _tracks.length,
              itemBuilder: (context, index) {
                final t = _tracks[index];
                final isSelected = _selected?.id == t.id;
                return GestureDetector(
                  onTap: () => setState(() => _selected = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: isSelected ? const Color(0xFF0095F6) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title, style: const TextStyle(color: Colors.white)),
                              Text(t.artist, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text(t.duration, style: const TextStyle(color: Colors.white54)),
                        const SizedBox(width: 12),
                        Icon(Icons.play_arrow, color: isSelected ? Colors.white : Colors.white54),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: _selected == null ? 0 : 120,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: _selected == null
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selected!.title,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            height: 40,
                            width: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _volume,
                        min: 0,
                        max: 100,
                        activeColor: const Color(0xFF0095F6),
                        onChanged: (v) => setState(() => _volume = v),
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _selected = null),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              final sel = _selected;
                              if (sel == null) return;
                              widget.onSelect((path: sel.id, volume: _volume / 100.0));
                              Navigator.of(context).pop();
                            },
                            child: const Text('Use this track →', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _activeGenre == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _activeGenre = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.grey[800],
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String duration;

  const _AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
  });
}
