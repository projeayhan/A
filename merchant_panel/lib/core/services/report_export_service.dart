import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';

import '../providers/merchant_provider.dart';

/// Service for exporting reports in various formats
class ReportExportService {
  static final ReportExportService _instance = ReportExportService._internal();
  factory ReportExportService() => _instance;
  ReportExportService._internal();

  final _dateFormat = DateFormat('dd.MM.yyyy', 'tr');
  final _currencyFormat = NumberFormat('#,###', 'tr');

  /// Export report as PDF
  Future<bool> exportPdf({
    required BuildContext context,
    required ReportsStats stats,
    required DateTimeRange dateRange,
    required String merchantName,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          header: (context) => _buildPdfHeader(merchantName, dateRange),
          footer: (context) => _buildPdfFooter(context),
          build: (context) => [
            _buildPdfSummary(stats),
            pw.SizedBox(height: 20),
            _buildPdfDailyTable(stats),
            pw.SizedBox(height: 20),
            _buildPdfTopProducts(stats),
          ],
        ),
      );

      // Use printing package to share/print the PDF
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'rapor_${_dateFormat.format(dateRange.start)}_${_dateFormat.format(dateRange.end)}.pdf',
      );

      return true;
    } catch (e) {
      debugPrint('PDF export error: $e');
      return false;
    }
  }

  pw.Widget _buildPdfHeader(String merchantName, DateTimeRange dateRange) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          merchantName,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Rapor Tarihi: ${_dateFormat.format(dateRange.start)} - ${_dateFormat.format(dateRange.end)}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Olusturulma: ${_dateFormat.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Sayfa ${context.pageNumber} / ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
      ),
    );
  }

  pw.Widget _buildPdfSummary(ReportsStats stats) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Ozet Bilgiler',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatItem('Toplam Siparis', stats.totalOrders.toString()),
              _buildPdfStatItem('Toplam Gelir', '${_currencyFormat.format(stats.totalRevenue)} TL'),
              _buildPdfStatItem('Ortalama Siparis', '${stats.averageOrderValue.toStringAsFixed(2)} TL'),
              _buildPdfStatItem('Iptal Orani', '%${stats.cancellationRate.toStringAsFixed(1)}'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildPdfStatItem('Toplam Musteri', stats.totalCustomers.toString()),
              _buildPdfStatItem('Tekrar Eden', '%${stats.repeatCustomerRate.toStringAsFixed(0)}'),
              _buildPdfStatItem('Ort. Puan', stats.averageRating.toStringAsFixed(1)),
              _buildPdfStatItem('En Cok Satan', stats.bestSellingProduct),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfStatItem(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDailyTable(ReportsStats stats) {
    if (stats.dailyStats.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Center(
          child: pw.Text('Secilen tarih araliginda siparis bulunamadi'),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Gunluk Satis Ozeti',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPdfTableHeader('Tarih'),
                _buildPdfTableHeader('Siparis'),
                _buildPdfTableHeader('Gelir'),
                _buildPdfTableHeader('Ort. Sepet'),
              ],
            ),
            ...stats.dailyStats.map((daily) {
              final date = DateTime.parse(daily.date);
              return pw.TableRow(
                children: [
                  _buildPdfTableCell(_dateFormat.format(date)),
                  _buildPdfTableCell(daily.orders.toString()),
                  _buildPdfTableCell('${_currencyFormat.format(daily.revenue)} TL'),
                  _buildPdfTableCell('${daily.averageOrderValue.toStringAsFixed(2)} TL'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
    );
  }

  pw.Widget _buildPdfTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
    );
  }

  pw.Widget _buildPdfTopProducts(ReportsStats stats) {
    if (stats.topProducts.isEmpty) return pw.Container();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'En Cok Satan Urunler',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(0.5),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                _buildPdfTableHeader('#'),
                _buildPdfTableHeader('Urun'),
                _buildPdfTableHeader('Adet'),
                _buildPdfTableHeader('Gelir'),
              ],
            ),
            ...stats.topProducts.asMap().entries.map((entry) {
              final index = entry.key;
              final product = entry.value;
              return pw.TableRow(
                children: [
                  _buildPdfTableCell('${index + 1}'),
                  _buildPdfTableCell(product.name),
                  _buildPdfTableCell(product.quantity.toString()),
                  _buildPdfTableCell('${product.revenue.toStringAsFixed(0)} TL'),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  /// Export report as Excel
  Future<bool> exportExcel({
    required BuildContext context,
    required ReportsStats stats,
    required DateTimeRange dateRange,
    required String merchantName,
  }) async {
    try {
      final excel = Excel.createExcel();

      // Stil tanimlari
      final headerStyle = CellStyle(
        bold: true,
        fontSize: 12,
        backgroundColorHex: ExcelColor.fromHexString('#4CAF50'),
        fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
        horizontalAlign: HorizontalAlign.Center,
      );

      final titleStyle = CellStyle(
        bold: true,
        fontSize: 16,
        fontColorHex: ExcelColor.fromHexString('#1a1a1a'),
      );

      final subtitleStyle = CellStyle(
        fontSize: 11,
        fontColorHex: ExcelColor.fromHexString('#666666'),
        italic: true,
      );

      final metricLabelStyle = CellStyle(
        bold: true,
        fontSize: 11,
        backgroundColorHex: ExcelColor.fromHexString('#f5f5f5'),
      );

      final valueStyle = CellStyle(
        fontSize: 11,
        horizontalAlign: HorizontalAlign.Right,
      );

      // ========== OZET SHEET ==========
      final summarySheet = excel['Ozet'];

      // Sutun genislikleri
      summarySheet.setColumnWidth(0, 25);
      summarySheet.setColumnWidth(1, 20);

      // Baslik
      summarySheet.appendRow([TextCellValue(merchantName)]);
      summarySheet.cell(CellIndex.indexByString('A1')).cellStyle = titleStyle;

      summarySheet.appendRow([TextCellValue('Rapor Tarihi: ${_dateFormat.format(dateRange.start)} - ${_dateFormat.format(dateRange.end)}')]);
      summarySheet.cell(CellIndex.indexByString('A2')).cellStyle = subtitleStyle;

      summarySheet.appendRow([TextCellValue('')]); // Bos satir

      // Baslik satiri
      summarySheet.appendRow([TextCellValue('Metrik'), TextCellValue('Değer')]);
      summarySheet.cell(CellIndex.indexByString('A4')).cellStyle = headerStyle;
      summarySheet.cell(CellIndex.indexByString('B4')).cellStyle = headerStyle;

      // Veri satirlari
      final summaryData = [
        ['Toplam Sipariş', stats.totalOrders.toString()],
        ['Toplam Gelir', '${_currencyFormat.format(stats.totalRevenue)} TL'],
        ['Ortalama Sipariş', '${stats.averageOrderValue.toStringAsFixed(2)} TL'],
        ['İptal Oranı', '%${stats.cancellationRate.toStringAsFixed(1)}'],
        ['Toplam Müşteri', stats.totalCustomers.toString()],
        ['Tekrar Eden Müşteri', '%${stats.repeatCustomerRate.toStringAsFixed(0)}'],
        ['Ortalama Puan', stats.averageRating.toStringAsFixed(2)],
        ['En Çok Satan', stats.bestSellingProduct],
      ];

      for (var i = 0; i < summaryData.length; i++) {
        final rowIndex = i + 5;
        summarySheet.appendRow([TextCellValue(summaryData[i][0]), TextCellValue(summaryData[i][1])]);
        summarySheet.cell(CellIndex.indexByString('A$rowIndex')).cellStyle = metricLabelStyle;
        summarySheet.cell(CellIndex.indexByString('B$rowIndex')).cellStyle = valueStyle;
      }

      // ========== GUNLUK SATISLAR SHEET ==========
      final dailySheet = excel['Gunluk Satislar'];

      // Sutun genislikleri
      dailySheet.setColumnWidth(0, 15);
      dailySheet.setColumnWidth(1, 15);
      dailySheet.setColumnWidth(2, 15);
      dailySheet.setColumnWidth(3, 18);

      // Baslik satiri
      dailySheet.appendRow([
        TextCellValue('Tarih'),
        TextCellValue('Sipariş Sayısı'),
        TextCellValue('Gelir (TL)'),
        TextCellValue('Ortalama Sepet (TL)'),
      ]);
      dailySheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
      dailySheet.cell(CellIndex.indexByString('B1')).cellStyle = headerStyle;
      dailySheet.cell(CellIndex.indexByString('C1')).cellStyle = headerStyle;
      dailySheet.cell(CellIndex.indexByString('D1')).cellStyle = headerStyle;

      // Veri satirlari
      for (var i = 0; i < stats.dailyStats.length; i++) {
        final daily = stats.dailyStats[i];
        final date = DateTime.parse(daily.date);
        final rowIndex = i + 2;
        dailySheet.appendRow([
          TextCellValue(_dateFormat.format(date)),
          IntCellValue(daily.orders),
          DoubleCellValue(daily.revenue),
          DoubleCellValue(double.parse(daily.averageOrderValue.toStringAsFixed(2))),
        ]);
        // Alternatif satir rengi
        if (i % 2 == 1) {
          final altStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#f9f9f9'));
          dailySheet.cell(CellIndex.indexByString('A$rowIndex')).cellStyle = altStyle;
          dailySheet.cell(CellIndex.indexByString('B$rowIndex')).cellStyle = altStyle;
          dailySheet.cell(CellIndex.indexByString('C$rowIndex')).cellStyle = altStyle;
          dailySheet.cell(CellIndex.indexByString('D$rowIndex')).cellStyle = altStyle;
        }
      }

      // ========== URUN SATISLARI SHEET ==========
      final productSheet = excel['Urun Satislari'];

      // Sutun genislikleri
      productSheet.setColumnWidth(0, 8);
      productSheet.setColumnWidth(1, 30);
      productSheet.setColumnWidth(2, 12);
      productSheet.setColumnWidth(3, 15);

      // Baslik satiri
      productSheet.appendRow([
        TextCellValue('Sıra'),
        TextCellValue('Ürün Adı'),
        TextCellValue('Satış Adedi'),
        TextCellValue('Gelir (TL)'),
      ]);
      productSheet.cell(CellIndex.indexByString('A1')).cellStyle = headerStyle;
      productSheet.cell(CellIndex.indexByString('B1')).cellStyle = headerStyle;
      productSheet.cell(CellIndex.indexByString('C1')).cellStyle = headerStyle;
      productSheet.cell(CellIndex.indexByString('D1')).cellStyle = headerStyle;

      // Veri satirlari
      for (var i = 0; i < stats.topProducts.length; i++) {
        final product = stats.topProducts[i];
        final rowIndex = i + 2;
        productSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(product.name),
          IntCellValue(product.quantity),
          DoubleCellValue(double.parse(product.revenue.toStringAsFixed(2))),
        ]);
        // Alternatif satir rengi
        if (i % 2 == 1) {
          final altStyle = CellStyle(backgroundColorHex: ExcelColor.fromHexString('#f9f9f9'));
          productSheet.cell(CellIndex.indexByString('A$rowIndex')).cellStyle = altStyle;
          productSheet.cell(CellIndex.indexByString('B$rowIndex')).cellStyle = altStyle;
          productSheet.cell(CellIndex.indexByString('C$rowIndex')).cellStyle = altStyle;
          productSheet.cell(CellIndex.indexByString('D$rowIndex')).cellStyle = altStyle;
        }
      }

      // Varsayilan sheet'i sil
      excel.delete('Sheet1');

      // Dosyayi kaydet ve paylas
      final bytes = excel.encode();
      if (bytes == null) return false;

      final fileName = 'rapor_${_dateFormat.format(dateRange.start)}_${_dateFormat.format(dateRange.end)}.xlsx';

      if (kIsWeb) {
        // Web icin printing ile paylas
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
        );
      } else {
        // Mobil/Desktop icin dosya sistemine kaydet
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(bytes);

        // Dosya yolunu goster
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel dosyasi kaydedildi: ${file.path}'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('Excel export error: $e');
      return false;
    }
  }

  /// Export report as CSV
  Future<bool> exportCsv({
    required BuildContext context,
    required ReportsStats stats,
    required DateTimeRange dateRange,
    required String merchantName,
  }) async {
    try {
      final buffer = StringBuffer();

      // Header
      buffer.writeln('# $merchantName');
      buffer.writeln('# Rapor Tarihi: ${_dateFormat.format(dateRange.start)} - ${_dateFormat.format(dateRange.end)}');
      buffer.writeln('');

      // Ozet
      buffer.writeln('# OZET');
      buffer.writeln('Metrik,Deger');
      buffer.writeln('Toplam Siparis,${stats.totalOrders}');
      buffer.writeln('Toplam Gelir,${stats.totalRevenue}');
      buffer.writeln('Ortalama Siparis,${stats.averageOrderValue.toStringAsFixed(2)}');
      buffer.writeln('Iptal Orani,${stats.cancellationRate.toStringAsFixed(1)}');
      buffer.writeln('Toplam Musteri,${stats.totalCustomers}');
      buffer.writeln('Tekrar Eden Musteri,${stats.repeatCustomerRate.toStringAsFixed(0)}');
      buffer.writeln('Ortalama Puan,${stats.averageRating.toStringAsFixed(1)}');
      buffer.writeln('En Cok Satan,${stats.bestSellingProduct}');
      buffer.writeln('');

      // Gunluk Satislar
      buffer.writeln('# GUNLUK SATISLAR');
      buffer.writeln('Tarih,Siparis Sayisi,Gelir (TL),Ortalama Sepet (TL)');
      for (final daily in stats.dailyStats) {
        final date = DateTime.parse(daily.date);
        buffer.writeln('${_dateFormat.format(date)},${daily.orders},${daily.revenue},${daily.averageOrderValue.toStringAsFixed(2)}');
      }
      buffer.writeln('');

      // Urun Satislari
      buffer.writeln('# URUN SATISLARI');
      buffer.writeln('Sira,Urun Adi,Satis Adedi,Gelir (TL)');
      for (var i = 0; i < stats.topProducts.length; i++) {
        final product = stats.topProducts[i];
        // CSV icin urun adindaki virgulleri escape et
        final escapedName = product.name.contains(',') ? '"${product.name}"' : product.name;
        buffer.writeln('${i + 1},$escapedName,${product.quantity},${product.revenue.toStringAsFixed(2)}');
      }

      final csvContent = buffer.toString();
      final fileName = 'rapor_${_dateFormat.format(dateRange.start)}_${_dateFormat.format(dateRange.end)}.csv';
      final bytes = Uint8List.fromList(csvContent.codeUnits);

      if (kIsWeb) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: fileName,
        );
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvContent);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV dosyasi kaydedildi: ${file.path}'),
              backgroundColor: const Color(0xFF22C55E),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      return true;
    } catch (e) {
      debugPrint('CSV export error: $e');
      return false;
    }
  }
}

/// Global instance
final reportExportService = ReportExportService();
