import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

enum StoreMockItemType { product, service }

enum StoreMockOrderStatus { newOrder, processing, shipped, completed }

class StoreMockCatalogItem {
  final String id;
  final StoreMockItemType type;
  final String title;
  final String category;
  final String description;
  final String imageAsset;
  final IconData icon;
  final double price;
  final String duration;
  final String rating;
  final String reviews;

  const StoreMockCatalogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.category,
    required this.description,
    required this.imageAsset,
    required this.icon,
    required this.price,
    required this.duration,
    required this.rating,
    required this.reviews,
  });

  String get priceLabel {
    final whole = price == price.roundToDouble();
    return '\$${whole ? price.toStringAsFixed(0) : price.toStringAsFixed(2)}';
  }
}

class StoreMockCartLine {
  final StoreMockCatalogItem item;
  final int quantity;
  final String? schedule;

  const StoreMockCartLine({
    required this.item,
    required this.quantity,
    this.schedule,
  });

  StoreMockCartLine copyWith({int? quantity, String? schedule}) {
    return StoreMockCartLine(
      item: item,
      quantity: quantity ?? this.quantity,
      schedule: schedule ?? this.schedule,
    );
  }

  double get total => item.price * quantity;
}

class StoreMockOrder {
  final String id;
  final String customerName;
  final Color avatarColor;
  final StoreMockOrderStatus status;
  final List<StoreMockCartLine> lines;
  final double paidAmount;
  final double bCoinsSavings;
  final String address;

  const StoreMockOrder({
    required this.id,
    required this.customerName,
    required this.avatarColor,
    required this.status,
    required this.lines,
    required this.paidAmount,
    required this.bCoinsSavings,
    required this.address,
  });

  String get customerInitials {
    final parts = customerName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'BS';
    final first = parts.first.characters.first.toUpperCase();
    if (parts.length == 1) return first;
    return '$first${parts.last.characters.first.toUpperCase()}';
  }

  int get itemCount => lines.fold(0, (sum, line) => sum + line.quantity);
}

class StoreMockState extends ChangeNotifier {
  StoreMockState._();

  static final StoreMockState instance = StoreMockState._();

