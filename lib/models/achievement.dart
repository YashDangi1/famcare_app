import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconPath; // We can use emoji or a specific icon text for now
  final Color color;
  final int requiredStreak;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconPath,
    required this.color,
    required this.requiredStreak,
  });

  static const List<Achievement> availableBadges = [
    Achievement(
      id: 'streak_1',
      title: 'First Step',
      description: 'You logged your first dose!',
      iconPath: '🐣',
      color: Colors.pink,
      requiredStreak: 1,
    ),
    Achievement(
      id: 'streak_3',
      title: 'Getting Started',
      description: 'You maintained a 3-day streak!',
      iconPath: '🌱',
      color: Colors.green,
      requiredStreak: 3,
    ),
    Achievement(
      id: 'streak_7',
      title: 'Perfect Week',
      description: 'You completed a full 7-day streak!',
      iconPath: '🥉',
      color: Colors.orange,
      requiredStreak: 7,
    ),
    Achievement(
      id: 'streak_14',
      title: 'Two Weeks Strong',
      description: '14 days of consistent adherence!',
      iconPath: '🥈',
      color: Colors.blue,
      requiredStreak: 14,
    ),
    Achievement(
      id: 'streak_30',
      title: 'Monthly Master',
      description: 'An entire month of perfection!',
      iconPath: '🥇',
      color: Colors.amber,
      requiredStreak: 30,
    ),
    Achievement(
      id: 'streak_60',
      title: 'Double Month',
      description: '60 days straight! Incredible dedication.',
      iconPath: '💎',
      color: Colors.cyan,
      requiredStreak: 60,
    ),
    Achievement(
      id: 'streak_100',
      title: 'Century Club',
      description: '100 days streak! You are an inspiration.',
      iconPath: '👑',
      color: Colors.purple,
      requiredStreak: 100,
    ),
    Achievement(
      id: 'streak_365',
      title: 'A Year of Health',
      description: '365 days of continuous streaks!',
      iconPath: '🔥',
      color: Colors.redAccent,
      requiredStreak: 365,
    ),
  ];
}
