import 'package:flutter/material.dart';
import '../models/product.dart';
import '../utils/currency_formatter.dart';

class ProductTable extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onAdd;
  final Function(Product) onRemove;
  final Function(Product) onDelete;
  final Function(Product) onEdit;
  final Function(Product, int) onSetQuantity;
  final Map<int, int> cartQuantities;

  const ProductTable({
    super.key,
    required this.products,
    required this.onAdd,
    required this.onRemove,
    required this.onDelete,
    required this.onEdit,
    required this.onSetQuantity,
    required this.cartQuantities,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final quantity = cartQuantities[product.id] ?? 0;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          child: ListTile(
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              CurrencyFormatter.formatRupiah(product.price),
              style: const TextStyle(color: Colors.green, fontSize: 16),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blueGrey),
                  onPressed: () => onEdit(product),
                  tooltip: 'Edit Barang',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () => onDelete(product),
                  tooltip: 'Hapus Barang',
                ),
                const SizedBox(width: 8),
                quantity > 0
                    ? Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCC0000)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: const Color(0xFFCC0000)),
                              onPressed: () => onRemove(product),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                            InkWell(
                              onTap: () {
                                _showQuantityDialog(context, product, quantity);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                child: Text(
                                  '$quantity',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add, color: const Color(0xFFCC0000)),
                              onPressed: () => onAdd(product),
                              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => onAdd(product),
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                        child: const Text('ADD'),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQuantityDialog(BuildContext context, Product product, int currentQuantity) {
    final TextEditingController _qtyController = TextEditingController(text: currentQuantity.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Jumlah'),
          content: TextField(
            controller: _qtyController,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Jumlah untuk ${product.name}',
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final int? newQty = int.tryParse(_qtyController.text);
                if (newQty != null && newQty >= 0) {
                  onSetQuantity(product, newQty);
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0000),
                foregroundColor: Colors.white,
              ),
              child: const Text('SIMPAN'),
            ),
          ],
        );
      },
    );
  }
}
