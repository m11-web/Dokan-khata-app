import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';

import 'domain.dart';

const double a4Width = 826.6667;
const double a4Height = 1169.3333;

TextStyle _urduStyle({double size = 17, FontWeight weight = FontWeight.w400}) =>
    TextStyle(
      fontFamily: 'NotoNaskhArabic',
      fontSize: size,
      fontWeight: weight,
      height: 1.24,
      color: Colors.black,
    );

TextStyle _numberStyle({
  double size = 14,
  FontWeight weight = FontWeight.w500,
}) => TextStyle(
  fontFamily: 'Inter',
  fontSize: size,
  fontWeight: weight,
  fontFeatures: const [FontFeature.tabularFigures()],
  color: Colors.black,
);

class DocumentService {
  static Future<Uint8List> renderPng(
    BuildContext context,
    Widget document, {
    required double width,
    required double height,
  }) async {
    final key = GlobalKey();
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        left: -10000,
        top: 0,
        width: width,
        height: height,
        child: RepaintBoundary(key: key, child: document),
      ),
    );
    Overlay.of(context).insert(overlay);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not encode document as PNG.');
      return data.buffer.asUint8List();
    } finally {
      overlay.remove();
    }
  }

  static Future<String> savePng(Uint8List bytes, String name) async {
    final directory = await getApplicationDocumentsDirectory();
    final exports = Directory('${directory.path}/Exports');
    await exports.create(recursive: true);
    final file = File('${exports.path}/$name.png');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  static Future<void> sharePngs(List<Uint8List> images, String prefix) async {
    final paths = <String>[];
    for (var index = 0; index < images.length; index++) {
      paths.add(await savePng(images[index], '${prefix}_${index + 1}'));
    }
    await SharePlus.instance.share(
      ShareParams(
        files: paths.map((path) => XFile(path, mimeType: 'image/png')).toList(),
        text: prefix.replaceAll('_', ' '),
      ),
    );
  }

  static Future<void> printPngs(List<Uint8List> images) async {
    final document = pw.Document();
    for (final image in images) {
      final pageImage = pw.MemoryImage(image);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Center(child: pw.Image(pageImage, fit: pw.BoxFit.contain)),
        ),
      );
    }
    await Printing.layoutPdf(onLayout: (_) => document.save());
  }
}

class ReceiptDocument extends StatelessWidget {
  const ReceiptDocument({
    required this.customer,
    required this.entry,
    required this.config,
    required this.previousBalance,
    required this.closingBalance,
    required this.farmName,
    required this.proprietor,
    required this.phones,
    required this.address,
    this.compact = false,
    super.key,
  });

  final Customer customer;
  final DailyEntry entry;
  final DailyConfig config;
  final int previousBalance;
  final int closingBalance;
  final String farmName;
  final String proprietor;
  final String phones;
  final String address;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bill = entry.bill(customer, config);
    final netRate = entry.netRate(customer, config);
    final titleSize = compact ? 17.0 : 24.0;
    final textSize = compact ? 13.0 : 20.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black, width: compact ? 0.8 : 1.5),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              farmName,
              textAlign: TextAlign.center,
              style: _urduStyle(size: titleSize, weight: FontWeight.w700),
            ),
            Text(
              '$proprietor  |  $phones',
              textAlign: TextAlign.center,
              style: _urduStyle(size: textSize - 2),
            ),
            if (!compact)
              Text(
                address,
                textAlign: TextAlign.center,
                style: _urduStyle(size: textSize - 3),
              ),
            Divider(color: Colors.black, height: compact ? 10 : 18),
            _ReceiptLine(
              label: 'رسید نمبر',
              value: '${entry.id}',
              size: textSize,
            ),
            _ReceiptLine(
              label: 'تاریخ',
              value: displayDate(entry.date),
              size: textSize,
            ),
            _ReceiptLine(
              label: 'نام خریدار',
              value: customer.name,
              size: textSize,
              valueIsUrdu: true,
            ),
            _ReceiptLine(
              label: 'سپلائی ریٹ',
              value: '${config.supplyRate} روپے فی کلو',
              size: textSize,
            ),
            Divider(color: Colors.black, height: compact ? 10 : 18),
            _ReceiptLine(
              label: 'تفصیل',
              value: entry.totalGrams == 0
                  ? 'ناگا'
                  : '${formatWeight(entry.totalGrams)} کلو مال',
              size: textSize,
              valueIsUrdu: true,
            ),
            _ReceiptLine(label: 'نرخ', value: '$netRate', size: textSize),
            _ReceiptLine(
              label: 'روپے',
              value: _money(bill),
              size: textSize,
              bold: true,
            ),
            Divider(color: Colors.black, height: compact ? 10 : 18),
            _ReceiptLine(
              label: 'سابقہ بقایا',
              value: _money(previousBalance),
              size: textSize,
            ),
            _ReceiptLine(
              label: 'جمع رقم',
              value: _money(entry.cashReceived),
              size: textSize,
            ),
            _ReceiptLine(
              label: 'بقایا رقم',
              value: _money(previousBalance - entry.cashReceived),
              size: textSize,
            ),
            _ReceiptLine(label: 'تازہ بل', value: _money(bill), size: textSize),
            Container(
              margin: EdgeInsets.only(top: compact ? 3 : 8),
              padding: EdgeInsets.symmetric(
                vertical: compact ? 3 : 8,
                horizontal: 8,
              ),
              color: const Color(0xFFF0F0F0),
              child: _ReceiptLine(
                label: 'ٹوٹل بل',
                value: _money(closingBalance),
                size: textSize + 1,
                bold: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({
    required this.label,
    required this.value,
    required this.size,
    this.bold = false,
    this.valueIsUrdu = false,
  });

  final String label;
  final String value;
  final double size;
  final bool bold;
  final bool valueIsUrdu;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: _urduStyle(
              size: size,
              weight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          textDirection: valueIsUrdu ? TextDirection.rtl : TextDirection.ltr,
          style: valueIsUrdu
              ? _urduStyle(
                  size: size,
                  weight: bold ? FontWeight.w700 : FontWeight.w400,
                )
              : _numberStyle(
                  size: size - 2,
                  weight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
        ),
      ],
    ),
  );
}

