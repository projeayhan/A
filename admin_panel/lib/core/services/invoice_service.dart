import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_panel/core/services/log_service.dart';
import 'supabase_service.dart';

class InvoiceService {
  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _invoiceDateFormat = DateFormat('dd.MM.yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: 'TL',
    decimalDigits: 2,
  );

  static pw.Font? _cachedFont;

  static Future<pw.Font> _loadFont() async {
    if (_cachedFont != null) return _cachedFont!;
    // Türkçe karakter destekli fontları sırayla dene
    for (final fontPath in [
      'assets/fonts/NotoSans.ttf',
      'assets/fonts/DejaVuSans.ttf',
    ]) {
      try {
        final data = await rootBundle.load(fontPath);
        if (data.lengthInBytes > 0) {
          final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          _cachedFont = pw.Font.ttf(ByteData.sublistView(bytes));
          return _cachedFont!;
        }
      } catch (e, st) {
        LogService.error('Font loading failed: $fontPath', error: e, stackTrace: st, source: 'invoice_service.dart:_loadFont');
        continue;
      }
    }
    _cachedFont = pw.Font.helvetica();
    return _cachedFont!;
  }

  /// Clear font cache (useful after hot reload)
  static void clearFontCache() {
    _cachedFont = null;
  }

  static Map<String, String>? _cachedCompanyInfo;

  static Future<Map<String, String>> getCompanyInfo() async {
    if (_cachedCompanyInfo != null) return _cachedCompanyInfo!;
    final row = await SupabaseService.client
        .from('company_settings')
        .select()
        .limit(1)
        .single();
    _cachedCompanyInfo = {
      'name': row['name'] as String,
      'address': row['address'] as String,
      'phone': row['phone'] as String? ?? '',
      'email': row['email'] as String? ?? '',
      'taxOffice': row['tax_office'] as String,
      'taxNumber': row['tax_number'] as String,
      'website': row['website'] as String? ?? '',
      'invoicePrefix': row['invoice_prefix'] as String? ?? 'ODB',
    };
    return _cachedCompanyInfo!;
  }

  static void clearCompanyInfoCache() => _cachedCompanyInfo = null;

  static Future<String> generateInvoiceNumberFromDB() async {
    final result = await SupabaseService.client.rpc('get_next_invoice_number');
    return result as String;
  }

