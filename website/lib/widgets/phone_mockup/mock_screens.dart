import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fake app screens rendered as Flutter widgets inside phone mockups.
/// These mimic the real app UI without needing screenshot assets.

class MockHomeScreen extends StatelessWidget {
  const MockHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF6366F1),
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hoş Geldin!',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 10)),
                  Text('Ayhan',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const Spacer(),
              _iconBadge(Icons.notifications_outlined, count: 3),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2230),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white38, size: 18),
                const SizedBox(width: 8),
                Text('Restoran, mağaza ara...',
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('Hizmetler',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          // Services grid
          _serviceCard('Yemek', Icons.restaurant, const Color(0xFFEC6D13), true),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _serviceCard(
                      'Mağaza', Icons.shopping_cart, const Color(0xFF34D399))),
              const SizedBox(width: 6),
              Expanded(
                  child: _serviceCard(
                      'Taksi', Icons.local_taxi, const Color(0xFFFBBF24))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _serviceCard(
                      'Emlak', Icons.home_work, const Color(0xFF3B82F6))),
              const SizedBox(width: 6),
              Expanded(
                  child: _serviceCard(
                      'Araç', Icons.directions_car, const Color(0xFFF43F5E))),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _serviceCard(
                      'Kiralama', Icons.car_rental, const Color(0xFF8B5CF6))),
              const SizedBox(width: 6),
              Expanded(
                  child: _serviceCard(
                      'İş İlanı', Icons.work, const Color(0xFF6366F1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBadge(IconData icon, {int count = 0}) {
    return Stack(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        if (count > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: Text('$count',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

Widget _serviceCard(String label, IconData icon, Color color,
    [bool large = false]) {
  return Container(
    height: large ? 70 : 50,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
      ),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        Icon(icon, color: color, size: large ? 24 : 18),
        const SizedBox(width: 8),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: large ? 14 : 12,
                fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class MockFoodScreen extends StatelessWidget {
  const MockFoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Restoranlar',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Hepsi', 'Pizza', 'Burger', 'Kebap', 'Tatlı']
                  .map((c) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: c == 'Hepsi'
                              ? const Color(0xFFEC6D13)
                              : const Color(0xFF1A2230),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(c,
                            style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          _restaurantCard('Cypress Kitchen', '4.8', '25-35 dk', 0xFFEC6D13),
          const SizedBox(height: 8),
          _restaurantCard('Pizza House', '4.6', '20-30 dk', 0xFFF97316),
          const SizedBox(height: 8),
          _restaurantCard('Burger Lab', '4.7', '15-25 dk', 0xFFEF4444),
          const SizedBox(height: 8),
          _restaurantCard('Kebap Sarayı', '4.9', '30-40 dk', 0xFF22C55E),
        ],
      ),
    );
  }

  Widget _restaurantCard(String name, String rating, String time, int color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Color(color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.restaurant, color: Color(color), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFBBF24), size: 12),
                    const SizedBox(width: 3),
                    Text(rating,
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 11)),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time,
                        color: Colors.white38, size: 12),
                    const SizedBox(width: 3),
                    Text(time,
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MockTaxiScreen extends StatelessWidget {
  const MockTaxiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      child: Stack(
        children: [
          // Fake map
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1A2230),
                  const Color(0xFF0F172A),
                ],
              ),
            ),
            child: CustomPaint(
              painter: _MapGridPainter(),
              size: Size.infinite,
            ),
          ),
          // Map markers
          Positioned(
            top: 80,
            left: 60,
            child: _mapPin(const Color(0xFF3B82F6)),
          ),
          Positioned(
            top: 140,
            right: 50,
            child: _taxiIcon(),
          ),
          Positioned(
            top: 200,
            left: 90,
            child: _taxiIcon(),
          ),
          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2230),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search,
                            color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Text('Nereye gitmek istersiniz?',
                            style: GoogleFonts.inter(
                                color: Colors.white54, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _quickDest(Icons.home, 'Ev'),
                      const SizedBox(width: 8),
                      _quickDest(Icons.work, 'İş'),
                      const SizedBox(width: 8),
                      _quickDest(Icons.star, 'Favori'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPin(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
        ],
      ),
      child: const Icon(Icons.person, color: Colors.white, size: 14),
    );
  }

  Widget _taxiIcon() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFFBBF24),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
              blurRadius: 6),
        ],
      ),
      child: const Icon(Icons.local_taxi, color: Colors.black87, size: 16),
    );
  }

  Widget _quickDest(IconData icon, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white54, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;
    // Horizontal lines
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Vertical lines
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Some roads
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 4;
    canvas.drawLine(Offset(size.width * 0.3, 0),
        Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0),
        Offset(size.width * 0.7, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MockAIChatScreen extends StatelessWidget {
  const MockAIChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF00D4FF)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Text('AI Asistan',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.mic, color: Color(0xFF00D4FF), size: 20),
            ],
          ),
          const SizedBox(height: 14),
          // Chat messages
          _chatBubble('Merhaba! Bugün ne yemek istersin?', true),
          const SizedBox(height: 8),
          _chatBubble('Lahmacun yemek istiyorum', false),
          const SizedBox(height: 8),
          _chatBubble(
              'Yakınında 3 lahmacun restoranı buldum! En yakını Ustam Lahmacun, 15 dk teslimat. Sipariş vereyim mi?',
              true),
          const SizedBox(height: 8),
          _chatBubble('Evet, sipariş ver', false),
          const SizedBox(height: 8),
          _chatBubble('Siparişiniz oluşturuldu! Tahmini teslimat: 15-20 dk 🎉',
              true),
          const Spacer(),
          // Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2230),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.mic, color: Color(0xFF00D4FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Mesaj yazın...',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 12)),
                ),
                const Icon(Icons.send, color: Color(0xFF6366F1), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(String text, bool isBot) {
    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isBot
              ? const Color(0xFF1A2230)
              : const Color(0xFF6366F1).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: isBot
              ? Border.all(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.2))
              : null,
        ),
        child: Text(text,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 11, height: 1.3)),
      ),
    );
  }
}