  static const List<StoreMockCatalogItem> catalog = [
    StoreMockCatalogItem(
      id: 'svc-home-cleaning',
      type: StoreMockItemType.service,
      title: 'Home Cleaning',
      category: 'Home Services',
      description: 'Thorough and reliable cleaning for a fresh, healthy home.',
      imageAsset: 'assets/bSmart_Store/mockimages/clothes.jpg',
      icon: LucideIcons.house,
      price: 40,
      duration: '2-3 hrs',
      rating: '4.8',
      reviews: '64',
    ),
    StoreMockCatalogItem(
      id: 'prd-cleaning-kit',
      type: StoreMockItemType.product,
      title: 'Eco Cleaning Kit',
      category: 'Home & Living',
      description:
          'Reusable, plant-friendly cleaning essentials for a naturally fresh home.',
      imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
      icon: LucideIcons.package,
      price: 24.99,
      duration: '2-3 days',
      rating: '4.8',
      reviews: '64',
    ),
    StoreMockCatalogItem(
      id: 'prd-aroma-diffuser',
      type: StoreMockItemType.product,
      title: 'Aroma Diffuser',
      category: 'Wellness',
      description:
          'Quiet ultrasonic diffuser with soft lighting for workspaces and bedrooms.',
      imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
      icon: LucideIcons.sparkles,
      price: 32,
      duration: '2-3 days',
      rating: '4.7',
      reviews: '38',
    ),
    StoreMockCatalogItem(
      id: 'prd-handmade-notebook',
      type: StoreMockItemType.product,
      title: 'Handmade Notebook',
      category: 'Stationery',
      description:
          'Textured cover notebook with smooth pages for planning, notes, and sketches.',
      imageAsset: 'assets/bSmart_Store/mockimages/clothes_cutout_grid.png',
      icon: LucideIcons.notebookPen,
      price: 15,
      duration: '2-3 days',
      rating: '4.9',
      reviews: '91',
    ),
    StoreMockCatalogItem(
      id: 'prd-mobile-stand',
      type: StoreMockItemType.product,
      title: 'Foldable Mobile Stand',
      category: 'Electronics',
      description:
          'Compact desk stand with an adjustable angle for video calls and streaming.',
      imageAsset: 'assets/bSmart_Store/mobilephone/shopping.webp',
      icon: LucideIcons.smartphone,
      price: 18.5,
      duration: '2-3 days',
      rating: '4.6',
      reviews: '44',
    ),
    StoreMockCatalogItem(
      id: 'prd-fresh-market-box',
      type: StoreMockItemType.product,
      title: 'Fresh Market Box',
      category: 'Groceries',
      description:
          'A curated weekly basket with greens, seasonal vegetables, and herbs.',
      imageAsset: 'assets/bSmart_Store/mockimages/vegetables_cutout_grid.png',
      icon: LucideIcons.leaf,
      price: 29,
      duration: '1-2 days',
      rating: '4.9',
      reviews: '76',
    ),
    StoreMockCatalogItem(
      id: 'svc-business-consulting',
      type: StoreMockItemType.service,
      title: 'Business Consulting',
      category: 'Services',
      description: 'Expert advice to help your business grow and succeed.',
      imageAsset: 'assets/bSmart_Store/mockimages/electronics.jpg',
      icon: LucideIcons.briefcaseBusiness,
      price: 60,
      duration: '60 min',
      rating: '4.9',
      reviews: '52',
    ),
    StoreMockCatalogItem(
      id: 'svc-yoga-coaching',
      type: StoreMockItemType.service,
      title: 'Yoga Coaching',
      category: 'Wellness',
      description: 'Personalized sessions to improve your mind and body.',
      imageAsset: 'assets/bSmart_Store/mockimages/vegetables.jpg',
      icon: LucideIcons.flower2,
      price: 35,
      duration: '45 min',
      rating: '4.9',
      reviews: '48',
    ),
    StoreMockCatalogItem(
      id: 'svc-phone-setup',
      type: StoreMockItemType.service,
      title: 'Phone Setup Help',
      category: 'Tech Services',
      description:
          'One-on-one setup for backups, app transfers, privacy, and accessibility.',
      imageAsset: 'assets/bSmart_Store/mobilephone/download.webp',
      icon: LucideIcons.settings,
      price: 25,
      duration: '45 min',
      rating: '4.7',
      reviews: '33',
    ),
  ];

  final List<StoreMockCartLine> _cartLines = [
    StoreMockCartLine(item: catalog[1], quantity: 1),
    StoreMockCartLine(item: catalog[3], quantity: 1),
  ];

  final List<StoreMockOrder> _orders = [
    StoreMockOrder(
      id: 'BS10482',
      customerName: 'Emily Carter',
      avatarColor: const Color(0xFFEAD8CC),
      status: StoreMockOrderStatus.newOrder,
      paidAmount: 39.99,
      bCoinsSavings: 4,
      address:
          'Emily Carter\n123 Greenway St.\nPortland, OR 97201\nUnited States',
      lines: [
        StoreMockCartLine(item: catalog[1], quantity: 1),
        StoreMockCartLine(item: catalog[3], quantity: 1),
      ],
    ),
    StoreMockOrder(
      id: 'BS10481',
      customerName: 'Ryan Kim',
      avatarColor: const Color(0xFFD9E8F2),
      status: StoreMockOrderStatus.newOrder,
      paidAmount: 32,
      bCoinsSavings: 0,
      address: 'Ryan Kim\n45 Market Street\nSeattle, WA 98101\nUnited States',
      lines: [StoreMockCartLine(item: catalog[2], quantity: 1)],
    ),
    StoreMockOrder(
      id: 'BS10479',
      customerName: 'Sophie Williams',
      avatarColor: const Color(0xFFEBD8C8),
      status: StoreMockOrderStatus.processing,
      paidAmount: 75,
      bCoinsSavings: 0,
      address:
          'Sophie Williams\n88 Lake Avenue\nAustin, TX 78701\nUnited States',
      lines: [
        StoreMockCartLine(item: catalog[7], quantity: 1, schedule: 'Today'),
        StoreMockCartLine(item: catalog[4], quantity: 1),
      ],
    ),
  ];

