class BondOcrParser {
  static const denominations = [100, 200, 750, 1500, 25000, 40000];

  static int? detectDenomination(String text) {
    final normalized = text.toUpperCase().replaceAll(',', '');
    final patterns = <int, List<RegExp>>{
      25000: [
        RegExp(r'\b25000\b'),
        RegExp(r'\bTWENTY[\s-]+FIVE[\s-]+THOUSAND\b'),
      ],
      40000: [RegExp(r'\b40000\b'), RegExp(r'\bFORTY[\s-]+THOUSAND\b')],
      1500: [
        RegExp(r'\b1500\b'),
        RegExp(r'\bONE\s+THOUSAND\s+FIVE\s+HUNDRED\b'),
        RegExp(r'\bFIFTEEN\s+HUNDRED\b'),
      ],
      750: [
        RegExp(r'\b750\b'),
        RegExp(r'\bSEVEN\s+HUNDRED(?:\s+AND)?\s+FIFTY\b'),
      ],
      200: [RegExp(r'\b200\b'), RegExp(r'\bTWO\s+HUNDRED\b')],
      100: [RegExp(r'\b100\b'), RegExp(r'\bONE\s+HUNDRED\b')],
    };

    for (final entry in patterns.entries) {
      if (entry.value.any((pattern) => pattern.hasMatch(normalized))) {
        return entry.key;
      }
    }
    return null;
  }

  static List<String> findBondNumbers(String text) {
    final lines = text.split('\n');
    final numbers = <String>{};

    final stampKeywords = RegExp(
      r'\b(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC|SBP|BSD|20[1-2][0-9])\b',
      caseSensitive: false,
    );

    final numberPattern = RegExp(
      r'(^|[^A-Z0-9])([A-Z]{1,4})?([0-9OQDIL|]{6})(?=$|[^A-Z0-9])',
      caseSensitive: false,
    );

    for (final line in lines) {
      if (stampKeywords.hasMatch(line)) {
        continue;
      }

      for (final match in numberPattern.allMatches(line.toUpperCase())) {
        final digitsRaw = match.group(3)!;
        final digitsPart = digitsRaw
            .replaceAll(RegExp(r'[OQD]'), '0')
            .replaceAll(RegExp(r'[IL|]'), '1');
        if (digitsPart.length == 6 && RegExp(r'^\d{6}$').hasMatch(digitsPart)) {
          numbers.add(digitsPart);
        }
      }
    }

    return numbers.toList();
  }
}
