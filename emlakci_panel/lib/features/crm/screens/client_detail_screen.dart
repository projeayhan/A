import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:emlakci_panel/core/services/log_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/client_model.dart';
import '../../../providers/client_provider.dart';
import '../../../services/client_service.dart';
import '../../../shared/widgets/status_badge.dart';
import '../widgets/property_activity_card.dart';
import '../widgets/activity_timeline.dart';

class ClientDetailScreen extends ConsumerStatefulWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends ConsumerState<ClientDetailScreen> {
  final _clientService = ClientService();

  RealtorClient? _client;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClient();
  }

  Future<void> _loadClient() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = await _clientService.getClient(widget.clientId);
      if (mounted) {
        setState(() {
          _client = client;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      LogService.error('Failed to load client detail', error: e, stackTrace: st, source: 'ClientDetailScreen:_loadClient');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
        return lookingFor ?? 'Belirtilmemis';
    }
  }

  String _getPropertyTypeLabel(String? type) {
    switch (type) {
      case 'apartment':
        return 'Daire';
      case 'villa':
        return 'Villa';
      case 'residence':
        return 'Rezidans';
      case 'land':
        return 'Arsa';
      case 'office':
        return 'Ofis';
      case 'shop':
        return 'Dukkan';
      default:
        return type ?? 'Belirtilmemis';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null || _client == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              _client == null ? 'Musteri bulunamadi' : 'Bir hata olustu',
              style: TextStyle(color: AppColors.textSecondary(isDark)),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.go('/clients'),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Musterilere Don'),
            ),
          ],
        ),
      );
    }

    final client = _client!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          TextButton.icon(
            onPressed: () => context.go('/clients'),
            icon: Icon(
              Icons.arrow_back_rounded,
              size: 18,
              color: AppColors.textSecondary(isDark),
            ),
            label: Text(
              'Musteriler',
              style: TextStyle(
                color: AppColors.textSecondary(isDark),
                fontSize: 13,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
          const SizedBox(height: 12),

          // Profile header card
          _buildProfileHeader(client, isDark),
          const SizedBox(height: 16),

          // Engagement metrics bar
          _buildEngagementMetrics(isDark),
          const SizedBox(height: 16),

          // Multi-column layout on desktop
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Contact + Preferences
                    Expanded(
                      child: Column(
                        children: [
                          _buildContactSection(client, isDark),
                          const SizedBox(height: 16),
                          _buildPreferencesSection(client, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Middle: Viewed + Favorited properties
                    Expanded(
                      child: Column(
                        children: [
                          _buildViewedPropertiesSection(isDark),
                          const SizedBox(height: 16),
                          _buildFavoritedPropertiesSection(isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Notes + Timeline + Actions
                    Expanded(
                      child: Column(
                        children: [
                          _buildNotesSection(client, isDark),
                          const SizedBox(height: 16),
                          _buildActivityTimelineSection(isDark),
                          const SizedBox(height: 16),
                          _buildActionsSection(client, isDark),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _buildContactSection(client, isDark),
                  const SizedBox(height: 16),
                  _buildPreferencesSection(client, isDark),
                  const SizedBox(height: 16),
                  _buildViewedPropertiesSection(isDark),
                  const SizedBox(height: 16),
                  _buildFavoritedPropertiesSection(isDark),
                  const SizedBox(height: 16),
                  _buildNotesSection(client, isDark),
                  const SizedBox(height: 16),
                  _buildActivityTimelineSection(isDark),
                  const SizedBox(height: 16),
                  _buildActionsSection(client, isDark),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // PROFILE HEADER
  // ============================================

  Widget _buildProfileHeader(RealtorClient client, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              client.name.isNotEmpty
                  ? client.name.substring(0, 1).toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        client.name,
                        style: TextStyle(
                          color: AppColors.textPrimary(isDark),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    StatusBadge(
                      label: client.status.label,
                      color: _getStatusColor(client.status),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (client.source != null && client.source!.isNotEmpty)
                  Text(
                    'Kaynak: ${client.source}',
                    style: TextStyle(
                      color: AppColors.textMuted(isDark),
                      fontSize: 13,
                    ),
                  ),
                Text(
                  'Eklenme: ${DateFormat('dd MMM yyyy', 'tr').format(client.createdAt)}',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Quick action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (client.phone != null && client.phone!.isNotEmpty)
                _buildQuickAction(
                  icon: Icons.phone_rounded,
                  color: AppColors.success,
                  tooltip: 'Ara',
                  onTap: () => _launchUrl('tel:${client.phone}'),
                ),
              const SizedBox(width: 8),
              if (client.email != null && client.email!.isNotEmpty)
                _buildQuickAction(
                  icon: Icons.email_rounded,
                  color: AppColors.info,
                  tooltip: 'E-posta Gonder',
                  onTap: () => _launchUrl('mailto:${client.email}'),
                ),
              const SizedBox(width: 8),
              if (client.phone != null && client.phone!.isNotEmpty)
                _buildQuickAction(
                  icon: Icons.message_rounded,
                  color: const Color(0xFF25D366),
                  tooltip: 'WhatsApp',
                  onTap: () => _launchUrl(
                    'https://wa.me/${_normalizePhone(client.phone!)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }

  // ============================================
  // CONTACT SECTION
  // ============================================

  Widget _buildContactSection(RealtorClient client, bool isDark) {
    return _buildSection(
      title: 'Iletisim Bilgileri',
      icon: Icons.contact_phone_rounded,
      isDark: isDark,
      children: [
        _buildInfoRow(
          Icons.person_outline_rounded,
          'Ad Soyad',
          client.name,
          isDark,
        ),
        if (client.phone != null)
          _buildInfoRow(Icons.phone_outlined, 'Telefon', client.phone!, isDark),
        if (client.email != null)
          _buildInfoRow(Icons.email_outlined, 'E-posta', client.email!, isDark),
        if (client.lastContactAt != null)
          _buildInfoRow(
            Icons.history_rounded,
            'Son Iletisim',
            DateFormat('dd MMM yyyy', 'tr').format(client.lastContactAt!),
            isDark,
          ),
        if (client.nextFollowupAt != null)
          _buildInfoRow(
            Icons.event_rounded,
            'Sonraki Takip',
            DateFormat('dd MMM yyyy', 'tr').format(client.nextFollowupAt!),
            isDark,
            valueColor: client.isFollowupDue ? AppColors.warning : null,
          ),
      ],
    );
  }

  // ============================================
  // PREFERENCES SECTION
  // ============================================

  Widget _buildPreferencesSection(RealtorClient client, bool isDark) {
    return _buildSection(
      title: 'Tercihler',
      icon: Icons.tune_rounded,
      isDark: isDark,
      children: [
        _buildInfoRow(
          Icons.sell_outlined,
          'Aranan Tur',
          _getLookingForLabel(client.lookingFor),
          isDark,
        ),
        _buildInfoRow(
          Icons.home_outlined,
          'Emlak Tipi',
          _getPropertyTypeLabel(client.propertyType),
          isDark,
        ),
        _buildInfoRow(
          Icons.payments_outlined,
          'Butce',
          client.formattedBudget,
          isDark,
        ),
        if (client.preferredCities.isNotEmpty)
          _buildInfoRow(
            Icons.location_city_rounded,
            'Tercih Edilen Sehirler',
            client.preferredCities.join(', '),
            isDark,
          ),
        if (client.preferredDistricts.isNotEmpty)
          _buildInfoRow(
            Icons.map_outlined,
            'Tercih Edilen Ilceler',
            client.preferredDistricts.join(', '),
            isDark,
          ),
      ],
    );
  }

  // ============================================
  // NOTES SECTION
  // ============================================

  Widget _buildNotesSection(RealtorClient client, bool isDark) {
    return _buildSection(
      title: 'Notlar',
      icon: Icons.note_alt_outlined,
      isDark: isDark,
      children: [
        if (client.notes != null && client.notes!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              client.notes!,
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Henuz not eklenmemis',
              style: TextStyle(
                color: AppColors.textMuted(isDark),
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================
  // ACTIONS SECTION
  // ============================================

  Widget _buildActionsSection(RealtorClient client, bool isDark) {
    return _buildSection(
      title: 'Islemler',
      icon: Icons.settings_rounded,
      isDark: isDark,
      children: [
        const SizedBox(height: 4),
        // Edit button
        _buildActionButton(
          icon: Icons.edit_rounded,
          label: 'Duzenle',
          color: AppColors.primary,
          isDark: isDark,
          onTap: () => _showEditStatusDialog(client),
        ),
        const SizedBox(height: 8),

        // Call button
        if (client.phone != null && client.phone!.isNotEmpty)
          _buildActionButton(
            icon: Icons.phone_rounded,
            label: 'Ara',
            color: AppColors.success,
            isDark: isDark,
            onTap: () => _launchUrl('tel:${client.phone}'),
          ),
        if (client.phone != null && client.phone!.isNotEmpty)
          const SizedBox(height: 8),

        // Message button
        if (client.phone != null && client.phone!.isNotEmpty)
          _buildActionButton(
            icon: Icons.message_rounded,
            label: 'WhatsApp Mesaj Gonder',
            color: const Color(0xFF25D366),
            isDark: isDark,
            onTap: () =>
                _launchUrl('https://wa.me/${_normalizePhone(client.phone!)}'),
          ),
        if (client.phone != null && client.phone!.isNotEmpty)
          const SizedBox(height: 8),

        // Delete button
        _buildActionButton(
          icon: Icons.delete_rounded,
          label: 'Musteriyi Sil',
          color: AppColors.error,
          isDark: isDark,
          onTap: () => _confirmDeleteClient(client),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================
  // SHARED SECTION BUILDER
  // ============================================

  Widget _buildSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    bool isDark, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted(isDark)),
          const SizedBox(width: 10),
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.textMuted(isDark),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary(isDark),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ENGAGEMENT METRICS BAR
  // ============================================

  Widget _buildEngagementMetrics(bool isDark) {
    final activityAsync = ref.watch(
      clientPropertyActivityProvider(widget.clientId),
    );

    return activityAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (activities) {
        if (activities.isEmpty && _client?.userId == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bu musteri henuz platform hesabina bagli degil. Hesap baglandiginda goruntulenme ve favori verileri burada gosterilecek.',
                    style: TextStyle(color: AppColors.info, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        final totalViews = activities.fold<int>(
          0,
          (sum, a) => sum + a.viewCount,
        );
        final totalFavs = activities.where((a) => a.isFavorited).length;
        final viewedCount = activities.where((a) => a.viewCount > 0).length;

        return Row(
          children: [
            _buildMetricChip(
              Icons.visibility,
              '$totalViews goruntulenme',
              AppColors.info,
              isDark,
            ),
            const SizedBox(width: 10),
            _buildMetricChip(
              Icons.favorite,
              '$totalFavs favori',
              AppColors.error,
              isDark,
            ),
            const SizedBox(width: 10),
            _buildMetricChip(
              Icons.home_outlined,
              '$viewedCount ilan incelendi',
              AppColors.primary,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricChip(
    IconData icon,
    String label,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // VIEWED PROPERTIES SECTION
  // ============================================

  Widget _buildViewedPropertiesSection(bool isDark) {
    final activityAsync = ref.watch(
      clientPropertyActivityProvider(widget.clientId),
    );

    return _buildSection(
      title: 'Goruntulediği Ilanlar',
      icon: Icons.visibility_outlined,
      isDark: isDark,
      children: [
        activityAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Veri yuklenemedi',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          data: (activities) {
            final viewed = activities.where((a) => a.viewCount > 0).toList();
            if (viewed.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _client?.userId != null
                      ? 'Henuz ilan goruntulemedi'
                      : 'Platform hesabi bagli degil',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return Column(
              children: viewed
                  .map((a) => PropertyActivityCard(activity: a))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================
  // FAVORITED PROPERTIES SECTION
  // ============================================

  Widget _buildFavoritedPropertiesSection(bool isDark) {
    final activityAsync = ref.watch(
      clientPropertyActivityProvider(widget.clientId),
    );

    return _buildSection(
      title: 'Favori Ilanlari',
      icon: Icons.favorite_outlined,
      isDark: isDark,
      children: [
        activityAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Veri yuklenemedi',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          data: (activities) {
            final favorited = activities.where((a) => a.isFavorited).toList();
            if (favorited.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _client?.userId != null
                      ? 'Henuz favori ilani yok'
                      : 'Platform hesabi bagli degil',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return Column(
              children: favorited
                  .map((a) => PropertyActivityCard(activity: a))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================
  // ACTIVITY TIMELINE SECTION
  // ============================================

  Widget _buildActivityTimelineSection(bool isDark) {
    final activityAsync = ref.watch(
      clientPropertyActivityProvider(widget.clientId),
    );

    return _buildSection(
      title: 'Aktivite Gecmisi',
      icon: Icons.timeline_rounded,
      isDark: isDark,
      children: [
        activityAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Veri yuklenemedi',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          data: (activities) {
            if (activities.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Henuz aktivite yok',
                  style: TextStyle(
                    color: AppColors.textMuted(isDark),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }
            return ActivityTimeline(activities: activities);
          },
        ),
      ],
    );
  }

  // ============================================
  // EDIT STATUS DIALOG
  // ============================================

  void _showEditStatusDialog(RealtorClient client) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ClientStatus selectedStatus = client.status;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.card(isDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                'Musteri Durumunu Guncelle',
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: ClientStatus.values.map((status) {
                  final isSelected = selectedStatus == status;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () =>
                          setDialogState(() => selectedStatus = status),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _getStatusColor(status).withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? _getStatusColor(status)
                                : AppColors.border(isDark),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              status.label,
                              style: TextStyle(
                                color: AppColors.textPrimary(isDark),
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Icon(
                                Icons.check_rounded,
                                color: _getStatusColor(status),
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Vazgec',
                    style: TextStyle(color: AppColors.textMuted(isDark)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();

                    try {
                      await _clientService.updateClient(client.id, {
                        'status': selectedStatus.name,
                      });
                      await _loadClient();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Musteri durumu guncellendi'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    } catch (e, st) {
                      LogService.error('Failed to update client status', error: e, stackTrace: st, source: 'ClientDetailScreen:updateStatus');
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
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Musteriyi Sil',
          style: TextStyle(
            color: AppColors.textPrimary(isDark),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '"${client.name}" adli musteriyi silmek istediginize emin misiniz? Bu islem geri alinamaz.',
          style: TextStyle(
            color: AppColors.textSecondary(isDark),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Vazgec',
              style: TextStyle(color: AppColors.textMuted(isDark)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _clientService.deleteClient(client.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Musteri silindi'),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/clients');
        }
      } catch (e, st) {
        LogService.error('Failed to delete client', error: e, stackTrace: st, source: 'ClientDetailScreen:_deleteClient');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e, st) {
      LogService.error('URL açılamadı', error: e, stackTrace: st, source: 'ClientDetailScreen:_launchUrl');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Baglanti acilamadi'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Normalize phone for WhatsApp link (remove spaces, dashes, leading 0)
  String _normalizePhone(String phone) {
    var normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (normalized.startsWith('0')) {
      normalized = '90${normalized.substring(1)}';
    }
    if (!normalized.startsWith('+') && !normalized.startsWith('90')) {
      normalized = '90$normalized';
    }
    return normalized;
  }
}
