class SlaCalculator {
  static DateTime calculateSlaDue(String priority) {
    final now = DateTime.now();
    switch (priority) {
      case 'urgent':
        return now.add(const Duration(hours: 4));
      case 'high':
        return now.add(const Duration(hours: 8));
      case 'normal':
        return now.add(const Duration(hours: 24));
      case 'low':
        return now.add(const Duration(hours: 48));
      default:
        return now.add(const Duration(hours: 24));
    }
  }

  static Duration getFirstResponseTarget(String priority) {
    switch (priority) {
      case 'urgent':
        return const Duration(minutes: 15);
      case 'high':
        return const Duration(minutes: 30);
      case 'normal':
        return const Duration(hours: 2);
      case 'low':
        return const Duration(hours: 4);
      default:
        return const Duration(hours: 2);
    }
  }

  static String formatRemaining(DateTime? slaDueAt) {
    if (slaDueAt == null) return '-';
    final diff = slaDueAt.difference(DateTime.now());
    if (diff.isNegative) {
      final overdue = diff.abs();
      if (overdue.inHours > 0) return '-${overdue.inHours}s ${overdue.inMinutes % 60}dk';
      return '-${overdue.inMinutes}dk';
    }
    if (diff.inHours > 0) return '${diff.inHours}s ${diff.inMinutes % 60}dk';
    return '${diff.inMinutes}dk';
  }

  static bool isBreached(DateTime? slaDueAt) {
    if (slaDueAt == null) return false;
    return DateTime.now().isAfter(slaDueAt);
  }
}
