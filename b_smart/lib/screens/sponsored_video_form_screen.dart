import 'package:flutter/material.dart';
import '../models/user_account_model.dart';
import '../services/sponsored_video_service.dart';
import 'sponsored_video_preview_screen.dart';

class SponsoredVideoFormScreen extends StatefulWidget {
  const SponsoredVideoFormScreen({super.key});

  @override
  State<SponsoredVideoFormScreen> createState() => _SponsoredVideoFormScreenState();
}

class _SponsoredVideoFormScreenState extends State<SponsoredVideoFormScreen> {
  final SponsoredVideoService _videoService = SponsoredVideoService();
  final PageController _pageController = PageController();
  
  int _currentStep = 0;
  String? _videoUrl;
  String? _thumbnailUrl;
  final List<String> _productImageUrls = [];
  final _productNameController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _currencyController = TextEditingController();
  final _discountController = TextEditingController();
  String? _selectedCategory;
  final _brandNameController = TextEditingController();
  final _productUrlController = TextEditingController();
  final _skuController = TextEditingController();
  final _variantController = TextEditingController();
  String? _affiliateId;
  
  SponsoredVideo? _draftVideo;
  bool _isSubmitting = false;

  final List<String> _categories = [
    'Fashion',
    'Beauty',
    'Electronics',
    'Fitness',
    'Home & Living',
    'Food & Beverage',
    'Travel',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _createDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _productNameController.dispose();
    _productDescriptionController.dispose();
    _priceController.dispose();
    _currencyController.dispose();
    _discountController.dispose();
    _brandNameController.dispose();
    _productUrlController.dispose();
    _skuController.dispose();
    _variantController.dispose();
    super.dispose();
  }

  Future<void> _createDraft() async {
    final video = await _videoService.createDraft(
      userId: 'user-1',
      productName: '',
      productDescription: '',
      brandName: '',
      productUrl: '',
    );
    setState(() {
      _draftVideo = video;
    });
  }

