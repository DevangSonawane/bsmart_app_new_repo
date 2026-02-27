import 'package:flutter/material.dart';
import '../models/user_account_model.dart';
import '../services/user_account_service.dart';
import '../theme/instagram_theme.dart';

class AccountUpgradeScreen extends StatelessWidget {
  const AccountUpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountService = UserAccountService();
    final currentAccount = accountService.getCurrentAccount();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Upgrade Account'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account Types',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Current Account Status
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Current Account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Type: ${_getAccountTypeLabel(currentAccount.accountType)}'),
                    Text('Followers: ${currentAccount.followers}'),
                    Text('Email Verified: ${currentAccount.emailVerified ? 'Yes' : 'No'}'),
                    Text('Phone Verified: ${currentAccount.phoneVerified ? 'Yes' : 'No'}'),
                    if (currentAccount.hasPolicyViolations)
                      const Text(
                        '⚠️ Policy Violations Detected',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Creator Account
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.blue, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Creator Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Requirements:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementItem('Verified email & phone', currentAccount.emailVerified && currentAccount.phoneVerified),
                    _buildRequirementItem('Minimum 1,000 followers', currentAccount.followers >= 1000),
                    _buildRequirementItem('No policy violations', !currentAccount.hasPolicyViolations),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        final success = await accountService.upgradeToCreator(currentAccount.userId);
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account upgrade request submitted. Awaiting approval.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot upgrade. Please check requirements.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Apply for Creator Account'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Business Account
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Business Account',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Requirements:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildRequirementItem('Payment method verified', currentAccount.paymentVerified),
                    _buildRequirementItem('Business verification', false),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        if (!currentAccount.paymentVerified) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please add and verify a payment method first'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        final success = await accountService.upgradeToBusiness(currentAccount.userId);
                        if (context.mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account upgraded to Business. Full access granted.'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Cannot upgrade. Please verify payment method.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Upgrade to Business Account'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isMet ? Colors.green : Colors.grey[600],
                decoration: isMet ? null : TextDecoration.lineThrough,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAccountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.regular:
        return 'Regular';
      case AccountType.creator:
        return 'Creator';
      case AccountType.business:
        return 'Business';
    }
  }
}