  // Faturayı DB'ye kaydet ve PDF'i Storage'a yükle
  static Future<Map<String, dynamic>> saveInvoice({
    required String sourceType,
    required String sourceId,
    required String buyerName,
    String? buyerEmail,
    String? buyerTaxNumber,
    String? buyerTaxOffice,
    String? buyerAddress,
    String? buyerPhone,
    required double subtotal,
    required double kdvRate,
    required double kdvAmount,
    required double total,
    required List<Map<String, dynamic>> items,
    String invoiceType = 'sale',
    String? parentInvoiceId,
    String? invoicePeriod,
    double? onlineTotal,
    double? cashTotal,
    double? netTransfer,
    String? paymentMethod,
    String? customInvoiceNumber,
  }) async {
    final supabase = SupabaseService.client;
    final company = await getCompanyInfo();
    final invoiceNumber = (customInvoiceNumber != null && customInvoiceNumber.isNotEmpty)
        ? customInvoiceNumber
        : await generateInvoiceNumberFromDB();

    // 1. DB'ye kaydet
    final invoice = await supabase.from('invoices').insert({
      'invoice_number': invoiceNumber,
      'invoice_type': invoiceType,
      'source_type': sourceType,
      'source_id': sourceId,
      'parent_invoice_id': parentInvoiceId,
      'seller_name': company['name'],
      'seller_tax_number': company['taxNumber'],
      'seller_tax_office': company['taxOffice'],
      'seller_address': company['address'],
      'buyer_name': buyerName,
      'buyer_email': buyerEmail,
      'buyer_tax_number': buyerTaxNumber,
      'buyer_address': buyerAddress,
      if (invoicePeriod != null) 'invoice_period': invoicePeriod,
      'subtotal': subtotal,
      'kdv_rate': kdvRate,
      'kdv_amount': kdvAmount,
      'total': total,
      'currency': 'TRY',
      'status': 'issued',
    }).select().single();

    // 2. Kalemleri ekle
    if (items.isNotEmpty) {
      await supabase.from('invoice_items').insert(
        items.asMap().entries.map((e) {
          final item = e.value;
          final orderAmt = item['order_amount'] ?? item['unit_price'] ?? 0;
          final commission = item['commission'] ?? item['total'] ?? 0;
          return {
            'invoice_id': invoice['id'],
            'description': item['description'],
            'quantity': item['quantity'] ?? 1,
            'unit_price': orderAmt,
            'kdv_rate': kdvRate,
            'total': commission,
            'sort_order': e.key,
          };
        }).toList(),
      );
    }

    // 3. PDF oluştur
    final pdfBytes = await generateInvoicePdf(
      payment: {
        'amount': total,
        'users': {'full_name': buyerName},
      },
      invoiceNumber: invoiceNumber,
      customerInfo: {
        'name': buyerName,
        if (buyerTaxNumber != null) 'taxNumber': buyerTaxNumber,
        if (buyerTaxOffice != null) 'taxOffice': buyerTaxOffice,
        if (buyerAddress != null) 'address': buyerAddress,
        if (buyerPhone != null) 'phone': buyerPhone,
        if (buyerEmail != null) 'email': buyerEmail,
      },
      invoiceType: invoiceType == 'refund' ? 'İADE FATURASI' : 'FATURA',
      items: items,
      subtotalOverride: subtotal,
      kdvAmountOverride: kdvAmount,
      kdvRateOverride: kdvRate,
      onlineTotal: onlineTotal,
      cashTotal: cashTotal,
      netTransfer: netTransfer,
      paymentMethod: paymentMethod,
    );

    // 4. Storage'a yükle — her seferinde benzersiz dosya adı (CDN cache sorunu önlenir)
    final safeBuyerName = _sanitizeFileName(buyerName);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'invoices/${safeBuyerName}_${invoiceNumber}_$ts.pdf';
    await supabase.storage.from('invoices').uploadBinary(
      fileName,
      pdfBytes,
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );
    final pdfUrl = supabase.storage.from('invoices').getPublicUrl(fileName);

    // 5. pdf_url güncelle
    await supabase.from('invoices')
        .update({'pdf_url': pdfUrl})
        .eq('id', invoice['id']);

    return {...invoice, 'pdf_url': pdfUrl};
  }

  // PDF Fatura Olustur
  static Future<Uint8List> generateInvoicePdf({
    required Map<String, dynamic> payment,
    required String invoiceNumber,
    Map<String, String>? customerInfo,
    String? invoiceType,
    List<Map<String, dynamic>>? items,
    double? subtotalOverride,
    double? kdvAmountOverride,
    double? kdvRateOverride,
    double? onlineTotal,
    double? cashTotal,
    double? netTransfer,
    String? paymentMethod,
  }) async {
    final company = await getCompanyInfo();
    final font = await _loadFont();
    final pdf = pw.Document();

    // Logo yükle
    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/supercyp_logo_horizontal.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e, st) {
      LogService.error('Logo loading failed', error: e, stackTrace: st, source: 'invoice_service.dart:generateInvoicePdf');
    }

    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    final kdvRateVal = kdvRateOverride ?? 0.20;
    final kdvAmount = kdvAmountOverride ?? (amount * kdvRateVal / (1 + kdvRateVal));
    final netAmount = subtotalOverride ?? (amount - kdvAmount);
    final kdvPercent = (kdvRateVal * 100).round();

