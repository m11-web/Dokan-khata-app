import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'domain.dart';

class KhataDatabase {
  KhataDatabase._();

  static final KhataDatabase instance = KhataDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database case final Database database) return database;
    final directory = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      p.join(directory.path, 'hamza_poultry_khata.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            phone TEXT NOT NULL DEFAULT '',
            opening_balance INTEGER NOT NULL DEFAULT 0,
            fixed_less INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE daily_settings (
            date TEXT PRIMARY KEY,
            is_locked INTEGER NOT NULL DEFAULT 0,
            supply_rate INTEGER NOT NULL DEFAULT 0,
            load_3152_grams INTEGER NOT NULL DEFAULT 0,
            load_6540_grams INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            date TEXT NOT NULL,
            vehicle_3152_grams INTEGER NOT NULL DEFAULT 0,
            vehicle_6540_grams INTEGER NOT NULL DEFAULT 0,
            cash_received INTEGER NOT NULL DEFAULT 0,
            less_override INTEGER,
            is_naga INTEGER NOT NULL DEFAULT 0,
            UNIQUE(customer_id, date)
          )
        ''');
        await db.execute(
          'CREATE TABLE app_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute('CREATE INDEX entries_date_idx ON entries(date)');
      },
    );
    _database = db;
    return db;
  }

  Future<void> seedIfEmpty() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM customers'),
    );
    if (count != 0) return;
    final names = ['گلو بھائی', 'وقاص', 'فاروق', 'فرحان', 'حسیب'];
    await db.transaction((txn) async {
      for (var index = 0; index < names.length; index++) {
        await txn.insert('customers', {
          'name': names[index],
          'phone': '',
          'opening_balance': 0,
          'fixed_less': 45,
          'sort_order': index,
          'is_active': 1,
        });
      }
    });
  }

  Future<List<Customer>> getCustomers({bool activeOnly = false}) async {
    final db = await database;
    final rows = await db.query(
      'customers',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order, name COLLATE NOCASE',
    );
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> saveCustomer(Customer customer) async {
    final db = await database;
    if (customer.id == 0) {
      final values = customer.toMap()..remove('id');
      return db.insert('customers', values);
    }
    return db.update(
      'customers',
      customer.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<void> saveCustomerOrder(List<Customer> customers) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var i = 0; i < customers.length; i++) {
        await txn.update(
          'customers',
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [customers[i].id],
        );
      }
    });
  }

  Future<DailyConfig> getOrCreateConfig(String date) async {
    final db = await database;
    final rows = await db.query(
      'daily_settings',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );
    if (rows.isNotEmpty) return DailyConfig.fromMap(rows.first);
    final config = DailyConfig(
      date: date,
      isLocked: false,
      supplyRate: 0,
      load3152Grams: 0,
      load6540Grams: 0,
    );
    await db.insert('daily_settings', config.toMap());
    return config;
  }

  Future<void> saveConfig(DailyConfig config) async {
    final db = await database;
    await db.insert(
      'daily_settings',
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DailyEntry>> getEntries({String? date}) async {
    final db = await database;
    final rows = await db.query(
      'entries',
      where: date == null ? null : 'date = ?',
      whereArgs: date == null ? null : [date],
      orderBy: 'date, id',
    );
    return rows.map(DailyEntry.fromMap).toList();
  }

  Future<void> saveEntry(DailyEntry entry) async {
    final db = await database;
    final values = entry.toMap()..remove('id');
    final existing = await db.query(
      'entries',
      columns: ['id'],
      where: 'customer_id = ? AND date = ?',
      whereArgs: [entry.customerId, entry.date],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('entries', values);
    } else {
      await db.update(
        'entries',
        values,
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    }
  }

  Future<List<DailyConfig>> getConfigs() async {
    final db = await database;
    final rows = await db.query('daily_settings', orderBy: 'date');
    return rows.map(DailyConfig.fromMap).toList();
  }

  Future<void> deleteEmptyEntry(int customerId, String date) async {
    final db = await database;
    await db.delete(
      'entries',
      where: 'customer_id = ? AND date = ?',
      whereArgs: [customerId, date],
    );
  }

  Future<Map<String, String>> getAppSettings() async {
    final db = await database;
    final rows = await db.query('app_settings');
    return {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
  }

  Future<void> saveAppSettings(Map<String, String> settings) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final setting in settings.entries) {
        await txn.insert('app_settings', {
          'key': setting.key,
          'value': setting.value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<Map<String, Object?>> exportAll() async {
    final db = await database;
    return {
      'version': 1,
      'customers': await db.query('customers'),
      'daily_settings': await db.query('daily_settings'),
      'entries': await db.query('entries'),
      'app_settings': await db.query('app_settings'),
    };
  }

  Future<void> importAll(Map<String, Object?> backup) async {
    final db = await database;
    final customers = backup['customers']! as List;
    final dailySettings = backup['daily_settings']! as List;
    final entries = backup['entries']! as List;
    final appSettings = backup['app_settings']! as List;
    await db.transaction((txn) async {
      await txn.delete('entries');
      await txn.delete('daily_settings');
      await txn.delete('customers');
      await txn.delete('app_settings');
      for (final row in customers) {
        await txn.insert('customers', Map<String, Object?>.from(row as Map));
      }
      for (final row in dailySettings) {
        await txn.insert(
          'daily_settings',
          Map<String, Object?>.from(row as Map),
        );
      }
      for (final row in entries) {
        await txn.insert('entries', Map<String, Object?>.from(row as Map));
      }
      for (final row in appSettings) {
        await txn.insert('app_settings', Map<String, Object?>.from(row as Map));
      }
    });
  }
}
