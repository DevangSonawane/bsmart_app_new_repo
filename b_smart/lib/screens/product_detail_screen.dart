import 'package:flutter/material.dart';
import '../services/ads_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final AdsService _ads = AdsService();
  Map<String, dynamic>? _product;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await _ads.getProductById(widget.productId);
    if (mounted) setState(() { _product = p; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_product == null) return Scaffold(body: Center(child: Text('Product not found')));
    return Scaffold(
      appBar: AppBar(title: Text(_product?['name'] ?? 'Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_product?['image_url'] != null)
              Image.network(_product!['image_url']),
            const SizedBox(height: 12),
            Text(_product?['name'] ?? '', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_product?['price'] != null ? '\$${_product!['price']}' : ''),
            const SizedBox(height: 12),
            Text(_product?['description'] ?? ''),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final url = _product?['external_url'] as String?;
                  if (url != null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open external link')));
                  }
                },
                child: const Text('View / Buy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

