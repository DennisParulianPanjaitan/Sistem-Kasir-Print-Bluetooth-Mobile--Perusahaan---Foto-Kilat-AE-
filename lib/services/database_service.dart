import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/product.dart';
import '../models/receipt.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('foto_kilat_ae.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE print_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receiptNumber TEXT NOT NULL,
          date TEXT NOT NULL,
          total REAL NOT NULL,
          itemsJson TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Menambahkan kolom diskon untuk histori nota
      await db.execute('ALTER TABLE print_history ADD COLUMN discountPercent REAL DEFAULT 0');
      await db.execute('ALTER TABLE print_history ADD COLUMN discountAmount REAL DEFAULT 0');
      await db.execute('ALTER TABLE print_history ADD COLUMN subtotalBeforeDiscount REAL DEFAULT 0');
    }
    if (oldVersion < 4) {
      // Menambahkan kolom shift dan logical_date
      await db.execute('ALTER TABLE print_history ADD COLUMN shift_index INTEGER DEFAULT 1');
      await db.execute('ALTER TABLE print_history ADD COLUMN logical_date TEXT');
      await db.execute("UPDATE print_history SET logical_date = substr(date, 1, 10) WHERE logical_date IS NULL");
    }
  }

  Future _createDB(Database db, int version) async {
    // Create products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL
      )
    ''');
    
    // Create settings table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    
    // Create print_history table for fresh installs
    await db.execute('''
      CREATE TABLE print_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receiptNumber TEXT NOT NULL,
        date TEXT NOT NULL,
        total REAL NOT NULL,
        itemsJson TEXT NOT NULL,
        discountPercent REAL DEFAULT 0,
        discountAmount REAL DEFAULT 0,
        subtotalBeforeDiscount REAL DEFAULT 0,
        shift_index INTEGER DEFAULT 1,
        logical_date TEXT NOT NULL
      )
    ''');
    
    // Seed initial dummy data for products
    await db.execute('''
      INSERT INTO products (name, price) VALUES 
      ('Barang A', 100000),
      ('Barang Panjang', 250000),
      ('Barang C', 300000),
      ('Barang Spesial', 100000000)
    ''');
    
    // Seed initial settings
    await db.execute('''
      INSERT INTO settings (key, value) VALUES 
      ('header', 'FOTO KILAT AE\\nMenerima Pesanan Foto & Printing\\nJl. Contoh No. 123\\nTelp. 08123456789'),
      ('footer', 'Terima kasih telah berbelanja\\nBarang yang sudah dibeli tidak dapat dikembalikan')
    ''');
  }

  // --- Product CRUD ---
  
  Future<Product> createProduct(Product product) async {
    final db = await instance.database;
    final id = await db.insert('products', product.toMap());
    return Product(id: id, name: product.name, price: product.price);
  }

  Future<List<Product>> readAllProducts() async {
    final db = await instance.database;
    final result = await db.query('products', orderBy: 'id ASC');
    return result.map((json) => Product.fromMap(json)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> deleteProduct(int id) async {
    final db = await instance.database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // --- Settings & Receipt Logic ---

  Future<String> getSetting(String key, String defaultValue) async {
    final db = await instance.database;
    final result = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return defaultValue;
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await instance.database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String> generateNextReceiptNumber() async {
    final now = DateTime.now();

    // Baca tanggal reset yang dikonfigurasi (default: 1)
    final resetDayStr = await getSetting('reset_day', '1');
    final resetDay = int.tryParse(resetDayStr) ?? 1;

    // Format periode berdasarkan tanggal reset:
    // Jika tanggal sekarang >= resetDay → periode bulan ini
    // Jika tanggal sekarang < resetDay → masih periode bulan lalu
    DateTime periodStart;
    if (now.day >= resetDay) {
      periodStart = DateTime(now.year, now.month, resetDay);
    } else {
      // Masih di periode bulan lalu
      final lastMonth = DateTime(now.year, now.month - 1, resetDay);
      periodStart = lastMonth;
    }
    final currentPeriod = '${periodStart.year}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}';

    // Cek apakah periode sudah berganti
    final lastResetMonth = await getSetting('last_reset_month', '');
    if (lastResetMonth != currentPeriod) {
      // Periode baru → reset nomor nota ke 0
      await saveSetting('last_receipt_number', '0');
      await saveSetting('last_reset_month', currentPeriod);
    }

    // Baca nomor terakhir dan generate nomor berikutnya
    final lastNumberStr = await getSetting('last_receipt_number', '0');
    int lastNumber = int.tryParse(lastNumberStr) ?? 0;
    int nextNumber = lastNumber + 1;

    // Format dengan leading zeros, e.g. #000001
    return '#${nextNumber.toString().padLeft(6, '0')}';
  }

  // --- History Logic ---

  Future<Map<String, dynamic>> getCurrentShiftInfo(DateTime time) async {
    final shiftCountStr = await getSetting('shift_count', '1');
    final shiftCount = int.tryParse(shiftCountStr) ?? 1;

    for (int i = 1; i <= shiftCount; i++) {
      final startStr = await getSetting('shift_${i}_start', '00:00');
      final endStr = await getSetting('shift_${i}_end', '23:59');

      try {
        final startParts = startStr.split(':');
        final endParts = endStr.split(':');
        
        final startH = int.parse(startParts[0]);
        final startM = int.parse(startParts[1]);
        final endH = int.parse(endParts[0]);
        final endM = int.parse(endParts[1]);

        final startMinutes = startH * 60 + startM;
        final endMinutes = endH * 60 + endM;
        final currentMinutes = time.hour * 60 + time.minute;

        if (startMinutes <= endMinutes) {
          // Normal shift (e.g., 06:00 to 15:00)
          if (currentMinutes >= startMinutes && currentMinutes < endMinutes) {
            return {
              'shift_index': i,
              'logical_date': '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}'
            };
          }
        } else {
          // Overnight shift (e.g., 22:00 to 06:00)
          if (currentMinutes >= startMinutes) {
            // Night part, logical date is today
            return {
              'shift_index': i,
              'logical_date': '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}'
            };
          } else if (currentMinutes < endMinutes) {
            // Morning part (after midnight), logical date is YESTERDAY
            final yesterday = time.subtract(const Duration(days: 1));
            return {
              'shift_index': i,
              'logical_date': '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}'
            };
          }
        }
      } catch (e) {
        // Fallback on parse error
        continue;
      }
    }

    // Default if not matched
    return {
      'shift_index': 1,
      'logical_date': '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}'
    };
  }

  Future<void> saveHistory(Receipt receipt) async {
    final db = await instance.database;
    
    // Convert items to JSON string for easy storage
    final itemsList = receipt.items.map((e) => {
      'name': e.product.name,
      'price': e.product.price,
      'quantity': e.quantity,
      'subtotal': e.subtotal,
    }).toList();

    final shiftInfo = await getCurrentShiftInfo(receipt.date);

    await db.insert('print_history', {
      'receiptNumber': receipt.receiptNumber,
      'date': receipt.date.toIso8601String(),
      'total': receipt.total,
      'itemsJson': jsonEncode(itemsList),
      'discountPercent': receipt.discountPercent,
      'discountAmount': receipt.discountAmount,
      'subtotalBeforeDiscount': receipt.subtotalBeforeDiscount,
      'shift_index': shiftInfo['shift_index'],
      'logical_date': shiftInfo['logical_date'],
    });

    // Update last receipt number
    final cleanReceiptNumber = receipt.receiptNumber.replaceAll('#', '');
    await saveSetting('last_receipt_number', int.parse(cleanReceiptNumber).toString());
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    return await db.query('print_history', orderBy: 'id DESC');
  }

  // Mengambil daftar tanggal unik dan total omset per tanggal
  Future<List<Map<String, dynamic>>> getDailyOmsetSummary() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT logical_date, SUM(total) as daily_omset 
      FROM print_history 
      GROUP BY logical_date 
      ORDER BY logical_date DESC
    ''');
    return result;
  }

  // Mengambil history untuk tanggal tertentu saja
  Future<List<Map<String, dynamic>>> getHistoryByDate(String logicalDate) async {
    final db = await instance.database;
    return await db.query(
      'print_history', 
      where: 'logical_date = ?', 
      whereArgs: [logicalDate],
      orderBy: 'id DESC'
    );
  }

  // Mengambil total omset dipecah per shift untuk tanggal tertentu
  Future<List<Map<String, dynamic>>> getShiftOmsetByDate(String logicalDate) async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT shift_index, SUM(total) as shift_omset 
      FROM print_history 
      WHERE logical_date = ?
      GROUP BY shift_index 
      ORDER BY shift_index ASC
    ''', [logicalDate]);
  }

  Future<void> deleteHistory(int id) async {
    final db = await instance.database;
    await db.delete('print_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteHistoryByDate(String logicalDate) async {
    final db = await instance.database;
    await db.delete('print_history', where: 'logical_date = ?', whereArgs: [logicalDate]);
  }

  Future<void> clearAllHistory() async {
    final db = await instance.database;
    await db.delete('print_history');
  }
}
