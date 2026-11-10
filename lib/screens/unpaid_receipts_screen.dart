import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/product.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/escpos_image_converter.dart';
import '../widgets/receipt_widget.dart';
import 'history_detail_screen.dart';

class UnpaidReceiptsScreen extends StatefulWidget {
  const UnpaidReceiptsScreen({super.key});

  @override
  State<UnpaidReceiptsScreen> createState() => _UnpaidReceiptsScreenState();
}

class _UnpaidReceiptsScreenState extends State<UnpaidReceiptsScreen> {
  List<Map<String, dynamic>> _unpaidList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _headerText = '';
  String _footerText = '';
  Receipt? _receiptToPrint;
  final GlobalKey _receiptKeyPrint = GlobalKey();
  final GlobalKey _receiptKeyNoLogo = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadHeaderFooter();
    _loadUnpaidReceipts();
  }

  Future<void> _loadHeaderFooter() async {
    final header = await DatabaseService.instance.getSetting('header', 'FOTO KILAT AE');
    final footer = await DatabaseService.instance.getSetting('footer', 'Terima kasih!');
    if (mounted) {
      setState(() {
        _headerText = header.replaceAll('\\n', '\n');
        _footerText = footer.replaceAll('\\n', '\n');
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUnpaidReceipts() async {
    setState(() => _isLoading = true);
    final data = await DatabaseService.instance.getUnpaidReceipts();
    if (mounted) {
      setState(() {
        _unpaidList = data;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredList {
    if (_searchQuery.trim().isEmpty) return _unpaidList;
    final query = _searchQuery.trim().toLowerCase();
    return _unpaidList.where((item) {
      final receiptNumber = (item['receiptNumber'] as String? ?? '').toLowerCase();
      // Match with or without '#' (e.g. searching '1' matches '#000001')
      final cleanReceiptNumber = receiptNumber.replaceAll('#', '');
      final phone = (item['customer_phone'] as String? ?? '').toLowerCase();
      return receiptNumber.contains(query) || cleanReceiptNumber.contains(query) || phone.contains(query);
    }).toList();
  }

  double get _totalRemainingUnpaid {
    return _unpaidList.fold(0.0, (sum, item) {
      final total = (item['total'] as num?)?.toDouble() ?? 0.0;
      final dp = (item['downPayment'] as num?)?.toDouble() ?? 0.0;
      final remaining = total - dp;
      return sum + (remaining > 0 ? remaining : 0.0);
    });
  }

  Future<void> _handleSettle(Map<String, dynamic> row) async {
    final id = row['id'] as int;
    final receiptNumber = row['receiptNumber'] as String? ?? '';
    final total = (row['total'] as num?)?.toDouble() ?? 0.0;
    final dp = (row['downPayment'] as num?)?.toDouble() ?? 0.0;
    final remaining = (total - dp) > 0 ? (total - dp) : 0.0;
    final customerPhone = row['customer_phone'] as String?;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Konfirmasi Pelunasan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nota: $receiptNumber',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (customerPhone != null && customerPhone.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 15, color: Colors.green),
                  const SizedBox(width: 6),
                  Text(
                    'No. HP: ${customerPhone.trim()}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green[800]),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tagihan:', style: TextStyle(color: Colors.black87)),
                      Text(CurrencyFormatter.formatRupiah(total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('DP Sebelumnya:', style: TextStyle(color: Colors.blueAccent)),
                      Text(CurrencyFormatter.formatRupiah(dp), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sisa Pelunasan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        CurrencyFormatter.formatRupiah(remaining),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Apakah pembayaran sisa sebesar ${CurrencyFormatter.formatRupiah(remaining)} sudah diterima?',
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('LUNASKAN SEKARANG', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm == true) {
      // 1. Simpan pelunasan di database
      await DatabaseService.instance.settleReceipt(id);

      // 2. Rekonstruksi model Receipt dengan status Lunas
      List<ReceiptItem> items = [];
      try {
        final itemsJson = jsonDecode(row['itemsJson'] as String) as List<dynamic>;
        items = itemsJson.map((item) {
          return ReceiptItem(
            product: Product(
              name: item['name'] as String,
              price: (item['price'] as num).toDouble(),
            ),
            quantity: item['quantity'] as int,
          );
        }).toList();
      } catch (_) {}

      final settledReceipt = Receipt(
        receiptNumber: receiptNumber,
        date: DateTime.tryParse(row['date'] as String? ?? '') ?? DateTime.now(),
        items: items,
        total: total,
        discountPercent: (row['discountPercent'] as num?)?.toDouble() ?? 0.0,
        downPayment: dp,
        isSettled: true,
        settledDate: DateTime.now().toIso8601String(),
        customerPhone: row['customer_phone'] as String?,
      );

      // 3. Render widget nota tersembunyi
      if (mounted) {
        setState(() {
          _receiptToPrint = settledReceipt;
        });
      }
      await Future.delayed(const Duration(milliseconds: 250));

      // 4. Langsung cetak nota ke printer thermal Bluetooth (tanpa blocking loading)
      await _printSettledReceipt(settledReceipt);

      // 5. Muat ulang daftar nota belum lunas
      await _loadUnpaidReceipts();
    }
  }

  Future<void> _printSettledReceipt(Receipt receipt) async {
    try {
      final macAddress = await DatabaseService.instance.getSetting('printer_mac', '');
      if (macAddress.isEmpty) {
        if (mounted) {
          _showInfoDialog(
            'Printer Belum Terhubung',
            'Nota berhasil dilunasi, namun printer Bluetooth belum diatur. Buka menu Sidebar -> Printer / Bluetooth untuk menghubungkan.',
          );
        }
        return;
      }

      final boundary = _receiptKeyPrint.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final cleanNumber = receipt.receiptNumber.replaceAll('#', '');
      final file = File('${directory.path}/nota_settle_$cleanNumber.png');
      await file.writeAsBytes(pngBytes);

      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      }

      if (connected) {
        final escPosBytes = await EscPosImageConverter.convertImageToEscPos(file);
        final copiesStr = await DatabaseService.instance.getSetting('print_copies', '1');
        final copies = int.tryParse(copiesStr) ?? 1;

        List<int>? escPosBytesNoLogo;
        if (copies > 1) {
          final boundaryNoLogo = _receiptKeyNoLogo.currentContext?.findRenderObject() as RenderRepaintBoundary?;
          if (boundaryNoLogo != null) {
            final imgNoLogo = await boundaryNoLogo.toImage(pixelRatio: 3.0);
            final bDataNoLogo = await imgNoLogo.toByteData(format: ui.ImageByteFormat.png);
            if (bDataNoLogo != null) {
              final fileNoLogo = File('${directory.path}/nota_settle_${cleanNumber}_nologo.png');
              await fileNoLogo.writeAsBytes(bDataNoLogo.buffer.asUint8List());
              escPosBytesNoLogo = await EscPosImageConverter.convertImageToEscPos(fileNoLogo);
            }
          }
        }

        final List<int> separator = [0x0A, 0x0A, 0x0A];
        for (int i = 0; i < copies; i++) {
          if (i == 0) {
            await PrintBluetoothThermal.writeBytes(escPosBytes);
          } else {
            await PrintBluetoothThermal.writeBytes(separator);
            await Future.delayed(const Duration(milliseconds: 300));
            await PrintBluetoothThermal.writeBytes(escPosBytesNoLogo ?? escPosBytes);
          }
          if (i < copies - 1) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
      } else {
        if (mounted) {
          _showInfoDialog(
            'Gagal Cetak Nota',
            'Nota berhasil dilunasi di sistem, tetapi printer Bluetooth gagal terhubung. Pastikan printer dalam keadaan menyala.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showInfoDialog('Error Cetak', 'Gagal mencetak nota: $e');
      }
    }
  }

  void _showInfoDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Daftar Belum Lunas'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadUnpaidReceipts,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Widget tersembunyi untuk capture nota cetak fisik
          if (_receiptToPrint != null) ...[
            ClipRect(
              child: SizedBox(
                width: 0,
                height: 0,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: RepaintBoundary(
                    key: _receiptKeyPrint,
                    child: ReceiptWidget(
                      receipt: _receiptToPrint!,
                      headerText: _headerText,
                      footerText: _footerText,
                      horizontalPadding: 0,
                      showLogo: true,
                    ),
                  ),
                ),
              ),
            ),
            ClipRect(
              child: SizedBox(
                width: 0,
                height: 0,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: RepaintBoundary(
                    key: _receiptKeyNoLogo,
                    child: ReceiptWidget(
                      receipt: _receiptToPrint!,
                      headerText: _headerText,
                      footerText: _footerText,
                      horizontalPadding: 0,
                      showLogo: false,
                    ),
                  ),
                ),
              ),
            ),
          ],
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFCC0000)))
              : Column(
                  children: [
                // --- TOP SUMMARY & SEARCH CARD ---
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 16,
                    vertical: 14,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Ringkasan Piutang
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 24),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Nota Belum Lunas', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                      Text(
                                        '${_unpaidList.length} Transaksi',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFCC0000).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFCC0000).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFCC0000), size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Total Sisa Tagihan', style: TextStyle(fontSize: 11, color: Colors.black54)),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            CurrencyFormatter.formatRupiah(_totalRemainingUnpaid),
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFCC0000)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Search Bar
                      TextField(
                        controller: _searchController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Cari ID nota (ketik angka e.g. 1, 000001)...',
                          hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFFCC0000)),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                            borderSide: BorderSide(color: Color(0xFFCC0000), width: 1.5),
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ],
                  ),
                ),

                // --- LIST NOTA ---
                Expanded(
                  child: _unpaidList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green[400]),
                              const SizedBox(height: 12),
                              const Text(
                                'Semua Nota Sudah Lunas!',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tidak ada transaksi dengan sisa DP saat ini.',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _filteredList.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 54, color: Colors.grey),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nota dengan ID "$_searchQuery" tidak ditemukan',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 24 : 16,
                                vertical: 12,
                              ),
                              itemCount: _filteredList.length,
                              itemBuilder: (context, index) {
                                final row = _filteredList[index];
                                final receiptNumber = row['receiptNumber'] as String? ?? '';
                                final total = (row['total'] as num?)?.toDouble() ?? 0.0;
                                final dp = (row['downPayment'] as num?)?.toDouble() ?? 0.0;
                                final remaining = (total - dp) > 0 ? (total - dp) : 0.0;
                                final shiftIndex = row['shift_index'] ?? 1;
                                final customerPhone = row['customer_phone'] as String?;

                                String formattedDate = '';
                                try {
                                  final date = DateTime.parse(row['date'] as String);
                                  formattedDate =
                                      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                                } catch (_) {
                                  formattedDate = row['date'] as String? ?? '';
                                }

                                int itemCount = 0;
                                try {
                                  final itemsJson = jsonDecode(row['itemsJson'] as String) as List<dynamic>;
                                  itemCount = itemsJson.length;
                                } catch (_) {}

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => HistoryDetailScreen(historyRow: row),
                                        ),
                                      );
                                      _loadUnpaidReceipts();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Baris Header Nota
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    receiptNumber,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'BELUM LUNAS',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'SHIFT $shiftIndex',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFCC0000),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          // Tanggal, Jumlah Item & No HP
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 12,
                                            runSpacing: 4,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.access_time, size: 13, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text(formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                ],
                                              ),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.shopping_bag_outlined, size: 13, color: Colors.grey),
                                                  const SizedBox(width: 4),
                                                  Text('$itemCount item', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                                ],
                                              ),
                                              if (customerPhone != null && customerPhone.trim().isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.phone_android_rounded, size: 13, color: Colors.green),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        customerPhone.trim(),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.green[800],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const Divider(height: 18),
                                          // Rincian Pembayaran & Tombol Lunasi
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Text('Total: ', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                                        Text(
                                                          CurrencyFormatter.formatRupiah(total),
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        const Text('DP: ', style: TextStyle(fontSize: 12, color: Colors.blueAccent)),
                                                        Text(
                                                          CurrencyFormatter.formatRupiah(dp),
                                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        const Text(
                                                          'SISA: ',
                                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
                                                        ),
                                                        Text(
                                                          CurrencyFormatter.formatRupiah(remaining),
                                                          style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFCC0000),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton.icon(
                                                onPressed: () => _handleSettle(row),
                                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                                label: const Text('LUNASI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green[700],
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
