import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit.dart';
import '../api/habit_api_service.dart';
import '../services/auth_service.dart';

@pragma('vm:entry-point')
class WidgetService {
  static const String androidWidgetName = 'FlowWidgetProvider';
  static const String appGroupId = 'group.com.codex.flow';

  /// Syncs top uncompleted habits to the native widget storage.
  /// Safe to call from anywhere — silently skips if user is not authenticated.
  /// You can optionally pass pre-loaded [habits] to avoid fetching them again.
  static Future<void> updateWidget({List<Habit>? habits}) async {
    try {
      // Set AppGroup on both platforms so SharedPreferences names are perfectly aligned
      await HomeWidget.setAppGroupId(appGroupId);

      // Don't attempt API call if user is not logged in
      final token = await AuthService.instance.getToken();
      if (token == null) {
        debugPrint('[WidgetService] Skipping update — user not authenticated.');
        await HomeWidget.saveWidgetData<bool>('is_logged_in', false);
        await HomeWidget.updateWidget(name: androidWidgetName);
        return;
      }

      await HomeWidget.saveWidgetData<bool>('is_logged_in', true);

      // Use pre-loaded habits if available, otherwise fetch from api
      List<Habit> list = habits ?? [];
      if (habits == null) {
        final api = HabitApiService.instance;
        list = await api.getHabits();
      }

      final today = DateTime.now();

      final todayHabits = list.where((h) => h.isScheduledFor(today)).toList();
      final incomplete = todayHabits.where((h) => !h.isCompletedToday).toList();
      final complete = todayHabits.where((h) => h.isCompletedToday).toList();

      // Show up to 4 habits: incomplete first, then fill with completed ones
      final displayHabits = <Habit>[...incomplete, ...complete].take(4).toList();

      // Clear old slots
      for (int i = 0; i < 4; i++) {
        await HomeWidget.saveWidgetData<String>('habit_${i}_id', '');
        await HomeWidget.saveWidgetData<String>('habit_${i}_title', '');
        await HomeWidget.saveWidgetData<bool>('habit_${i}_completed', false);
      }

      // Write new data
      for (int i = 0; i < displayHabits.length; i++) {
        final habit = displayHabits[i];
        await HomeWidget.saveWidgetData<String>('habit_${i}_id', habit.id ?? '');
        await HomeWidget.saveWidgetData<String>('habit_${i}_title', habit.title);
        await HomeWidget.saveWidgetData<bool>('habit_${i}_completed', habit.isCompletedToday);
      }

      // Write totals for progress line as Strings to prevent Kotlin ClassCastExceptions
      await HomeWidget.saveWidgetData<String>('total_today', todayHabits.length.toString());
      await HomeWidget.saveWidgetData<String>('completed_today', complete.length.toString());

      // Signal Android to redraw the widget
      await HomeWidget.updateWidget(name: androidWidgetName);

      debugPrint('[WidgetService] Widget updated: ${incomplete.length} incomplete, ${complete.length} complete today.');
    } catch (e) {
      debugPrint('[WidgetService] updateWidget failed: $e');
    }
  }

  /// Called natively in background when user taps a habit checkbox on the widget.
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    debugPrint('[WidgetService] backgroundCallback: $uri');
    if (uri?.host == 'completehabit') {
      final habitId = uri?.queryParameters['id'];
      if (habitId != null && habitId.isNotEmpty) {
        try {
          final api = HabitApiService.instance;
          await api.toggleHabit(habitId);
          await updateWidget(); // refresh widget after toggling
        } catch (e) {
          debugPrint('[WidgetService] Background toggle failed: $e');
        }
      }
    }
  }
}
