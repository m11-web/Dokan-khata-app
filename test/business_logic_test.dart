import 'package:flutter_test/flutter_test.dart';
import 'package:hamza_poultry_khata/domain.dart';

void main() {
  const customer = Customer(
    id: 1,
    name: 'Shop',
    phone: '',
    openingBalance: 0,
    fixedLess: 45,
    sortOrder: 0,
    isActive: true,
  );
  const config = DailyConfig(
    date: '2026-11-20',
    isLocked: true,
    supplyRate: 425,
    load3152Grams: 1150000,
    load6540Grams: 1920000,
  );

  test('decimal weights sum in grams and the bill rounds correctly', () {
    final entry = DailyEntry(
      id: 1,
      customerId: customer.id,
      date: config.date,
      vehicle3152Grams: parseWeightGrams('50.300'),
      vehicle6540Grams: parseWeightGrams('31.000'),
      cashReceived: 0,
      lessOverride: null,
      isNaga: false,
    );

    expect(entry.totalGrams, 81300);
    expect(entry.netRate(customer, config), 380);
    expect(entry.bill(customer, config), 30894);
    expect(formatWeight(entry.totalGrams), '81.300');
  });

  test('zero-weight Naga has no bill while cash still reduces balance', () {
    final entry = DailyEntry(
      id: 1,
      customerId: customer.id,
      date: config.date,
      vehicle3152Grams: 0,
      vehicle6540Grams: 0,
      cashReceived: 250,
      lessOverride: null,
      isNaga: true,
    );

    expect(entry.bill(customer, config), 0);
    expect(
      calculateBalanceAfter(
        previousBalance: 100,
        entry: entry,
        customer: customer,
        config: config,
      ),
      -150,
    );
  });

  test('a positive delivery remains billed even if Naga data is flagged', () {
    final entry = DailyEntry(
      id: 1,
      customerId: customer.id,
      date: config.date,
      vehicle3152Grams: 1000,
      vehicle6540Grams: 0,
      cashReceived: 0,
      lessOverride: null,
      isNaga: true,
    );

    expect(entry.bill(customer, config), 380);
  });

  test('editing a past entry recalculates all later running balances', () {
    final firstDay = DailyEntry(
      id: 1,
      customerId: customer.id,
      date: '2026-11-18',
      vehicle3152Grams: 1000,
      vehicle6540Grams: 0,
      cashReceived: 500,
      lessOverride: null,
      isNaga: false,
    );
    final secondDay = DailyEntry(
      id: 2,
      customerId: customer.id,
      date: '2026-11-19',
      vehicle3152Grams: 1000,
      vehicle6540Grams: 0,
      cashReceived: 100,
      lessOverride: null,
      isNaga: false,
    );
    const openingCustomer = Customer(
      id: 1,
      name: 'Shop',
      phone: '',
      openingBalance: 1000,
      fixedLess: 0,
      sortOrder: 0,
      isActive: true,
    );
    const historicConfig = DailyConfig(
      date: '2026-11-18',
      isLocked: true,
      supplyRate: 400,
      load3152Grams: 0,
      load6540Grams: 0,
    );
    const secondConfig = DailyConfig(
      date: '2026-11-19',
      isLocked: true,
      supplyRate: 400,
      load3152Grams: 0,
      load6540Grams: 0,
    );
    final configs = {
      historicConfig.date: historicConfig,
      secondConfig.date: secondConfig,
    };

    expect(
      balanceBefore(
        openingBalance: openingCustomer.openingBalance,
        customerId: customer.id,
        date: '2026-11-20',
        entries: [firstDay, secondDay],
        customer: openingCustomer,
        configs: configs,
      ),
      1200,
    );
    final editedFirstDay = DailyEntry(
      id: firstDay.id,
      customerId: firstDay.customerId,
      date: firstDay.date,
      vehicle3152Grams: 2000,
      vehicle6540Grams: 0,
      cashReceived: firstDay.cashReceived,
      lessOverride: null,
      isNaga: false,
    );
    expect(
      balanceBefore(
        openingBalance: openingCustomer.openingBalance,
        customerId: customer.id,
        date: '2026-11-20',
        entries: [editedFirstDay, secondDay],
        customer: openingCustomer,
        configs: configs,
      ),
      1600,
    );
  });

  test('calendar month lengths include February leap years', () {
    expect(calendarDaysInMonth(DateTime(2025, 2)), 28);
    expect(calendarDaysInMonth(DateTime(2024, 2)), 29);
    expect(calendarDaysInMonth(DateTime(2026, 4)), 30);
    expect(calendarDaysInMonth(DateTime(2026, 1)), 31);
  });

  test('invalid and negative weights are rejected', () {
    expect(() => parseWeightGrams('not-a-weight'), throwsFormatException);
    expect(() => parseWeightGrams('-0.5'), throwsFormatException);
  });
}
