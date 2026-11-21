import 'package:intl/intl.dart';

const int gramsPerKilogram = 1000;

String dateKey(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

String displayDate(String key) =>
    DateFormat('dd-MM-yyyy').format(DateTime.parse(key));

int calendarDaysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

int parseWeightGrams(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (normalized.isEmpty) return 0;
  final weight = double.tryParse(normalized);
  if (weight == null || weight < 0 || !weight.isFinite) {
    throw const FormatException('Enter a valid non-negative weight.');
  }
  return (weight * gramsPerKilogram).round();
}

String formatWeight(int grams) => (grams / gramsPerKilogram).toStringAsFixed(3);

class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.openingBalance,
    required this.fixedLess,
    required this.sortOrder,
    required this.isActive,
  });

  final int id;
  final String name;
  final String phone;
  final int openingBalance;
  final int fixedLess;
  final int sortOrder;
  final bool isActive;

  factory Customer.fromMap(Map<String, Object?> row) => Customer(
    id: row['id']! as int,
    name: row['name']! as String,
    phone: row['phone'] as String? ?? '',
    openingBalance: row['opening_balance']! as int,
    fixedLess: row['fixed_less']! as int,
    sortOrder: row['sort_order']! as int,
    isActive: (row['is_active']! as int) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id == 0 ? null : id,
    'name': name,
    'phone': phone,
    'opening_balance': openingBalance,
    'fixed_less': fixedLess,
    'sort_order': sortOrder,
    'is_active': isActive ? 1 : 0,
  };
}

class DailyConfig {
  const DailyConfig({
    required this.date,
    required this.isLocked,
    required this.supplyRate,
    required this.load3152Grams,
    required this.load6540Grams,
  });

  final String date;
  final bool isLocked;
  final int supplyRate;
  final int load3152Grams;
  final int load6540Grams;

  int get totalLoadGrams => load3152Grams + load6540Grams;

  factory DailyConfig.fromMap(Map<String, Object?> row) => DailyConfig(
    date: row['date']! as String,
    isLocked: (row['is_locked']! as int) == 1,
    supplyRate: row['supply_rate']! as int,
    load3152Grams: row['load_3152_grams']! as int,
    load6540Grams: row['load_6540_grams']! as int,
  );

  Map<String, Object?> toMap() => {
    'date': date,
    'is_locked': isLocked ? 1 : 0,
    'supply_rate': supplyRate,
    'load_3152_grams': load3152Grams,
    'load_6540_grams': load6540Grams,
  };
}

class DailyEntry {
  const DailyEntry({
    required this.id,
    required this.customerId,
    required this.date,
    required this.vehicle3152Grams,
    required this.vehicle6540Grams,
    required this.cashReceived,
    required this.lessOverride,
    required this.isNaga,
  });

  final int id;
  final int customerId;
  final String date;
  final int vehicle3152Grams;
  final int vehicle6540Grams;
  final int cashReceived;
  final int? lessOverride;
  final bool isNaga;

  int get totalGrams => vehicle3152Grams + vehicle6540Grams;
  bool get hasTransaction => totalGrams > 0 || cashReceived != 0 || isNaga;

  int netRate(Customer customer, DailyConfig config) =>
      config.supplyRate - (lessOverride ?? customer.fixedLess);

  int bill(Customer customer, DailyConfig config) {
    if (totalGrams == 0) return 0;
    return (totalGrams * netRate(customer, config) / gramsPerKilogram).round();
  }

  factory DailyEntry.fromMap(Map<String, Object?> row) => DailyEntry(
    id: row['id']! as int,
    customerId: row['customer_id']! as int,
    date: row['date']! as String,
    vehicle3152Grams: row['vehicle_3152_grams']! as int,
    vehicle6540Grams: row['vehicle_6540_grams']! as int,
    cashReceived: row['cash_received']! as int,
    lessOverride: row['less_override'] as int?,
    isNaga: (row['is_naga']! as int) == 1,
  );

  Map<String, Object?> toMap() => {
    'id': id == 0 ? null : id,
    'customer_id': customerId,
    'date': date,
    'vehicle_3152_grams': vehicle3152Grams,
    'vehicle_6540_grams': vehicle6540Grams,
    'cash_received': cashReceived,
    'less_override': lessOverride,
    'is_naga': isNaga ? 1 : 0,
  };
}

class BusinessTotals {
  const BusinessTotals({
    required this.vehicle3152Grams,
    required this.vehicle6540Grams,
    required this.sale,
    required this.cash,
  });

  final int vehicle3152Grams;
  final int vehicle6540Grams;
  final int sale;
  final int cash;

  int get totalGrams => vehicle3152Grams + vehicle6540Grams;
}

int balanceBefore({
  required int openingBalance,
  required int customerId,
  required String date,
  required Iterable<DailyEntry> entries,
  required Customer customer,
  required Map<String, DailyConfig> configs,
}) {
  var balance = openingBalance;
  final earlier =
      entries
          .where(
            (entry) =>
                entry.customerId == customerId &&
                entry.date.compareTo(date) < 0,
          )
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
  for (final entry in earlier) {
    final config = configs[entry.date];
    if (config != null) {
      balance += entry.bill(customer, config) - entry.cashReceived;
    }
  }
  return balance;
}

int calculateBalanceAfter({
  required int previousBalance,
  required DailyEntry entry,
  required Customer customer,
  required DailyConfig config,
}) => previousBalance - entry.cashReceived + entry.bill(customer, config);
