import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_model.dart';
import '../../../models/client_engagement_model.dart';
import '../../../providers/client_provider.dart';
import '../../../services/client_service.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/stat_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../widgets/client_card.dart';
import '../widgets/engagement_table.dart';
import '../widgets/property_interest_table.dart';
import '../widgets/activity_feed.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _clientService = ClientService();
  final _searchController = TextEditingController();

  List<RealtorClient> _clients = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedStatus;
  bool _addDialogShown = false;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final action = GoRouterState.of(context).uri.queryParameters['action'];
    if (action == 'add' && !_addDialogShown) {
      _addDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showAddClientDialog(context);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clients = await _clientService.getClients();
      if (mounted) {
        setState(() {
          _clients = clients;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<RealtorClient> get _filteredClients {
    var result = _clients;
    if (_selectedStatus != null) {
      result =
          result.where((c) => c.status.name == _selectedStatus).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((c) {
        return c.name.toLowerCase().contains(query) ||
            (c.phone?.toLowerCase().contains(query) ?? false) ||
            (c.email?.toLowerCase().contains(query) ?? false);
      }).toList();
    }
    return result;
  }

  Color _getStatusColor(ClientStatus status) {
    switch (status) {
      case ClientStatus.potential:
        return AppColors.warning;
      case ClientStatus.active:
        return AppColors.success;
      case ClientStatus.closed:
        return AppColors.info;
      case ClientStatus.lost:
        return AppColors.error;
    }
  }

  String _getLookingForLabel(String? lookingFor) {
    switch (lookingFor) {
      case 'sale':
        return 'Satilik';
      case 'rent':
        return 'Kiralik';
      default:
        return lookingFor ?? '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Column(
      children: [
        // Header (title + filters + search)
        _buildHeader(isDark),

        // Scrollable content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48,
                              color: AppColors.error.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          Text('Musteriler yuklenemedi',
                              style: TextStyle(
                                  color: AppColors.textSecondary(isDark))),
                          const SizedBox(height: 12),
                          TextButton(
                              onPressed: _loadClients,
                              child: const Text('Tekrar Dene')),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // KPI Row
                          _buildKpiRow(isDark),
                          const SizedBox(height: 16),

                          // Analytics section (2 column on desktop)
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: EngagementTable(
                                    onClientTap: (id) =>
                                        context.push('/clients/$id'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: PropertyInterestTable(),
                                ),
                              ],
                            )
                          else ...[
                            EngagementTable(
                              onClientTap: (id) =>
                                  context.push('/clients/$id'),
                            ),
                            const SizedBox(height: 16),
                            const PropertyInterestTable(),
                          ],
                          const SizedBox(height: 16),

                          // Activity feed
                          ActivityFeed(
                            onClientTap: (id) =>
                                context.push('/clients/$id'),
                          ),
                          const SizedBox(height: 16),

                          // Client list section title
                          Text(
                            'Musteri Listesi',
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Client table/list
                          _filteredClients.isEmpty
                              ? EmptyState(
                                  message: _clients.isEmpty
                                      ? 'Henuz musteriniz yok'
                                      : 'Aramayla eslesen musteri bulunamadi',
                                  icon: Icons.people_outline_rounded,
                                  buttonText: _clients.isEmpty
                                      ? 'Musteri Ekle'
                                      : null,
                                  onPressed: _clients.isEmpty
                                      ? () => _showAddClientDialog(context)
                                      : null,
                                )
                              : isDesktop
                                  ? _buildEnhancedDataTable(isDark)
                                  : _buildMobileList(isDark),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  // ============================================
  // KPI ROW
  // ============================================

  Widget _buildKpiRow(bool isDark) {
    final kpisAsync = ref.watch(crmKpisProvider);

    return kpisAsync.when(
      loading: () => _buildKpiRowShimmer(isDark),
      error: (_, __) => _buildKpiRowFallback(isDark),
      data: (kpis) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            if (isWide) {
              return Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Toplam Musteri',
                      value: '${kpis.totalClients}',
                      icon: Icons.people_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Aktif Musteri',
                      value: '${kpis.activeClients}',
                      icon: Icons.person_pin_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'En Aktif Musteri',
                      value: kpis.mostEngagedClientName ?? '-',
                      icon: Icons.star_rounded,
                      color: AppColors.accent,
                      onTap: kpis.mostEngagedClientId != null
                          ? () => context
                              .push('/clients/${kpis.mostEngagedClientId}')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      title: 'Bekleyen Takip',
                      value: '${kpis.dueFollowups}',
                      icon: Icons.notification_important_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              );
            }
            // Mobile: 2x2 grid
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Toplam',
                        value: '${kpis.totalClients}',
                        icon: Icons.people_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Aktif',
                        value: '${kpis.activeClients}',
                        icon: Icons.person_pin_rounded,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'En Aktif',
                        value: kpis.mostEngagedClientName ?? '-',
                        icon: Icons.star_rounded,
                        color: AppColors.accent,
                        onTap: kpis.mostEngagedClientId != null
                            ? () => context.push(
                                '/clients/${kpis.mostEngagedClientId}')
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Bekleyen Takip',
                        value: '${kpis.dueFollowups}',
                        icon: Icons.notification_important_rounded,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildKpiRowShimmer(bool isDark) {
    return Row(
      children: List.generate(
        4,
        (i) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i > 0 ? 12 : 0),
            child: StatCard(
              title: '',
              value: '',
              icon: Icons.circle,
              color: AppColors.primary,
              isLoading: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKpiRowFallback(bool isDark) {
    // Fallback with local data
    final total = _clients.length;
    final active = _clients.where((c) => c.status == ClientStatus.active).length;
    final due = _clients.where((c) => c.isFollowupDue).length;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            title: 'Toplam Musteri',
            value: '$total',
            icon: Icons.people_rounded,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Aktif Musteri',
            value: '$active',
            icon: Icons.person_pin_rounded,
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            title: 'Bekleyen Takip',
            value: '$due',
            icon: Icons.notification_important_rounded,
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }

  // ============================================
  // HEADER
  // ============================================

  Widget _buildHeader(bool isDark) {
    final statusFilters = <(String?, String)>[
      (null, 'Tumu'),
      ('potential', 'Potansiyel'),
      ('active', 'Aktif'),
      ('closed', 'Kapandi'),
      ('lost', 'Kayip'),
    ];

    return Container(
      color: AppColors.card(isDark),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              Text(
                'Musteriler',
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_clients.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredClients.length}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddClientDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Musteri Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Filters + search row
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: statusFilters.map((filter) {
                      final filterValue = filter.$1;
                      final filterLabel = filter.$2;
                      final isSelected = _selectedStatus == filterValue;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filterLabel),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedStatus = filterValue);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary(isDark),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontSize: 13,
                          ),
                          backgroundColor: AppColors.card(isDark),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : AppColors.border(isDark),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: TextStyle(
                    color: AppColors.textPrimary(isDark),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Musteri ara...',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        size: 18, color: AppColors.textMuted(isDark)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted(isDark)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.backgroundDark
                        : const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppColors.border(isDark)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: AppColors.border(isDark)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // ENHANCED DESKTOP DATA TABLE
  // ============================================

  Widget _buildEnhancedDataTable(bool isDark) {
    final clients = _filteredClients;
    final engagementAsync = ref.watch(clientEngagementProvider);

    // Build engagement lookup map
    final engagementMap = <String, ClientEngagement>{};
    engagementAsync.whenData((items) {
      for (final e in items) {
        engagementMap[e.clientId] = e;
      }
    });

    return Container(
      height: (clients.length * 56.0 + 56).clamp(200, 600),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DataTable2(
        columnSpacing: 12,
        horizontalMargin: 16,
        minWidth: 900,
        headingRowColor:
            WidgetStateProperty.all(AppColors.background(isDark)),
        headingTextStyle: TextStyle(
          color: AppColors.textSecondary(isDark),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(
          color: AppColors.textPrimary(isDark),
          fontSize: 13,
        ),
        dataRowHeight: 56,
        columns: const [
          DataColumn2(label: Text('Isim'), size: ColumnSize.L),
          DataColumn2(label: Text('Telefon'), size: ColumnSize.M),
          DataColumn2(label: Text('Aranan Tur'), size: ColumnSize.S),
          DataColumn2(label: Text('Butce'), size: ColumnSize.M),
          DataColumn2(label: Text('Durum'), size: ColumnSize.S),
          DataColumn2(label: Text('Goruntulenme'), fixedWidth: 100),
          DataColumn2(label: Text('Favori'), fixedWidth: 70),
          DataColumn2(label: Text('Skor'), fixedWidth: 70),
          DataColumn2(label: Text(''), fixedWidth: 70),
        ],
        rows: clients.map((client) {
          final eng = engagementMap[client.id];
          return DataRow2(
            onTap: () => context.push('/clients/${client.id}'),
            cells: [
              // Name
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        client.name.isNotEmpty
                            ? client.name.substring(0, 1).toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        client.name,
                        overflow: TextOverflow.ellipsis,
                        style:
                            const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              // Phone
              DataCell(Text(client.phone ?? '-')),
              // Looking for
              DataCell(Text(_getLookingForLabel(client.lookingFor))),
              // Budget
              DataCell(Text(client.formattedBudget)),
              // Status
              DataCell(
                StatusBadge(
                  label: client.status.label,
                  color: _getStatusColor(client.status),
                ),
              ),
              // Views
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility,
                        size: 13, color: AppColors.info),
                    const SizedBox(width: 4),
                    Text(
                      eng != null ? '${eng.viewCount}' : '-',
                      style: TextStyle(
                        color: eng != null && eng.viewCount > 0
                            ? AppColors.textPrimary(isDark)
                            : AppColors.textMuted(isDark),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Favorites
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite,
                        size: 13, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(
                      eng != null ? '${eng.favoriteCount}' : '-',
                      style: TextStyle(
                        color: eng != null && eng.favoriteCount > 0
                            ? AppColors.textPrimary(isDark)
                            : AppColors.textMuted(isDark),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Score
              DataCell(
                eng != null && eng.engagementScore > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _scoreColor(eng.engagementScore)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          eng.engagementScore.toStringAsFixed(0),
                          style: TextStyle(
                            color: _scoreColor(eng.engagementScore),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Text('-',
                        style: TextStyle(
                            color: AppColors.textMuted(isDark))),
              ),
              // Actions
              DataCell(
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.error),
                  onPressed: () => _confirmDeleteClient(client),
                  tooltip: 'Sil',
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score > 20) return AppColors.success;
    if (score > 5) return AppColors.warning;
    return AppColors.textMutedLight;
  }

  // ============================================
  // MOBILE LIST VIEW
  // ============================================

  Widget _buildMobileList(bool isDark) {
    final clients = _filteredClients;
    return Column(
      children: clients.map((client) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ClientCard(
            client: client,
            onTap: () => context.push('/clients/${client.id}'),
          ),
        );
      }).toList(),
    );
  }

  // ============================================
  // DELETE CONFIRM
  // ============================================

  Future<void> _confirmDeleteClient(RealtorClient client) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card(isDark),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Musteriyi Sil',
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '"${client.name}" adli musteriyi silmek istediginize emin misiniz?',
          style: TextStyle(
            color: AppColors.textSecondary(isDark),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgec',
                style: TextStyle(color: AppColors.textMuted(isDark))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _clientService.deleteClient(client.id);
        await _loadClients();
        ref.invalidate(crmKpisProvider);
        ref.invalidate(clientEngagementProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Musteri silindi'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Hata: $e'),
                backgroundColor: AppColors.error),
          );
        }
      }
    }
  }

  // ============================================
  // ADD CLIENT DIALOG
  // ============================================

  void _showAddClientDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final budgetMinController = TextEditingController();
    final budgetMaxController = TextEditingController();
    final notesController = TextEditingController();
    String? lookingFor;
    String? propertyType;

    final lookingForOptions = [
      ('sale', 'Satilik'),
      ('rent', 'Kiralik'),
    ];

    final propertyTypeOptions = [
      ('apartment', 'Daire'),
      ('villa', 'Villa'),
      ('residence', 'Rezidans'),
      ('land', 'Arsa'),
      ('office', 'Ofis'),
      ('shop', 'Dukkan'),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Yeni Musteri',
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Ad Soyad *', isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: nameController,
                        hint: 'Musteri adi',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Telefon', isDark),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: phoneController,
                                  hint: '05xx xxx xx xx',
                                  isDark: isDark,
                                  prefixIcon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildLabel('E-posta', isDark),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: emailController,
                                  hint: 'ornek@email.com',
                                  isDark: isDark,
                                  prefixIcon: Icons.email_outlined,
                                  keyboardType:
                                      TextInputType.emailAddress,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Aranan Tur', isDark),
                      const SizedBox(height: 6),
                      _buildDropdown<String>(
                        value: lookingFor,
                        hint: 'Secin',
                        isDark: isDark,
                        items: lookingForOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt.$1,
                                  child: Text(
                                    opt.$2,
                                    style: TextStyle(
                                      color:
                                          AppColors.textPrimary(isDark),
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => lookingFor = val),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Emlak Tipi', isDark),
                      const SizedBox(height: 6),
                      _buildDropdown<String>(
                        value: propertyType,
                        hint: 'Secin',
                        isDark: isDark,
                        items: propertyTypeOptions
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt.$1,
                                  child: Text(
                                    opt.$2,
                                    style: TextStyle(
                                      color:
                                          AppColors.textPrimary(isDark),
                                      fontSize: 14,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => propertyType = val),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Butce Araligi', isDark),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: budgetMinController,
                              hint: 'Min (TL)',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            child: Text('-',
                                style: TextStyle(
                                    color: AppColors.textMuted(isDark),
                                    fontSize: 16)),
                          ),
                          Expanded(
                            child: _buildTextField(
                              controller: budgetMaxController,
                              hint: 'Max (TL)',
                              isDark: isDark,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Notlar', isDark),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: notesController,
                        hint: 'Musteri ile ilgili notlar...',
                        isDark: isDark,
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Vazgec',
                      style:
                          TextStyle(color: AppColors.textMuted(isDark))),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lutfen musteri adini girin'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop();

                    final data = <String, dynamic>{
                      'name': name,
                      'status': 'potential',
                    };

                    final phone = phoneController.text.trim();
                    if (phone.isNotEmpty) data['phone'] = phone;

                    final email = emailController.text.trim();
                    if (email.isNotEmpty) data['email'] = email;

                    if (lookingFor != null) {
                      data['looking_for'] = lookingFor;
                    }
                    if (propertyType != null) {
                      data['property_type'] = propertyType;
                    }

                    final minStr = budgetMinController.text.trim();
                    if (minStr.isNotEmpty) {
                      data['budget_min'] = double.tryParse(minStr);
                    }

                    final maxStr = budgetMaxController.text.trim();
                    if (maxStr.isNotEmpty) {
                      data['budget_max'] = double.tryParse(maxStr);
                    }

                    final notes = notesController.text.trim();
                    if (notes.isNotEmpty) data['notes'] = notes;

                    try {
                      await _clientService.addClient(data);
                      await _loadClients();
                      ref.invalidate(crmKpisProvider);
                      ref.invalidate(clientEngagementProvider);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Musteri eklendi'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================
  // SHARED FORM WIDGETS
  // ============================================

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary(isDark),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: TextStyle(
        color: AppColors.textPrimary(isDark),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textMuted(isDark),
          fontSize: 14,
        ),
        filled: true,
        fillColor:
            isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon,
                size: 18, color: AppColors.textMuted(isDark))
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required bool isDark,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: AppColors.textMuted(isDark),
              fontSize: 14,
            ),
          ),
          isExpanded: true,
          dropdownColor: AppColors.card(isDark),
          icon: Icon(Icons.keyboard_arrow_down,
              color: AppColors.textMuted(isDark)),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
