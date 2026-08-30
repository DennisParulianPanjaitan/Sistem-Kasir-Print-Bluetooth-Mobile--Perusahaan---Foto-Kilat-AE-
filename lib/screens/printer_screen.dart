import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../services/database_service.dart';

class PrinterScreen extends StatefulWidget {
  const PrinterScreen({super.key});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen> {
  List<BluetoothInfo> _devices = [];
  bool _isScanning = false;
  String _connectionStatus = 'Belum terhubung';
  String _savedMacAddress = '';

  @override
  void initState() {
    super.initState();
    _loadSavedPrinter();
    _scanDevices();
  }

  Future<void> _loadSavedPrinter() async {
    final mac = await DatabaseService.instance.getSetting('printer_mac', '');
    if (mounted) {
      setState(() {
        _savedMacAddress = mac;
        if (mac.isNotEmpty) {
          _connectionStatus = 'Printer tersimpan: $mac';
        }
      });
    }
  }

  Future<void> _scanDevices() async {
    setState(() {
      _isScanning = true;
    });

    try {
      final List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;
      setState(() {
        _devices = devices;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencari Bluetooth: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _connectAndSave(BluetoothInfo device) async {
    setState(() {
      _connectionStatus = 'Menghubungkan ke ${device.name}...';
    });
    
    try {
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      if (result) {
        // Simpan MAC address ke database
        await DatabaseService.instance.saveSetting('printer_mac', device.macAdress);
        
        setState(() {
          _savedMacAddress = device.macAdress;
          _connectionStatus = 'Berhasil terhubung ke ${device.name}!';
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Printer berhasil disimpan dan dikoneksikan!'), backgroundColor: Colors.green)
          );
        }
      } else {
        setState(() {
          _connectionStatus = 'Gagal terhubung ke ${device.name}';
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Printer Bluetooth'),
        backgroundColor: const Color(0xFFCC0000),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _scanDevices,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: Colors.grey[200],
            child: Text(
              _connectionStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: _devices.isEmpty && !_isScanning
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'Tidak ada printer Bluetooth yang ditemukan. Pastikan Bluetooth aktif dan printer sudah di-pairing (dipasangkan) ke HP ini di pengaturan Android Anda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      final isSaved = device.macAdress == _savedMacAddress;
                      
                      return ListTile(
                        leading: Icon(Icons.print, color: isSaved ? Colors.green : const Color(0xFFCC0000)),
                        title: Text(device.name, style: TextStyle(fontWeight: isSaved ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(device.macAdress),
                        trailing: isSaved 
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : ElevatedButton(
                              onPressed: () => _connectAndSave(device),
                              child: const Text('KONEK & SIMPAN'),
                            ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
