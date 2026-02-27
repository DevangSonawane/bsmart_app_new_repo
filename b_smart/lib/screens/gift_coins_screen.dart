import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../utils/current_user.dart';
import '../services/wallet_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../models/notification_model.dart';
import '../theme/instagram_theme.dart';

class GiftCoinsScreen extends StatefulWidget {
  const GiftCoinsScreen({super.key});

  @override
  State<GiftCoinsScreen> createState() => _GiftCoinsScreenState();
}

class _GiftCoinsScreenState extends State<GiftCoinsScreen> {
  final WalletService _walletService = WalletService();
  final NotificationService _notificationService = NotificationService();
  final SupabaseService _svc = SupabaseService();

  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _selectedUser;
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  int _currentBalance = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _loadUsers() async {
    // Get list of users to gift (exclude current user)
    final myId = await CurrentUser.id;
    _svc.fetchUsers(excludeUserId: myId).then((list) {
      if (mounted) setState(() => _users = list);
    });
  }

  Future<void> _loadBalance() async {
    final balance = await _walletService.getCoinBalance();
    if (mounted) {
      setState(() {
        _currentBalance = balance;
      });
    }
  }

  Future<void> _sendGift() async {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a user'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

      final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!await _walletService.hasSufficientBalance(amount)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Gift'),
        content: Text(
          'Send $amount coins to ${_selectedUser!['full_name'] ?? _selectedUser!['username']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Send'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Send gift
      final success = await _walletService.sendGiftCoins(
        amount,
        _selectedUser!['id'] as String,
        _selectedUser!['full_name'] as String? ?? _selectedUser!['username'] as String,
      );

      if (success) {
        // Refresh balance
        await _loadBalance();

        // In real app, the server would:
        // 1. Deduct coins from sender
        // 2. Add coins to receiver
        // 3. Send notification to receiver
        
        // For demo: Show notification that gift was sent
        _notificationService.addNotification(
          NotificationItem(
            id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
            type: NotificationType.activity,
            title: 'Gift Sent',
            message: 'You sent $amount coins to ${_selectedUser!['full_name'] ?? _selectedUser!['username']}',
            timestamp: DateTime.now(),
            isRead: false,
          ),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully sent $amount coins to ${_selectedUser!['full_name'] ?? _selectedUser!['username']}'),
                backgroundColor: Colors.green,
              ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send gift. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gift Coins'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.pink.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.pink.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Balance',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$_currentBalance coins',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.pink,
                        ),
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.card_giftcard,
                    size: 48,
                    color: Colors.pink,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Select User
            const Text(
              'Select User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _users.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users available'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        final isSelected = _selectedUser?['id'] == user['id'];

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedUser = user;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.pink.shade50 : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.pink,
                                  child: Text(
                                    (user['full_name'] ?? user['username'] ?? '').toString().isNotEmpty
                                        ? (user['full_name'] ?? user['username'] ?? '').toString()[0].toUpperCase()
                                        : '',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    (user['full_name'] ?? user['username'] ?? '').toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.pink,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 24),

            // Enter Amount
            const Text(
              'Enter Amount',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter coins to gift',
                prefixIcon: const Icon(LucideIcons.coins),
                suffixText: 'coins',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 24),

            // Send Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendGift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Send Gift',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
