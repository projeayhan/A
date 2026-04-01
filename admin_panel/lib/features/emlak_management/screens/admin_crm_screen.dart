import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/supabase_service.dart';

class AdminCrmScreen extends ConsumerStatefulWidget {
  final String realtorId;
  const AdminCrmScreen({super.key, required this.realtorId});

  @override
  ConsumerState<AdminCrmScreen> createState() => _AdminCrmScreenState();
}

class _AdminCrmScreenState extends ConsumerState<AdminCrmScreen>
    with SingleTickerProviderStateMixin {
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  final _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '\u20BA',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  Timer? _debounce;
  late TabController _tabController;

  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  static const _statusTabs = [
    ('all', 'Tümü', Icons.people_alt),
    ('potential', 'Potansiyel', Icons.person_search),
    ('active', 'Aktif', Icons.person),
    ('closed', 'Kapandı', Icons.check_circle_outline),
    ('lost', 'Kayıp', Icons.person_off),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _fetchClients();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  String get _currentStatus => _statusTabs[_tabController.index].$1;

  Future<void> _fetchClients() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('realtor_clients')
          .select()
          .eq('realtor_id', widget.realtorId)
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _clients = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchClients error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Müşteriler yüklenemedi: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    return _clients.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(query) ||
          phone.contains(query) ||
          email.contains(query);

      final status = c['status'] as String? ?? '';
      final matchesStatus = _currentStatus == 'all' || status == _currentStatus;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  int _countByStatus(String status) {
    return _clients.where((c) => c['status'] == status).length;
  }

  int get _followUpsDueToday {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return _clients.where((c) {
      final followUp = c['next_followup_at'] as String?;
      if (followUp == null) return false;
      return followUp.compareTo(todayStr) <= 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredClients;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Müşteri Yönetimi (CRM)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci musterilerini yonetin ve takip edin',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fetchClients,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Yenile'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddClientDialog(),
                      icon: const Icon(Icons.person_add, size: 18),
                      label: const Text('Müşteri Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            Row(
              children: [
                _buildStatCard(
                  'Toplam Müşteri',
                  _clients.length.toString(),
                  Icons.people,
                  AppColors.primary,
                  null,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Aktif',
                  _countByStatus('active').toString(),
                  Icons.person,
                  AppColors.success,
                  null,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Potansiyel',
                  _countByStatus('potential').toString(),
                  Icons.person_search,
                  AppColors.info,
                  null,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Bugün Takip',
                  _followUpsDueToday.toString(),
                  Icons.notification_important,
                  _followUpsDueToday > 0 ? AppColors.warning : AppColors.textMuted,
                  _followUpsDueToday > 0 ? 'Takip gereken musteri!' : null,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Search + Pipeline Tabs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) {
                      _debounce?.cancel();
                      _debounce = Timer(const Duration(milliseconds: 300), () {
                        if (mounted) {
                          setState(() => _searchQuery = value);
                        }
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Müşteri ara (ad, telefon, e-posta)...',
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Pipeline tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: AppColors.primary,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textMuted,
                    dividerColor: Colors.transparent,
                    tabs: _statusTabs.map((tab) {
                      final count = tab.$1 == 'all'
                          ? _clients.length
                          : _countByStatus(tab.$1);
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tab.$3, size: 16),
                            const SizedBox(width: 6),
                            Text(tab.$2),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Client Cards Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.people,
                                size: 64,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Müşteri bulunamadı',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchQuery.isNotEmpty ||
                                  _currentStatus != 'all')
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _tabController.animateTo(0);
                                    });
                                  },
                                  child: const Text('Filtreleri Temizle'),
                                ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 480,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildClientCard(filtered[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientCard(Map<String, dynamic> client) {
    final status = client['status'] as String? ?? 'potential';
    final preferredCities = client['preferred_cities'] as List? ?? [];
    final budgetMin = (client['budget_min'] as num?)?.toDouble();
    final budgetMax = (client['budget_max'] as num?)?.toDouble();
    final interests = client['interests'] as List? ?? [];
    final lookingFor = client['looking_for'] as String?;
    final nextFollowUp = client['next_followup_at'] as String?;
    final isFollowUpDue = _isFollowUpDue(nextFollowUp);
    final name = client['name'] as String? ?? 'İsimsiz';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFollowUpDue
              ? AppColors.warning.withValues(alpha: 0.4)
              : AppColors.surfaceLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar, name, status, actions
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor:
                    _getStatusColor(status).withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _getStatusColor(status),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(status),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showEditClientDialog(client);
                  } else if (value == 'delete') {
                    _deleteClient(client['id']);
                  } else if (value == 'detail') {
                    _showClientDetailDialog(client);
                  } else if (value == 'note') {
                    _showAddNoteDialog(client);
                  } else if (value == 'followup') {
                    _showSetFollowUpDialog(client);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'detail',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Detay'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'note',
                    child: Row(
                      children: [
                        Icon(Icons.note_add, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Not Ekle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'followup',
                    child: Row(
                      children: [
                        Icon(Icons.event, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Takip Tarihi'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Text('Düzenle'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 16, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Sil', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.surfaceLight),
          const SizedBox(height: 12),
          // Contact info
          if (client['phone'] != null)
            _buildInfoRow(Icons.phone, client['phone']),
          if (client['email'] != null)
            _buildInfoRow(Icons.email, client['email']),
          if (lookingFor != null && lookingFor.isNotEmpty)
            _buildInfoRow(Icons.search, lookingFor),
          // Budget
          if (budgetMin != null || budgetMax != null)
            _buildInfoRow(
              Icons.account_balance_wallet,
              '${budgetMin != null ? _currencyFormat.format(budgetMin) : '?'} - ${budgetMax != null ? _currencyFormat.format(budgetMax) : '?'}',
            ),
          // Preferred cities
          if (preferredCities.isNotEmpty)
            _buildInfoRow(Icons.location_city, preferredCities.join(', ')),
          // Interest tags
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: (interests).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag.toString(),
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          // Notes
          if (client['notes'] != null &&
              (client['notes'] as String).isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildInfoRow(Icons.note, client['notes']),
          ],
          const Spacer(),
          const Divider(height: 1, color: AppColors.surfaceLight),
          const SizedBox(height: 8),
          // Footer: dates
          Row(
            children: [
              if (client['last_contact_at'] != null) ...[
                const Icon(Icons.history, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  'Son: ${_dateFormat.format(DateTime.parse(client['last_contact_at']))}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
              const Spacer(),
              if (nextFollowUp != null) ...[
                Icon(
                  Icons.event,
                  size: 12,
                  color: isFollowUpDue ? AppColors.warning : AppColors.info,
                ),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isFollowUpDue
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Takip: ${_dateFormat.format(DateTime.parse(nextFollowUp))}',
                    style: TextStyle(
                      color: isFollowUpDue ? AppColors.warning : AppColors.info,
                      fontSize: 11,
                      fontWeight:
                          isFollowUpDue ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  bool _isFollowUpDue(String? dateStr) {
    if (dateStr == null) return false;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final followUpDay = DateTime(date.year, date.month, date.day);
    return !followUpDay.isAfter(today);
  }

  void _showClientDetailDialog(Map<String, dynamic> client) {
    final notes = client['notes'] as String? ?? '';
    final interests = client['interests'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 550, maxHeight: 550),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: _getStatusColor(
                        client['status'] ?? 'potential',
                      ).withValues(alpha: 0.15),
                      child: Text(
                        ((client['name'] ?? '?') as String).isNotEmpty
                            ? (client['name'] as String)[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: _getStatusColor(
                            client['status'] ?? 'potential',
                          ),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client['name'] ?? 'İsimsiz',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildStatusBadge(
                            client['status'] ?? 'potential',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Contact
                      const Text(
                        'İletişim Bilgileri',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (client['phone'] != null)
                        _buildDetailRow(Icons.phone, 'Telefon', client['phone']),
                      if (client['email'] != null)
                        _buildDetailRow(Icons.email, 'E-posta', client['email']),
                      const SizedBox(height: 16),
                      // Interest tags
                      if (interests.isNotEmpty) ...[
                        const Text(
                          'Ilgi Alanlari',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: interests.map((tag) {
                            return Chip(
                              label: Text(
                                tag.toString(),
                                style: const TextStyle(
                                  color: AppColors.info,
                                  fontSize: 12,
                                ),
                              ),
                              backgroundColor:
                                  AppColors.info.withValues(alpha: 0.1),
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Looking for
                      if (client['looking_for'] != null) ...[
                        _buildDetailRow(
                          Icons.search,
                          'Aranan Mülk',
                          client['looking_for'],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Budget
                      if (client['budget_min'] != null ||
                          client['budget_max'] != null) ...[
                        _buildDetailRow(
                          Icons.account_balance_wallet,
                          'Bütçe',
                          '${client['budget_min'] != null ? _currencyFormat.format((client['budget_min'] as num).toDouble()) : '?'} - ${client['budget_max'] != null ? _currencyFormat.format((client['budget_max'] as num).toDouble()) : '?'}',
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Preferred cities
                      if ((client['preferred_cities'] as List?)?.isNotEmpty ??
                          false) ...[
                        _buildDetailRow(
                          Icons.location_city,
                          'Tercih Edilen Şehirler',
                          (client['preferred_cities'] as List).join(', '),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Notes
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Notlar',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notes,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      // Follow-up
                      if (client['next_followup_at'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.event,
                                size: 18,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Sonraki Takip: ${_dateFormat.format(DateTime.parse(client['next_followup_at']))}',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showAddNoteDialog(client);
                      },
                      icon: const Icon(Icons.note_add, size: 16),
                      label: const Text('Not Ekle'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showSetFollowUpDialog(client);
                      },
                      icon: const Icon(Icons.event, size: 16),
                      label: const Text('Takip Tarihi'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _showEditClientDialog(client);
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Düzenle'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(Map<String, dynamic> client) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Not Ekle',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: noteController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Notunuzu yazin...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final existingNotes = client['notes'] as String? ?? '';
              final newNote = noteController.text.trim();
              if (newNote.isEmpty) return;
              final timestamp = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
              final updatedNotes = existingNotes.isNotEmpty
                  ? '$existingNotes\n[$timestamp] $newNote'
                  : '[$timestamp] $newNote';
              await _updateClient(client['id'], {
                'notes': updatedNotes,
                'last_contact_at': DateTime.now().toIso8601String(),
              });
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showSetFollowUpDialog(Map<String, dynamic> client) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      await _updateClient(client['id'], {
        'next_followup_at': picked.toIso8601String(),
      });
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String? subtitle,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = _getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'potential':
        return AppColors.info;
      case 'active':
        return AppColors.success;
      case 'closed':
        return AppColors.warning;
      case 'lost':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'potential':
        return 'Potansiyel';
      case 'active':
        return 'Aktif';
      case 'closed':
        return 'Kapandı';
      case 'lost':
        return 'Kayıp';
      default:
        return status;
    }
  }

  void _showAddClientDialog() {
    _showClientFormDialog(null);
  }

  void _showEditClientDialog(Map<String, dynamic> client) {
    _showClientFormDialog(client);
  }

  void _showClientFormDialog(Map<String, dynamic>? client) {
    final isEdit = client != null;
    final nameController =
        TextEditingController(text: client?['name'] ?? '');
    final phoneController =
        TextEditingController(text: client?['phone'] ?? '');
    final emailController =
        TextEditingController(text: client?['email'] ?? '');
    final lookingForController =
        TextEditingController(text: client?['looking_for'] ?? '');
    final budgetMinController =
        TextEditingController(text: client?['budget_min']?.toString() ?? '');
    final budgetMaxController =
        TextEditingController(text: client?['budget_max']?.toString() ?? '');
    final citiesController = TextEditingController(
      text: (client?['preferred_cities'] as List?)?.join(', ') ?? '',
    );
    final interestsController = TextEditingController(
      text: (client?['interests'] as List?)?.join(', ') ?? '',
    );
    final notesController =
        TextEditingController(text: client?['notes'] ?? '');
    String selectedStatus = client?['status'] ?? 'potential';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Müşteriyi Düzenle' : 'Yeni Müşteri Ekle',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Ad Soyad',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Durum',
                      border: OutlineInputBorder(),
                    ),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(
                        value: 'potential',
                        child: Text('Potansiyel'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Aktif'),
                      ),
                      DropdownMenuItem(
                        value: 'closed',
                        child: Text('Kapandı'),
                      ),
                      DropdownMenuItem(
                        value: 'lost',
                        child: Text('Kayıp'),
                      ),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => selectedStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lookingForController,
                    decoration: const InputDecoration(
                      labelText: 'Aranan Mülk Tipi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: budgetMinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Min Bütçe',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: budgetMaxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Max Bütçe',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: citiesController,
                    decoration: const InputDecoration(
                      labelText: 'Tercih Edilen Şehirler',
                      hintText: 'İstanbul, Ankara, İzmir',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: interestsController,
                    decoration: const InputDecoration(
                      labelText: 'Ilgi Alanlari (etiketler)',
                      hintText: 'Daire, Villa, Deniz Manzarali',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notlar',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final cities = citiesController.text.trim().isEmpty
                    ? <String>[]
                    : citiesController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();
                final interestTags = interestsController.text.trim().isEmpty
                    ? <String>[]
                    : interestsController.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList();

                final data = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  'email': emailController.text.trim().isEmpty
                      ? null
                      : emailController.text.trim(),
                  'status': selectedStatus,
                  'looking_for': lookingForController.text.trim().isEmpty
                      ? null
                      : lookingForController.text.trim(),
                  'budget_min':
                      double.tryParse(budgetMinController.text.trim()),
                  'budget_max':
                      double.tryParse(budgetMaxController.text.trim()),
                  'preferred_cities': cities,
                  'interests': interestTags,
                  'notes': notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                };

                if (isEdit) {
                  await _updateClient(client['id'], data);
                } else {
                  data['realtor_id'] = widget.realtorId;
                  await _createClient(data);
                }
              },
              child: Text(isEdit ? 'Kaydet' : 'Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createClient(Map<String, dynamic> data) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('realtor_clients').insert(data);
      _fetchClients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri eklendi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updateClient(
    String clientId,
    Map<String, dynamic> data,
  ) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('realtor_clients')
          .update(data)
          .eq('id', clientId);
      _fetchClients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri güncellendi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _deleteClient(String clientId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi Sil'),
        content: const Text(
          'Bu müşteriyi silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase
          .from('realtor_clients')
          .delete()
          .eq('id', clientId);
      _fetchClients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Müşteri silindi'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