String _money(int value) => value
    .abs()
    .toString()
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',')
    .replaceFirstMapped(RegExp(r'^'), (_) => value < 0 ? '-' : '');

class DailyMasterDocument extends StatelessWidget {
  const DailyMasterDocument({
    required this.date,
    required this.config,
    required this.customers,
    required this.entries,
    required this.totals,
    required this.farmName,
    super.key,
  });

  final String date;
  final DailyConfig config;
  final List<Customer> customers;
  final List<DailyEntry> entries;
  final BusinessTotals totals;
  final String farmName;

  @override
  Widget build(BuildContext context) {
    final entryMap = {for (final entry in entries) entry.customerId: entry};
    final vehicle1Short = config.load3152Grams - totals.vehicle3152Grams;
    final vehicle2Short = config.load6540Grams - totals.vehicle6540Grams;
    return Container(
      width: a4Width,
      height: a4Height,
      color: Colors.white,
      padding: const EdgeInsets.all(28),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              farmName,
              textAlign: TextAlign.center,
              style: _urduStyle(size: 27, weight: FontWeight.w700),
            ),
            Text(
              'کھاتہ بنام روزنامچہ  •  ${displayDate(date)}  •  سپلائی ریٹ ${config.supplyRate}',
              textAlign: TextAlign.center,
              style: _urduStyle(size: 17),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _vehicleSummary(
                    'گاڑی 3152',
                    config.load3152Grams,
                    totals.vehicle3152Grams,
                    vehicle1Short,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _vehicleSummary(
                    'گاڑی 6540',
                    config.load6540Grams,
                    totals.vehicle6540Grams,
                    vehicle2Short,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Table(
                border: TableBorder.all(color: Colors.black, width: 0.6),
                columnWidths: const {
                  0: FlexColumnWidth(1.7),
                  1: FlexColumnWidth(1.1),
                  2: FlexColumnWidth(1.1),
                  3: FlexColumnWidth(1.2),
                  4: FlexColumnWidth(0.9),
                  5: FlexColumnWidth(1.2),
                  6: FlexColumnWidth(1.1),
                },
                children: [
                  _tableHeader([
                    'نام خریدار',
                    '3152 وزن',
                    '6540 وزن',
                    'کل وزن',
                    'نرخ',
                    'آج کا بل',
                    'جمع رقم',
                  ]),
                  for (final customer in customers)
                    _masterRow(customer, entryMap[customer.id], config),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'کل فارم لوڈ: ${formatWeight(config.totalLoadGrams)} کلو  |  کل سپلائی: ${formatWeight(totals.totalGrams)} کلو  |  کل شارٹیج: ${formatWeight(config.totalLoadGrams - totals.totalGrams)} کلو',
              textAlign: TextAlign.center,
              style: _urduStyle(size: 17, weight: FontWeight.w700),
            ),
            Text(
              'کل بل: ${_money(totals.sale)} روپے  |  کل جمع رقم: ${_money(totals.cash)} روپے',
              textAlign: TextAlign.center,
              style: _urduStyle(size: 17, weight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _vehicleSummary(
  String title,
  int load,
  int supplied,
  int shortage,
) => Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(border: Border.all(color: Colors.black)),
  child: Column(
    children: [
      Text(title, style: _urduStyle(size: 17, weight: FontWeight.w700)),
      Text(
        'لوڈ ${formatWeight(load)}  |  سپلائی ${formatWeight(supplied)}  |  شارٹیج ${formatWeight(shortage)}',
        textAlign: TextAlign.center,
        style: _urduStyle(size: 14),
      ),
    ],
  ),
);

TableRow _tableHeader(List<String> labels) => TableRow(
  decoration: const BoxDecoration(color: Color(0xFFE9E9E9)),
  children: [
    for (final label in labels)
      Padding(
        padding: const EdgeInsets.all(5),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: _urduStyle(size: 13, weight: FontWeight.w700),
        ),
      ),
  ],
);

TableRow _masterRow(Customer customer, DailyEntry? entry, DailyConfig config) =>
    TableRow(
      children: [
        _tableCell(customer.name, urdu: true),
        _tableCell(formatWeight(entry?.vehicle3152Grams ?? 0)),
        _tableCell(formatWeight(entry?.vehicle6540Grams ?? 0)),
        _tableCell(formatWeight(entry?.totalGrams ?? 0)),
        _tableCell(entry == null ? '' : '${entry.netRate(customer, config)}'),
        _tableCell(entry == null ? '' : _money(entry.bill(customer, config))),
        _tableCell(entry == null ? '' : _money(entry.cashReceived)),
      ],
    );

Widget _tableCell(String value, {bool urdu = false}) => Padding(
  padding: const EdgeInsets.all(5),
  child: Text(
    value,
    textAlign: TextAlign.center,
    style: urdu ? _urduStyle(size: 13) : _numberStyle(size: 11),
  ),
);

class MonthlyStatementDocument extends StatelessWidget {
  const MonthlyStatementDocument({
    required this.customer,
    required this.month,
    required this.monthOpening,
    required this.entries,
    required this.configs,
    required this.farmName,
    required this.phones,
    super.key,
  });

  final Customer customer;
  final DateTime month;
  final int monthOpening;
  final List<DailyEntry> entries;
  final Map<String, DailyConfig> configs;
  final String farmName;
  final String phones;

  @override
  Widget build(BuildContext context) {
    final days = calendarDaysInMonth(month);
    final monthEntries = {
      for (final entry in entries)
        if (entry.customerId == customer.id &&
            entry.date.startsWith(DateFormat('yyyy-MM').format(month)))
          DateTime.parse(entry.date).day: entry,
    };
    var balance = monthOpening;
    var billed = 0;
    var cash = 0;
    final rows = <TableRow>[_monthlyHeader()];
    for (var day = 1; day <= days; day++) {
      final entry = monthEntries[day];
      if (entry == null || !entry.hasTransaction) {
        rows.add(_blankMonthRow(day));
        continue;
      }
      final dayConfig = configs[entry.date];
      if (dayConfig == null) {
        rows.add(_blankMonthRow(day));
        continue;
      }
      final previous = balance;
      final bill = entry.bill(customer, dayConfig);
      final due = previous + bill;
      balance = due - entry.cashReceived;
      billed += bill;
      cash += entry.cashReceived;
      rows.add(
        _monthRow(
          day,
          _money(previous),
          entry.totalGrams == 0 ? 'ناگا' : formatWeight(entry.totalGrams),
          _money(bill),
          _money(due),
          _money(entry.cashReceived),
          _money(balance),
        ),
      );
    }

    return Container(
      width: a4Width,
      height: a4Height,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 18),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              farmName,
              textAlign: TextAlign.center,
              style: _urduStyle(size: 25, weight: FontWeight.w700),
            ),
            Text(
              'ماہانہ کھاتہ سٹیٹمنٹ  •  ${month.month}/${month.year}',
              textAlign: TextAlign.center,
              style: _urduStyle(size: 18, weight: FontWeight.w700),
            ),
            Text(
              'خریدار: ${customer.name}    فون: ${customer.phone}    ماہانہ سابقہ بقایا: ${_money(monthOpening)}',
              textAlign: TextAlign.center,
              style: _urduStyle(size: 15),
            ),
            Text(
              phones,
              textAlign: TextAlign.center,
              style: _urduStyle(size: 13),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Table(
                border: TableBorder.all(color: Colors.black, width: 0.5),
                columnWidths: const {
                  0: FlexColumnWidth(0.55),
                  1: FlexColumnWidth(1.05),
                  2: FlexColumnWidth(0.9),
                  3: FlexColumnWidth(0.9),
                  4: FlexColumnWidth(0.95),
                  5: FlexColumnWidth(0.9),
                  6: FlexColumnWidth(1.05),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: rows,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceAround,
              children: [
                _monthSummary('ماہانہ سابقہ بقایا', _money(monthOpening)),
                _monthSummary('کل ماہانہ بل', _money(billed)),
                _monthSummary('کل جمع رقم', _money(cash)),
                _monthSummary('موجودہ کل بقایا', _money(balance)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

TableRow _monthlyHeader() => TableRow(
  decoration: const BoxDecoration(color: Color(0xFFE9E9E9)),
  children: [
    for (final text in [
      'تاریخ',
      'سابقہ بقایا',
      'وزن / تفصیل',
      'آج کا بل',
      'ٹوٹل',
      'جمع رقم',
      'بقایا رقم',
    ])
      Padding(
        padding: const EdgeInsets.all(3),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: _urduStyle(size: 12, weight: FontWeight.w700),
        ),
      ),
  ],
);

TableRow _blankMonthRow(int day) => _monthRow(day, '', '', '', '', '', '');

TableRow _monthRow(
  int day,
  String previous,
  String weight,
  String bill,
  String total,
  String cash,
  String closing,
) => TableRow(
  children: [
    _monthCell(day.toString().padLeft(2, '0')),
    _monthCell(previous),
    _monthCell(weight, urdu: weight == 'ناگا'),
    _monthCell(bill),
    _monthCell(total),
    _monthCell(cash),
    _monthCell(closing),
  ],
);

Widget _monthCell(String value, {bool urdu = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
  child: Text(
    value,
    textAlign: TextAlign.center,
    style: urdu ? _urduStyle(size: 11) : _numberStyle(size: 10),
  ),
);

Widget _monthSummary(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  child: Column(
    children: [
      Text(label, style: _urduStyle(size: 12, weight: FontWeight.w700)),
      Text(value, style: _numberStyle(size: 12, weight: FontWeight.w700)),
    ],
  ),
);

class MultiBillPageDocument extends StatelessWidget {
  const MultiBillPageDocument({
    required this.bills,
    required this.columns,
    required this.rows,
    required this.farmName,
    required this.proprietor,
    required this.phones,
    required this.address,
    super.key,
  });

  final List<ReceiptDocument> bills;
  final int columns;
  final int rows;
  final String farmName;
  final String proprietor;
  final String phones;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: a4Width,
      height: a4Height,
      color: Colors.white,
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Column(
            children: [
              for (var row = 0; row < rows; row++)
                Expanded(
                  child: Row(
                    children: [
                      for (var column = 0; column < columns; column++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(9),
                            child: row * columns + column < bills.length
                                ? bills[row * columns + column]
                                : const SizedBox.expand(),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _CutLinesPainter(columns, rows)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CutLinesPainter extends CustomPainter {
  const _CutLinesPainter(this.columns, this.rows);

  final int columns;
  final int rows;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 0.8;
    void dashed(Offset start, Offset end) {
      const dash = 6.0;
      const gap = 4.0;
      final delta = end - start;
      final length = delta.distance;
      final unit = delta / length;
      for (double offset = 0; offset < length; offset += dash + gap) {
        final next = (offset + dash).clamp(0, length).toDouble();
        canvas.drawLine(start + unit * offset, start + unit * next, paint);
      }
    }

    for (var column = 1; column < columns; column++) {
      final x = size.width * column / columns;
      dashed(Offset(x, 0), Offset(x, size.height));
    }
    for (var row = 1; row < rows; row++) {
      final y = size.height * row / rows;
      dashed(Offset(0, y), Offset(size.width, y));
      _paintScissors(canvas, Offset(size.width / 2, y));
    }
    for (var column = 1; column < columns; column++) {
      final x = size.width * column / columns;
      _paintScissors(canvas, Offset(x, size.height / 2));
    }
  }

  void _paintScissors(Canvas canvas, Offset center) {
    final painter = TextPainter(
      text: const TextSpan(
        text: '✂',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          color: Colors.black,
          backgroundColor: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_CutLinesPainter oldDelegate) =>
      oldDelegate.columns != columns || oldDelegate.rows != rows;
}
