import 'package:flutter/material.dart';
import '../services/database_service.dart';
import 'history_daily_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> _omsetSummary = [];
  bool _isLoading = true;
  String _currentLogicalDate = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Dapatkan logical date hari ini untuk menentukan warna kotak
    final shiftInfo = await DatabaseService.instance.getCurrentShiftInfo(DateTime.now());
    _currentLogicalDate = shiftInfo['logical_date'] as String;

    final summary = await DatabaseService.instance.getDailyOmsetSummary();

    if (mounted) {
      setState(() {
        _omsetSummary = summary;
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  // --- SEEDER DUMMY DATA UNTUK DEMO KLIEN ---
  Future<void> _seedDummyData() async {
    final db = await DatabaseService.instance.database;
    final batch = db.batch();
    
    // Transaksi Shift 1 (Pagi)
    batch.insert('print_history', {
      'receiptNumber': '#000001',
      'date': '2026-08-31T09:15:00',
      'total': 15000,
      'itemsJson': '[{"name":"Cetak Foto 4R","price":5000,"quantity":3,"subtotal":15000}]',
      'discountPercent': 0,
      'discountAmount': 0,
      'subtotalBeforeDiscount': 15000,
      'shift_index': 1,
      'logical_date': '2026-08-31',
    });

    batch.insert('print_history', {
      'receiptNumber': '#000002',
      'date': '2026-08-31T11:30:00',
      'total': 30000,
      'itemsJson': '[{"name":"Pas Foto 3x4","price":15000,"quantity":2,"subtotal":30000}]',
      'discountPercent': 0,
      'discountAmount': 0,
      'subtotalBeforeDiscount': 30000,
      'shift_index': 1,
      'logical_date': '2026-08-31',
    });

    // Transaksi Shift 2 (Siang-Sore)
    batch.insert('print_history', {
      'receiptNumber': '#000003',
      'date': '2026-08-31T14:45:00',
      'total': 150000,
      'itemsJson': '[{"name":"Cetak Banner 2x1","price":150000,"quantity":1,"subtotal":150000}]',
      'discountPercent': 0,
      'discountAmount': 0,
      'subtotalBeforeDiscount': 150000,
      'shift_index': 2,
      'logical_date': '2026-08-31',
    });

    // Transaksi Shift 3 (Malam)
    batch.insert('print_history', {
      'receiptNumber': '#000004',
      'date': '2026-08-31T19:20:00',
      'total': 8000,
      'itemsJson': '[{"name":"Print Dokumen HVS","price":1000,"quantity":8,"subtotal":8000}]',
      'discountPercent': 0,
      'discountAmount': 0,
      'subtotalBeforeDiscount': 8000,
      'shift_index': 3,
      'logical_date': '2026-08-31',
    });

    await batch.commit();
    _loadData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dummy Data 31 Agustus berhasil ditambahkan!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _clearAllHistory() async {
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
                'Hapus Semua Riwayat?',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'Anda akan menghapus SEMUA transaksi secara permanen.\n\nTindakan ini tidak dapat dibatalkan.',
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
      await DatabaseService.instance.clearAllHistory();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua riwayat berhasil dihapus.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  String _getMonthName(int month) {
    const months = [
      '', 'JANUARI', 'FEBRUARI', 'MARET', 'APRIL', 'MEI', 'JUNI',
      'JULI', 'AGUSTUS', 'SEPTEMBER', 'OKTOBER', 'NOVEMBER', 'DESEMBER'
    ];
    return months[month];
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 12) {
      return DateTime(year + 1, 1, 0).day;
    }
    return DateTime(year, month + 1, 0).day;
  }

  bool _isFinished(String cellDate) {
    // Jika cellDate < _currentLogicalDate, maka sudah selesai (Hijau)
    return cellDate.compareTo(_currentLogicalDate) < 0;
  }

  double _getOmsetForDate(String date) {
    try {
      final record = _omsetSummary.firstWhere((element) => element['logical_date'] == date);
      return (record['daily_omset'] as num).toDouble();
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = _getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfWeek = _currentMonth.weekday; // 1 = Senin, 7 = Minggu

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Riwayat Kalender'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- KONTROL BULAN ---
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
                        onPressed: _previousMonth,
                      ),
                      Text(
                        '${_getMonthName(_currentMonth.month)} ${_currentMonth.year}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.black87),
                        onPressed: _nextMonth,
                      ),
                    ],
                  ),
                ),

                // --- GRID KALENDER Tanpa Nama Hari ---
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsif: Batasi lebar agar rapi di tablet
                      final maxWidth = constraints.maxWidth > 600 ? 600.0 : constraints.maxWidth;
                      
                      return Center(
                        child: SizedBox(
                          width: maxWidth,
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: 1.0,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: daysInMonth,
                            itemBuilder: (context, index) {
                              final day = index + 1;
                              final cellLogicalDate = '${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                              
                              final omset = _getOmsetForDate(cellLogicalDate);
                              final hasData = omset > 0;
                              final isFinished = _isFinished(cellLogicalDate);

                              // Penentuan Warna Kotak
                              Color boxColor;
                              if (isFinished) {
                                boxColor = hasData ? Colors.green.shade600 : Colors.green.shade200;
                              } else {
                                boxColor = Colors.grey.shade400;
                                // Jika hari ini, beri penanda warna sedikit berbeda agar jelas
                                if (cellLogicalDate == _currentLogicalDate) {
                                  boxColor = const Color(0xFFCC0000).withValues(alpha: 0.6);
                                }
                              }

                              // Hanya tanggal di masa depan yang tidak bisa diklik
                              final isClickable = cellLogicalDate.compareTo(_currentLogicalDate) <= 0;

                              return InkWell(
                                onTap: isClickable
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => HistoryDailyScreen(
                                              logicalDate: cellLogicalDate,
                                              isFinished: isFinished,
                                            ),
                                          ),
                                        ).then((_) => _loadData()); // Refresh kalau ada yg dihapus
                                      }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: boxColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: cellLogicalDate == _currentLogicalDate
                                        ? Border.all(color: const Color(0xFFCC0000), width: 3)
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: maxWidth > 400 ? 18 : 16,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _omsetSummary.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: _clearAllHistory,
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
