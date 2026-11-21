import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'database.dart';
import 'domain.dart';

class KhataState extends ChangeNotifier {
  KhataState({KhataDatabase? database})
    : _database = database ?? KhataDatabase.instance;

  final KhataDatabase _database;
  final Map<String, String> appSettings = {};
  final Map<String, DailyConfig> _configs = {};
  List<Customer> customers = [];
  List<DailyEntry> entries = [];
  DailyConfig? config;
  String selectedDate = dateKey(DateTime.now());
  bool initialized = false;

  List<Customer> get activeCustomers =>
      customers.where((customer) => customer.isActive).toList();
  Map<String, DailyConfig> get dailyConfigs => Map.unmodifiable(_configs);

  Customer? customerById(int id) {
    for (final customer in customers) {
      if (customer.id == id) return customer;
    }
    return null;
  }

  DailyEntry? entryFor(int customerId) {
    for (final entry in entries) {
      if (entry.customerId == customerId) return entry;
    }
    return null;
  }

  DailyConfig? configFor(String date) => _configs[date];

  Future<void> initialize() async {
    await _database.seedIfEmpty();
    appSettings.addAll(await _database.getAppSettings());
    selectedDate = appSettings['working_date'] ?? selectedDate;
    await _loadData();
    initialized = true;
    notifyListeners();
  }

  Future<void> _loadData() async {
    config = await _database.getOrCreateConfig(selectedDate);
    _configs
      ..clear()
      ..addEntries(
        (await _database.getConfigs()).map((item) => MapEntry(item.date, item)),
      )
      ..[selectedDate] = config!;
    customers = await _database.getCustomers();
    entries = await _database.getEntries();
  }

  Future<void> selectDate(String date) async {
    if (config?.isLocked ?? false) {
      throw StateError('Unlock the working date before changing it.');
    }
    selectedDate = date;
    appSettings['working_date'] = date;
    await _database.saveAppSettings({'working_date': date});
    await _loadData();
    notifyListeners();
  }

  Future<void> updateConfig({
    int? supplyRate,
    int? load3152Grams,
    int? load6540Grams,
    bool? isLocked,
  }) async {
    final current = config!;
    final updated = DailyConfig(
      date: selectedDate,
      isLocked: isLocked ?? current.isLocked,
      supplyRate: supplyRate ?? current.supplyRate,
      load3152Grams: load3152Grams ?? current.load3152Grams,
      load6540Grams: load6540Grams ?? current.load6540Grams,
    );
    await _database.saveConfig(updated);
    config = updated;
    _configs[selectedDate] = updated;
    notifyListeners();
  }

  Future<void> saveEntry({
    required int customerId,
    required int vehicle3152Grams,
    required int vehicle6540Grams,
    required int cashReceived,
    required bool isNaga,
    int? lessOverride,
  }) async {
    final entry = DailyEntry(
      id: entryFor(customerId)?.id ?? 0,
      customerId: customerId,
      date: selectedDate,
      vehicle3152Grams: vehicle3152Grams,
      vehicle6540Grams: vehicle6540Grams,
      cashReceived: cashReceived,
      lessOverride: lessOverride,
      isNaga: isNaga,
    );
    if (entry.hasTransaction) {
      await _database.saveEntry(entry);
    } else {
      await _database.deleteEmptyEntry(customerId, selectedDate);
    }
    entries = await _database.getEntries();
    notifyListeners();
  }

  Future<void> saveCustomer(Customer customer) async {
    await _database.saveCustomer(customer);
    customers = await _database.getCustomers();
    notifyListeners();
  }

  Future<void> reorderCustomers(int oldIndex, int newIndex) async {
    final active = activeCustomers;
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);
    final inactive = customers.where((c) => !c.isActive).toList();
    customers = [...active, ...inactive];
    await _database.saveCustomerOrder(customers);
    customers = await _database.getCustomers();
    notifyListeners();
  }

  int previousBalance(Customer customer, String date) => balanceBefore(
    openingBalance: customer.openingBalance,
    customerId: customer.id,
    date: date,
    entries: entries,
    customer: customer,
    configs: _configs,
  );

  int closingBalanceFor(
    Customer customer,
    DailyEntry entry,
    DailyConfig dayConfig,
  ) => calculateBalanceAfter(
    previousBalance: previousBalance(customer, entry.date),
    entry: entry,
    customer: customer,
    config: dayConfig,
  );

  BusinessTotals totalsFor(String date) {
    final dayConfig = _configs[date];
    if (dayConfig == null) {
      return const BusinessTotals(
        vehicle3152Grams: 0,
        vehicle6540Grams: 0,
        sale: 0,
        cash: 0,
      );
    }
    var v3152 = 0;
    var v6540 = 0;
    var sale = 0;
    var cash = 0;
    for (final entry in entries.where((entry) => entry.date == date)) {
      final customer = customerById(entry.customerId);
      if (customer == null) continue;
      v3152 += entry.vehicle3152Grams;
      v6540 += entry.vehicle6540Grams;
      sale += entry.bill(customer, dayConfig);
      cash += entry.cashReceived;
    }
    return BusinessTotals(
      vehicle3152Grams: v3152,
      vehicle6540Grams: v6540,
      sale: sale,
      cash: cash,
    );
  }

  Future<void> saveAppSettings(Map<String, String> values) async {
    appSettings.addAll(values);
    await _database.saveAppSettings(values);
    notifyListeners();
  }

  Future<String> exportBackup() async =>
      const JsonEncoder.withIndent('  ').convert(await _database.exportAll());

  Future<void> importBackup(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Unsupported backup file.');
    }
    await _database.importAll(Map<String, Object?>.from(decoded));
    appSettings
      ..clear()
      ..addAll(await _database.getAppSettings());
    selectedDate = appSettings['working_date'] ?? dateKey(DateTime.now());
    await _loadData();
    notifyListeners();
  }
}
