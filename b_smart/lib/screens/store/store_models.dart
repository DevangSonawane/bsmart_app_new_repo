import 'package:flutter/material.dart';

class StoreCategory {
  final String label;
  final IconData icon;

  const StoreCategory(this.label, this.icon);
}

class StoreProduct {
  final String title;
  final String subtitle;
  final Color color;
  final String imageAsset;

  const StoreProduct(this.title, this.subtitle, this.color, this.imageAsset);
}
