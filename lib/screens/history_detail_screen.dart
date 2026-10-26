import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../widgets/receipt_widget.dart';
import '../utils/escpos_image_converter.dart';

class HistoryDetailScreen extends StatefulWidget {
  final Map<String, dynamic> historyRow;

  const HistoryDetailScreen({super.key, required this.historyRow});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  String _headerText = '';
  String _footerText = '';
  bool _isLoading = true;
  final GlobalKey _receiptKey = GlobalKey();
  final GlobalKey _receiptKeyShare = GlobalKey();
  final GlobalKey _receiptKeyPrint = GlobalKey();
  late Receipt _receipt;

  @override
  void initState() {
    super.initState();
    _buildReceipt();
  }

  Future<void> _buildReceipt() async {
    // Rekonstruksi objek Receipt dari data JSON yang tersimpan di history
    final itemsJson = jsonDecode(widget.historyRow['itemsJson'] as String) as List<dynamic>;
    final items = itemsJson.map((item) {
      return ReceiptItem(
        product: Product(
          name: item['name'] as String,
          price: (item['price'] as num).toDouble(),
        ),
        quantity: item['quantity'] as int,
      );
    }).toList();

    _receipt = Receipt(
      receiptNumber: widget.historyRow['receiptNumber'] as String,
      date: DateTime.parse(widget.historyRow['date'] as String),
      items: items,
      total: (widget.historyRow['total'] as num).toDouble(),
      discountPercent: (widget.historyRow['discountPercent'] as num?)?.toDouble() ?? 0.0,
      downPayment: (widget.historyRow['downPayment'] as num?)?.toDouble() ?? 0.0,
    );

    final header = await DatabaseService.instance.getSetting('header', 'FOTO KILAT AE');
    final footer = await DatabaseService.instance.getSetting('footer', 'Terima kasih!');

    if (mounted) {
      setState(() {
        _headerText = header.replaceAll('\\n', '\n');
        _footerText = footer.replaceAll('\\n', '\n');
        _isLoading = false;
      });
    }
  }

  Future<File?> _captureReceiptImage() async {
    try {
      final boundary = _receiptKeyPrint.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final cleanNumber = _receipt.receiptNumber.replaceAll('#', '');
      final file = File('${directory.path}/nota_history_$cleanNumber.png');
      await file.writeAsBytes(pngBytes);
      return file;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menangkap gambar: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
      return null;
    }
  }

  Future<void> _handleShare() async {
    try {
      final boundary = _receiptKeyShare.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();
      final directory = await getTemporaryDirectory();
      final cleanNumber = _receipt.receiptNumber.replaceAll('#', '');
      final file = File('${directory.path}/nota_share_$cleanNumber.png');
      await file.writeAsBytes(pngBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Berikut nota transaksi ${_receipt.receiptNumber} dari FOTO KILAT ae.',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal menangkap gambar: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Future<void> _handlePrint() async {
    final macAddress = await DatabaseService.instance.getSetting('printer_mac', '');

    if (macAddress.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer belum diatur! Buka menu Sidebar -> Printer / Bluetooth.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final file = await _captureReceiptImage();
    if (file == null) return;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mencetak ulang nota...')),
      );
    }

    try {
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      }
      if (connected) {
        // Konversi PNG ke ESC/POS agar printer POS bisa membaca gambar ini.
        // Jika kita kirim raw PNG bytes, printer POS akan mencetak teks acak/sampah.
        final escPosBytes = await EscPosImageConverter.convertImageToEscPos(file);
        await PrintBluetoothThermal.writeBytes(escPosBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nota berhasil dicetak ulang!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal terhubung ke printer.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: Text(_isLoading ? 'Detail Nota' : 'Detail ${_receipt.receiptNumber}'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleShare,
                        icon: const Icon(Icons.share),
                        label: const Text('BAGIKAN'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: const Color(0xFFCC0000),
                          side: const BorderSide(color: Color(0xFFCC0000)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _handlePrint,
                        icon: const Icon(Icons.print),
                        label: const Text('CETAK ULANG', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFFCC0000),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Widget tersembunyi dengan padding untuk share WA
                ClipRect(
                  child: SizedBox(
                    width: 0,
                    height: 0,
                    child: OverflowBox(
                      alignment: Alignment.topLeft,
                      maxWidth: double.infinity,
                      maxHeight: double.infinity,
                      child: RepaintBoundary(
                        key: _receiptKeyShare,
                        child: ReceiptWidget(
                          receipt: _receipt,
                          headerText: _headerText,
                          footerText: _footerText,
                          horizontalPadding: 16,
                          imagePath: 'assets/images/logopreview.png',
                        ),
                      ),
                    ),
                  ),
                ),
                // Widget tersembunyi tanpa padding untuk print
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
                          receipt: _receipt,
                          headerText: _headerText,
                          footerText: _footerText,
                          horizontalPadding: 0,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        key: _receiptKey,
                        child: ReceiptWidget(
                          receipt: _receipt,
                          headerText: _headerText,
                          footerText: _footerText,
                          horizontalPadding: 16,
                          imagePath: 'assets/images/logopreview.png',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
