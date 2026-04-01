import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../core/models/sector_type.dart';

class GlobalSearchOverlay extends ConsumerStatefulWidget {
  final FocusNode focusNode;

  const GlobalSearchOverlay({super.key, required this.focusNode});

  @override
  ConsumerState<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends ConsumerState<GlobalSearchOverlay> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<_SearchResult> _results = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) {
      // Delay hiding so tap on result works
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !widget.focusNode.hasFocus) {
          setState(() => _showResults = false);
        }
      });
    } else {
      if (_controller.text.length >= 2) {
        setState(() => _showResults = true);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _results = [];
        _showResults = false;
      });
      return;
    }
    setState(() => _showResults = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _performSearch(query));
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() => _isSearching = true);

    final results = <_SearchResult>[];
    final supabase = ref.read(supabaseProvider);
    final q = query.toLowerCase();

    try {
      // 1. İşletme araması (merchants)
      final merchants = await supabase
          .from('merchants')
          .select('id, business_name, type')
          .ilike('business_name', '%$q%')
          .limit(5);
      for (final m in merchants) {
        final type = m['type'] as String?;
        SectorType sector;
        String sectorLabel;
        switch (type) {
          case 'restaurant':
            sector = SectorType.food;
            sectorLabel = 'Yemek';
            break;
          case 'market':
            sector = SectorType.market;
            sectorLabel = 'Market';
            break;
          default:
            sector = SectorType.store;
            sectorLabel = 'Mağaza';
        }
        results.add(_SearchResult(
          title: m['business_name'] ?? 'İşletme',
          subtitle: sectorLabel,
          icon: sector.icon,
          color: Colors.deepOrange,
          sectorTag: sectorLabel,
          route: '${sector.baseRoute}/${m['id']}',
        ));
      }

      // 2. Kullanıcı araması
      final users = await supabase
          .from('users')
          .select('id, full_name, email')
          .or('full_name.ilike.%$q%,email.ilike.%$q%')
          .limit(5);
      for (final u in users) {
        results.add(_SearchResult(
          title: u['full_name'] ?? u['email'] ?? 'Kullanıcı',
          subtitle: u['email'] ?? '',
          icon: Icons.person_rounded,
          color: AppColors.info,
          sectorTag: 'Kullanıcı',
          route: '/users',
        ));
      }

      // 3. Fatura no araması
      final invoices = await supabase
          .from('invoices')
          .select('id, invoice_number, buyer_name, total_amount')
          .ilike('invoice_number', '%$q%')
          .limit(5);
      for (final inv in invoices) {
        results.add(_SearchResult(
          title: inv['invoice_number'] ?? 'Fatura',
          subtitle: inv['buyer_name'] ?? '',
          icon: Icons.receipt_long_rounded,
          color: Colors.purple,
          sectorTag: 'Fatura',
          route: '/finans/faturalar',
        ));
      }

      // 4. Emlakçı araması
      try {
        final realtors = await supabase
            .from('realtors')
            .select('id, company_name')
            .ilike('company_name', '%$q%')
            .limit(3);
        for (final r in realtors) {
          results.add(_SearchResult(
            title: r['company_name'] ?? 'Emlakçı',
            subtitle: 'Emlak',
            icon: SectorType.realEstate.icon,
            color: Colors.indigo,
            sectorTag: 'Emlak',
            route: '${SectorType.realEstate.baseRoute}/${r['id']}',
          ));
        }
      } catch (_) {}

      // 5. Taksi şoförü araması
      try {
        final drivers = await supabase
            .from('taxi_drivers')
            .select('id, full_name')
            .ilike('full_name', '%$q%')
            .limit(3);
        for (final d in drivers) {
          results.add(_SearchResult(
            title: d['full_name'] ?? 'Şoför',
            subtitle: 'Taksi',
            icon: SectorType.taxi.icon,
            color: Colors.amber.shade700,
            sectorTag: 'Taksi',
            route: '${SectorType.taxi.baseRoute}/${d['id']}',
          ));
        }
      } catch (_) {}
    } catch (_) {}

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final searchBg = isDark ? AppColors.background : const Color(0xFFF1F5F9);
    final textMuted = isDark ? AppColors.textMuted : const Color(0xFF94A3B8);
    final dropBg = isDark ? AppColors.surface : Colors.white;
    final borderColor = isDark ? AppColors.surfaceLight : const Color(0xFFE2E8F0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: TextField(
            controller: _controller,
            focusNode: widget.focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'İşletme, kullanıcı, fatura ara... (Ctrl+K)',
              prefixIcon: Icon(Icons.search, color: textMuted),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, size: 18, color: textMuted),
                      onPressed: () {
                        _controller.clear();
                        setState(() {
                          _results = [];
                          _showResults = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: searchBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (_showResults)
          Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 400),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: dropBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : _results.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            _controller.text.length >= 2 ? 'Sonuç bulunamadı' : 'En az 2 karakter girin',
                            style: TextStyle(color: textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                widget.focusNode.unfocus();
                                _controller.clear();
                                setState(() {
                                  _results = [];
                                  _showResults = false;
                                });
                                context.go(result.route);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: result.color.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(result.icon, size: 16, color: result.color),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            result.title,
                                            style: TextStyle(
                                              color: isDark ? AppColors.textPrimary : const Color(0xFF0F172A),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (result.subtitle.isNotEmpty)
                                            Text(
                                              result.subtitle,
                                              style: TextStyle(color: textMuted, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: result.color.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        result.sectorTag,
                                        style: TextStyle(
                                          color: result.color,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
      ],
    );
  }
}

class _SearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String sectorTag;
  final String route;

  const _SearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.sectorTag,
    required this.route,
  });
}
