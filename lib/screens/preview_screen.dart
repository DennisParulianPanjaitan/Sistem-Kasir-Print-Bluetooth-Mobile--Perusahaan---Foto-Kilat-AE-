import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../utils/escpos_image_converter.dart';
import '../models/receipt.dart';
import '../services/database_service.dart';
import '../widgets/receipt_widget.dart';

class PreviewScreen extends StatefulWidget {
  final Receipt receipt;
  final bool autoPrint;

  const PreviewScreen({super.key, required this.receipt, this.autoPrint = false});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String _headerText = '';
  String _footerText = '';
  bool _isLoading = true;
  final GlobalKey _receiptKey = GlobalKey();
  final GlobalKey _receiptKeyPrint = GlobalKey();
  final GlobalKey _receiptKeyNoLogo = GlobalKey();
  final GlobalKey _receiptKeyShare = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadSettings().then((_) {
      if (widget.autoPrint) {
        // Beri sedikit delay agar rendering selesai
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _handlePrint();
        });
      }
    });
  }

  Future<void> _loadSettings() async {
    final header = await DatabaseService.instance.getSetting(
        'header', 'FOTO KILAT AE\nJl. Contoh No. 123');
    final footer = await DatabaseService.instance.getSetting(
        'footer', 'Terima kasih telah berbelanja');

    if (mounted) {
      setState(() {
        _headerText = header.replaceAll('\\n', '\n');
        _footerText = footer.replaceAll('\\n', '\n');
        _isLoading = false;
      });
    }
  }

  Future<File?> _captureReceiptImage() async {
    return _captureReceiptImageFromKey(_receiptKeyPrint, suffix: '');
  }

  Future<File?> _captureReceiptImageFromKey(GlobalKey key, {String suffix = '_nologо'}) async {
    try {
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final cleanReceiptNumber = widget.receipt.receiptNumber.replaceAll('#', '');
      final file = File('${directory.path}/nota_$cleanReceiptNumber$suffix.png');
      
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

  bool _isSaved = false; // Flag to prevent duplicate saves

  Future<void> _saveToHistoryIfNeeded() async {
    if (!_isSaved) {
      await DatabaseService.instance.saveHistory(widget.receipt);
      _isSaved = true;
    }
  }

  Future<void> _handleShare() async {
    final file = await _captureReceiptImageFromKey(_receiptKeyShare, suffix: '_share');
    if (file != null) {
      await _saveToHistoryIfNeeded();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Berikut adalah nota transaksi Anda dari FOTO KILAT ae.',
        ),
      );
    }
  }

  Future<void> _handlePrint() async {
    // 1. Ambil MAC Address printer yang tersimpan
    final macAddress = await DatabaseService.instance.getSetting('printer_mac', '');
    
    if (macAddress.isEmpty) {
      if (mounted) {
        if (widget.autoPrint) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Printer belum diatur! Buka menu Sidebar -> Printer / Bluetooth.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    // 2. Siapkan file nota
    final file = await _captureReceiptImage();
    if (file == null) {
      if (mounted && widget.autoPrint) Navigator.pop(context);
      return;
    }

    // 3. Tampilkan loading
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mencetak nota...')),
      );
    }

    try {
      // Cek apakah sudah terhubung sebelumnya (karena di layar Printer sudah di-konek)
      bool connected = await PrintBluetoothThermal.connectionStatus;
      if (!connected) {
        // Jika belum, coba hubungkan ulang
        connected = await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      }
      
      if (connected) {
        // Konversi copy PERTAMA (dengan logo)
        final escPosBytesWithLogo = await EscPosImageConverter.convertImageToEscPos(file);
        
        // Ambil pengaturan jumlah print
        final copiesStr = await DatabaseService.instance.getSetting('print_copies', '1');
        final copies = int.tryParse(copiesStr) ?? 1;

        // Jika ada lebih dari 1 copy, siapkan juga versi TANPA LOGO
        List<int>? escPosBytesNoLogo;
        if (copies > 1) {
          // Capture versi nota tanpa logo (dari _receiptKeyNoLogo)
          final fileNoLogo = await _captureReceiptImageFromKey(_receiptKeyNoLogo);
          if (fileNoLogo != null) {
            escPosBytesNoLogo = await EscPosImageConverter.convertImageToEscPos(fileNoLogo);
          }
        }

        // 3 line feeds sebagai separator antar salinan
        final List<int> separator = [0x0A, 0x0A, 0x0A];

        // Print: copy ke-1 dengan logo, copy ke-2+ tanpa logo
        for (int i = 0; i < copies; i++) {
          if (i == 0) {
            await PrintBluetoothThermal.writeBytes(escPosBytesWithLogo);
          } else {
            // Tambah separator sebelum copy berikutnya
            await PrintBluetoothThermal.writeBytes(separator);
            await Future.delayed(const Duration(milliseconds: 300));
            await PrintBluetoothThermal.writeBytes(escPosBytesNoLogo ?? escPosBytesWithLogo);
          }
          if (i < copies - 1) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }
        
        await _saveToHistoryIfNeeded();
        
        if (mounted) {
          if (widget.autoPrint) {
            Navigator.pop(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nota berhasil dicetak $copies kali!'), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          if (widget.autoPrint) {
            Navigator.pop(context);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal terhubung ke printer. Pastikan printer menyala.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (widget.autoPrint) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error pencetakan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Widget nota tanpa logo (tersembunyi, hanya untuk di-capture saat print copy ke-2+)
    final hiddenNoLogoWidget = ClipRect(
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
              receipt: widget.receipt,
              headerText: _headerText,
              footerText: _footerText,
              showLogo: false,
            ),
          ),
        ),
      ),
    );

    // Widget nota dengan padding untuk di-share ke WA (tersembunyi tapi tetap dirender/dipaint)
    final hiddenShareWidget = ClipRect(
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
              receipt: widget.receipt,
              headerText: _headerText,
              footerText: _footerText,
              showLogo: true,
              horizontalPadding: 16,
              imagePath: 'assets/images/logopreview.png',
            ),
          ),
        ),
      ),
    );

    // Widget nota khusus untuk cetak asli printer (tanpa padding)
    final hiddenPrintWidget = ClipRect(
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
              receipt: widget.receipt,
              headerText: _headerText,
              footerText: _footerText,
              showLogo: true,
              horizontalPadding: 0,
            ),
          ),
        ),
      ),
    );

    final receiptWidgetTree = Stack(
      children: [
        hiddenNoLogoWidget,
        hiddenShareWidget,
        hiddenPrintWidget,
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
                  receipt: widget.receipt,
                  headerText: _headerText,
                  footerText: _footerText,
                  showLogo: true,
                  horizontalPadding: 16,
                  imagePath: 'assets/images/logopreview.png',
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (widget.autoPrint) {
      return Scaffold(
        backgroundColor: Colors.black54,
        body: Stack(
          children: [
            Opacity(
              opacity: 0.01,
              child: receiptWidgetTree,
            ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(color: Color(0xFFCC0000)),
                    SizedBox(height: 16),
                    Text('Mencetak nota...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Text('Preview Nota'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleShare,
                  icon: const Icon(Icons.share),
                  label: const Text('BAGIKAN'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handlePrint,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT BLUETOOTH', style: TextStyle(fontWeight: FontWeight.bold)),
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
          : receiptWidgetTree,
    );
  }
}
