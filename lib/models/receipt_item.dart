import 'product.dart';

class ReceiptItem {
  final Product product;
  int quantity;

  ReceiptItem({
    required this.product,
    this.quantity = 1,
  });

  double get subtotal => product.price * quantity;
}
