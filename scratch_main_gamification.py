import os

file_path = r"c:\Projects\famcare_app\lib\main_app_shell.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

import_gamification = "import 'services/gamification_service.dart';\n"
if import_gamification not in content:
    content = content.replace("import 'widgets/achievement_dialog.dart';", "import 'widgets/achievement_dialog.dart';\n" + import_gamification)

old_check = """  Future<void> _checkStreakCelebration(int streak) async {
    if (streak == 0) return;
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    if (!milestones.contains(streak)) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCelebrated = prefs.getInt('last_celebrated_streak') ?? 0;
    
    if (streak > lastCelebrated) {
      await prefs.setInt('last_celebrated_streak', streak);
      
      // Find the achievement
      Achievement? unlockedBadge;
      for (final badge in Achievement.availableBadges) {
        if (badge.requiredStreak == streak) {
          unlockedBadge = badge;
          break;
        }
      }

      if (unlockedBadge != null) {
        // Save to SharedPreferences
        List<String> unlockedIds = prefs.getStringList('unlocked_achievements') ?? [];
        if (!unlockedIds.contains(unlockedBadge.id)) {
          unlockedIds.add(unlockedBadge.id);
          await prefs.setStringList('unlocked_achievements', unlockedIds);
        }

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AchievementDialog(achievement: unlockedBadge!),
          );
        }
      }
    }
  }"""

new_check = """  Future<void> _checkStreakCelebration(int streak) async {
    if (streak == 0) return;
    final milestones = [3, 7, 14, 30, 60, 100, 365];
    if (!milestones.contains(streak)) return;

    final prefs = await SharedPreferences.getInstance();
    final lastCelebrated = prefs.getInt('last_celebrated_streak') ?? 0;
    
    if (streak > lastCelebrated) {
      await prefs.setInt('last_celebrated_streak', streak);
      
      // Find the achievement
      Achievement? unlockedBadge;
      for (final badge in Achievement.availableBadges) {
        if (badge.requiredStreak == streak) {
          unlockedBadge = badge;
          break;
        }
      }

      if (unlockedBadge != null) {
        // Unlock via GamificationService
        final unlocked = await GamificationService.instance.unlockAchievement(unlockedBadge.id);

        if (unlocked && mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AchievementDialog(achievement: unlockedBadge!),
          );
        }
      }
    }
  }"""

content = content.replace(old_check, new_check)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