class MockEmlakScreen extends StatelessWidget {
  const MockEmlakScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Emlak İlanları',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: ['Satılık', 'Kiralık', 'Arsa']
                .map((c) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c == 'Satılık'
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF1A2230),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(c,
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 11)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          _propertyCard('3+1 Daire, Gönyeli', '£85,000', '120 m²'),
          const SizedBox(height: 8),
          _propertyCard('2+1 Daire, Lefkoşa', '£65,000', '85 m²'),
          const SizedBox(height: 8),
          _propertyCard('Villa, Girne', '£250,000', '280 m²'),
          const SizedBox(height: 8),
          _propertyCard('1+1 Stüdyo, Mağusa', '£45,000', '55 m²'),
        ],
      ),
    );
  }

  Widget _propertyCard(String title, String price, String size) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.home_work,
                color: Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(price,
                        style: GoogleFonts.inter(
                            color: const Color(0xFF3B82F6),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(size,
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MockCarScreen extends StatelessWidget {
  const MockCarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Araç İlanları',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          _carCard('BMW 3 Serisi', '2022', '£320,000', '15,000 km'),
          const SizedBox(height: 8),
          _carCard('Mercedes C180', '2021', '£280,000', '25,000 km'),
          const SizedBox(height: 8),
          _carCard('VW Golf 8', '2023', '£250,000', '8,000 km'),
          const SizedBox(height: 8),
          _carCard('Toyota Corolla', '2022', '£180,000', '20,000 km'),
        ],
      ),
    );
  }

  Widget _carCard(String name, String year, String price, String km) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2230),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_car,
                color: Color(0xFFF43F5E), size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name  $year',
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(price,
                        style: GoogleFonts.inter(
                            color: const Color(0xFFF43F5E),
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text(km,
                        style: GoogleFonts.inter(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MockDriverScreen extends StatelessWidget {
  const MockDriverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Şoför Paneli',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Çevrimiçi',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF22C55E), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Stats
          Row(
            children: [
              _statBox('Bugün', '₺1,250', const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _statBox('Biniş', '8', const Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              _statBox('Puan', '4.9', const Color(0xFF3B82F6)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Yeni Talep',
              style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person,
                        color: Color(0xFFFBBF24), size: 16),
                    const SizedBox(width: 6),
                    Text('Mehmet A.',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('₺45',
                        style: GoogleFonts.inter(
                            color: const Color(0xFFFBBF24),
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.circle,
                        color: Color(0xFF22C55E), size: 8),
                    const SizedBox(width: 6),
                    Text('Gönyeli Çemberi',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFF43F5E), size: 12),
                    const SizedBox(width: 4),
                    Text('Dereboyu',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class MockCourierScreen extends StatelessWidget {
  const MockCourierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF101622),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Kurye Paneli',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Aktif',
                    style: GoogleFonts.inter(
                        color: const Color(0xFF22C55E), fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _statBox2('Bugün', '₺380', const Color(0xFF22C55E)),
              const SizedBox(width: 8),
              _statBox2('Teslimat', '12', const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 14),
          Text('Aktif Teslimat',
              style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.delivery_dining,
                        color: Color(0xFF22C55E), size: 18),
                    const SizedBox(width: 6),
                    Text('Sipariş #1234',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.store, color: Colors.white54, size: 14),
                    const SizedBox(width: 6),
                    Text('Cypress Kitchen',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Color(0xFFF43F5E), size: 14),
                    const SizedBox(width: 6),
                    Text('Gönyeli, Lefkoşa',
                        style: GoogleFonts.inter(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBox2(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: GoogleFonts.inter(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style:
                    GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
