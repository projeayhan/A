/// Profanity filter utility for Turkish content moderation
/// Filters inappropriate language from user-generated content
library;

class ProfanityFilter {
  // Turkish profanity words list (censored for code readability)
  // This list should be expanded based on your needs
  static final List<String> _badWords = [
    // Common Turkish profanity (abbreviated/masked)
    'amk', 'aq', 'mk', 'mq',
    'oç', 'oc', 'orospu', 'oruspu', 'orsp',
    'piç', 'pic', 'pič',
    'sik', 'sık', 's1k', 'siK',
    'yarak', 'yarra', 'yarrak',
    'göt', 'got', 'g0t',
    'mal', 'gerizekalı', 'gerizekali', 'aptal', 'salak',
    'ibne', 'top', 'puşt', 'pust',
    'kahpe', 'kaltak',
    'siktir', 's1kt1r', 'sıktır',
    'hassiktir', 'hass1kt1r',
    'bok', 'b0k',
    'pezevenk', 'pzvnk',
    'dangalak', 'hıyar', 'hiyar',
    'gavat', 'g@vat',
    'amcık', 'amcik', 'amc1k',
    'dalyarak', 'dalyarrak',
    'sokuk', 'şerefsiz', 'serefsiz',
    'namussuz', 'alçak', 'alcak',
    'haysiyetsiz', 'karaktersiz',
    'yavşak', 'yavsak',
    // English profanity that might be used
    'fuck', 'f*ck', 'fck', 'fuk',
    'shit', 'sh1t', 'sh*t',
    'ass', r'a$$', '@ss',
    'bitch', 'b1tch', 'b*tch',
    'damn', 'crap',
    'bastard', 'idiot', 'moron',
  ];

  // Words that are borderline but might need review
  static final List<String> _warningWords = [
    'berbat',
    'rezalet',
    'felaket',
    'iğrenç',
    'igrenç',
    'korkunç',
    'korkunc',
    'kötü',
    'kotu',
    'saçma',
    'sacma',
    'saçmalık',
    'sacmalik',
  ];

  /// Check if text contains profanity
  /// Returns true if profanity is found
  static bool containsProfanity(String text) {
    if (text.isEmpty) return false;

    final normalizedText = _normalizeText(text);

    for (final word in _badWords) {
      final normalizedWord = _normalizeText(word);
      // Check for word boundaries to avoid false positives
      final pattern = RegExp(
        r'(^|\s|[.,!?;:])' + RegExp.escape(normalizedWord) + r'($|\s|[.,!?;:])',
        caseSensitive: false,
      );

      if (pattern.hasMatch(normalizedText)) {
        return true;
      }

      // Also check if the word is contained without boundaries (for concatenated words)
      if (normalizedText.contains(normalizedWord)) {
        return true;
      }
    }

    return false;
  }

  /// Get list of found profanity words for logging/moderation
  static List<String> findProfanity(String text) {
    if (text.isEmpty) return [];

    final normalizedText = _normalizeText(text);
    final found = <String>[];

    for (final word in _badWords) {
      final normalizedWord = _normalizeText(word);
      if (normalizedText.contains(normalizedWord)) {
        found.add(word);
      }
    }

    return found;
  }

  /// Check if text contains warning words (borderline content)
  static bool containsWarningWords(String text) {
    if (text.isEmpty) return false;

    final normalizedText = _normalizeText(text);

    for (final word in _warningWords) {
      if (normalizedText.contains(_normalizeText(word))) {
        return true;
      }
    }

    return false;
  }

  /// Censor profanity in text by replacing with asterisks
  static String censorText(String text) {
    if (text.isEmpty) return text;

    String result = text;

    for (final word in _badWords) {
      final pattern = RegExp(RegExp.escape(word), caseSensitive: false);

      result = result.replaceAllMapped(pattern, (match) {
        final matchedWord = match.group(0)!;
        if (matchedWord.length <= 2) {
          return '*' * matchedWord.length;
        }
        return matchedWord[0] +
            '*' * (matchedWord.length - 2) +
            matchedWord[matchedWord.length - 1];
      });
    }

    return result;
  }

  /// Normalize text for comparison
  /// Handles common character substitutions used to bypass filters
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        // Turkish character normalization
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        // Common substitutions
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('@', 'a')
        .replaceAll('\$', 's')
        .replaceAll('!', 'i')
        // Remove repeated characters (e.g., "fuuuck" -> "fuck")
        .replaceAll(RegExp(r'(.)\1{2,}'), r'$1$1')
        // Remove spaces between characters (e.g., "f u c k" -> "fuck")
        .replaceAll(' ', '');
  }

  /// Validate text and return error message if inappropriate
  /// Returns null if text is clean, error message otherwise
  static String? validate(String text, {String fieldName = 'Metin'}) {
    if (containsProfanity(text)) {
      return '$fieldName uygunsuz ifadeler içeriyor. Lütfen düzenleyin.';
    }
    return null;
  }

  /// Check if text is appropriate for public display
  static ValidationResult validateForDisplay(String text) {
    if (text.isEmpty) {
      return ValidationResult(isValid: true);
    }

    if (containsProfanity(text)) {
      return ValidationResult(
        isValid: false,
        errorMessage:
            'Mesajınız uygunsuz ifadeler içeriyor. Lütfen düzenleyin.',
        severity: ValidationSeverity.blocked,
      );
    }

    if (containsWarningWords(text)) {
      return ValidationResult(
        isValid: true,
        warningMessage:
            'Mesajınız olumsuz ifadeler içeriyor. Yine de göndermek istiyor musunuz?',
        severity: ValidationSeverity.warning,
      );
    }

    return ValidationResult(isValid: true);
  }
}

enum ValidationSeverity { none, warning, blocked }

class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? warningMessage;
  final ValidationSeverity severity;

  ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.warningMessage,
    this.severity = ValidationSeverity.none,
  });
}
