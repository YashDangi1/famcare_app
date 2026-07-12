import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/achievement.dart';

class AchievementDialog extends StatelessWidget {
  final Achievement achievement;

  const AchievementDialog({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: achievement.color.withOpacity(0.3),
                blurRadius: 24,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge Icon with Shimmer and Bounce
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: achievement.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: achievement.color.withOpacity(0.5), width: 4),
                ),
                child: Center(
                  child: Text(
                    achievement.iconPath,
                    style: const TextStyle(fontSize: 48),
                  ),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.8))
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.easeOutBack)
                  .then()
                  .shake(hz: 4, curve: Curves.easeInOutCubic, duration: 500.ms),
              
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Achievement Unlocked!',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.5),
              
              const SizedBox(height: 8),
              
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: achievement.color,
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
              
              const SizedBox(height: 12),
              
              // Description
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.5),
              
              const SizedBox(height: 32),
              
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: achievement.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Awesome!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms).scale(curve: Curves.easeOutBack),
            ],
          ),
        ),
      ),
    );
  }
}
