import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:provider/provider.dart';

import 'documents.dart';
import 'domain.dart';
import 'khata_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = KhataState();
  runApp(KhataApp(state: state));
}

class KhataApp extends StatelessWidget {
  const KhataApp({required this.state, super.key});

  final KhataState state;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider.value(
    value: state,
    child: MaterialApp(
      title: 'Hamza Poultry Khata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF176B52),
          surface: const Color(0xFFF7F8F5),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F5),
        fontFamily: 'Inter',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          bodyMedium: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          bodySmall: TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 11,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
      home: const StartupScreen(),
    ),
  );
}

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = context.read<KhataState>().initialize();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 44, color: Colors.red),
                  const SizedBox(height: 12),
                  Text('Database could not be opened:\n${snapshot.error}'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(
                      () => _initialization = context
                          .read<KhataState>()
                          .initialize(),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return const MainShell();
    },
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  final _pages = const [
    DailySheetScreen(),
    CustomersScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: _pages),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.edit_note),
          label: 'Daily Sheet',
        ),
        NavigationDestination(icon: Icon(Icons.people_alt), label: 'Customers'),
        NavigationDestination(icon: Icon(Icons.assessment), label: 'Reports'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
      ],
    ),
  );
}

class DailySheetScreen extends StatelessWidget {
  const DailySheetScreen({super.key});

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      final config = state.config!;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hamza Poultry Khata'),
          actions: [
            IconButton(
              tooltip: 'Print Roznamcha',
              onPressed: () => _openMasterSheet(context, state, config.date),
              icon: const Icon(Icons.summarize_outlined),
            ),
          ],
        ),
        body: Column(
          children: [
            _DailyHeader(config: config),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MultiBillScreen(date: config.date),
                        ),
                      ),
                      icon: const Icon(Icons.grid_view),
                      label: const Text('Print Multiple Bills on A4'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Daily Roznamcha',
                    onPressed: () =>
                        _openMasterSheet(context, state, config.date),
                    icon: const Icon(Icons.print_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.activeCustomers.isEmpty
                  ? const Center(
                      child: Text(
                        'No active shopkeepers. Add a customer first.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      itemCount: state.activeCustomers.length,
                      itemBuilder: (context, index) {
                        final customer = state.activeCustomers[index];
                        return DailyCustomerRow(
                          key: ValueKey('${config.date}_${customer.id}'),
                          customer: customer,
                          config: config,
                        );
                      },
                    ),
            ),
            _DailyTotalsFooter(config: config),
          ],
        ),
      );
    },
  );
}

class _DailyHeader extends StatefulWidget {
  const _DailyHeader({required this.config});

  final DailyConfig config;

  @override
  State<_DailyHeader> createState() => _DailyHeaderState();
}

class _DailyHeaderState extends State<_DailyHeader> {
  late final TextEditingController _rate;
  late final TextEditingController _load3152;
  late final TextEditingController _load6540;

  @override
  void initState() {
    super.initState();
    _rate = TextEditingController(text: '${widget.config.supplyRate}');
    _load3152 = TextEditingController(
      text: formatWeight(widget.config.load3152Grams),
    );
    _load6540 = TextEditingController(
      text: formatWeight(widget.config.load6540Grams),
    );
  }

