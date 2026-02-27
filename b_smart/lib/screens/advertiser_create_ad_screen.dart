import 'package:flutter/material.dart';
import '../models/advertiser_model.dart';
import '../services/advertiser_service.dart';
import 'advertiser_dashboard_screen.dart';

class AdvertiserCreateAdScreen extends StatefulWidget {
  const AdvertiserCreateAdScreen({super.key});

  @override
  State<AdvertiserCreateAdScreen> createState() => _AdvertiserCreateAdScreenState();
}

class _AdvertiserCreateAdScreenState extends State<AdvertiserCreateAdScreen> {
  final AdvertiserService _advertiserService = AdvertiserService();
  final PageController _pageController = PageController();
  
  int _currentStep = 0;
  AdCategory? _selectedCategory;
  String? _videoUrl;
  String? _bannerUrl;
  final _ctaTextController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyDescriptionController = TextEditingController();
  List<String> _targetLocations = [];
  List<String> _targetLanguages = [];
  List<String> _targetInterests = [];
  String? _targetAgeRange;
  String? _targetGender;
  bool _commentsDisabled = false;
  bool _likesDisabled = false;
  bool _sharingDisabled = false;
  bool _hideViewCount = false;
  final _budgetController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _locations = ['US', 'India', 'UK', 'Canada', 'Australia'];
  final List<String> _languages = ['en', 'hi', 'es', 'fr', 'de'];
  final List<String> _interests = ['technology', 'fashion', 'fitness', 'food', 'travel'];
  final List<String> _ageRanges = ['18-24', '25-34', '35-44', '45-54', '55+'];
  final List<String> _genders = ['Male', 'Female', 'Other', 'All'];

