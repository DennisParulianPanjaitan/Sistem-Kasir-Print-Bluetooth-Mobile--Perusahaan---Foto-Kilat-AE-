import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/receipt_item.dart';
import '../widgets/product_table.dart';
import '../utils/currency_formatter.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import 'preview_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'printer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';

  List<Product> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;
    return _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void initState() {
    super.initState();
    _refreshProducts();
  }

  Future<void> _refreshProducts() async {
    setState(() => _isLoading = true);
    final products = await DatabaseService.instance.readAllProducts();
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  Future<void> _showAddProductDialog() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final priceFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Barang Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                focusNode: priceFocusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                if (name.isNotEmpty && priceText.isNotEmpty) {
                  final price = double.tryParse(priceText);
                  if (price != null) {
                    final newProduct = Product(name: name, price: price);
                    await DatabaseService.instance.createProduct(newProduct);
                    if (context.mounted) Navigator.pop(context);
                    _refreshProducts();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Future<void> _showEditProductDialog(Product product) async {
    final nameController = TextEditingController(text: product.name);
    final priceController = TextEditingController(text: product.price.toStringAsFixed(0));
    final priceFocusNode = FocusNode();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit Barang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: 'Nama Barang',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceController,
                focusNode: priceFocusNode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Harga (Rp)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                if (name.isNotEmpty && priceText.isNotEmpty) {
                  final price = double.tryParse(priceText);
                  if (price != null && product.id != null) {
                    final updated = Product(id: product.id, name: name, price: price);
                    await DatabaseService.instance.updateProduct(updated);
                    if (context.mounted) Navigator.pop(context);
                    _refreshProducts();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              child: const Text('SIMPAN'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Hapus'),
          content: Text('Yakin ingin menghapus ${product.name}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('TIDAK', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('YA, HAPUS'),
            ),
          ],
        );
      },
    );

    if (confirm == true && product.id != null) {
      await DatabaseService.instance.deleteProduct(product.id!);
      
      // Also remove from cart if it exists
      setState(() {
        _cart.removeWhere((item) => item.product.id == product.id);
      });
      
      _refreshProducts();
    }
  }

  final List<ReceiptItem> _cart = [];

  void _addToCart(Product product) {
    setState(() {
      final existingItemIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (existingItemIndex >= 0) {
        _cart[existingItemIndex].quantity++;
      } else {
        _cart.add(ReceiptItem(product: product));
      }
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      final existingItemIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (existingItemIndex >= 0) {
        if (_cart[existingItemIndex].quantity > 1) {
          _cart[existingItemIndex].quantity--;
        } else {
          _cart.removeAt(existingItemIndex);
        }
      }
    });
  }

  void _setQuantity(Product product, int quantity) {
    setState(() {
      final existingItemIndex = _cart.indexWhere((item) => item.product.id == product.id);
      if (quantity <= 0) {
        if (existingItemIndex >= 0) _cart.removeAt(existingItemIndex);
      } else {
        if (existingItemIndex >= 0) {
          _cart[existingItemIndex].quantity = quantity;
        } else {
          _cart.add(ReceiptItem(product: product, quantity: quantity));
        }
      }
    });
  }

  void _clearCart() {
    setState(() {
      _cart.clear();
      _discountPercent = 0;
    });
  }

  double _discountPercent = 0;

  double get _cartTotal {
    return _cart.fold(0, (sum, item) => sum + item.subtotal);
  }

  double get _cartFinalTotal {
    return _cartTotal - (_cartTotal * _discountPercent / 100);
  }

  void _showDiscountDialog() {
    final controller = TextEditingController(
      text: _discountPercent > 0 ? _discountPercent.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Input Diskon'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Persentase Diskon (%)',
            border: OutlineInputBorder(),
            suffixText: '%',
          ),
        ),
        actions: [
          if (_discountPercent > 0)
            TextButton(
              onPressed: () {
                setState(() => _discountPercent = 0);
                Navigator.pop(context);
              },
              child: const Text('HAPUS DISKON', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null && val >= 0 && val <= 100) {
                setState(() => _discountPercent = val);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('TERAPKAN'),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePreview() async {
    final receiptNumber = await DatabaseService.instance.generateNextReceiptNumber();
    
    final receipt = Receipt(
      receiptNumber: receiptNumber,
      date: DateTime.now(),
      items: List.from(_cart),
      total: _cartFinalTotal,
      discountPercent: _discountPercent,
    );

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PreviewScreen(receipt: receipt),
        ),
      );
    }
  }

  Future<void> _handleQuickPrint() async {
    final receiptNumber = await DatabaseService.instance.generateNextReceiptNumber();
    
    final receipt = Receipt(
      receiptNumber: receiptNumber,
      date: DateTime.now(),
      items: List.from(_cart),
      total: _cartFinalTotal,
      discountPercent: _discountPercent,
    );

    if (mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, _, __) => PreviewScreen(receipt: receipt, autoPrint: true),
        ),
      );
    }
  }

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool _obscure = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Color(0xFFCC0000)),
                  SizedBox(width: 8),
                  Text('Password Diperlukan'),
                ],
              ),
              content: TextField(
                controller: passwordController,
                obscureText: _obscure,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Masukkan Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setStateDialog(() => _obscure = !_obscure),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordController.text == '1234') {
                      Navigator.pop(context); // tutup dialog
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Password salah!'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0000),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('MASUK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showResetScheduleDialog() async {
    final savedDay = await DatabaseService.instance.getSetting('reset_day', '1');
    int selectedDay = int.tryParse(savedDay) ?? 1;
    final controller = TextEditingController(text: selectedDay.toString());

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.calendar_month, color: Color(0xFFCC0000)),
                  SizedBox(width: 8),
                  Text('Jadwal Reset ID Nota'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanggal reset nomor nota setiap bulannya:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: selectedDay > 1
                            ? () {
                                setStateDialog(() => selectedDay--);
                                controller.text = selectedDay.toString();
                              }
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: const Color(0xFFCC0000),
                        iconSize: 32,
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFCC0000),
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCC0000), width: 2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCC0000), width: 2),
                            ),
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val);
                            if (parsed != null && parsed >= 1 && parsed <= 28) {
                              setStateDialog(() => selectedDay = parsed);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: selectedDay < 28
                            ? () {
                                setStateDialog(() => selectedDay++);
                                controller.text = selectedDay.toString();
                              }
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: const Color(0xFFCC0000),
                        iconSize: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '* Angka 1–28. Maks 28 agar aman di bulan Februari.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await DatabaseService.instance.saveSetting('reset_day', selectedDay.toString());
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Reset ID nota diatur ke setiap tanggal $selectedDay.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
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
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    // Determine layout based on screen width (tablet vs phone)
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOTA ae'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: _buildSidebar(),
      body: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _buildProductList(),
        ),
        const VerticalDivider(width: 1, thickness: 1),
        Expanded(
          flex: 1,
          child: _buildCart(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: _buildProductList(),
        ),
        _buildCartBottomSheet(),
      ],
    );
  }

  Widget _buildProductList() {
    final Map<int, int> cartQuantities = {};
    for (var item in _cart) {
      if (item.product.id != null) {
        cartQuantities[item.product.id!] = item.quantity;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Barang',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add),
                label: const Text('Tambah'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cari barang...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _filteredProducts.isEmpty
              ? const Center(child: Text('Barang tidak ditemukan.'))
              : ProductTable(
                  products: _filteredProducts,
                  onAdd: _addToCart,
                  onRemove: _removeFromCart,
                  onDelete: _deleteProduct,
                  onEdit: _showEditProductDialog,
                  onSetQuantity: _setQuantity,
                  cartQuantities: cartQuantities,
                ),
        ),
      ],
    );
  }

  Widget _buildCart() {
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Nota Saat Ini',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _cart.isEmpty
                ? const Center(child: Text('Belum ada barang.'))
                : ListView.builder(
                    itemCount: _cart.length,
                    itemBuilder: (context, index) {
                      final item = _cart[index];
                      return ListTile(
                        title: Text(item.product.name),
                        subtitle: Text('${item.quantity} x ${CurrencyFormatter.formatRupiah(item.product.price)}'),
                        trailing: Text(
                          CurrencyFormatter.formatRupiah(item.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          _buildCartFooter(),
        ],
      ),
    );
  }

  Widget _buildCartBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Baris subtotal (selalu tampil)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _discountPercent > 0 ? 'SUBTOTAL:' : 'TOTAL:',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  CurrencyFormatter.formatRupiah(_cartTotal),
                  style: TextStyle(
                    fontSize: _discountPercent > 0 ? 18 : 24,
                    fontWeight: FontWeight.bold,
                    color: _discountPercent > 0 ? Colors.grey : const Color(0xFFCC0000),
                    decoration: _discountPercent > 0 ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
            // Baris diskon & total akhir (hanya tampil jika ada diskon)
            if (_discountPercent > 0) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Diskon ${_discountPercent.toStringAsFixed(0)}%:',
                    style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                  ),
                  Text(
                    '- ${CurrencyFormatter.formatRupiah(_cartTotal * _discountPercent / 100)}',
                    style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'BAYAR:',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyFormatter.formatRupiah(_cartFinalTotal),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFCC0000),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Column(
              children: [
                // Baris 1: CLEAR + PREVIEW
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cart.isEmpty ? null : _clearCart,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('CLEAR'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty ? null : _handlePreview,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blueGrey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('PREVIEW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Baris 2: DISKON % + PRINT CEPAT (dominan)
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _cart.isEmpty ? null : _showDiscountDialog,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: _discountPercent > 0 ? Colors.orange : const Color(0xFFCC0000),
                          ),
                          foregroundColor: _discountPercent > 0 ? Colors.orange : const Color(0xFFCC0000),
                        ),
                        child: Text(
                          _discountPercent > 0
                              ? '${_discountPercent.toStringAsFixed(0)}% ✓'
                              : '% Diskon',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: _cart.isEmpty ? null : _handleQuickPrint,
                        icon: const Icon(Icons.print),
                        label: const Text('PRINT CEPAT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFCC0000),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartFooter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
      ),
      child: Column(
        children: [
          // Baris subtotal (selalu tampil)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _discountPercent > 0 ? 'SUBTOTAL:' : 'TOTAL:',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                CurrencyFormatter.formatRupiah(_cartTotal),
                style: TextStyle(
                  fontSize: _discountPercent > 0 ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: _discountPercent > 0 ? Colors.grey : const Color(0xFFCC0000),
                  decoration: _discountPercent > 0 ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          // Baris diskon & total akhir (hanya tampil jika ada diskon)
          if (_discountPercent > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Diskon ${_discountPercent.toStringAsFixed(0)}%:',
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
                Text(
                  '- ${CurrencyFormatter.formatRupiah(_cartTotal * _discountPercent / 100)}',
                  style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'BAYAR:',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  CurrencyFormatter.formatRupiah(_cartFinalTotal),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFCC0000),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Column(
            children: [
              // Baris 1: CLEAR + PREVIEW
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cart.isEmpty ? null : _clearCart,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CLEAR'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _cart.isEmpty ? null : _handlePreview,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('PREVIEW', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Baris 2: DISKON % + PRINT CEPAT (dominan)
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: _cart.isEmpty ? null : _showDiscountDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _discountPercent > 0 ? Colors.orange : const Color(0xFFCC0000),
                        ),
                        foregroundColor: _discountPercent > 0 ? Colors.orange : const Color(0xFFCC0000),
                      ),
                      child: Text(
                        _discountPercent > 0
                            ? '${_discountPercent.toStringAsFixed(0)}% ✓'
                            : '% Diskon',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _cart.isEmpty ? null : _handleQuickPrint,
                      icon: const Icon(Icons.print),
                      label: const Text('PRINT CEPAT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFCC0000),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: const Color(0xFFCC0000),
            ),
            child: Text(
              'FOTO KILAT AE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan (Shift & Nota)'),
            onTap: () {
              Navigator.pop(context); // Tutup drawer
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Printer / Bluetooth'),
            onTap: () {
              Navigator.pop(context); // Tutup drawer
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrinterScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Riwayat Penjualan'),
            onTap: () {
              Navigator.pop(context); // Tutup drawer dulu
              _showPasswordDialog();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Color(0xFFCC0000)),
            title: const Text('Jadwal Reset ID'),
            subtitle: const Text('Atur tanggal reset nomor nota'),
            onTap: () {
              Navigator.pop(context);
              _showResetScheduleDialog();
            },
          ),
        ],
      ),
    );
  }
}
