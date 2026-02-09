import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

class AiSupportScreen extends ConsumerStatefulWidget {
  const AiSupportScreen({super.key});

  @override
  ConsumerState<AiSupportScreen> createState() => _AiSupportScreenState();
}

class _AiSupportScreenState extends ConsumerState<AiSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _sessions = [];
  List<Map<String, dynamic>> _knowledgeBase = [];
  List<Map<String, dynamic>> _systemPrompts = [];
  Map<String, dynamic> _stats = {};

  bool _isLoading = true;
  String _selectedAppSource = 'all';
  String _selectedStatus = 'all';
  String? _selectedSessionId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadSessions(),
      _loadKnowledgeBase(),
      _loadSystemPrompts(),
      _loadStats(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadSessions() async {
    try {
      var query = _supabase
          .from('support_chat_sessions')
          .select('*, support_chat_messages(count)');

      if (_selectedAppSource != 'all') {
        query = query.eq('app_source', _selectedAppSource);
      }
      if (_selectedStatus != 'all') {
        query = query.eq('status', _selectedStatus);
      }

      final response = await query
          .order('updated_at', ascending: false)
          .limit(100);

      setState(() {
        _sessions = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
  }

  Future<void> _loadKnowledgeBase() async {
    try {
      final response = await _supabase
          .from('ai_knowledge_base')
          .select()
          .order('category')
          .order('priority', ascending: false);

      setState(() {
        _knowledgeBase = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading knowledge base: $e');
    }
  }

  Future<void> _loadSystemPrompts() async {
    try {
      final response = await _supabase
          .from('ai_system_prompts')
          .select()
          .order('app_source');

      setState(() {
        _systemPrompts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading system prompts: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      // Get session counts by status
      final sessionsResponse = await _supabase
          .from('support_chat_sessions')
          .select('status, app_source');

      final sessions = List<Map<String, dynamic>>.from(sessionsResponse);

      int totalSessions = sessions.length;
      int activeSessions = sessions
          .where((s) => s['status'] == 'active')
          .length;
      int escalatedSessions = sessions
          .where((s) => s['status'] == 'escalated')
          .length;
      int superAppSessions = sessions
          .where((s) => s['app_source'] == 'super_app')
          .length;
      int merchantSessions = sessions
          .where((s) => s['app_source'] == 'merchant_panel')
          .length;

      // Get average rating
      final ratingsResponse = await _supabase
          .from('support_chat_sessions')
          .select('user_rating')
          .not('user_rating', 'is', null);

      final ratings = List<Map<String, dynamic>>.from(ratingsResponse);
      double avgRating = 0;
      if (ratings.isNotEmpty) {
        avgRating =
            ratings
                .map((r) => (r['user_rating'] as num).toDouble())
                .reduce((a, b) => a + b) /
            ratings.length;
      }

      setState(() {
        _stats = {
          'total_sessions': totalSessions,
          'active_sessions': activeSessions,
          'escalated_sessions': escalatedSessions,
          'super_app_sessions': superAppSessions,
          'merchant_sessions': merchantSessions,
          'avg_rating': avgRating,
        };
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsRow(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSessionsTab(),
                      _buildKnowledgeBaseTab(),
                      _buildSystemPromptsTab(),
                      _buildAnalyticsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Destek Yonetimi',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Sohbet oturumlari, bilgi tabanı ve sistem ayarlari',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          _buildStatCard(
            'Toplam Oturum',
            '${_stats['total_sessions'] ?? 0}',
            Icons.chat_bubble_outline,
            AppColors.primary,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Aktif Oturum',
            '${_stats['active_sessions'] ?? 0}',
            Icons.play_circle_outline,
            AppColors.success,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Insan Desteğe Aktarilan',
            '${_stats['escalated_sessions'] ?? 0}',
            Icons.person_outline,
            AppColors.warning,
          ),
          const SizedBox(width: 16),
          _buildStatCard(
            'Ortalama Puan',
            (_stats['avg_rating'] ?? 0).toStringAsFixed(1),
            Icons.star_outline,
            AppColors.info,
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
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.surfaceLight)),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        tabs: const [
          Tab(text: 'Sohbet Oturumlari'),
          Tab(text: 'Bilgi Tabani'),
          Tab(text: 'Sistem Promptlari'),
          Tab(text: 'Analitik'),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    return Row(
      children: [
        // Sessions List
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight),
            ),
            child: Column(
              children: [
                _buildSessionFilters(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: _sessions.length,
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      return _buildSessionItem(session);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Session Detail
        if (_selectedSessionId != null)
          Expanded(flex: 3, child: _buildSessionDetail()),
      ],
    );
  }

  Widget _buildSessionFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text(
            'Uygulama:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedAppSource,
            dropdownColor: AppColors.surface,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tümü')),
              DropdownMenuItem(value: 'super_app', child: Text('SuperCyp')),
              DropdownMenuItem(
                value: 'merchant_panel',
                child: Text('SuperCyp İşletme'),
              ),
            ],
            onChanged: (value) {
              setState(() => _selectedAppSource = value!);
              _loadSessions();
            },
          ),
          const SizedBox(width: 24),
          const Text('Durum:', style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: _selectedStatus,
            dropdownColor: AppColors.surface,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('Tümü')),
              DropdownMenuItem(value: 'active', child: Text('Aktif')),
              DropdownMenuItem(value: 'closed', child: Text('Kapali')),
              DropdownMenuItem(value: 'escalated', child: Text('Aktarildi')),
            ],
            onChanged: (value) {
              setState(() => _selectedStatus = value!);
              _loadSessions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSessionItem(Map<String, dynamic> session) {
    final isSelected = _selectedSessionId == session['id'];
    final status = session['status'] ?? 'active';
    final appSource = session['app_source'] ?? 'unknown';
    final updatedAt = DateTime.tryParse(session['updated_at'] ?? '');

    Color statusColor;
    switch (status) {
      case 'active':
        statusColor = AppColors.success;
        break;
      case 'escalated':
        statusColor = AppColors.warning;
        break;
      case 'closed':
        statusColor = AppColors.textMuted;
        break;
      default:
        statusColor = AppColors.textMuted;
    }

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.primary.withAlpha(20),
      leading: CircleAvatar(
        backgroundColor: statusColor.withAlpha(30),
        child: Icon(
          appSource == 'super_app' ? Icons.phone_android : Icons.store,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Text(
        'Oturum #${session['id'].toString().substring(0, 8)}',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            appSource == 'super_app' ? 'SuperCyp' : 'SuperCyp İşletme',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
          if (updatedAt != null)
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(updatedAt),
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: statusColor.withAlpha(30),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          status == 'active'
              ? 'Aktif'
              : (status == 'escalated' ? 'Aktarildi' : 'Kapali'),
          style: TextStyle(
            color: statusColor,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      onTap: () {
        setState(() => _selectedSessionId = session['id']);
      },
    );
  }

  Widget _buildSessionDetail() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _loadSessionMessages(_selectedSessionId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data ?? [];

        return Container(
          margin: const EdgeInsets.fromLTRB(0, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceLight),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.surfaceLight),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Sohbet Gecmisi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          setState(() => _selectedSessionId = null),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isUser = message['role'] == 'user';

                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.4,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? AppColors.primary
                              : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['content'] ?? '',
                              style: TextStyle(
                                color: isUser
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isUser ? 'Kullanici' : 'AI',
                              style: TextStyle(
                                fontSize: 10,
                                color: isUser
                                    ? Colors.white70
                                    : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadSessionMessages(
    String sessionId,
  ) async {
    try {
      final response = await _supabase
          .from('support_chat_messages')
          .select()
          .eq('session_id', sessionId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Widget _buildKnowledgeBaseTab() {
    final groupedKnowledge = <String, List<Map<String, dynamic>>>{};
    for (var item in _knowledgeBase) {
      final category = item['category'] ?? 'Diger';
      groupedKnowledge.putIfAbsent(category, () => []).add(item);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.surfaceLight),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Bilgi Tabani',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _showAddKnowledgeDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Yeni Ekle'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: groupedKnowledge.keys.length,
                      itemBuilder: (context, index) {
                        final category = groupedKnowledge.keys.elementAt(index);
                        final items = groupedKnowledge[category]!;

                        return ExpansionTile(
                          title: Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${items.length} madde',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          children: items.map((item) {
                            return ListTile(
                              title: Text(item['question'] ?? ''),
                              subtitle: Text(
                                item['answer'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text(
                                      item['app_source'] ?? 'all',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: AppColors.surfaceLight,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () =>
                                        _showEditKnowledgeDialog(item),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    onPressed: () =>
                                        _deleteKnowledgeItem(item['id']),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddKnowledgeDialog() {
    final questionController = TextEditingController();
    final answerController = TextEditingController();
    final categoryController = TextEditingController();
    String selectedAppSource = 'all';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Yeni Bilgi Ekle'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Soru'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Cevap'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedAppSource,
                decoration: const InputDecoration(labelText: 'Uygulama'),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tüm Uygulamalar'),
                  ),
                  DropdownMenuItem(
                    value: 'super_app',
                    child: Text('SuperCyp'),
                  ),
                  DropdownMenuItem(
                    value: 'merchant_panel',
                    child: Text('SuperCyp İşletme'),
                  ),
                ],
                onChanged: (value) => selectedAppSource = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('ai_knowledge_base').insert({
                'category': categoryController.text,
                'question': questionController.text,
                'answer': answerController.text,
                'app_source': selectedAppSource,
              });
              Navigator.pop(context);
              _loadKnowledgeBase();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showEditKnowledgeDialog(Map<String, dynamic> item) {
    final questionController = TextEditingController(text: item['question']);
    final answerController = TextEditingController(text: item['answer']);
    final categoryController = TextEditingController(text: item['category']);
    String selectedAppSource = item['app_source'] ?? 'all';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Bilgi Düzenle'),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Kategori'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: questionController,
                decoration: const InputDecoration(labelText: 'Soru'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: answerController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Cevap'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedAppSource,
                decoration: const InputDecoration(labelText: 'Uygulama'),
                items: const [
                  DropdownMenuItem(
                    value: 'all',
                    child: Text('Tüm Uygulamalar'),
                  ),
                  DropdownMenuItem(
                    value: 'super_app',
                    child: Text('SuperCyp'),
                  ),
                  DropdownMenuItem(
                    value: 'merchant_panel',
                    child: Text('SuperCyp İşletme'),
                  ),
                ],
                onChanged: (value) => selectedAppSource = value!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabase
                  .from('ai_knowledge_base')
                  .update({
                    'category': categoryController.text,
                    'question': questionController.text,
                    'answer': answerController.text,
                    'app_source': selectedAppSource,
                  })
                  .eq('id', item['id']);
              Navigator.pop(context);
              _loadKnowledgeBase();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteKnowledgeItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Silmek istediginize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('ai_knowledge_base').delete().eq('id', id);
      _loadKnowledgeBase();
    }
  }

  Widget _buildSystemPromptsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.surfaceLight),
                ),
              ),
              child: const Row(
                children: [
                  Text(
                    'Sistem Promptlari',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _systemPrompts.length,
                itemBuilder: (context, index) {
                  final prompt = _systemPrompts[index];
                  return Card(
                    color: AppColors.surfaceLight,
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(30),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  prompt['app_source'] ?? '',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: prompt['is_active'] ?? true,
                                onChanged: (value) async {
                                  await _supabase
                                      .from('ai_system_prompts')
                                      .update({'is_active': value})
                                      .eq('id', prompt['id']);
                                  _loadSystemPrompts();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            prompt['name'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            prompt['prompt'] ?? '',
                            maxLines: 5,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _showEditPromptDialog(prompt),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Düzenle'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditPromptDialog(Map<String, dynamic> prompt) {
    final nameController = TextEditingController(text: prompt['name']);
    final promptController = TextEditingController(text: prompt['prompt']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('${prompt['app_source']} Promptunu Düzenle'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Isim'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Sistem Promptu'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _supabase
                  .from('ai_system_prompts')
                  .update({
                    'name': nameController.text,
                    'prompt': promptController.text,
                  })
                  .eq('id', prompt['id']);
              Navigator.pop(context);
              _loadSystemPrompts();
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Uygulama Bazli Dagilim',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsItem(
                    'SuperCyp',
                    _stats['super_app_sessions'] ?? 0,
                    _stats['total_sessions'] ?? 1,
                    AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticsItem(
                    'Merchant Panel',
                    _stats['merchant_sessions'] ?? 0,
                    _stats['total_sessions'] ?? 1,
                    AppColors.success,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Oturum Durumu',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  _buildAnalyticsItem(
                    'Aktif',
                    _stats['active_sessions'] ?? 0,
                    _stats['total_sessions'] ?? 1,
                    AppColors.success,
                  ),
                  const SizedBox(height: 16),
                  _buildAnalyticsItem(
                    'Insan Desteğe Aktarilan',
                    _stats['escalated_sessions'] ?? 0,
                    _stats['total_sessions'] ?? 1,
                    AppColors.warning,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text('$count (${percentage.toStringAsFixed(1)}%)'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: AppColors.surfaceLight,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ],
    );
  }
}
