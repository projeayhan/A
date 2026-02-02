import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class InvoiceService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _invoiceDateFormat = DateFormat('dd.MM.yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: 'TL',
    decimalDigits: 2,
  );

  // Sirket Bilgileri
  static const Map<String, String> companyInfo = {
    'name': 'OdaBase Teknoloji A.S.',
    'address': 'Levent Mah. Buyukdere Cad. No:123\n34394 Sisli/Istanbul',
    'phone': '+90 212 555 00 00',
    'email': 'fatura@odabase.com',
    'taxOffice': 'Besiktas Vergi Dairesi',
    'taxNumber': '1234567890',
    'website': 'www.odabase.com',
  };

  // Fatura numarasi uret
  static String generateInvoiceNumber({String prefix = 'ODB'}) {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final random = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    return '$prefix$year$month-$random';
  }

  // PDF Fatura Olustur
  static Future<Uint8List> generateInvoicePdf({
    required Map<String, dynamic> payment,
    required String invoiceNumber,
    Map<String, String>? customerInfo,
    String? invoiceType,
  }) async {
    final pdf = pw.Document();

    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final kdvRate = 0.20;
    final kdvAmount = amount * kdvRate / (1 + kdvRate);
    final netAmount = amount - kdvAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        companyInfo['name']!,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(companyInfo['address']!, style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Tel: ${companyInfo['phone']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('E-posta: ${companyInfo['email']}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          invoiceType ?? 'FATURA',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('No: $invoiceNumber', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(
                          'Tarih: ${_invoiceDateFormat.format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Sirket Bilgileri
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Satici Bilgileri', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(companyInfo['name']!, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Vergi Dairesi: ${companyInfo['taxOffice']}', style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('Vergi No: ${companyInfo['taxNumber']}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Alici Bilgileri', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(
                            customerInfo?['name'] ?? payment['users']?['full_name'] ?? 'Musteri',
                            style: const pw.TextStyle(fontSize: 10),
                          ),
                          if (customerInfo?['taxNumber'] != null)
                            pw.Text('Vergi/TC No: ${customerInfo!['taxNumber']}', style: const pw.TextStyle(fontSize: 10)),
                          if (customerInfo?['address'] != null)
                            pw.Text(customerInfo!['address']!, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Tablo Basligi
              pw.Container(
                color: PdfColors.blue800,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Aciklama', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    pw.Expanded(flex: 1, child: pw.Text('Miktar', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.center)),
                    pw.Expanded(flex: 2, child: pw.Text('Birim Fiyat', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Toplam', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // Tablo Icerigi
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    _buildTableRow(
                      _getPaymentDescription(payment),
                      '1',
                      _currencyFormat.format(netAmount),
                      _currencyFormat.format(netAmount),
                    ),
                    if (payment['tip_amount'] != null && (double.tryParse(payment['tip_amount'].toString()) ?? 0) > 0)
                      _buildTableRow(
                        'Bahsis',
                        '1',
                        _currencyFormat.format(double.parse(payment['tip_amount'].toString())),
                        _currencyFormat.format(double.parse(payment['tip_amount'].toString())),
                      ),
                    if (payment['toll_amount'] != null && (double.tryParse(payment['toll_amount'].toString()) ?? 0) > 0)
                      _buildTableRow(
                        'Gecis Ucreti',
                        '1',
                        _currencyFormat.format(double.parse(payment['toll_amount'].toString())),
                        _currencyFormat.format(double.parse(payment['toll_amount'].toString())),
                      ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Toplamlar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 250,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Ara Toplam', _currencyFormat.format(netAmount)),
                        _buildTotalRow('KDV (%20)', _currencyFormat.format(kdvAmount)),
                        pw.Divider(color: PdfColors.grey400),
                        _buildTotalRow('Genel Toplam', _currencyFormat.format(amount), isBold: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Bu fatura elektronik ortamda olusturulmustur.',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      '${companyInfo['website']} | ${companyInfo['email']}',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildTableRow(String description, String quantity, String unitPrice, String total) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 4, child: pw.Text(description, style: const pw.TextStyle(fontSize: 10))),
          pw.Expanded(flex: 1, child: pw.Text(quantity, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text(unitPrice, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text(total, style: const pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: isBold ? 12 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: isBold ? 12 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  static String _getPaymentDescription(Map<String, dynamic> payment) {
    final rideId = payment['ride_id']?.toString().substring(0, 8) ?? '';
    final paymentType = payment['payment_type'] ?? '';

    String typeLabel;
    switch (paymentType) {
      case 'cash':
        typeLabel = 'Nakit';
        break;
      case 'card':
        typeLabel = 'Kredi Karti';
        break;
      case 'online':
        typeLabel = 'Online';
        break;
      default:
        typeLabel = paymentType;
    }

    return 'Taksi Yolculuk Hizmeti #$rideId ($typeLabel)';
  }

  // Yemek Siparisi PDF
  static Future<Uint8List> generateFoodOrderInvoicePdf({
    required Map<String, dynamic> order,
    required String invoiceNumber,
  }) async {
    final pdf = pw.Document();

    final amount = double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0;
    final kdvRate = 0.10; // Yemek icin %10 KDV
    final kdvAmount = amount * kdvRate / (1 + kdvRate);
    final netAmount = amount - kdvAmount;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        order['merchants']?['name'] ?? 'Isletme',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text('OdaBase Yemek Siparis Platformu', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(15),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.orange),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'SIPARIS FATURASI',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange800,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Text('No: $invoiceNumber', style: const pw.TextStyle(fontSize: 11)),
                        pw.Text(
                          'Tarih: ${_invoiceDateFormat.format(DateTime.now())}',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Musteri Bilgileri
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Musteri Bilgileri', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.SizedBox(height: 5),
                    pw.Text(order['users']?['full_name'] ?? 'Musteri', style: const pw.TextStyle(fontSize: 10)),
                    if (order['delivery_address'] != null)
                      pw.Text('Adres: ${order['delivery_address']}', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Tablo
              pw.Container(
                color: PdfColors.orange800,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Urun', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    pw.Expanded(flex: 2, child: pw.Text('Toplam', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Column(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(
                              'Yemek Siparisi #${order['id']?.toString().substring(0, 8) ?? ''}',
                              style: const pw.TextStyle(fontSize: 10),
                            ),
                          ),
                          pw.Expanded(
                            flex: 2,
                            child: pw.Text(
                              _currencyFormat.format(netAmount),
                              style: const pw.TextStyle(fontSize: 10),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Toplamlar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Container(
                    width: 200,
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Ara Toplam', _currencyFormat.format(netAmount)),
                        _buildTotalRow('KDV (%10)', _currencyFormat.format(kdvAmount)),
                        pw.Divider(color: PdfColors.grey400),
                        _buildTotalRow('Genel Toplam', _currencyFormat.format(amount), isBold: true),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              pw.Center(
                child: pw.Text(
                  'Afiyet olsun! - OdaBase',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.orange800, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // Excel Export
  static Future<List<int>> exportPaymentsToExcel(List<Map<String, dynamic>> payments) async {
    final excel = Excel.createExcel();
    final sheet = excel['Odemeler'];

    // Basliklar
    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Tarih'),
      TextCellValue('Kullanici'),
      TextCellValue('Surucu ID'),
      TextCellValue('Tutar'),
      TextCellValue('Para Birimi'),
      TextCellValue('Odeme Tipi'),
      TextCellValue('Durum'),
      TextCellValue('Bahsis'),
      TextCellValue('Gecis Ucreti'),
      TextCellValue('Indirim'),
      TextCellValue('Iade Tutari'),
      TextCellValue('Iade Nedeni'),
    ]);

    // Stil
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue600,
      fontColorHex: ExcelColor.white,
    );

    for (var i = 0; i < 13; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    // Veriler
    for (final payment in payments) {
      sheet.appendRow([
        TextCellValue(payment['id']?.toString() ?? ''),
        TextCellValue(_formatDateTime(payment['created_at'])),
        TextCellValue(payment['users']?['full_name'] ?? payment['user_id']?.toString() ?? ''),
        TextCellValue(payment['driver_id']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(payment['amount']?.toString() ?? '0') ?? 0),
        TextCellValue(payment['currency'] ?? 'TRY'),
        TextCellValue(_getPaymentTypeLabel(payment['payment_type'])),
        TextCellValue(_getStatusLabel(payment['status'])),
        DoubleCellValue(double.tryParse(payment['tip_amount']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(payment['toll_amount']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(payment['discount_amount']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(payment['refund_amount']?.toString() ?? '0') ?? 0),
        TextCellValue(payment['refund_reason'] ?? ''),
      ]);
    }

    // Sutun genisliklerini ayarla
    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 25);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 15);

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  static Future<List<int>> exportFoodOrdersToExcel(List<Map<String, dynamic>> orders) async {
    final excel = Excel.createExcel();
    final sheet = excel['Yemek Siparisleri'];

    // Basliklar
    sheet.appendRow([
      TextCellValue('Siparis No'),
      TextCellValue('Tarih'),
      TextCellValue('Musteri'),
      TextCellValue('Isletme'),
      TextCellValue('Tutar'),
      TextCellValue('Odeme Yontemi'),
      TextCellValue('Durum'),
      TextCellValue('Teslimat Adresi'),
    ]);

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.orange,
      fontColorHex: ExcelColor.white,
    );

    for (var i = 0; i < 8; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final order in orders) {
      sheet.appendRow([
        TextCellValue(order['id']?.toString() ?? ''),
        TextCellValue(_formatDateTime(order['created_at'])),
        TextCellValue(order['users']?['full_name'] ?? ''),
        TextCellValue(order['merchants']?['name'] ?? ''),
        DoubleCellValue(double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0),
        TextCellValue(order['payment_method'] ?? ''),
        TextCellValue(_getOrderStatusLabel(order['status'])),
        TextCellValue(order['delivery_address'] ?? ''),
      ]);
    }

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  static String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      return _dateFormat.format(DateTime.parse(dateStr));
    } catch (e) {
      return '-';
    }
  }

  static String _getPaymentTypeLabel(String? type) {
    switch (type) {
      case 'cash': return 'Nakit';
      case 'card': return 'Kart';
      case 'online': return 'Online';
      default: return type ?? '-';
    }
  }

  static String _getStatusLabel(String? status) {
    switch (status) {
      case 'completed': return 'Tamamlandi';
      case 'pending': return 'Bekliyor';
      case 'failed': return 'Basarisiz';
      case 'refunded': return 'Iade Edildi';
      default: return status ?? '-';
    }
  }

  static String _getOrderStatusLabel(String? status) {
    switch (status) {
      case 'delivered': return 'Teslim Edildi';
      case 'preparing': return 'Hazirlaniyor';
      case 'on_the_way': return 'Yolda';
      case 'cancelled': return 'Iptal';
      default: return status ?? '-';
    }
  }
}

// Manuel Fatura Modeli
class ManualInvoice {
  final String invoiceNumber;
  final DateTime date;
  final String customerName;
  final String? customerTaxNumber;
  final String? customerAddress;
  final List<InvoiceItem> items;
  final double subtotal;
  final double kdvRate;
  final double kdvAmount;
  final double total;

  ManualInvoice({
    required this.invoiceNumber,
    required this.date,
    required this.customerName,
    this.customerTaxNumber,
    this.customerAddress,
    required this.items,
    required this.subtotal,
    required this.kdvRate,
    required this.kdvAmount,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'invoice_number': invoiceNumber,
    'date': date.toIso8601String(),
    'customer_name': customerName,
    'customer_tax_number': customerTaxNumber,
    'customer_address': customerAddress,
    'items': items.map((e) => e.toJson()).toList(),
    'subtotal': subtotal,
    'kdv_rate': kdvRate,
    'kdv_amount': kdvAmount,
    'total': total,
  };
}

class InvoiceItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'total': total,
  };
}
