import 'package:flutter/foundation.dart';

class ServiceCartLine {
  const ServiceCartLine(
      {required this.payload, required this.title, required this.total});
  final Map<String, dynamic> payload;
  final String title;
  final int total;
}

class ServiceCartState extends ChangeNotifier {
  static final instance = ServiceCartState._();
  ServiceCartState._();
  final List<ServiceCartLine> lines = [];
  int get total => lines.fold(0, (sum, line) => sum + line.total);
  void add(ServiceCartLine line) {
    lines.add(line);
    notifyListeners();
  }

  void remove(ServiceCartLine line) {
    lines.remove(line);
    notifyListeners();
  }

  void clear() {
    lines.clear();
    notifyListeners();
  }
}