  @override
  void didUpdateWidget(covariant _DailyHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.date != widget.config.date) {
      _rate.text = '${widget.config.supplyRate}';
      _load3152.text = formatWeight(widget.config.load3152Grams);
      _load6540.text = formatWeight(widget.config.load6540Grams);
    }
  }

  @override
  void dispose() {
    _rate.dispose();
    _load3152.dispose();
    _load6540.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<KhataState>();
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 2),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: widget.config.isLocked
                        ? null
                        : () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: DateTime.parse(state.selectedDate),
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (selected == null || !context.mounted) return;
                            await _perform(
                              context,
                              () => state.selectDate(dateKey(selected)),
                            );
                          },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(displayDate(widget.config.date)),
                  ),
                ),
                const Text('Working date'),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: widget.config.isLocked
                      ? 'Unlock working date'
                      : 'Lock working date',
                  onPressed: () => _perform(
                    context,
                    () => state.updateConfig(isLocked: !widget.config.isLocked),
                  ),
                  icon: Icon(
                    widget.config.isLocked ? Icons.lock : Icons.lock_open,
                    color: widget.config.isLocked
                        ? Colors.deepOrange
                        : Colors.green,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _configField(
                    context: context,
                    controller: _rate,
                    label: 'Rate Rs/kg',
                    decimal: false,
                    onSaved: () async {
                      final value = int.tryParse(_rate.text.trim());
                      if (value == null || value < 0) {
                        throw const FormatException(
                          'Enter a valid daily rate.',
                        );
                      }
                      await state.updateConfig(supplyRate: value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _configField(
                    context: context,
                    controller: _load3152,
                    label: '3152 Load kg',
                    decimal: true,
                    onSaved: () async => state.updateConfig(
                      load3152Grams: parseWeightGrams(_load3152.text),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _configField(
                    context: context,
                    controller: _load6540,
                    label: '6540 Load kg',
                    decimal: true,
                    onSaved: () async => state.updateConfig(
                      load6540Grams: parseWeightGrams(_load6540.text),
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'Total Farm Load  ${formatWeight(widget.config.totalLoadGrams)} kg',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _configField({
  required BuildContext context,
  required TextEditingController controller,
  required String label,
  required bool decimal,
  required Future<void> Function() onSaved,
}) => TextField(
  controller: controller,
  keyboardType: TextInputType.numberWithOptions(decimal: decimal),
  inputFormatters: [
    FilteringTextInputFormatter.allow(
      decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
    ),
  ],
  decoration: InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11),
  ),
  onSubmitted: (_) => _perform(context, onSaved),
  onTapOutside: (_) => _perform(context, onSaved),
);

class DailyCustomerRow extends StatefulWidget {
  const DailyCustomerRow({
    required this.customer,
    required this.config,
    super.key,
  });

  final Customer customer;
  final DailyConfig config;

  @override
  State<DailyCustomerRow> createState() => _DailyCustomerRowState();
}

class _DailyCustomerRowState extends State<DailyCustomerRow> {
  late final TextEditingController _weight3152;
  late final TextEditingController _weight6540;
  late final TextEditingController _cash;
  final _focus3152 = FocusNode();
  final _focus6540 = FocusNode();
  final _focusCash = FocusNode();
  Timer? _timer;
  bool _naga = false;
  int? _lessOverride;

  @override
  void initState() {
    super.initState();
    final entry = context.read<KhataState>().entryFor(widget.customer.id);
    _weight3152 = TextEditingController(
      text: formatWeight(entry?.vehicle3152Grams ?? 0),
    );
    _weight6540 = TextEditingController(
      text: formatWeight(entry?.vehicle6540Grams ?? 0),
    );
    _cash = TextEditingController(text: '${entry?.cashReceived ?? 0}');
    _naga = entry?.isNaga ?? false;
    _lessOverride = entry?.lessOverride;
  }

  @override
  void didUpdateWidget(covariant DailyCustomerRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final entry = context.read<KhataState>().entryFor(widget.customer.id);
    if (!_focus3152.hasFocus) {
      _weight3152.text = formatWeight(entry?.vehicle3152Grams ?? 0);
    }
    if (!_focus6540.hasFocus) {
      _weight6540.text = formatWeight(entry?.vehicle6540Grams ?? 0);
    }
    if (!_focusCash.hasFocus) _cash.text = '${entry?.cashReceived ?? 0}';
    _naga = entry?.isNaga ?? false;
    _lessOverride = entry?.lessOverride;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _weight3152.dispose();
    _weight6540.dispose();
    _cash.dispose();
    _focus3152.dispose();
    _focus6540.dispose();
    _focusCash.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () {
      _perform(context, _save);
    });
  }

  void _onWeightChanged(String _) {
    if (_naga &&
        _safeGrams(_weight3152.text) + _safeGrams(_weight6540.text) > 0) {
      setState(() => _naga = false);
    }
    _scheduleSave();
  }

  Future<void> _save() async {
    final weight3152 = parseWeightGrams(_weight3152.text);
    final weight6540 = parseWeightGrams(_weight6540.text);
    final cash = int.tryParse(_cash.text.trim());
    if (cash == null || cash < 0) {
      throw const FormatException('Enter a valid cash received amount.');
    }
    await context.read<KhataState>().saveEntry(
      customerId: widget.customer.id,
      vehicle3152Grams: weight3152,
      vehicle6540Grams: weight6540,
      cashReceived: cash,
      isNaga: _naga || (weight3152 + weight6540 == 0 && cash > 0),
      lessOverride: _lessOverride,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<KhataState>();
    final entry = state.entryFor(widget.customer.id);
    final grams = _safeGrams(_weight3152.text) + _safeGrams(_weight6540.text);
    final less = _lessOverride ?? widget.customer.fixedLess;
    final rate = widget.config.supplyRate - less;
    final bill = grams == 0 ? 0 : (grams * rate / gramsPerKilogram).round();
    final previous = state.previousBalance(widget.customer, widget.config.date);
    final due = previous - (int.tryParse(_cash.text.trim()) ?? 0) + bill;
    final isNaga = _naga || (grams == 0 && (int.tryParse(_cash.text) ?? 0) > 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _editLess,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: Text(
                    'Less $less • Rate $rate',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ),
                IconButton(
                  tooltip: 'Monthly statement',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _openMonthly(context, widget.customer.id),
                  icon: const Icon(Icons.calendar_view_month, size: 20),
                ),
                IconButton(
                  tooltip: 'Receipt',
                  visualDensity: VisualDensity.compact,
                  onPressed: entry == null
                      ? null
                      : () => _openReceipt(
                          context,
                          state,
                          widget.customer,
                          entry,
                        ),
                  icon: const Icon(Icons.receipt_long, size: 20),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _entryField(
                    controller: _weight3152,
                    focusNode: _focus3152,
                    label: '3152 kg',
                    decimal: true,
                    onChanged: _onWeightChanged,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _entryField(
                    controller: _weight6540,
                    focusNode: _focus6540,
                    label: '6540 kg',
                    decimal: true,
                    onChanged: _onWeightChanged,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _entryField(
                    controller: _cash,
                    focusNode: _focusCash,
                    label: 'Jama Rs',
                    decimal: false,
                    onChanged: (_) => _scheduleSave(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${formatWeight(grams)} kg  •  Bill ${_formatMoney(bill)}  •  Due ${_formatMoney(due)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  isNaga ? 'ناگا' : 'Active',
                  style: TextStyle(
                    color: isNaga ? Colors.deepOrange : Colors.green.shade700,
                    fontFamily: 'NotoNaskhArabic',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Switch(
                  value: _naga,
                  onChanged: (value) {
                    if (value && grams > 0) {
                      _showMessage(
                        context,
                        'Naga is only valid at zero weight.',
                      );
                      return;
                    }
                    setState(() => _naga = value);
                    _scheduleSave();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editLess() async {
    final controller = TextEditingController(
      text: '${_lessOverride ?? widget.customer.fixedLess}',
    );
    final value = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Less (Rs/kg)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Fixed Less is Rs ${widget.customer.fixedLess}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'fixed'),
            child: const Text('Use fixed Less'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a valid daily Less.')),
                );
                return;
              }
              Navigator.pop(context, '$parsed');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _lessOverride = value == 'fixed' ? null : int.parse(value));
    _scheduleSave();
  }
}

int _safeGrams(String value) {
  try {
    return parseWeightGrams(value);
  } on FormatException {
    return 0;
  }
}

Widget _entryField({
  required TextEditingController controller,
  required FocusNode focusNode,
  required String label,
  required bool decimal,
  required ValueChanged<String> onChanged,
}) => TextField(
  controller: controller,
  focusNode: focusNode,
  keyboardType: TextInputType.numberWithOptions(decimal: decimal),
  inputFormatters: [
    FilteringTextInputFormatter.allow(
      decimal ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
    ),
  ],
  decoration: InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 11),
  ),
  onChanged: onChanged,
);

class _DailyTotalsFooter extends StatelessWidget {
  const _DailyTotalsFooter({required this.config});

  final DailyConfig config;

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      final totals = state.totalsFor(config.date);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Column(
          children: [
            Text(
              '3152 Shortage ${formatWeight(config.load3152Grams - totals.vehicle3152Grams)} kg'
              '   |   6540 Shortage ${formatWeight(config.load6540Grams - totals.vehicle6540Grams)} kg',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            Text(
              'Total Shortage ${formatWeight(config.totalLoadGrams - totals.totalGrams)} kg'
              '  •  Sale Rs ${_formatMoney(totals.sale)}'
              '  •  Cash Rs ${_formatMoney(totals.cash)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    },
  );
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Shopkeepers'),
      actions: [
        if (stateInactiveCount(context) > 0)
          IconButton(
            tooltip: 'Inactive shopkeepers',
            onPressed: () => _showInactiveCustomers(context),
            icon: const Icon(Icons.visibility_off_outlined),
          ),
        IconButton(
          tooltip: 'Add shopkeeper',
          onPressed: () => _editCustomer(context),
          icon: const Icon(Icons.person_add_alt_1),
        ),
      ],
    ),
    body: Consumer<KhataState>(
      builder: (context, state, _) => ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: state.activeCustomers.length,
        onReorderItem: (oldIndex, newIndex) =>
            _perform(context, () => state.reorderCustomers(oldIndex, newIndex)),
        itemBuilder: (context, index) {
          final customer = state.activeCustomers[index];
          return Card(
            key: ValueKey(customer.id),
            child: ListTile(
              title: Text(customer.name),
              subtitle: Text(
                'Less Rs ${customer.fixedLess}  •  Opening Rs ${_formatMoney(customer.openingBalance)}'
                '${customer.phone.isEmpty ? '' : '  •  ${customer.phone}'}',
              ),
              leading: const Icon(Icons.drag_handle),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _editCustomer(context, customer);
                  } else {
                    _openMonthly(context, customer.id);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit profile')),
                  PopupMenuItem(
                    value: 'statement',
                    child: Text('Monthly statement'),
                  ),
                ],
              ),
              onTap: () => _editCustomer(context, customer),
            ),
          );
        },
      ),
    ),
  );
}

int stateInactiveCount(BuildContext context) => context
    .read<KhataState>()
    .customers
    .where((customer) => !customer.isActive)
    .length;

Future<void> _showInactiveCustomers(BuildContext context) async {
  final state = context.read<KhataState>();
  final inactive = state.customers
      .where((customer) => !customer.isActive)
      .toList();
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Inactive shopkeepers')),
          for (final customer in inactive)
            ListTile(
              title: Text(customer.name),
              trailing: const Icon(Icons.edit),
              onTap: () {
                Navigator.pop(sheetContext);
                _editCustomer(context, customer);
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _editCustomer(BuildContext context, [Customer? customer]) async {
  final result = await showDialog<Customer>(
    context: context,
    builder: (_) => _CustomerForm(customer: customer),
  );
  if (result == null || !context.mounted) return;
  await _perform(
    context,
    () => context.read<KhataState>().saveCustomer(result),
  );
}

class _CustomerForm extends StatefulWidget {
  const _CustomerForm({this.customer});

  final Customer? customer;

  @override
  State<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<_CustomerForm> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _opening;
  late final TextEditingController _less;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _opening = TextEditingController(text: '${customer?.openingBalance ?? 0}');
    _less = TextEditingController(text: '${customer?.fixedLess ?? 45}');
    _active = customer?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _opening.dispose();
    _less.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.customer == null ? 'Add shopkeeper' : 'Edit shopkeeper'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name / نام'),
            textDirection: TextDirection.rtl,
          ),
          TextField(
            controller: _phone,
            decoration: const InputDecoration(labelText: 'Phone / WhatsApp'),
            keyboardType: TextInputType.phone,
          ),
          TextField(
            controller: _opening,
            decoration: const InputDecoration(
              labelText: 'Opening balance (Rs)',
            ),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: _less,
            decoration: const InputDecoration(labelText: 'Fixed Less (Rs/kg)'),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active shopkeeper'),
            value: _active,
            onChanged: (value) => setState(() => _active = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final opening = int.tryParse(_opening.text.trim());
          final less = int.tryParse(_less.text.trim());
          if (_name.text.trim().isEmpty || opening == null || less == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Enter a name and valid amounts.')),
            );
            return;
          }
          Navigator.pop(
            context,
            Customer(
              id: widget.customer?.id ?? 0,
              name: _name.text.trim(),
              phone: _phone.text.trim(),
              openingBalance: opening,
              fixedLess: less,
              sortOrder: widget.customer?.sortOrder ?? 999,
              isActive: _active,
            ),
          );
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _reportDate;

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      final dates = state.entries.map((entry) => entry.date).toSet().toList()
        ..sort((a, b) => b.compareTo(a));
      final selected = _reportDate ?? state.selectedDate;
      final config = state.configFor(selected);
      final totals = state.totalsFor(selected);
      final dayEntries =
          state.entries.where((entry) => entry.date == selected).toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      return Scaffold(
        appBar: AppBar(title: const Text('Reports')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayDate(selected),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      'Farm load ${formatWeight(config?.totalLoadGrams ?? 0)} kg'
                      '  •  Supplied ${formatWeight(totals.totalGrams)} kg'
                      '  •  Sale Rs ${_formatMoney(totals.sale)}'
                      '  •  Cash Rs ${_formatMoney(totals.cash)}',
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: config == null
                              ? null
                              : () =>
                                    _openMasterSheet(context, state, selected),
                          icon: const Icon(Icons.print),
                          label: const Text('Roznamcha'),
                        ),
                        OutlinedButton.icon(
                          onPressed: config == null || dayEntries.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MultiBillScreen(date: selected),
                                  ),
                                ),
                          icon: const Icon(Icons.receipt),
                          label: const Text('Bills'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (dates.isEmpty)
              const Center(
                child: Text('Saved daily entries will appear here.'),
              ),
            for (final date in dates)
              ListTile(
                selected: selected == date,
                leading: const Icon(Icons.event_note),
                title: Text(displayDate(date)),
                subtitle: Text(
                  '${state.entries.where((e) => e.date == date).length} customer entries',
                ),
                onTap: () => setState(() => _reportDate = date),
              ),
            const Divider(),
            for (final entry in dayEntries)
              Builder(
                builder: (context) {
                  final customer = state.customerById(entry.customerId);
                  final dayConfig = state.configFor(entry.date);
                  if (customer == null || dayConfig == null) {
                    return const SizedBox.shrink();
                  }
                  return ListTile(
                    title: Text(customer.name),
                    subtitle: Text(
                      '${formatWeight(entry.totalGrams)} kg  •  Bill Rs ${_formatMoney(entry.bill(customer, dayConfig))}  •  Cash Rs ${_formatMoney(entry.cashReceived)}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Receipt PNG',
                      icon: const Icon(Icons.image_outlined),
                      onPressed: () =>
                          _openReceipt(context, state, customer, entry),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fields = <String, TextEditingController>{};
  static const _defaults = {
    'farm_name': 'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
    'proprietor': 'چوہدری وقاص مینو',
    'phones': '0300-7400070 | 0315-7400079',
    'address': 'چوک شاہ عباس سورج کنڈ روڈ نزد جاہد بیکری ملتان',
  };

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      for (final field in _defaults.entries) {
        final value = state.appSettings[field.key] ?? field.value;
        _fields.putIfAbsent(
          field.key,
          () => TextEditingController(text: value),
        );
      }
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final field in _defaults.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: _fields[field.key],
                  textDirection: field.key == 'phones'
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  decoration: InputDecoration(labelText: field.value),
                  maxLines: field.key == 'address' ? 2 : 1,
                ),
              ),
            FilledButton.icon(
              onPressed: () => _perform(context, () {
                final values = {
                  for (final key in _fields.keys)
                    key: _fields[key]!.text.trim(),
                };
                return state.saveAppSettings(values);
              }),
              icon: const Icon(Icons.save),
              label: const Text('Save farm details'),
            ),
            const SizedBox(height: 26),
            Text(
              'Offline data backup',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _perform(context, _exportBackup),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export full JSON backup'),
            ),
            OutlinedButton.icon(
              onPressed: () => _perform(context, _importBackup),
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('Import JSON backup'),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _exportBackup() async {
    final json = await context.read<KhataState>().exportBackup();
    final path = await FilePicker.saveFile(
      fileName: 'hamza_poultry_backup.json',
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
    if (path == null || !mounted) return;
    _message('Backup saved.');
  }

  Future<void> _importBackup() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw StateError('The selected backup could not be read.');
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace local data?'),
        content: const Text(
          'Importing this backup replaces customers and entries currently on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<KhataState>().importBackup(utf8.decode(bytes));
    _message('Backup imported.');
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class MultiBillScreen extends StatefulWidget {
  const MultiBillScreen({required this.date, super.key});

  final String date;

  @override
  State<MultiBillScreen> createState() => _MultiBillScreenState();
}

class _MultiBillScreenState extends State<MultiBillScreen> {
  final Set<int> _selected = {};
  int _columns = 2;

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      final dayEntries = state.entries
          .where((entry) => entry.date == widget.date)
          .where((entry) => state.customerById(entry.customerId) != null)
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text('Bills • ${displayDate(widget.date)}')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 2,
                        label: Text('4 per page (2 × 2)'),
                      ),
                      ButtonSegment(
                        value: 3,
                        label: Text('6 per page (2 × 3)'),
                      ),
                    ],
                    selected: {_columns},
                    onSelectionChanged: (value) =>
                        setState(() => _columns = value.first),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => setState(
                          () => _selected.addAll(
                            dayEntries.map((e) => e.customerId),
                          ),
                        ),
                        child: const Text('Select all'),
                      ),
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        child: const Text('Deselect all'),
                      ),
                      const Spacer(),
                      Text('${_selected.length} selected'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final entry in dayEntries)
                    Builder(
                      builder: (context) {
                        final customer = state.customerById(entry.customerId)!;
                        return CheckboxListTile(
                          value: _selected.contains(customer.id),
                          onChanged: (value) => setState(() {
                            if (value ?? false) {
                              _selected.add(customer.id);
                            } else {
                              _selected.remove(customer.id);
                            }
                          }),
                          title: Text(customer.name),
                          subtitle: Text(
                            '${formatWeight(entry.totalGrams)} kg  •  Rs ${_formatMoney(entry.bill(customer, state.configFor(widget.date)!))}',
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: _selected.isEmpty
                    ? null
                    : () => _createPages(state, dayEntries),
                icon: const Icon(Icons.image),
                label: const Text('Create PNG pages'),
              ),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _createPages(
    KhataState state,
    List<DailyEntry> dayEntries,
  ) async {
    final config = state.configFor(widget.date);
    if (config == null) return;
    final customers = state.customers;
    final selectedEntries = dayEntries
        .where((entry) => _selected.contains(entry.customerId))
        .toList();
    final pages = <Uint8List>[];
    final pageSize = _columns * 2;
    for (var start = 0; start < selectedEntries.length; start += pageSize) {
      final chunk = selectedEntries.skip(start).take(pageSize).toList();
      final bills = chunk.map((entry) {
        final customer = customers.firstWhere((c) => c.id == entry.customerId);
        final previous = state.previousBalance(customer, entry.date);
        return ReceiptDocument(
          customer: customer,
          entry: entry,
          config: config,
          previousBalance: previous,
          closingBalance: state.closingBalanceFor(customer, entry, config),
          farmName: _setting(
            state,
            'farm_name',
            'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
          ),
          proprietor: _setting(state, 'proprietor', 'چوہدری وقاص مینو'),
          phones: _setting(state, 'phones', '0300-7400070 | 0315-7400079'),
          address: _setting(
            state,
            'address',
            'چوک شاہ عباس سورج کنڈ روڈ نزد جاہد بیکری ملتان',
          ),
          compact: true,
        );
      }).toList();
      final document = MultiBillPageDocument(
        bills: bills,
        columns: 2,
        rows: _columns,
        farmName: _setting(
          state,
          'farm_name',
          'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
        ),
        proprietor: _setting(state, 'proprietor', 'چوہدری وقاص مینو'),
        phones: _setting(state, 'phones', '0300-7400070 | 0315-7400079'),
        address: _setting(
          state,
          'address',
          'چوک شاہ عباس سورج کنڈ روڈ نزد جاہد بیکری ملتان',
        ),
      );
      pages.add(
        await DocumentService.renderPng(
          context,
          document,
          width: a4Width,
          height: a4Height,
        ),
      );
    }
    if (!mounted) return;
    await _showImagesDialog(
      context,
      title: 'Multiple bills • ${displayDate(widget.date)}',
      images: pages,
      name: 'bills_${widget.date}',
      allowPrint: true,
    );
  }
}

class MonthlyStatementScreen extends StatefulWidget {
  const MonthlyStatementScreen({required this.customerId, super.key});

  final int customerId;

  @override
  State<MonthlyStatementScreen> createState() => _MonthlyStatementScreenState();
}

class _MonthlyStatementScreenState extends State<MonthlyStatementScreen> {
  DateTime _month = DateTime.now();

  @override
  Widget build(BuildContext context) => Consumer<KhataState>(
    builder: (context, state, _) {
      final customer = state.customerById(widget.customerId);
      if (customer == null) {
        return const Scaffold(body: Center(child: Text('Customer not found.')));
      }
      final opening = state.previousBalance(
        customer,
        dateKey(DateTime(_month.year, _month.month, 1)),
      );
      final document = _monthlyDocument(state, customer, _month, opening);
      return Scaffold(
        appBar: AppBar(
          title: const Text('Monthly statement'),
          actions: [
            IconButton(
              tooltip: 'Choose month',
              onPressed: _chooseMonth,
              icon: const Icon(Icons.calendar_month),
            ),
          ],
        ),
        body: Column(
          children: [
            ListTile(
              title: Text(customer.name),
              subtitle: Text(DateFormat('MMMM yyyy').format(_month)),
              trailing: Text('Opening Rs ${_formatMoney(opening)}'),
            ),
            Expanded(
              child: InteractiveViewer(
                minScale: 0.3,
                maxScale: 2,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: a4Width,
                    height: a4Height,
                    child: document,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () async {
                  final image = await DocumentService.renderPng(
                    context,
                    document,
                    width: a4Width,
                    height: a4Height,
                  );
                  if (!context.mounted) return;
                  await _showImagesDialog(
                    context,
                    title: 'Monthly statement',
                    images: [image],
                    name:
                        'monthly_${customer.id}_${_month.year}_${_month.month}',
                    allowPrint: true,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Save / Share / Print A4 PNG'),
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _monthlyDocument(
    KhataState state,
    Customer customer,
    DateTime month,
    int opening,
  ) => MonthlyStatementDocument(
    customer: customer,
    month: month,
    monthOpening: opening,
    entries: state.entries,
    configs: state.dailyConfigs,
    farmName: _setting(
      state,
      'farm_name',
      'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
    ),
    phones: _setting(state, 'phones', '0300-7400070 | 0315-7400079'),
  );

  Future<void> _chooseMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (selected != null) {
      setState(() => _month = DateTime(selected.year, selected.month));
    }
  }
}

void _openMonthly(BuildContext context, int customerId) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MonthlyStatementScreen(customerId: customerId),
    ),
  );
}

Future<void> _openReceipt(
  BuildContext context,
  KhataState state,
  Customer customer,
  DailyEntry entry,
) async {
  final config = state.configFor(entry.date);
  if (config == null) {
    _showMessage(context, 'Daily settings are missing for this entry.');
    return;
  }
  final previous = state.previousBalance(customer, entry.date);
  final document = ReceiptDocument(
    customer: customer,
    entry: entry,
    config: config,
    previousBalance: previous,
    closingBalance: state.closingBalanceFor(customer, entry, config),
    farmName: _setting(
      state,
      'farm_name',
      'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
    ),
    proprietor: _setting(state, 'proprietor', 'چوہدری وقاص مینو'),
    phones: _setting(state, 'phones', '0300-7400070 | 0315-7400079'),
    address: _setting(
      state,
      'address',
      'چوک شاہ عباس سورج کنڈ روڈ نزد جاہد بیکری ملتان',
    ),
  );
  final image = await DocumentService.renderPng(
    context,
    document,
    width: 420,
    height: 780,
  );
  if (!context.mounted) return;
  await _showImagesDialog(
    context,
    title: 'Receipt • ${customer.name}',
    images: [image],
    name: 'receipt_${entry.date}_${entry.id}',
    allowPrint: true,
  );
}

Future<void> _openMasterSheet(
  BuildContext context,
  KhataState state,
  String date,
) async {
  final config = state.configFor(date);
  if (config == null) {
    _showMessage(context, 'Daily settings are missing for this date.');
    return;
  }
  final document = DailyMasterDocument(
    date: date,
    config: config,
    customers: state.activeCustomers,
    entries: state.entries,
    totals: state.totalsFor(date),
    farmName: _setting(
      state,
      'farm_name',
      'حمزہ پولٹری اینڈ جنرل آرڈر سپلائرز',
    ),
  );
  final image = await DocumentService.renderPng(
    context,
    document,
    width: a4Width,
    height: a4Height,
  );
  if (!context.mounted) return;
  await _showImagesDialog(
    context,
    title: 'Daily Roznamcha • ${displayDate(date)}',
    images: [image],
    name: 'roznamcha_$date',
    allowPrint: true,
  );
}

Future<void> _showImagesDialog(
  BuildContext context, {
  required String title,
  required List<Uint8List> images,
  required String name,
  required bool allowPrint,
}) async {
  var page = 0;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (images.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: page == 0
                          ? null
                          : () => setDialogState(() => page--),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text('Page ${page + 1} of ${images.length}'),
                    IconButton(
                      onPressed: page == images.length - 1
                          ? null
                          : () => setDialogState(() => page++),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Image.memory(images[page], fit: BoxFit.contain),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton.icon(
            onPressed: () => _perform(context, () async {
              final path = await FilePicker.saveFile(
                fileName: '${name}_${page + 1}.png',
                bytes: images[page],
              );
              if (path != null && context.mounted) {
                Navigator.pop(dialogContext);
                _showMessage(context, 'PNG saved.');
              }
            }),
            icon: const Icon(Icons.save_alt),
            label: const Text('Save PNG'),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () => _perform(
              context,
              () => DocumentService.sharePngs(images, name),
            ),
            icon: const Icon(Icons.share),
          ),
          if (allowPrint)
            IconButton(
              tooltip: 'Print',
              onPressed: () =>
                  _perform(context, () => DocumentService.printPngs(images)),
              icon: const Icon(Icons.print),
            ),
        ],
      ),
    ),
  );
}

String _setting(KhataState state, String key, String fallback) =>
    state.appSettings[key]?.trim().isNotEmpty == true
    ? state.appSettings[key]!
    : fallback;

String _formatMoney(int value) => NumberFormat('#,##0; -#,##0').format(value);

Future<void> _perform(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } on FormatException catch (error) {
    if (context.mounted) _showMessage(context, error.message);
  } on StateError catch (error) {
    if (context.mounted) _showMessage(context, error.message);
  } catch (error) {
    if (context.mounted) _showMessage(context, 'Operation failed: $error');
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
