import os

file_path = r"c:\Projects\famcare_app\lib\screens\achievements_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

import_gamification = "import '../services/gamification_service.dart';\n"
if import_gamification not in content:
    content = content.replace("import '../models/achievement.dart';", "import '../models/achievement.dart';\n" + import_gamification)

old_load = """  Future<void> _loadUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _unlockedIds = prefs.getStringList('unlocked_achievements') ?? [];
      _isLoading = false;
    });
  }"""

new_load = """  Future<void> _loadUnlockedAchievements() async {
    final ids = await GamificationService.instance.getUnlockedAchievements();
    if (mounted) {
      setState(() {
        _unlockedIds = ids;
        _isLoading = false;
      });
    }
  }"""

content = content.replace(old_load, new_load)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
