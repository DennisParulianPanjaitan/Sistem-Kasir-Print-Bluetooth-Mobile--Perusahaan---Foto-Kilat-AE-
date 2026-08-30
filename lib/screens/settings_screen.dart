import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/product.dart';
import '../widgets/receipt_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _headerController = TextEditingController();
  final _footerController = TextEditingController();
  final _copiesController = TextEditingController(text: '1');
  bool _isLoading = true;

  int _shiftCount = 1;
  final List<TimeOfDay> _shiftStarts = List.filled(5, const TimeOfDay(hour: 0, minute: 0));
  final List<TimeOfDay> _shiftEnds = List.filled(5, const TimeOfDay(hour: 23, minute: 59));

  final Receipt _dummyReceipt = Receipt(
    receiptNumber: '#000001',
    date: DateTime.now(),
    items: [
      ReceiptItem(product: Product(name: 'Cetak Foto 4R', price: 5000), quantity: 3),
      ReceiptItem(product: Product(name: 'Cetak Banner', price: 75000), quantity: 1),
      ReceiptItem(product: Product(name: 'Laminating A4', price: 8000), quantity: 2),
    ],
    total: 106000,
  );

  @override
  void initState() {
    super.initState();
    _loadSettings();

    _headerController.addListener(() => setState(() {}));
    _footerController.addListener(() => setState(() {}));
  }

  Future<void> _loadSettings() async {
    final header = await DatabaseService.instance.getSetting('header', '');
    final footer = await DatabaseService.instance.getSetting('footer', '');
    final copies = await DatabaseService.instance.getSetting('print_copies', '1');
    final shiftCountStr = await DatabaseService.instance.getSetting('shift_count', '1');

    if (mounted) {
      setState(() {
        _headerController.text = header.replaceAll('\\n', '\n');
        _footerController.text = footer.replaceAll('\\n', '\n');
        _copiesController.text = copies;
        _shiftCount = int.tryParse(shiftCountStr) ?? 1;
      });
    }

    for (int i = 0; i < 5; i++) {
      final startStr = await DatabaseService.instance.getSetting('shift_${i + 1}_start', '00:00');
      final endStr = await DatabaseService.instance.getSetting('shift_${i + 1}_end', '23:59');

      try {
        final startParts = startStr.split(':');
        final endParts = endStr.split(':');
        if (mounted) {
          setState(() {
            _shiftStarts[i] = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
            _shiftEnds[i] = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
          });
        }
      } catch (e) {
        // fallback to default
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await DatabaseService.instance.saveSetting('header', _headerController.text);
      await DatabaseService.instance.saveSetting('footer', _footerController.text);
      await DatabaseService.instance.saveSetting('print_copies', _copiesController.text);
      await DatabaseService.instance.saveSetting('shift_count', _shiftCount.toString());

      for (int i = 0; i < _shiftCount; i++) {
        final startStr = '${_shiftStarts[i].hour.toString().padLeft(2, '0')}:${_shiftStarts[i].minute.toString().padLeft(2, '0')}';
        final endStr = '${_shiftEnds[i].hour.toString().padLeft(2, '0')}:${_shiftEnds[i].minute.toString().padLeft(2, '0')}';
        await DatabaseService.instance.saveSetting('shift_${i + 1}_start', startStr);
        await DatabaseService.instance.saveSetting('shift_${i + 1}_end', endStr);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Pengaturan berhasil disimpan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _headerController.dispose();
    _footerController.dispose();
    _copiesController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final initialTime = isStart ? _shiftStarts[index] : _shiftEnds[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFCC0000),
              ),
            ),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _shiftStarts[index] = picked;
        } else {
          _shiftEnds[index] = picked;
        }
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: _buildSettingsList(),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 1),
                        Expanded(
                          flex: 2,
                          child: Column(
                            children: [
                              _buildPreviewLabel(),
                              Expanded(child: _buildPreviewWidget()),
                              _buildSaveButton(),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        ..._buildSettingsList(),
                        const Divider(height: 48, thickness: 1),
                        _buildPreviewLabel(),
                        const SizedBox(height: 16),
                        _buildPreviewWidget(),
                        const SizedBox(height: 16),
                        _buildSaveButton(),
                      ],
                    );
                  }
                },
              ),
            ),
    );
  }

  List<Widget> _buildSettingsList() {
    return [
      _sectionLabel(icon: Icons.access_time, label: 'Pengaturan Shift Omset'),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _boxDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Jumlah Shift per Hari:', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _shiftCount,
                  items: [1, 2, 3, 4, 5]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e Shift')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _shiftCount = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < _shiftCount; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 60, child: Text('Shift ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i, true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text(_formatTime(_shiftStarts[i]))),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-')),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickTime(i, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Center(child: Text(_formatTime(_shiftEnds[i]))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _sectionLabel(icon: Icons.title, label: 'Teks Header (Nama Toko & Alamat)'),
      const SizedBox(height: 8),
      Container(
        decoration: _boxDecoration(),
        child: TextFormField(
          controller: _headerController,
          maxLines: 6,
          style: const TextStyle(fontSize: 15),
          decoration: _inputDecoration('Contoh:\nFOTO KILAT AE\nJl. Merdeka No. 17'),
          validator: (v) => v == null || v.isEmpty ? 'Header tidak boleh kosong' : null,
        ),
      ),
      const SizedBox(height: 24),
      _sectionLabel(icon: Icons.format_align_center, label: 'Teks Footer (Pesan di Bawah Struk)'),
      const SizedBox(height: 8),
      Container(
        decoration: _boxDecoration(),
        child: TextFormField(
          controller: _footerController,
          maxLines: 4,
          style: const TextStyle(fontSize: 15),
          decoration: _inputDecoration('Contoh: Terima kasih!'),
        ),
      ),
      const SizedBox(height: 24),
      _sectionLabel(icon: Icons.print, label: 'Default Jumlah Print (Lembar)'),
      const SizedBox(height: 8),
      Container(
        decoration: _boxDecoration(),
        child: TextFormField(
          controller: _copiesController,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 15),
          decoration: _inputDecoration('Contoh: 1 atau 2'),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Jumlah tidak boleh kosong';
            if (int.tryParse(v) == null || int.parse(v) <= 0) return 'Harus angka > 0';
            return null;
          },
        ),
      ),
    ];
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(16),
    );
  }

  Widget _buildPreviewLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: _sectionLabel(
        icon: Icons.visibility,
        label: 'Preview Langsung',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text('● LIVE', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildPreviewWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ReceiptWidget(
              receipt: _dummyReceipt,
              headerText: _headerController.text.isEmpty ? '(Header belum diisi)' : _headerController.text,
              footerText: _footerController.text.isEmpty ? '(Footer belum diisi)' : _footerController.text,
              imagePath: 'assets/images/logopreview.png',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save_rounded),
          label: const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: const Color(0xFFCC0000),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 3,
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel({required IconData icon, required String label, Widget? trailing}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFCC0000).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFFCC0000)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))),
        if (trailing != null) trailing,
      ],
    );
  }
}
