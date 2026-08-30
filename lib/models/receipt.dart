import 'receipt_item.dart';
import 'package:intl/intl.dart';

class Receipt {
  final String receiptNumber;
  final DateTime date;
  final List<ReceiptItem> items;
  final double total;
  final double discountPercent;

  Receipt({
    required this.receiptNumber,
    required this.date,
    required this.items,
    required this.total,
    this.discountPercent = 0,
  });

  double get subtotalBeforeDiscount => items.fold(0, (sum, item) => sum + item.subtotal);
  double get discountAmount => subtotalBeforeDiscount * discountPercent / 100;

  String get formattedDate {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }
}
