class Customer360 {
  final Map<String, dynamic> user;
  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> taxiRides;
  final List<Map<String, dynamic>> rentalBookings;
  final List<Map<String, dynamic>> properties;
  final List<Map<String, dynamic>> carListings;
  final List<Map<String, dynamic>> reviews;
  final List<Map<String, dynamic>> supportTickets;
  final double totalSpent;
  final int orderCount;
  final int rideCount;
  final int bookingCount;
  final int reviewCount;
  final int ticketCount;

  Customer360({
    required this.user,
    required this.orders,
    required this.taxiRides,
    required this.rentalBookings,
    required this.properties,
    required this.carListings,
    required this.reviews,
    required this.supportTickets,
    required this.totalSpent,
    required this.orderCount,
    required this.rideCount,
    required this.bookingCount,
    required this.reviewCount,
    required this.ticketCount,
  });

  factory Customer360.fromJson(Map<String, dynamic> json) {
    return Customer360(
      user: json['user'] as Map<String, dynamic>? ?? {},
      orders: _toList(json['orders']),
      taxiRides: _toList(json['taxi_rides']),
      rentalBookings: _toList(json['rental_bookings']),
      properties: _toList(json['properties']),
      carListings: _toList(json['car_listings']),
      reviews: _toList(json['reviews']),
      supportTickets: _toList(json['support_tickets']),
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      orderCount: json['order_count'] as int? ?? 0,
      rideCount: json['ride_count'] as int? ?? 0,
      bookingCount: json['booking_count'] as int? ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      ticketCount: json['ticket_count'] as int? ?? 0,
    );
  }

  static List<Map<String, dynamic>> _toList(dynamic data) {
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  String get fullName => '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
  String? get email => user['email'] as String?;
  String? get phone => user['phone'] as String?;
  String? get avatarUrl => user['avatar_url'] as String?;
  String? get membershipType => user['membership_type'] as String?;
  DateTime? get createdAt => user['created_at'] != null ? DateTime.parse(user['created_at'] as String) : null;
  int get loyaltyPoints => user['loyalty_points'] as int? ?? 0;
  double get averageRating => (user['average_rating'] ?? 0).toDouble();
}
