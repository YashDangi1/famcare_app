import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../services/gamification_service.dart';


class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<String> _unlockedIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUnlockedAchievements();
  }

  Future<void> _loadUnlockedAchievements() async {
    final ids = await GamificationService.instance.getUnlockedAchievements();
    if (mounted) {
      setState(() {
        _unlockedIds = ids;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Badges',
          style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: Achievement.availableBadges.length,
              itemBuilder: (context, index) {
                final badge = Achievement.availableBadges[index];
                final isUnlocked = _unlockedIds.contains(badge.id);

                return _buildBadgeCard(badge, isUnlocked, index);
              },
            ),
    );
  }

  Widget _buildBadgeCard(Achievement badge, bool isUnlocked, int index) {
    final bgColor = isUnlocked ? Colors.white : Colors.grey.shade100;
    final borderColor = isUnlocked ? badge.color.withOpacity(0.3) : Colors.grey.shade300;
    final iconColor = isUnlocked ? badge.color.withOpacity(0.1) : Colors.grey.shade200;

    Widget card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: badge.color.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isUnlocked
                  ? Text(badge.iconPath, style: const TextStyle(fontSize: 28))
                  : Icon(LucideIcons.lock, color: Colors.grey.shade400, size: 28),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            badge.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: isUnlocked ? const Color(0xFF1E293B) : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isUnlocked ? 'Unlocked!' : 'Requires ${badge.requiredStreak} days',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isUnlocked ? badge.color : Colors.grey.shade400,
              fontWeight: isUnlocked ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );

    if (isUnlocked) {
      card = card.animate().fade(delay: (index * 100).ms).scale(curve: Curves.easeOutBack);
    }

    return card;
  }
}
