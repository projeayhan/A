import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../services/batch_invoice_service.dart';

class BatchInvoiceScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const BatchInvoiceScreen({super.key, this.embedded = false});

  @override
  ConsumerState<BatchInvoiceScreen> createState() => _BatchInvoiceScreenState();
}

class _BatchInvoiceScreenState extends ConsumerState<BatchInvoiceScreen> {
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
  int _currentStep = 0;
  String _selectedSector = 'food';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<BatchInvoicePreview> _previews = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  BatchInvoiceResult? _result;

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Toplu Fatura', style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Seçili dönem için toplu komisyon faturası oluşturun', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 32),

          // Stepper
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.surfaceLight)),
            child: Column(
              children: [
                // Step Indicators
                _buildStepIndicators(),
                const SizedBox(height: 32),

                // Step Content
                if (_currentStep == 0) _buildStep1(),
                if (_currentStep == 1) _buildStep2(),
                if (_currentStep == 2) _buildStep3(),
                if (_currentStep == 3) _buildStep4(),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return Container(
        color: AppColors.background,
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: body,
    );
  }

  Widget _buildStepIndicators() {
    final steps = ['Sektör Seç', 'Tarih Seç', 'Önizleme', 'Sonuç'];
    return Row(
      children: steps.asMap().entries.map((e) {
        final isActive = e.key <= _currentStep;
        final isCurrent = e.key == _currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('${e.key + 1}', style: TextStyle(color: isActive ? Colors.white : AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: 14))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.value, style: TextStyle(color: isCurrent ? AppColors.textPrimary : AppColors.textMuted, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal, fontSize: 13)),
              ),
              if (e.key < steps.length - 1)
                Expanded(child: Container(height: 2, color: isActive ? AppColors.primary.withValues(alpha: 0.5) : AppColors.surfaceLight)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStep1() {
    final sectors = [
      ('food', 'Yemek', Icons.restaurant),
      ('store', 'Market/Mağaza', Icons.store),
      ('taxi', 'Taksi', Icons.local_taxi),
      ('rental', 'Kiralama', Icons.car_rental),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sektör Seçin', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: sectors.map((s) => InkWell(
            onTap: () => setState(() => _selectedSector = s.$1),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 160, padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _selectedSector == s.$1 ? AppColors.primary.withValues(alpha: 0.15) : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedSector == s.$1 ? AppColors.primary : AppColors.surfaceLight),
              ),
              child: Column(children: [
                Icon(s.$3, color: _selectedSector == s.$1 ? AppColors.primary : AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(s.$2, style: TextStyle(color: _selectedSector == s.$1 ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ]),
            ),
          )).toList(),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: const Text('İleri'),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    final dateFormat = DateFormat('dd MMM yyyy', 'tr');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tarih Aralığı', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (picked != null) setState(() => _startDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Başlangıç', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(dateFormat.format(_startDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2024), lastDate: DateTime.now());
                if (picked != null) setState(() => _endDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.surfaceLight)),
                child: Row(children: [
                  const Icon(Icons.calendar_today, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bitiş', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    Text(dateFormat.format(_endDate), style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
                  ]),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('Geri')),
          ElevatedButton(
            onPressed: _isLoading ? null : _fetchPreview,
            child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Önizle'),
          ),
        ]),
      ],
    );
  }

  Widget _buildStep3() {
    final totalCommission = _previews.fold(0.0, (s, p) => s + p.subtotal + p.onlineCommission);
    final totalOnlineComm = _previews.fold(0.0, (s, p) => s + p.onlineCommission);
    final totalCashComm = _previews.fold(0.0, (s, p) => s + p.subtotal);
    final totalNet = _previews.fold(0.0, (s, p) => s + p.netTransfer);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Fatura Önizleme', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          Text('Toplam Komisyon: ${_currencyFormat.format(totalCommission)} (${_previews.length} işletme)', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _summaryChip('Online Komisyon (kesildi)', totalOnlineComm, AppColors.success),
          const SizedBox(width: 12),
          _summaryChip('Nakit Komisyon (tahsil edilecek)', totalCashComm, AppColors.warning),
          const SizedBox(width: 12),
          _summaryChip(
            totalNet >= 0 ? 'İşletmelere Ödenecek' : 'İşletmelerden Tahsil',
            totalNet.abs(),
            totalNet >= 0 ? AppColors.info : AppColors.error,
          ),
        ]),
        const SizedBox(height: 16),
        if (_previews.isEmpty)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('Bu dönem için fatura kesilecek işletme bulunamadı', style: TextStyle(color: AppColors.textMuted))))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('İŞLETME', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600))),
                DataColumn(label: Text('SİPARİŞ', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('ONLİNE', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('KAPIDA', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('KOMİSYON', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('KDV', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('FATURA', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
                DataColumn(label: Text('NET TRANSFER', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)), numeric: true),
              ],
              rows: _previews.map((p) {
                final net = p.netTransfer;
                return DataRow(cells: [
                  DataCell(Text(p.merchantName, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12))),
                  DataCell(Text('${p.orderCount}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  DataCell(Text(_currencyFormat.format(p.onlineTotal), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  DataCell(Text(_currencyFormat.format(p.cashTotal), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  DataCell(Text(_currencyFormat.format(p.subtotal), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                  DataCell(Text(_currencyFormat.format(p.kdvAmount), style: const TextStyle(color: AppColors.textMuted, fontSize: 12))),
                  DataCell(Text(_currencyFormat.format(p.total), style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(
                    '${net >= 0 ? '+' : '-'}${_currencyFormat.format(net.abs())}',
                    style: TextStyle(
                      color: net >= 0 ? AppColors.success : AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.info),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Net Transfer (+): Platform → İşletmeye havale edilecek tutar (online tahsilat - komisyon faturası). '
              'Net Transfer (-): İşletme → Platforma ödeyecek tutar.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            )),
          ]),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Geri')),
          ElevatedButton(
            onPressed: _previews.isEmpty || _isProcessing ? null : _createInvoices,
            child: _isProcessing
                ? const Row(mainAxisSize: MainAxisSize.min, children: [SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)), SizedBox(width: 8), Text('Oluşturuluyor...')])
                : Text('${_previews.length} Fatura Oluştur'),
          ),
        ]),
      ],
    );
  }

  Widget _summaryChip(String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_currencyFormat.format(value), style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4() {
    if (_result == null) return const SizedBox.shrink();
    final isSuccess = _result!.totalFailed == 0;
    return Column(
      children: [
        Icon(isSuccess ? Icons.check_circle : Icons.warning, size: 64, color: isSuccess ? AppColors.success : AppColors.warning),
        const SizedBox(height: 16),
        Text(
          isSuccess ? 'Tüm faturalar oluşturuldu!' : 'İşlem tamamlandı (bazı hatalar var)',
          style: TextStyle(color: isSuccess ? AppColors.success : AppColors.warning, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text('${_result!.totalCreated} başarılı, ${_result!.totalFailed} başarısız', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        if (_result!.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _result!.errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(e, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              )).toList(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => setState(() {
            _currentStep = 0;
            _previews = [];
            _result = null;
          }),
          child: const Text('Yeni Toplu Fatura'),
        ),
      ],
    );
  }

  Future<void> _fetchPreview() async {
    setState(() => _isLoading = true);
    try {
      _previews = await BatchInvoiceService.getPreview(
        sector: _selectedSector,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _currentStep = 2;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _createInvoices() async {
    setState(() => _isProcessing = true);
    try {
      // KDV oranını preview'deki verilerden hesapla (RPC'den geliyor)
      final kdvRate = (_previews.isNotEmpty && _previews.first.subtotal > 0)
          ? _previews.first.kdvAmount / _previews.first.subtotal
          : 0.20;
      _result = await BatchInvoiceService.createBatchInvoices(
        previews: _previews,
        kdvRate: kdvRate,
        startDate: _startDate,
        endDate: _endDate,
      );
      setState(() {
        _currentStep = 3;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error));
      }
    }
  }
}
