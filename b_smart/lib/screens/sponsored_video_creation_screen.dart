import 'package:flutter/material.dart';
import '../models/user_account_model.dart';
import '../services/user_account_service.dart';
import 'sponsored_video_form_screen.dart';
import 'account_upgrade_screen.dart';

class SponsoredVideoCreationScreen extends StatelessWidget {
  const SponsoredVideoCreationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountService = UserAccountService();
    final currentAccount = accountService.getCurrentAccount();

    // Check eligibility
    if (!currentAccount.isEligibleForSponsoredContent) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Sponsored Video'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Colors.grey,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Sponsored Video Creation Not Available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _getEligibilityMessage(currentAccount),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AccountUpgradeScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text('Upgrade Account'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // User is eligible - show creation form
    return const SponsoredVideoFormScreen();
  }

  String _getEligibilityMessage(UserAccount account) {
    if (account.accountType == AccountType.regular) {
      return 'You need a Creator or Business account to create sponsored videos.';
    }

    if (!account.adAccountVerified) {
      return 'Your ad account needs to be verified before you can create sponsored videos.';
    }

    if (account.accountType == AccountType.creator) {
      if (!account.emailVerified || !account.phoneVerified) {
        return 'Please verify your email and phone number to create sponsored videos.';
      }
      if (account.followers < 1000) {
        return 'You need at least 1,000 followers to create sponsored videos.';
      }
    }

    if (account.hasPolicyViolations) {
      return 'You have policy violations. Please resolve them before creating sponsored videos.';
    }

    return 'You are not eligible to create sponsored videos at this time.';
  }
}
