import 'package:flutter/material.dart';
import '../utils/current_user.dart';
import '../models/boost_model.dart';
import '../services/boost_service.dart';
import 'boost_analytics_screen.dart';

class BoostPostScreen extends StatefulWidget {
  final String postId;
  final String contentType; // 'post' or 'reel'

  const BoostPostScreen({
    super.key,
    required this.postId,
    this.contentType = 'post',
  });

  @override
  State<BoostPostScreen> createState() => _BoostPostScreenState();
}

class _BoostPostScreenState extends State<BoostPostScreen> {
  final BoostService _boostService = BoostService();
  String _userId = 'user-1';

  BoostDuration? _selectedDuration;
  BoostEligibilityResult? _eligibilityResult;
  bool _isCheckingEligibility = false;
  bool _isProcessing = false;
  PostBoost? _createdBoost;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final uid = await CurrentUser.id;
    if (mounted && uid != null) {
      setState(() => _userId = uid);
    }
    _checkEligibility();
  }

  Future<void> _checkEligibility() async {
    setState(() {
      _isCheckingEligibility = true;
    });

    final result = await _boostService.checkBoostEligibility(
      userId: _userId,
      postId: widget.postId,
      contentType: widget.contentType,
    );

    setState(() {
      _eligibilityResult = result;
      _isCheckingEligibility = false;
    });
  }

  Future<void> _createBoost() async {
    if (_selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a boost duration')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Create boost
      final boost = await _boostService.createBoost(
        userId: _userId,
        postId: widget.postId,
        duration: _selectedDuration!,
      );

      if (boost == null) {
        throw Exception('Failed to create boost');
      }

      // Process payment
      final paymentSuccess = await _boostService.processPaymentAndActivate(boost.id);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (paymentSuccess) {
          setState(() {
            _createdBoost = _boostService.getBoost(boost.id);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Boost activated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment failed. Boost not activated.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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
        title: const Text('Boost Post'),
      ),
      body: _isCheckingEligibility
          ? const Center(child: CircularProgressIndicator())
          : _eligibilityResult?.isEligible == false
              ? _buildNotEligibleView()
              : _createdBoost != null
                  ? _buildSuccessView()
                  : _buildBoostOptions(),
    );
  }

  Widget _buildNotEligibleView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            const Text(
              'Cannot Boost This Content',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _eligibilityResult?.reason ?? 'Unknown reason',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final boost = _createdBoost!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Boost Activated!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        'Your content will be boosted for ${boost.duration.hours} hours',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
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
                    'Boost Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Duration', '${boost.duration.hours} hours'),
                  _buildDetailRow('Cost', '\$${boost.cost.toStringAsFixed(2)}'),
                  _buildDetailRow('Status', boost.status.name.toUpperCase()),
                  if (boost.endTime != null)
                    _buildDetailRow(
                      'Ends At',
                      '${boost.endTime!.day}/${boost.endTime!.month}/${boost.endTime!.year} ${boost.endTime!.hour}:${boost.endTime!.minute.toString().padLeft(2, '0')}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Boost increases visibility but does not guarantee views',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Boost may be paused if content is reported',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Boost ends automatically after the selected duration',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => BoostAnalyticsScreen(boostId: boost.id),
                  ),
                );
              },
              child: const Text('View Analytics'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostOptions() {
    final durations = BoostDuration.values;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Boost Duration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Boost increases your content visibility in the feed',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          ...durations.map((duration) {
            final cost = _boostService.calculateBoostCost(duration);
            final isSelected = _selectedDuration == duration;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: isSelected ? Colors.blue[50] : null,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedDuration = duration;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Radio<BoostDuration>(
                        value: duration,
                        groupValue: _selectedDuration,
                        onChanged: (value) {
                          setState(() {
                            _selectedDuration = value;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${duration.hours} ${duration.hours == 1 ? 'Hour' : 'Hours'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${cost.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Colors.blue),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 24),
          
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
                  'Boost Guidelines',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '• Boost does not guarantee views or engagement',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Boost may be paused if content violates policies',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Boost ends automatically after selected duration',
                  style: TextStyle(fontSize: 12),
                ),
                Text(
                  '• Refunds only available for system failures',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isProcessing || _selectedDuration == null
                  ? null
                  : _createBoost,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Boost Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
