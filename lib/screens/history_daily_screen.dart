import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../utils/currency_formatter.dart';
import 'history_detail_screen.dart';

class HistoryDailyScreen extends StatefulWidget {
  final String logicalDate; // format: YYYY-MM-DD
  final bool isFinished; // if all shifts for this day are finished

  const HistoryDailyScreen({
    super.key,
    required this.logicalDate,
    required this.isFinished,
  });

  @override
  State<HistoryDailyScreen> createState() => _HistoryDailyScreenState();
}

class _HistoryDailyScreenState extends State<HistoryDailyScreen> {
  List<Map<String, dynamic>> _historyItems = [];
  List<Map<String, dynamic>> _shiftOmsets = [];
  bool _isLoading = true;
  double _totalDailyOmset = 0;
  bool _isOmsetHidden = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final items = await DatabaseService.instance.getHistoryByDate(widget.logicalDate);
    final shifts = await DatabaseService.instance.getShiftOmsetByDate(widget.logicalDate);

    double total = 0;
    for (var shift in shifts) {
      total += (shift['shift_omset'] as num).toDouble();
    }

    if (mounted) {
      setState(() {
        _historyItems = items;
        _shiftOmsets = shifts;
        _totalDailyOmset = total;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteHistory(Map<String, dynamic> row) async {
    final passwordController = TextEditingController();
    bool _obscure = true;
    
    final isPasswordCorrect = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Color(0xFFD32F2F)),
                  SizedBox(width: 8),
                  Text('Password Hapus'),
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordController.text == '122333') {
                      Navigator.pop(context, true);
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
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('LANJUT'),
                ),
              ],
            );
          },
        );
      },
    );

    if (isPasswordCorrect != true) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat?'),
        content: Text('Data nota ${row['receiptNumber']} akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
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
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteHistory(row['id'] as int);
      _loadData();
    }
  }

  Future<void> _clearAllDataForDay() async {
    final passwordController = TextEditingController();
    bool _obscure = true;
    
    final isPasswordCorrect = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Color(0xFFD32F2F)),
                  SizedBox(width: 8),
                  Text('Password Hapus'),
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
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (passwordController.text == '122333') {
                      Navigator.pop(context, true);
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
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('LANJUT'),
                ),
              ],
            );
          },
        );
      },
    );

    if (isPasswordCorrect != true) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hapus Data Hari Ini?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Anda akan menghapus SEMUA nota transaksi pada tanggal ${_formatDisplayDate()} secara permanen.\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever),
            label: const Text('HAPUS SEMUA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteHistoryByDate(widget.logicalDate);
      if (mounted) {
        Navigator.pop(context); // Kembali ke kalender
      }
    }
  }

  String _formatDisplayDate() {
    try {
      final parts = widget.logicalDate.split('-');
      final y = parts[0];
      final m = parts[1];
      final d = parts[2];
      
      const months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      
      return '$d ${months[int.parse(m)]} $y';
    } catch (e) {
      return widget.logicalDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('Rekap ${_formatDisplayDate()}'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- KOTAK REKAP SHIFT ---
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: widget.isFinished 
                        ? Border.all(color: Colors.green, width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'TOTAL KESELURUHAN',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          IconButton(
                            icon: Icon(
                              _isOmsetHidden ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _isOmsetHidden = !_isOmsetHidden;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _isOmsetHidden ? '*****' : CurrencyFormatter.formatRupiah(_totalDailyOmset),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFCC0000),
                          ),
                        ),
                      ),
                      const Divider(height: 24, thickness: 1),
                      // Rincian per shift
                      if (_shiftOmsets.isEmpty)
                        const Text('Belum ada omset', style: TextStyle(color: Colors.grey))
                      else
                        ..._shiftOmsets.map((shift) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Omset Shift ${shift['shift_index']}',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  _isOmsetHidden 
                                      ? '***' 
                                      : CurrencyFormatter.formatRupiah((shift['shift_omset'] as num).toDouble()),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                // --- LIST NOTA HARI INI ---
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Daftar Transaksi',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                  ),
                ),
                
                Expanded(
                  child: _historyItems.isEmpty
                      ? const Center(
                          child: Text('Tidak ada transaksi di hari ini.', style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: _historyItems.length,
                          itemBuilder: (context, index) {
                            final row = _historyItems[index];
                            final itemsJson = jsonDecode(row['itemsJson'] as String) as List<dynamic>;
                            final date = DateTime.parse(row['date'] as String);
                            final formattedTime = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                            final shiftIndex = row['shift_index'] ?? 1;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => HistoryDetailScreen(historyRow: row),
                                    ),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Ikon Shift
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Text('SHIFT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFCC0000))),
                                            Text('$shiftIndex', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFCC0000))),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Info Transaksi
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  row['receiptNumber'] as String,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                                ),
                                                if (((row['downPayment'] as num?)?.toDouble() ?? 0) > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blueAccent.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text(
                                                      'DP',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.blueAccent,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                const SizedBox(width: 4),
                                                Text(formattedTime, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text('${itemsJson.length} item', style: const TextStyle(fontSize: 12)),
                                          ],
                                        ),
                                      ),

                                      // Harga & Hapus
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _isOmsetHidden ? '***' : CurrencyFormatter.formatRupiah((row['total'] as num).toDouble()),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFCC0000),
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (((row['downPayment'] as num?)?.toDouble() ?? 0) > 0) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              _isOmsetHidden
                                                  ? 'DP: ***'
                                                  : 'DP: ${CurrencyFormatter.formatRupiah(((row['downPayment'] as num?)?.toDouble() ?? 0))}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blueAccent,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          InkWell(
                                            onTap: () => _deleteHistory(row),
                                            borderRadius: BorderRadius.circular(4),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child: Icon(Icons.delete_outline, color: Colors.grey, size: 20),
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
      bottomNavigationBar: _historyItems.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _clearAllDataForDay,
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'CLEAR ALL DATA',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F), // Merah gelap
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 8,
                    shadowColor: Colors.redAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
    );
  }
}
