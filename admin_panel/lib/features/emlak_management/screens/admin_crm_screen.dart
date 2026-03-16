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

class _AdminCrmScreenState extends ConsumerState<AdminCrmScreen> {
  final _dateFormat = DateFormat('dd MMM yyyy', 'tr');
  final _currencyFormat = NumberFormat.currency(locale: 'tr_TR', symbol: '\u20BA', decimalDigits: 0);

  String _searchQuery = '';
  String _statusFilter = 'all';
  Timer? _debounce;

  List<Map<String, dynamic>> _clients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchClients();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

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
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredClients {
    return _clients.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final phone = (c['phone'] ?? '').toString().toLowerCase();
      final email = (c['email'] ?? '').toString().toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(_searchQuery.toLowerCase()) ||
          phone.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());

      final status = c['status'] as String? ?? '';
      final matchesStatus = _statusFilter == 'all' || status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredClients;

    final potentialCount = _clients.where((c) => c['status'] == 'potential').length;
    final activeCount = _clients.where((c) => c['status'] == 'active').length;
    final closedCount = _clients.where((c) => c['status'] == 'closed').length;
    final lostCount = _clients.where((c) => c['status'] == 'lost').length;

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
                      'Musteri Yonetimi (CRM)',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Emlakci musterilerini yonetin',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
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
                      label: const Text('Musteri Ekle'),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats Cards
            Row(
              children: [
                _buildStatCard('Toplam', _clients.length.toString(), Icons.people, AppColors.primary),
                const SizedBox(width: 16),
                _buildStatCard('Potansiyel', potentialCount.toString(), Icons.person_search, AppColors.info),
                const SizedBox(width: 16),
                _buildStatCard('Aktif', activeCount.toString(), Icons.person, AppColors.success),
                const SizedBox(width: 16),
                _buildStatCard('Kapandi', closedCount.toString(), Icons.check_circle, AppColors.warning),
                const SizedBox(width: 16),
                _buildStatCard('Kayip', lostCount.toString(), Icons.person_off, AppColors.error),
              ],
            ),

            const SizedBox(height: 24),

            // Filters
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (value) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          if (mounted) setState(() => _searchQuery = value);
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Musteri ara (ad, telefon, e-posta)...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tumu')),
                          DropdownMenuItem(value: 'potential', child: Text('Potansiyel')),
                          DropdownMenuItem(value: 'active', child: Text('Aktif')),
                          DropdownMenuItem(value: 'closed', child: Text('Kapandi')),
                          DropdownMenuItem(value: 'lost', child: Text('Kayip')),
                        ],
                        onChanged: (value) => setState(() => _statusFilter = value!),
                      ),
                    ),
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
                              const Icon(Icons.people, size: 64, color: AppColors.textMuted),
                              const SizedBox(height: 16),
                              const Text(
                                'Musteri bulunamadi',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                              ),
                              if (_searchQuery.isNotEmpty || _statusFilter != 'all')
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _searchQuery = '';
                                      _statusFilter = 'all';
                                    });
                                  },
                                  child: const Text('Filtreleri Temizle'),
                                ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 480,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.15,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) => _buildClientCard(filtered[index]),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: name + status + actions
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _getStatusColor(status).withValues(alpha: 0.15),
                child: Icon(Icons.person, color: _getStatusColor(status), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client['name'] ?? 'Isimsiz',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Duzenle')),
                  const PopupMenuItem(value: 'delete', child: Text('Sil')),
                ],
                icon: const Icon(Icons.more_vert, color: AppColors.textMuted, size: 20),
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
          if (client['looking_for'] != null)
            _buildInfoRow(Icons.search, client['looking_for']),
          // Budget
          if (budgetMin != null || budgetMax != null)
            _buildInfoRow(
              Icons.account_balance_wallet,
              '${budgetMin != null ? _currencyFormat.format(budgetMin) : '?'} - ${budgetMax != null ? _currencyFormat.format(budgetMax) : '?'}',
            ),
          // Preferred cities
          if (preferredCities.isNotEmpty)
            _buildInfoRow(Icons.location_city, preferredCities.join(', ')),
          // Notes
          if (client['notes'] != null && (client['notes'] as String).isNotEmpty)
            _buildInfoRow(Icons.note, client['notes']),
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
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
              const Spacer(),
              if (client['next_followup_at'] != null) ...[
                const Icon(Icons.event, size: 12, color: AppColors.info),
                const SizedBox(width: 4),
                Text(
                  'Takip: ${_dateFormat.format(DateTime.parse(client['next_followup_at']))}',
                  style: const TextStyle(color: AppColors.info, fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            Column(
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
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
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
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
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
        return 'Kapandi';
      case 'lost':
        return 'Kayip';
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
    final nameController = TextEditingController(text: client?['name'] ?? '');
    final phoneController = TextEditingController(text: client?['phone'] ?? '');
    final emailController = TextEditingController(text: client?['email'] ?? '');
    final lookingForController = TextEditingController(text: client?['looking_for'] ?? '');
    final budgetMinController = TextEditingController(text: client?['budget_min']?.toString() ?? '');
    final budgetMaxController = TextEditingController(text: client?['budget_max']?.toString() ?? '');
    final citiesController = TextEditingController(
      text: (client?['preferred_cities'] as List?)?.join(', ') ?? '',
    );
    final notesController = TextEditingController(text: client?['notes'] ?? '');
    String selectedStatus = client?['status'] ?? 'potential';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            isEdit ? 'Musteriyi Duzenle' : 'Yeni Musteri Ekle',
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
                    decoration: const InputDecoration(labelText: 'Ad Soyad', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Durum', border: OutlineInputBorder()),
                    dropdownColor: AppColors.surface,
                    items: const [
                      DropdownMenuItem(value: 'potential', child: Text('Potansiyel')),
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'closed', child: Text('Kapandi')),
                      DropdownMenuItem(value: 'lost', child: Text('Kayip')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lookingForController,
                    decoration: const InputDecoration(labelText: 'Aranan Mulk Tipi', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: budgetMinController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Butce', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: budgetMaxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Butce', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: citiesController,
                    decoration: const InputDecoration(
                      labelText: 'Tercih Edilen Sehirler',
                      hintText: 'Istanbul, Ankara, Izmir',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notlar', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Iptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                final cities = citiesController.text.trim().isEmpty
                    ? <String>[]
                    : citiesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                final data = <String, dynamic>{
                  'name': nameController.text.trim(),
                  'phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                  'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  'status': selectedStatus,
                  'looking_for': lookingForController.text.trim().isEmpty ? null : lookingForController.text.trim(),
                  'budget_min': double.tryParse(budgetMinController.text.trim()),
                  'budget_max': double.tryParse(budgetMaxController.text.trim()),
                  'preferred_cities': cities,
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
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
        const SnackBar(content: Text('Musteri eklendi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _updateClient(String clientId, Map<String, dynamic> data) async {
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('realtor_clients').update(data).eq('id', clientId);
      _fetchClients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musteri guncellendi'), backgroundColor: AppColors.success),
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
        title: const Text('Musteriyi Sil'),
        content: const Text('Bu musteriyi silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgec')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('realtor_clients').delete().eq('id', clientId);
      _fetchClients();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musteri silindi'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.error),
      );
    }
  }
}