  @override
  void dispose() {
    _pageController.dispose();
    _ctaTextController.dispose();
    _companyNameController.dispose();
    _companyDescriptionController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 6) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _selectedCategory != null;
      case 1:
        return _videoUrl != null || _bannerUrl != null;
      case 2:
        return _companyNameController.text.isNotEmpty;
      case 3:
        return _targetLocations.isNotEmpty && _targetLanguages.isNotEmpty;
      case 4:
        return true; // Optional controls
      case 5:
        return _budgetController.text.isNotEmpty &&
            double.tryParse(_budgetController.text) != null &&
            double.parse(_budgetController.text) > 0;
      default:
        return true;
    }
  }

  Future<void> _submitAd() async {
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2) ||
        !_validateStep(3) || !_validateStep(5)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final budget = double.parse(_budgetController.text);
      await _advertiserService.createAd(
        advertiserId: 'advertiser-1',
        category: _selectedCategory!,
        companyName: _companyNameController.text,
        budgetRupees: budget,
        videoUrl: _videoUrl,
        bannerUrl: _bannerUrl,
        ctaText: _ctaTextController.text.isEmpty ? null : _ctaTextController.text,
        companyDescription: _companyDescriptionController.text.isEmpty
            ? null
            : _companyDescriptionController.text,
        targetLocations: _targetLocations,
        targetLanguages: _targetLanguages,
        targetInterests: _targetInterests,
        targetAgeRange: _targetAgeRange,
        targetGender: _targetGender,
        commentsDisabled: _commentsDisabled,
        likesDisabled: _likesDisabled,
        sharingDisabled: _sharingDisabled,
        hideViewCount: _hideViewCount,
      );

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ad Submitted'),
            content: const Text(
              'Your ad has been submitted for review. You will be notified once it\'s approved.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => const AdvertiserDashboardScreen(),
                    ),
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Ad'),
      ),
      body: Column(
        children: [
          // Step Indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Category'),
                _buildStepConnector(),
                _buildStepIndicator(1, 'Content'),
                _buildStepConnector(),
                _buildStepIndicator(2, 'Company'),
                _buildStepConnector(),
                _buildStepIndicator(3, 'Targeting'),
                _buildStepConnector(),
                _buildStepIndicator(4, 'Controls'),
                _buildStepConnector(),
                _buildStepIndicator(5, 'Budget'),
                _buildStepConnector(),
                _buildStepIndicator(6, 'Review'),
              ],
            ),
          ),

          // Form Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildCategoryStep(),
                _buildContentStep(),
                _buildCompanyStep(),
                _buildTargetingStep(),
                _buildControlsStep(),
                _buildBudgetStep(),
                _buildReviewStep(),
              ],
            ),
          ),

          // Navigation Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: _previousStep,
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(),
                if (_currentStep < 6)
                  ElevatedButton(
                    onPressed: _validateStep(_currentStep) ? _nextStep : null,
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitAd,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit for Review'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Expanded(
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted ? Colors.blue : Colors.grey[300],
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? Colors.blue : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      height: 2,
      width: 8,
      color: Colors.grey[300],
    );
  }

  Widget _buildCategoryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: Ad Category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select ad category. Duration is auto-locked based on category.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ...AdCategory.values.map((category) {
            final isSelected = _selectedCategory == category;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isSelected ? Colors.blue[50] : null,
              child: ListTile(
                title: Text(category.name.toUpperCase()),
                subtitle: Text('${category.durationSeconds} seconds'),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.blue)
                    : null,
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                  });
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildContentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2: Ad Content',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              setState(() {
                _videoUrl = 'https://example.com/video.mp4';
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Video uploaded (simulated)')),
              );
            },
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _videoUrl != null ? Colors.green : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: _videoUrl != null
                  ? const Icon(Icons.check_circle, size: 60, color: Colors.green)
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 60, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('Tap to upload video'),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctaTextController,
            decoration: const InputDecoration(
              labelText: 'CTA Text (Optional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3: Company Page Setup',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _companyNameController,
            decoration: const InputDecoration(
              labelText: 'Company Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _companyDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Company Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildTargetingStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 4: Targeting',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text('Location *'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _locations.map((location) {
              final isSelected = _targetLocations.contains(location);
              return FilterChip(
                label: Text(location),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _targetLocations.add(location);
                    } else {
                      _targetLocations.remove(location);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Language *'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languages.map((lang) {
              final isSelected = _targetLanguages.contains(lang);
              return FilterChip(
                label: Text(lang),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _targetLanguages.add(lang);
                    } else {
                      _targetLanguages.remove(lang);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Interests'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _interests.map((interest) {
              final isSelected = _targetInterests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _targetInterests.add(interest);
                    } else {
                      _targetInterests.remove(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _targetAgeRange,
            decoration: const InputDecoration(
              labelText: 'Age Range',
              border: OutlineInputBorder(),
            ),
            items: _ageRanges.map((range) {
              return DropdownMenuItem(
                value: range,
                child: Text(range),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _targetAgeRange = value;
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _targetGender,
            decoration: const InputDecoration(
              labelText: 'Gender (Optional)',
              border: OutlineInputBorder(),
            ),
            items: _genders.map((gender) {
              return DropdownMenuItem(
                value: gender,
                child: Text(gender),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _targetGender = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildControlsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 5: Optional Controls',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Disable Comments'),
            value: _commentsDisabled,
            onChanged: (value) {
              setState(() {
                _commentsDisabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Disable Likes'),
            value: _likesDisabled,
            onChanged: (value) {
              setState(() {
                _likesDisabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Disable Sharing'),
            value: _sharingDisabled,
            onChanged: (value) {
              setState(() {
                _sharingDisabled = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('Hide View Count'),
            value: _hideViewCount,
            onChanged: (value) {
              setState(() {
                _hideViewCount = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStep() {
    final advertiserService = AdvertiserService();
    int? coinsPreview;

    if (_budgetController.text.isNotEmpty) {
      final budget = double.tryParse(_budgetController.text);
      if (budget != null) {
        coinsPreview = advertiserService.rupeesToCoins(budget);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 6: Budget & Coins',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter amount in ₹. Conversion: ₹1 = 10 coins',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _budgetController,
            decoration: const InputDecoration(
              labelText: 'Budget (₹) *',
              prefixText: '₹',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              setState(() {});
            },
          ),
          if (coinsPreview != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Coins: ${coinsPreview.toString()}'),
                  Text('Estimated Rewards: ${(coinsPreview / 10).round()}'),
                  Text('Estimated Reach: ${(coinsPreview / 5).round()}'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Rules',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Coins never expire',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• No refunds under any condition',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• All ads require backend approval',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Coins locked upon approval',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    final advertiserService = AdvertiserService();
    final budget = double.tryParse(_budgetController.text) ?? 0.0;
    final coins = advertiserService.rupeesToCoins(budget);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 7: Review & Submit',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ad Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildReviewRow('Category', _selectedCategory?.name.toUpperCase() ?? 'Not selected'),
                  _buildReviewRow('Company', _companyNameController.text.isEmpty ? 'Not set' : _companyNameController.text),
                  _buildReviewRow('Budget', '₹${budget.toStringAsFixed(2)}'),
                  _buildReviewRow('Coins', coins.toString()),
                  _buildReviewRow('Locations', _targetLocations.isEmpty ? 'Not set' : _targetLocations.join(', ')),
                  _buildReviewRow('Languages', _targetLanguages.isEmpty ? 'Not set' : _targetLanguages.join(', ')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('I acknowledge the rules and terms'),
            value: true,
            onChanged: null,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
