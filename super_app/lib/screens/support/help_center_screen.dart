import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int? _expandedIndex;

  static const _faqCategories = [
    _FaqCategory(
      title: 'Sipariş ve Teslimat',
      icon: Icons.local_shipping_outlined,
      color: Color(0xFF3B82F6),
      questions: [
        _FaqItem(
          question: 'Siparişimi nasıl takip edebilirim?',
          answer: 'Siparişlerim sayfasından aktif siparişinizi seçerek gerçek zamanlı takip edebilirsiniz. Sipariş onaylandığında, hazırlanırken ve yola çıktığında bildirim alırsınız.',
        ),
        _FaqItem(
          question: 'Siparişimi iptal edebilir miyim?',
          answer: 'Sipariş henüz hazırlanmaya başlamadıysa iptal edebilirsiniz. Sipariş detay sayfasından "İptal Et" butonuna tıklayın. Hazırlanan siparişler için lütfen canlı destek ile iletişime geçin.',
        ),
        _FaqItem(
          question: 'Teslimat ücreti ne kadar?',
          answer: 'Teslimat ücreti mesafeye ve restorana göre değişir. Sipariş öncesinde sepet sayfasında teslimat ücreti gösterilir. Bazı restoranlarda minimum sipariş tutarı üzerinde ücretsiz teslimat sunulmaktadır.',
        ),
        _FaqItem(
          question: 'Yanlış veya eksik sipariş geldiyse ne yapmalıyım?',
          answer: 'Sipariş geçmişinden ilgili siparişi seçerek "Sorun Bildir" butonuna tıklayın. Ekibimiz en kısa sürede sizinle iletişime geçecektir. Fotoğraf eklemeniz çözüm sürecini hızlandırır.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Ödeme',
      icon: Icons.payment_outlined,
      color: Color(0xFF8B5CF6),
      questions: [
        _FaqItem(
          question: 'Hangi ödeme yöntemlerini kullanabilirim?',
          answer: 'Kredi kartı, banka kartı ve kapıda nakit ödeme seçeneklerini kullanabilirsiniz. Kart bilgileriniz güvenli bir şekilde şifrelenerek saklanır.',
        ),
        _FaqItem(
          question: 'İade ne zaman hesabıma yansır?',
          answer: 'İptal edilen veya iade onaylanan siparişlerde tutarınız 1-3 iş günü içinde kart hesabınıza iade edilir. Nakit ödemeler için ise SuperCyp bakiyenize eklenir.',
        ),
        _FaqItem(
          question: 'Kart bilgilerim güvende mi?',
          answer: 'Evet. Kart bilgileriniz PCI DSS standartlarına uygun olarak şifrelenir ve güvenli sunucularda saklanır. Kart numaranızın tamamı hiçbir zaman saklanmaz.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Hesap ve Güvenlik',
      icon: Icons.security_outlined,
      color: Color(0xFF10B981),
      questions: [
        _FaqItem(
          question: 'Şifremi nasıl değiştirebilirim?',
          answer: 'Ayarlar > Şifre ve Güvenlik bölümünden şifrenizi değiştirebilirsiniz. Mevcut şifrenizi girdikten sonra yeni şifrenizi belirleyebilirsiniz.',
        ),
        _FaqItem(
          question: 'Hesabımı nasıl silebilirim?',
          answer: 'Ayarlar > Gizlilik > Hesabı Sil bölümünden hesabınızı kalıcı olarak silebilirsiniz. Bu işlem geri alınamaz ve tüm verileriniz silinir.',
        ),
        _FaqItem(
          question: 'Biyometrik giriş nasıl çalışır?',
          answer: 'Ayarlar > Uygulama Tercihleri bölümünden biyometrik girişi aktifleştirebilirsiniz. Parmak izi veya yüz tanıma ile uygulamaya hızlı ve güvenli giriş yapabilirsiniz.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Taksi',
      icon: Icons.local_taxi_outlined,
      color: Color(0xFFF59E0B),
      questions: [
        _FaqItem(
          question: 'Taksi ücreti nasıl hesaplanır?',
          answer: 'Ücret, mesafe ve tahmini süreye göre otomatik hesaplanır. Yolculuk başlamadan önce tahmini ücreti görebilirsiniz. Trafik durumuna göre küçük farklar olabilir.',
        ),
        _FaqItem(
          question: 'Taksi çağırdıktan sonra iptal edebilir miyim?',
          answer: 'Evet, şoför atanmadan önce ücretsiz iptal edebilirsiniz. Şoför atandıktan sonra iptal etmeniz durumunda iptal ücreti uygulanabilir.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Emlak ve Araç',
      icon: Icons.home_outlined,
      color: Color(0xFFEC4899),
      questions: [
        _FaqItem(
          question: 'İlan nasıl verebilirim?',
          answer: 'İlgili bölüme giderek (Emlak veya Araç) "İlan Ver" butonuna tıklayın. Gerekli bilgileri doldurup fotoğraf ekledikten sonra ilanınız yayınlanır.',
        ),
        _FaqItem(
          question: 'İlanlarım ne kadar süre yayında kalır?',
          answer: 'İlanlarınız siz kaldırana kadar yayında kalır. Satılan veya kiralanan mülk/araç ilanlarını kaldırmanız tavsiye edilir.',
        ),
      ],
    ),
  ];

  List<_FaqCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _faqCategories;
    final query = _searchQuery.toLowerCase();
    return _faqCategories
        .map((cat) {
          final filtered = cat.questions
              .where((q) =>
                  q.question.toLowerCase().contains(query) ||
                  q.answer.toLowerCase().contains(query))
              .toList();
          if (filtered.isEmpty) return null;
          return _FaqCategory(
            title: cat.title,
            icon: cat.icon,
            color: cat.color,
            questions: filtered,
          );
        })
        .whereType<_FaqCategory>()
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categories = _filteredCategories;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
              ),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: isDark ? Colors.white : Colors.grey[800],
            ),
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Yardım Merkezi',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Soru ara...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          // FAQ list
          Expanded(
            child: categories.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Sonuç bulunamadı',
                          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: categories.length,
                    itemBuilder: (context, catIndex) {
                      final cat = categories[catIndex];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12, top: 8, left: 4),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: cat.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(cat.icon, color: cat.color, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  cat.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Questions
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: cat.questions.asMap().entries.map((entry) {
                                final qIndex = entry.key;
                                final q = entry.value;
                                final globalIndex = _getGlobalIndex(categories, catIndex, qIndex);
                                final isExpanded = _expandedIndex == globalIndex;

                                return Column(
                                  children: [
                                    if (qIndex > 0)
                                      Divider(
                                        height: 1,
                                        indent: 16,
                                        endIndent: 16,
                                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                                      ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          setState(() {
                                            _expandedIndex = isExpanded ? null : globalIndex;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      q.question,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                                                      ),
                                                    ),
                                                  ),
                                                  AnimatedRotation(
                                                    turns: isExpanded ? 0.5 : 0,
                                                    duration: const Duration(milliseconds: 200),
                                                    child: Icon(
                                                      Icons.keyboard_arrow_down,
                                                      color: Colors.grey[500],
                                                      size: 22,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (isExpanded) ...[
                                                const SizedBox(height: 10),
                                                Text(
                                                  q.answer,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    height: 1.5,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      // AI Assistant CTA
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GestureDetector(
            onTap: () => context.push('/support/ai-chat'),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF60A5FA)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy_outlined, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'AI Asistana Sor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getGlobalIndex(List<_FaqCategory> categories, int catIndex, int qIndex) {
    int index = 0;
    for (int i = 0; i < catIndex; i++) {
      index += categories[i].questions.length;
    }
    return index + qIndex;
  }
}

class _FaqCategory {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FaqItem> questions;

  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.questions,
  });
}

class _FaqItem {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});
}