    // items varsa onları kullan, yoksa eski payment-based satır
    final tableRows = <pw.Widget>[];
    if (items != null && items.isNotEmpty) {
      for (final item in items) {
        final orderAmount = double.tryParse(
            (item['order_amount'] ?? item['unit_price'] ?? '0').toString()) ?? 0;
        final commission = double.tryParse(
            (item['commission'] ?? item['total'] ?? '0').toString()) ?? 0;
        tableRows.add(_buildTableRow(
          item['description']?.toString() ?? '-',
          orderAmount > 0 ? _currencyFormat.format(orderAmount) : '',
          commission > 0 ? _currencyFormat.format(commission) : (orderAmount > 0 ? _currencyFormat.format(orderAmount) : ''),
          font: font,
          isBoldRow: item['bold'] == true,
        ));
      }
    } else {
      tableRows.add(_buildTableRow(
        payment['description']?.toString() ?? _getPaymentDescription(payment),
        _currencyFormat.format(netAmount),
        _currencyFormat.format(netAmount),
        font: font,
      ));
    }

    final buyerName = customerInfo?['name'] ?? payment['users']?['full_name'] ?? 'Müşteri';

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
                      if (logoImage != null) pw.Image(logoImage, width: 180, height: 50, fit: pw.BoxFit.contain) else pw.Text(company['name']!, style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text(company['address']!, style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Tel: ${company['phone']}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('E-posta: ${company['email']}', style: pw.TextStyle(font: font, fontSize: 10)),
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
                        pw.Text(invoiceType ?? 'FATURA', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.SizedBox(height: 5),
                        pw.Text('No: $invoiceNumber', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('Tarih: ${_invoiceDateFormat.format(DateTime.now())}', style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Satıcı / Alıcı Bilgileri
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Satıcı Bilgileri', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(company['name']!, style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('Vergi Dairesi: ${company['taxOffice']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('Vergi No: ${company['taxNumber']}', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Alıcı Bilgileri', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(buyerName, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          if (customerInfo?['taxOffice'] != null)
                            pw.Text('Vergi Dairesi: ${customerInfo!['taxOffice']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (customerInfo?['taxNumber'] != null)
                            pw.Text('Vergi No: ${customerInfo!['taxNumber']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (customerInfo?['address'] != null && (customerInfo!['address'] as String).isNotEmpty)
                            pw.Text('Adres: ${customerInfo['address']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (customerInfo?['phone'] != null)
                            pw.Text('Tel: ${customerInfo!['phone']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          if (customerInfo?['email'] != null)
                            pw.Text('E-posta: ${customerInfo!['email']}', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Tablo Başlığı
              pw.Container(
                color: PdfColors.blue800,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Açıklama', style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    pw.Expanded(flex: 2, child: pw.Text('Sipariş Tutarı', style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                    pw.Expanded(flex: 2, child: pw.Text('Komisyon', style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // Tablo İçeriği
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(children: tableRows),
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
                        _buildTotalRow('Ara Toplam', _currencyFormat.format(netAmount), font: font),
                        _buildTotalRow('KDV (%$kdvPercent)', _currencyFormat.format(kdvAmount), font: font),
                        pw.Divider(color: PdfColors.grey400),
                        _buildTotalRow('Genel Toplam', _currencyFormat.format(amount), isBold: true, font: font),
                      ],
                    ),
                  ),
                ],
              ),

              // Ödeme yöntemi bilgisi
              if (paymentMethod != null && paymentMethod.isNotEmpty) ...[
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 250,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: paymentMethod == 'online' ? PdfColors.green50 : PdfColors.grey100,
                        border: pw.Border.all(
                          color: paymentMethod == 'online' ? PdfColors.green400 : PdfColors.grey400,
                        ),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Odeme Yontemi:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            _getPaymentMethodLabel(paymentMethod),
                            style: pw.TextStyle(
                              font: font, fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: paymentMethod == 'online' ? PdfColors.green800 : PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              // Online ödeme özet kutusu
              if (onlineTotal != null && onlineTotal > 0) ...[
                pw.SizedBox(height: 20),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    border: pw.Border.all(color: PdfColors.blue300),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Online Ödeme Özeti', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.SizedBox(height: 8),
                      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text('Platform üzerinden tahsil edilen online ödemeler:', style: pw.TextStyle(font: font, fontSize: 10)),
                        pw.Text(_currencyFormat.format(onlineTotal), style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ]),
                      if (cashTotal != null && cashTotal > 0) ...[
                        pw.SizedBox(height: 4),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text('Nakit/Kart tahsilat (işletme tarafından alındı):', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text(_currencyFormat.format(cashTotal), style: pw.TextStyle(font: font, fontSize: 10)),
                        ]),
                      ],
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColors.blue300),
                      pw.SizedBox(height: 4),
                      if (netTransfer != null)
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text(
                            netTransfer >= 0 ? 'İşletmeye gönderilecek net tutar:' : 'İşletmeden tahsil edilecek net tutar:',
                            style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold,
                              color: netTransfer >= 0 ? PdfColors.green800 : PdfColors.red800),
                          ),
                          pw.Text(
                            _currencyFormat.format(netTransfer.abs()),
                            style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold,
                              color: netTransfer >= 0 ? PdfColors.green800 : PdfColors.red800),
                          ),
                        ]),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('Bu fatura elektronik ortamda oluşturulmuştur.', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('${company['website']} | ${company['email']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
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

  /// Arşivdeki herhangi bir fatura kaydından PDF oluşturur
  static Future<Uint8List> generateArchiveInvoicePdf({
    required Map<String, dynamic> invoice,
  }) async {
    final company = await getCompanyInfo();
    final font = await _loadFont();
    final boldFont = font; // DejaVuSans has no separate bold, reuse
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: boldFont),
    );

    pw.ImageProvider? logoImage;
    try {
      final logoData = await rootBundle.load('assets/images/supercyp_logo_horizontal.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e, st) {
      LogService.error('Logo loading failed', error: e, stackTrace: st, source: 'invoice_service.dart:generateInvoicePdfFromRecord');
    }

    final invoiceNumber = invoice['invoice_number']?.toString() ?? '-';
    final buyerName = invoice['buyer_name']?.toString() ?? 'Alıcı';
    final subtotal = double.tryParse(invoice['subtotal']?.toString() ?? '0') ?? 0;
    final kdvAmount = double.tryParse(invoice['kdv_amount']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(invoice['total']?.toString() ?? '0') ?? 0;
    final kdvRate = double.tryParse(invoice['kdv_rate']?.toString() ?? '20') ?? 20;
    final kdvPercent = kdvRate >= 1 ? kdvRate.round() : (kdvRate * 100).round();
    final createdAt = invoice['created_at'] != null ? DateTime.tryParse(invoice['created_at'].toString()) : null;
    final dateStr = createdAt != null ? _invoiceDateFormat.format(createdAt) : _invoiceDateFormat.format(DateTime.now());
    final period = invoice['invoice_period']?.toString() ?? '-';
    final sourceType = invoice['source_type']?.toString() ?? '-';

    String sourceLabel;
    switch (sourceType) {
      case 'merchant_commission': sourceLabel = 'Komisyon Faturası'; break;
      case 'merchant_invoice': sourceLabel = 'İşletme Faturası'; break;
      case 'manual': sourceLabel = 'Manuel Fatura'; break;
      case 'taxi_payment': sourceLabel = 'Taksi Ödeme Faturası'; break;
      case 'food_order': sourceLabel = 'Yemek Sipariş Faturası'; break;
      default: sourceLabel = 'Fatura';
    }

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
                      if (logoImage != null) pw.Image(logoImage, width: 180, height: 50, fit: pw.BoxFit.contain) else pw.Text(company['name']!, style: pw.TextStyle(font: font, fontSize: 20, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 5),
                      pw.Text(company['address']!, style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('Tel: ${company['phone']}', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('E-posta: ${company['email']}', style: pw.TextStyle(font: font, fontSize: 10)),
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
                        pw.Text(sourceLabel, style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.SizedBox(height: 5),
                        pw.Text('No: $invoiceNumber', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('Tarih: $dateStr', style: pw.TextStyle(font: font, fontSize: 11)),
                        if (period != '-') pw.Text('Dönem: $period', style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Satıcı / Alıcı
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Satıcı Bilgileri', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(company['name']!, style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('Vergi Dairesi: ${company['taxOffice']}', style: pw.TextStyle(font: font, fontSize: 10)),
                          pw.Text('Vergi No: ${company['taxNumber']}', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Alıcı Bilgileri', style: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, fontSize: 11)),
                          pw.SizedBox(height: 5),
                          pw.Text(buyerName, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),

              // Tablo Başlığı
              pw.Container(
                color: PdfColors.blue800,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 4, child: pw.Text('Açıklama', style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11))),
                    pw.Expanded(flex: 2, child: pw.Text('Tutar', style: pw.TextStyle(font: font, color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11), textAlign: pw.TextAlign.right)),
                  ],
                ),
              ),

              // Satır
              pw.Container(
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(sourceLabel, style: pw.TextStyle(font: font, fontSize: 10))),
                      pw.Expanded(flex: 2, child: pw.Text(_currencyFormat.format(subtotal), style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.right)),
                    ],
                  ),
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
                        _buildTotalRow('Ara Toplam', _currencyFormat.format(subtotal), font: font),
                        _buildTotalRow('KDV (%$kdvPercent)', _currencyFormat.format(kdvAmount), font: font),
                        pw.Divider(color: PdfColors.grey400),
                        _buildTotalRow('Genel Toplam', _currencyFormat.format(total), isBold: true, font: font),
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
                    pw.Text('Bu fatura elektronik ortamda oluşturulmuştur.', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
                    pw.Text('${company['website']} | ${company['email']}', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600)),
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

  static pw.Widget _buildTableRow(String description, String col2, String col3, {pw.Font? font, bool isBoldRow = false}) {
    final style = pw.TextStyle(font: font, fontSize: 10, fontWeight: isBoldRow ? pw.FontWeight.bold : pw.FontWeight.normal);
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(flex: 4, child: pw.Text(description, style: style)),
          pw.Expanded(flex: 2, child: pw.Text(col2, style: style, textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text(col3, style: style, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false, pw.Font? font}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: font,
              fontSize: isBold ? 12 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: font,
              fontSize: isBold ? 12 : 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Dosya adı için güvenli string: Türkçe karakterleri dönüştür, özel karakterleri kaldır
  static String _sanitizeFileName(String name) {
    const tr = 'çÇğĞıİöÖşŞüÜ';
    const en = 'cCgGiIoOsSuU';
    var result = name;
    for (var i = 0; i < tr.length; i++) {
      result = result.replaceAll(tr[i], en[i]);
    }
    return result
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase();
  }

  static String _getPaymentMethodLabel(String? method) {
    switch (method) {
      case 'online':
        return 'Online (Stripe)';
      case 'cash':
        return 'Nakit';
      case 'card':
        return 'Kredi Karti';
      case 'credit_card_on_delivery':
        return 'Kapida Kart';
      default:
        return method ?? '-';
    }
  }

  static String _getPaymentDescription(Map<String, dynamic> payment) {
    final rideIdStr = payment['ride_id']?.toString() ?? '';
    final rideId = rideIdStr.length > 8 ? rideIdStr.substring(0, 8) : rideIdStr;
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
    String? paymentMethod,
  }) async {
    final company = await getCompanyInfo();
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
                      pw.Text('${company['name']} Yemek Siparis Platformu', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
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
                              'Yemek Siparisi #${(order['id']?.toString() ?? '').length > 8 ? order['id'].toString().substring(0, 8) : (order['id']?.toString() ?? '')}',
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

              // Ödeme yöntemi
              if ((paymentMethod ?? order['payment_method']) != null) ...[
                pw.SizedBox(height: 15),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Container(
                      width: 200,
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: pw.BoxDecoration(
                        color: (paymentMethod ?? order['payment_method']) == 'online' ? PdfColors.green50 : PdfColors.grey100,
                        border: pw.Border.all(
                          color: (paymentMethod ?? order['payment_method']) == 'online' ? PdfColors.green400 : PdfColors.grey400,
                        ),
                        borderRadius: pw.BorderRadius.circular(5),
                      ),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Odeme:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            _getPaymentMethodLabel(paymentMethod ?? order['payment_method']?.toString()),
                            style: pw.TextStyle(
                              fontSize: 10, fontWeight: pw.FontWeight.bold,
                              color: (paymentMethod ?? order['payment_method']) == 'online' ? PdfColors.green800 : PdfColors.grey800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              pw.Spacer(),

              pw.Center(
                child: pw.Text(
                  'Afiyet olsun! - SuperCyp',
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
    } catch (e, st) {
      LogService.error('Date format failed', error: e, stackTrace: st, source: 'invoice_service.dart:_formatDateTime');
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

  static Future<List<int>> exportInvoicesToExcel(List<Map<String, dynamic>> invoices) async {
    final excel = Excel.createExcel();
    final sheet = excel['Faturalar'];

    sheet.appendRow([
      TextCellValue('Fatura No'),
      TextCellValue('Tarih'),
      TextCellValue('Dönem'),
      TextCellValue('Alıcı'),
      TextCellValue('Kaynak'),
      TextCellValue('Ara Toplam'),
      TextCellValue('KDV'),
      TextCellValue('Toplam'),
      TextCellValue('Ödeme Durumu'),
      TextCellValue('Fatura Durumu'),
      TextCellValue('Vade Tarihi'),
    ]);

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.blue600,
      fontColorHex: ExcelColor.white,
    );

    for (var i = 0; i < 11; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final inv in invoices) {
      sheet.appendRow([
        TextCellValue(inv['invoice_number']?.toString() ?? ''),
        TextCellValue(_formatDateTime(inv['created_at'])),
        TextCellValue(inv['invoice_period']?.toString() ?? '-'),
        TextCellValue(inv['buyer_name']?.toString() ?? '-'),
        TextCellValue(inv['source_type']?.toString() ?? '-'),
        DoubleCellValue(double.tryParse(inv['subtotal']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(inv['kdv_amount']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(inv['total']?.toString() ?? '0') ?? 0),
        TextCellValue(_getPaymentStatusLabel(inv['payment_status'])),
        TextCellValue(_getInvoiceStatusLabel(inv['status'])),
        TextCellValue(_formatDateTime(inv['payment_due_date'])),
      ]);
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 25);
    sheet.setColumnWidth(4, 18);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 14);
    sheet.setColumnWidth(8, 14);
    sheet.setColumnWidth(9, 14);
    sheet.setColumnWidth(10, 15);

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  static String _getPaymentStatusLabel(String? status) {
    switch (status) {
      case 'paid': return 'Ödendi';
      case 'pending': return 'Bekliyor';
      case 'overdue': return 'Gecikmiş';
      case 'partial': return 'Kısmi';
      default: return status ?? '-';
    }
  }

  static String _getInvoiceStatusLabel(String? status) {
    switch (status) {
      case 'issued': return 'Kesildi';
      case 'sent': return 'Gönderildi';
      case 'cancelled': return 'İptal';
      case 'draft': return 'Taslak';
      default: return status ?? '-';
    }
  }

  // ==================== GENERIC EXPORTS ====================

  /// Export users list to Excel
  static Future<List<int>> exportUsersToExcel(List<Map<String, dynamic>> users) async {
    final excel = Excel.createExcel();
    final sheet = excel['Kullanicilar'];

    sheet.appendRow([
      TextCellValue('ID'),
      TextCellValue('Ad Soyad'),
      TextCellValue('E-posta'),
      TextCellValue('Telefon'),
      TextCellValue('Durum'),
      TextCellValue('Yasakli'),
      TextCellValue('Kayit Tarihi'),
    ]);

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue600, fontColorHex: ExcelColor.white);
    for (var i = 0; i < 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final user in users) {
      sheet.appendRow([
        TextCellValue(user['id']?.toString() ?? ''),
        TextCellValue(user['full_name']?.toString() ?? ''),
        TextCellValue(user['email']?.toString() ?? ''),
        TextCellValue(user['phone']?.toString() ?? ''),
        TextCellValue('active'),
        TextCellValue(''),
        TextCellValue(_formatDateTime(user['created_at']?.toString())),
      ]);
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 25);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 15);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 10);
    sheet.setColumnWidth(6, 18);

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  /// Export orders list to Excel
  static Future<List<int>> exportOrdersToExcel(List<Map<String, dynamic>> orders) async {
    final excel = Excel.createExcel();
    final sheet = excel['Siparisler'];

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

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue600, fontColorHex: ExcelColor.white);
    for (var i = 0; i < 8; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final order in orders) {
      sheet.appendRow([
        TextCellValue(order['id']?.toString() ?? ''),
        TextCellValue(_formatDateTime(order['created_at']?.toString())),
        TextCellValue(order['customer_name']?.toString() ?? ''),
        TextCellValue(order['merchants']?['business_name']?.toString() ?? order['merchant_name']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(order['total_amount']?.toString() ?? '0') ?? 0),
        TextCellValue(order['payment_method']?.toString() ?? ''),
        TextCellValue(_getOrderStatusLabel(order['status'])),
        TextCellValue(order['delivery_address']?.toString() ?? ''),
      ]);
    }

    sheet.setColumnWidth(0, 15);
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 25);
    sheet.setColumnWidth(3, 25);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);
    sheet.setColumnWidth(7, 30);

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  /// Export logs to Excel
  static Future<List<int>> exportLogsToExcel(List<Map<String, dynamic>> logs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Log Kayitlari'];

    sheet.appendRow([
      TextCellValue('Tarih'),
      TextCellValue('Admin'),
      TextCellValue('Islem Tipi'),
      TextCellValue('Ciddiyet'),
      TextCellValue('Aciklama'),
      TextCellValue('Hedef'),
      TextCellValue('IP Adresi'),
    ]);

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue600, fontColorHex: ExcelColor.white);
    for (var i = 0; i < 7; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final log in logs) {
      sheet.appendRow([
        TextCellValue(_formatDateTime(log['created_at']?.toString())),
        TextCellValue(log['admin_users']?['full_name']?.toString() ?? log['admin_id']?.toString() ?? ''),
        TextCellValue(log['action_type']?.toString() ?? ''),
        TextCellValue(log['severity']?.toString() ?? ''),
        TextCellValue(log['description']?.toString() ?? ''),
        TextCellValue(log['target_type']?.toString() ?? ''),
        TextCellValue(log['ip_address']?.toString() ?? ''),
      ]);
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 20);
    sheet.setColumnWidth(2, 15);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 40);
    sheet.setColumnWidth(5, 15);
    sheet.setColumnWidth(6, 15);

    excel.delete('Sheet1');
    return excel.encode()!;
  }

  /// Export finance/transactions to Excel
  static Future<List<int>> exportFinanceToExcel(List<Map<String, dynamic>> transactions) async {
    final excel = Excel.createExcel();
    final sheet = excel['Finans'];

    sheet.appendRow([
      TextCellValue('Tarih'),
      TextCellValue('Islem Tipi'),
      TextCellValue('Aciklama'),
      TextCellValue('Tutar'),
      TextCellValue('Para Birimi'),
      TextCellValue('Durum'),
    ]);

    final headerStyle = CellStyle(bold: true, backgroundColorHex: ExcelColor.blue600, fontColorHex: ExcelColor.white);
    for (var i = 0; i < 6; i++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
    }

    for (final t in transactions) {
      sheet.appendRow([
        TextCellValue(_formatDateTime(t['created_at']?.toString())),
        TextCellValue(t['type']?.toString() ?? ''),
        TextCellValue(t['description']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(t['amount']?.toString() ?? '0') ?? 0),
        TextCellValue(t['currency']?.toString() ?? 'TRY'),
        TextCellValue(t['status']?.toString() ?? ''),
      ]);
    }

    sheet.setColumnWidth(0, 18);
    sheet.setColumnWidth(1, 15);
    sheet.setColumnWidth(2, 35);
    sheet.setColumnWidth(3, 12);
    sheet.setColumnWidth(4, 12);
    sheet.setColumnWidth(5, 12);

    excel.delete('Sheet1');
    return excel.encode()!;
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