  List<StoreMockCatalogItem> get products =>
      catalog.where((item) => item.type == StoreMockItemType.product).toList();

  List<StoreMockCatalogItem> get services =>
      catalog.where((item) => item.type == StoreMockItemType.service).toList();

  List<StoreMockCartLine> get cartLines => List.unmodifiable(_cartLines);

  List<StoreMockOrder> get orders => List.unmodifiable(_orders);

  int get cartCount => _cartLines.fold(0, (sum, line) => sum + line.quantity);

  double get subtotal => _cartLines.fold(0.0, (sum, line) => sum + line.total);

  StoreMockCatalogItem itemById(String id) {
    return catalog.firstWhere((item) => item.id == id);
  }

  int quantityFor(String id) {
    final index = _cartLines.indexWhere((line) => line.item.id == id);
    return index == -1 ? 0 : _cartLines[index].quantity;
  }

  void addToCart(
    StoreMockCatalogItem item, {
    int quantity = 1,
    String? schedule,
  }) {
    final index = _cartLines.indexWhere((line) => line.item.id == item.id);
    if (index == -1) {
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: quantity.clamp(1, 99),
          schedule: schedule,
        ),
      );
    } else {
      final current = _cartLines[index];
      _cartLines[index] = current.copyWith(
        quantity: (current.quantity + quantity).clamp(1, 99),
        schedule: schedule ?? current.schedule,
      );
    }
    notifyListeners();
  }

  void setCartQuantity(
    StoreMockCatalogItem item,
    int quantity, {
    String? schedule,
  }) {
    final index = _cartLines.indexWhere((line) => line.item.id == item.id);
    if (quantity <= 0) {
      if (index != -1) {
        _cartLines.removeAt(index);
        notifyListeners();
      }
      return;
    }

    if (index == -1) {
      _cartLines.add(
        StoreMockCartLine(
          item: item,
          quantity: quantity.clamp(1, 99),
          schedule: schedule,
        ),
      );
    } else {
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: quantity.clamp(1, 99),
        schedule: schedule ?? _cartLines[index].schedule,
      );
    }
    notifyListeners();
  }

  void updateQuantity(String itemId, int quantity) {
    final index = _cartLines.indexWhere((line) => line.item.id == itemId);
    if (index == -1) return;
    if (quantity <= 0) {
      _cartLines.removeAt(index);
    } else {
      _cartLines[index] = _cartLines[index].copyWith(
        quantity: quantity.clamp(1, 99),
      );
    }
    notifyListeners();
  }

  void removeFromCart(String itemId) {
    _cartLines.removeWhere((line) => line.item.id == itemId);
    notifyListeners();
  }

  StoreMockOrder placeOrder({
    required double paidAmount,
    required double bCoinsSavings,
  }) {
    final order = StoreMockOrder(
      id: 'BS${2048 + _orders.length}',
      customerName: 'You',
      avatarColor: const Color(0xFFE5F5F3),
      status: StoreMockOrderStatus.newOrder,
      lines: List<StoreMockCartLine>.from(_cartLines),
      paidAmount: paidAmount,
      bCoinsSavings: bCoinsSavings,
      address: 'You\n24 Market Street\nSan Francisco, CA 94103\nUnited States',
    );
    _orders.insert(0, order);
    _cartLines.clear();
    notifyListeners();
    return order;
  }

  String money(double amount) => '\$${amount.toStringAsFixed(2)}';
}
