import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  int _selectedTab = 0; // 0=All, 1=Unread, 2=Community

  final List<Map<String, dynamic>> _mockChats = [
    {
      'name': 'Aarav Mehta',
      'message': 'Can you send the catalog?',
      'time': '2:14 PM',
      'unread': 2,
      'isCommunity': false,
    },
    {
      'name': 'B-Smart Community',
      'message': 'Welcome to the weekly drops!',
      'time': '1:03 PM',
      'unread': 5,
      'isCommunity': true,
    },
    {
      'name': 'Isha Kapoor',
      'message': 'Thanks! I placed the order.',
      'time': '11:47 AM',
      'unread': 0,
      'isCommunity': false,
    },
    {
      'name': 'Vendor Circle',
      'message': 'New promo guidelines are live.',
      'time': '10:21 AM',
      'unread': 1,
      'isCommunity': true,
    },
    {
      'name': 'Rahul Singh',
      'message': 'Let’s connect tomorrow.',
      'time': 'Yesterday',
      'unread': 0,
      'isCommunity': false,
    },
    {
      'name': 'Local Deals',
      'message': 'Flash sale starts at 6 PM!',
      'time': 'Yesterday',
      'unread': 3,
      'isCommunity': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messaging'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTopTabs(context),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _filteredChats().length,
              itemBuilder: (context, index) {
                final chat = _filteredChats()[index];
                return _chatTile(chat);
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _filteredChats() {
    if (_selectedTab == 1) {
      return _mockChats.where((c) => (c['unread'] as int) > 0).toList();
    }
    if (_selectedTab == 2) {
      return _mockChats.where((c) => c['isCommunity'] == true).toList();
    }
    return _mockChats;
  }

  Widget _buildTopTabs(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _tabButton(context, label: 'All', index: 0),
            _tabButton(context, label: 'Unread', index: 1),
            _tabButton(context, label: 'Community', index: 2),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(
    BuildContext context, {
    required String label,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
          color: isSelected ? DesignTokens.instaPink : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chatTile(Map<String, dynamic> chat) {
    final unread = chat['unread'] as int;
    final isCommunity = chat['isCommunity'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isCommunity
                      ? DesignTokens.instaOrange
                      : DesignTokens.instaPink,
                  child: Text(
                    (chat['name'] as String).characters.first,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        chat['message'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color ??
                                  Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat['time'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).textTheme.bodySmall?.color ??
                                Colors.grey,
                      ),
                    ),
                    if (unread > 0) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: DesignTokens.instaPink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unread.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
