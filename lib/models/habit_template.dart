import 'package:flutter/material.dart';
import 'habit.dart';

class HabitTemplateCategory {
  final String name;
  final IconData icon;
  final Color color;
  final List<HabitTemplate> templates;

  const HabitTemplateCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.templates,
  });
}

class HabitTemplate {
  final String title;
  final String description;
  final int targetDays;
  final HabitRepeatType repeatType;
  final IconData icon;

  const HabitTemplate({
    required this.title,
    required this.description,
    this.targetDays = 30,
    this.repeatType = HabitRepeatType.everyDay,
    required this.icon,
  });
}

final List<HabitTemplateCategory> defaultTemplateCategories = [
  const HabitTemplateCategory(
    name: 'Morning Routine',
    icon: Icons.wb_sunny_outlined,
    color: Color(0xFFFFB74D), // Orange
    templates: [
      HabitTemplate(
        title: 'Drink Water',
        description: 'Start the day with a glass of water',
        icon: Icons.water_drop_outlined,
      ),
      HabitTemplate(
        title: 'Make the Bed',
        description: 'A small win to start your day right',
        icon: Icons.bed_outlined,
      ),
      HabitTemplate(
        title: 'Morning Stretch',
        description: '10 minutes of light stretching',
        icon: Icons.accessibility_new,
      ),
    ],
  ),
  const HabitTemplateCategory(
    name: 'Health & Fitness',
    icon: Icons.favorite_border,
    color: Color(0xFFE57373), // Red
    templates: [
      HabitTemplate(
        title: 'Workout',
        description: 'At least 30 minutes of exercise',
        icon: Icons.fitness_center,
      ),
      HabitTemplate(
        title: 'Walk 10,000 Steps',
        description: 'Keep moving throughout the day',
        icon: Icons.directions_walk,
      ),
      HabitTemplate(
        title: 'Eat Vegetables',
        description: 'Include veggies in at least one meal',
        icon: Icons.restaurant_outlined,
      ),
    ],
  ),
  const HabitTemplateCategory(
    name: 'Productivity',
    icon: Icons.bolt_outlined,
    color: Color(0xFF64B5F6), // Blue
    templates: [
      HabitTemplate(
        title: 'Read a Book',
        description: 'Read at least 10 pages',
        icon: Icons.menu_book,
      ),
      HabitTemplate(
        title: 'Deep Work',
        description: '2 hours of focused, distraction-free work',
        icon: Icons.computer,
      ),
      HabitTemplate(
        title: 'Plan Tomorrow',
        description: 'Write down 3 main tasks for the next day',
        icon: Icons.edit_note,
      ),
    ],
  ),
  const HabitTemplateCategory(
    name: 'Mental Wellbeing',
    icon: Icons.psychology_outlined,
    color: Color(0xFFBA68C8), // Purple
    templates: [
      HabitTemplate(
        title: 'Meditate',
        description: '10 minutes of mindfulness',
        icon: Icons.self_improvement,
      ),
      HabitTemplate(
        title: 'Journaling',
        description: 'Write down your thoughts and feelings',
        icon: Icons.book_outlined,
      ),
      HabitTemplate(
        title: 'No Screens Before Bed',
        description: 'Read or relax 1 hour before sleeping',
        icon: Icons.nights_stay_outlined,
      ),
    ],
  ),
];
