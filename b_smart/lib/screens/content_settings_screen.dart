import 'package:flutter/material.dart';
import '../services/content_moderation_service.dart';
import '../theme/instagram_theme.dart';
import 'auth/login/login_screen.dart';

class ContentSettingsScreen extends StatefulWidget {
  const ContentSettingsScreen({super.key});

  @override
  State<ContentSettingsScreen> createState() => _ContentSettingsScreenState();
}

class _ContentSettingsScreenState extends State<ContentSettingsScreen> {
  final ContentModerationService _moderationService = ContentModerationService();
  final String _currentUserId = 'user-1';
  
  bool _showRestrictedContent = false;
  int _userAge = 18; // Default age

  @override
  void initState() {
    super.initState();
    _loadUserSettings();
  }

  void _loadUserSettings() {
    // In real app, load from user preferences
    setState(() {
      _userAge = 18;
      _showRestrictedContent = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strikeRecord = _moderationService.getUserStrikes(_currentUserId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        foregroundColor: InstagramTheme.textBlack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (strikeRecord != null && strikeRecord.policyStrikes > 0) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: strikeRecord.policyStrikes >= 3
                                ? Colors.red
                                : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Policy Violations: ${strikeRecord.policyStrikes}',
                              style: TextStyle(
                                color: strikeRecord.policyStrikes >= 3
                                    ? Colors.red
                                    : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (strikeRecord.isSuspended)
                        const Text(
                          'Your account is suspended due to policy violations.',
                          style: TextStyle(color: Colors.red),
                        )
                      else if (strikeRecord.isRestricted)
                        const Text(
                          'Your posting is restricted due to policy violations.',
                          style: TextStyle(color: Colors.orange),
                        )
                      else
                        Text(
                          '${3 - strikeRecord.policyStrikes} strikes remaining before restrictions.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ] else
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            'No policy violations',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Content Preferences
            const Text(
              'Content Preferences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Age Setting
            Card(
              child: ListTile(
                title: const Text('Your Age'),
                subtitle: Text('$_userAge years old'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set Your Age'),
                      content: StatefulBuilder(
                        builder: (context, setState) {
                          int tempAge = _userAge;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Age: $tempAge'),
                              Slider(
                                value: tempAge.toDouble(),
                                min: 13,
                                max: 100,
                                divisions: 87,
                                label: '$tempAge',
                                onChanged: (value) {
                                  setState(() {
                                    tempAge = value.toInt();
                                  });
                                },
                              ),
                            ],
                          );
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _userAge = 18; // Would update from dialog
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Show Restricted Content
            Card(
              child: SwitchListTile(
                title: const Text('Show Restricted Content'),
                subtitle: const Text(
                  'Allow sexualized content (18+ only)',
                  style: TextStyle(fontSize: 12),
                ),
                value: _showRestrictedContent,
                onChanged: (value) {
                  if (_userAge < 18) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('You must be 18+ to view restricted content'),
                      ),
                    );
                    return;
                  }
                  setState(() {
                    _showRestrictedContent = value;
                  });
                },
              ),
            ),

            const SizedBox(height: 24),

            // App Settings
            const Text(
              'App Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Language & Region
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: const Text('Language'),
                    subtitle: const Text('English (Default)'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showLanguageDialog();
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.place),
                    title: const Text('Region / Address'),
                    subtitle: const Text('Set your location'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      _showAddressDialog();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Account Actions
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Logout Logic
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: InstagramTheme.surfaceWhite,
                  foregroundColor: InstagramTheme.textBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: InstagramTheme.dividerGrey),
                  ),
                ),
                child: const Text('Log Out'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  _showDeleteAccountDialog();
                },
                child: const Text(
                  'Delete Account',
                  style: TextStyle(color: InstagramTheme.errorRed),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            ListTile(title: Text('English (Default)'), trailing: Icon(Icons.check, color: InstagramTheme.primaryPink)),
            ListTile(title: Text('Spanish')),
            ListTile(title: Text('French')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddressDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Street Address'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(labelText: 'Postal Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Address updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: InstagramTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
