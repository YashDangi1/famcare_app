class SlotValidation {
  static List<int> parseTime(String time24) {
    final parts = time24.split(':');
    return [int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0];
  }

  static int minutesOf(String time24) {
    final parts = parseTime(time24);
    return parts[0] * 60 + parts[1];
  }

  static String capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  /// Validates slot configuration.
  /// Returns error message String if invalid, or null if valid.
  static String? validateSlotTimes(Map<String, dynamic> slotPrefs, int retryInterval) {
    final times = {
      'morning': [
        slotPrefs['morning_start']?.toString() ?? '08:00',
        slotPrefs['morning_end']?.toString() ?? '09:30',
      ],
      'afternoon': [
        slotPrefs['afternoon_start']?.toString() ?? '12:00',
        slotPrefs['afternoon_end']?.toString() ?? '14:00',
      ],
      'evening': [
        slotPrefs['evening_start']?.toString() ?? '16:00',
        slotPrefs['evening_end']?.toString() ?? '18:00',
      ],
      'night': [
        slotPrefs['night_start']?.toString() ?? '21:00',
        slotPrefs['night_end']?.toString() ?? '22:30',
      ],
    };

    var shortestRange = 24 * 60;
    for (final entry in times.entries) {
      final start = minutesOf(entry.value[0]);
      var end = minutesOf(entry.value[1]);
      if (entry.key == 'night' && end <= start) {
        end += 24 * 60; // night crossing midnight
      } else if (end <= start) {
        return '${capitalize(entry.key)} end must be after start time';
      }
      shortestRange = shortestRange < end - start ? shortestRange : end - start;
    }

    // Check overlap between sequential slots.
    // Fixed: Included 'night' in the slots array to ensure evening -> night overlaps are checked as well!
    final slots = ['morning', 'afternoon', 'evening', 'night'];
    for (int i = 0; i < slots.length - 1; i++) {
      final currentEnd = minutesOf(times[slots[i]]![1]);
      final nextStart = minutesOf(times[slots[i + 1]]![0]);
      if (nextStart < currentEnd) {
        return '${capitalize(slots[i + 1])} start must be after ${slots[i]} end';
      }
    }

    // Cross-midnight check: night end vs morning start
    final nightStart = minutesOf(times['night']![0]);
    var nightEnd = minutesOf(times['night']![1]);
    if (nightEnd <= nightStart) nightEnd += 24 * 60; // crosses midnight
    final morningStart = minutesOf(times['morning']![0]);
    if (nightEnd > 24 * 60 && (nightEnd - 24 * 60) > morningStart) {
      return 'Night end overlaps with Morning start — adjust night end or morning start';
    }

    if (retryInterval >= shortestRange) {
      return 'Retry interval (${retryInterval}min) must be less than slot range (${shortestRange}min)';
    }

    return null;
  }
}