  void _nextStep() {
    if (_currentStep < 3) {
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
        return _videoUrl != null;
      case 1:
        return _productImageUrls.isNotEmpty;
      case 2:
        return _productNameController.text.isNotEmpty &&
            _productDescriptionController.text.isNotEmpty &&
            _brandNameController.text.isNotEmpty &&
            _productUrlController.text.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _saveDraft() async {
    if (_draftVideo == null) return;

    final video = SponsoredVideo(
      id: _draftVideo!.id,
      userId: _draftVideo!.userId,
      videoUrl: _videoUrl,
      thumbnailUrl: _thumbnailUrl,
      productImageUrls: _productImageUrls,
      productName: _productNameController.text,
      productDescription: _productDescriptionController.text,
      price: double.tryParse(_priceController.text),
      currency: _currencyController.text.isEmpty ? 'USD' : _currencyController.text,
      discount: double.tryParse(_discountController.text),
      productCategory: _selectedCategory,
      brandName: _brandNameController.text,
      productUrl: _productUrlController.text,
      sku: _skuController.text.isEmpty ? null : _skuController.text,
      variant: _variantController.text.isEmpty ? null : _variantController.text,
      affiliateId: _affiliateId,
      status: SponsoredVideoStatus.draft,
      createdAt: _draftVideo!.createdAt,
    );

    await _videoService.updateDraft(video);
    setState(() {
      _draftVideo = video;
    });
  }

  Future<void> _submitForReview() async {
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all required fields')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Save draft first
    await _saveDraft();

    try {
      final status = await _videoService.submitForReview(_draftVideo!.id);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });

        if (status == SponsoredVideoStatus.rejected) {
          final updatedVideo = await _videoService.getVideo(_draftVideo!.id);
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Submission Rejected'),
              content: Text(updatedVideo?.rejectionReason ?? 'Content policy violation'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        } else {
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SponsoredVideoPreviewScreen(videoId: _draftVideo!.id),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Sponsored Video'),
        actions: [
          if (_draftVideo != null)
            TextButton(
              onPressed: _saveDraft,
              child: const Text('Save Draft'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Step Indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Video'),
                _buildStepConnector(),
                _buildStepIndicator(1, 'Images'),
                _buildStepConnector(),
                _buildStepIndicator(2, 'Details'),
                _buildStepConnector(),
                _buildStepIndicator(3, 'Preview'),
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
                _buildVideoUploadStep(),
                _buildProductImagesStep(),
                _buildProductDetailsStep(),
                _buildPreviewStep(),
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
                if (_currentStep < 3)
                  ElevatedButton(
                    onPressed: _validateStep(_currentStep) ? _nextStep : null,
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForReview,
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
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted ? Colors.blue : Colors.grey[300],
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.blue : Colors.grey[600],
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      height: 2,
      width: 20,
      color: Colors.grey[300],
    );
  }

  Widget _buildVideoUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 1: Upload Video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload your sponsored video (MP4, MOV). Duration limits apply.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              // Simulate video upload
              setState(() {
                _videoUrl = 'https://example.com/video.mp4';
                _thumbnailUrl = 'https://example.com/thumbnail.jpg';
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
                border: Border.all(color: Colors.grey[400]!, width: 2, style: BorderStyle.solid),
              ),
              child: _videoUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        const Icon(Icons.video_library, size: 60, color: Colors.grey),
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.upload_file, size: 60, color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text('Tap to upload video'),
                        const SizedBox(height: 4),
                        Text(
                          'MP4, MOV • Max 60s',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ),
          if (_videoUrl != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Video uploaded. Thumbnail generated automatically.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImagesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 2: Upload Product Images',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Upload product images for carousel and thumbnails (JPG, PNG). Minimum 1, maximum 5.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._productImageUrls.map((url) {
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.image, size: 40, color: Colors.grey),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _productImageUrls.remove(url);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_productImageUrls.length < 5)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _productImageUrls.add('https://example.com/image${_productImageUrls.length + 1}.jpg');
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Image uploaded (simulated)')),
                    );
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 40, color: Colors.grey),
                        SizedBox(height: 4),
                        Text('Add', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (_productImageUrls.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'At least one product image is required',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 3: Product Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Required Fields
          TextField(
            controller: _productNameController,
            decoration: const InputDecoration(
              labelText: 'Product Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _productDescriptionController,
            decoration: const InputDecoration(
              labelText: 'Short Description *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _currencyController,
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    border: OutlineInputBorder(),
                    hintText: 'USD',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _discountController,
            decoration: const InputDecoration(
              labelText: 'Discount (%)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Product Category',
              border: OutlineInputBorder(),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedCategory = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _brandNameController,
            decoration: const InputDecoration(
              labelText: 'Brand / Company Name *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _productUrlController,
            decoration: const InputDecoration(
              labelText: 'Product URL (Redirect Destination) *',
              border: OutlineInputBorder(),
              hintText: 'https://example.com/product',
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          
          // Optional Fields
          const Text(
            'Optional Fields',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _skuController,
            decoration: const InputDecoration(
              labelText: 'SKU',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: _variantController,
            decoration: const InputDecoration(
              labelText: 'Variant (Color, Size)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Step 4: Preview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Video Preview
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: _videoUrl != null
                ? const Icon(Icons.play_circle_outline, size: 60, color: Colors.grey)
                : const Icon(Icons.video_library, size: 60, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // Product Images Preview
          if (_productImageUrls.isNotEmpty) ...[
            const Text(
              'Product Images',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _productImageUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.image, size: 40, color: Colors.grey),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Product Details Preview
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _productNameController.text.isEmpty ? 'Product Name' : _productNameController.text,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _productDescriptionController.text.isEmpty
                        ? 'Product description'
                        : _productDescriptionController.text,
                  ),
                  const SizedBox(height: 8),
                  if (_priceController.text.isNotEmpty)
                    Text(
                      '${_currencyController.text.isEmpty ? 'USD' : _currencyController.text} ${_priceController.text}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('Brand: ${_brandNameController.text.isEmpty ? 'Brand Name' : _brandNameController.text}'),
                  if (_selectedCategory != null) ...[
                    const SizedBox(height: 4),
                    Text('Category: $_selectedCategory'),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Auto-Applied Metadata Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Auto-Applied Metadata (Non-editable)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('• Sponsored badge', style: TextStyle(fontSize: 12)),
                const Text('• Disclosure ("Sponsored" / "Paid Partnership")', style: TextStyle(fontSize: 12)),
                const Text('• Creator attribution', style: TextStyle(fontSize: 12)),
                const Text('• Timestamp & campaign ID', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
