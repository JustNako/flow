import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/habit.dart';
import '../api/habit_api_service.dart';
import '../services/auth_service.dart';
import '../services/local_database.dart';

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

      int compareTimes(Habit a, Habit b) {
        if (a.timeOfDay != null && b.timeOfDay != null) {
          return a.timeOfDay!.compareTo(b.timeOfDay!);
        } else if (a.timeOfDay != null) {
          return -1;
        } else if (b.timeOfDay != null) {
          return 1;
        }
        return 0;
      }

      final incomplete = todayHabits.where((h) => !h.isCompletedToday).toList()..sort(compareTimes);
      final complete = todayHabits.where((h) => h.isCompletedToday).toList()..sort(compareTimes);

      // Show up to 4 habits: incomplete first, then fill with completed ones (both sorted earliest-first)
      final displayHabits = <Habit>[...incomplete, ...complete].take(4).toList();

      // Clear old slots (also clear any stuck loading states)
      for (int i = 0; i < 4; i++) {
        await HomeWidget.saveWidgetData<String>('habit_${i}_id', '');
        await HomeWidget.saveWidgetData<String>('habit_${i}_title', '');
        await HomeWidget.saveWidgetData<bool>('habit_${i}_completed', false);
        await HomeWidget.saveWidgetData<String>('habit_${i}_time', '');
        await HomeWidget.saveWidgetData<bool>('habit_${i}_loading', false);
      }

      // Write new data
      for (int i = 0; i < displayHabits.length; i++) {
        final habit = displayHabits[i];
        await HomeWidget.saveWidgetData<String>('habit_${i}_id', habit.id ?? '');
        await HomeWidget.saveWidgetData<String>('habit_${i}_title', habit.title);
        await HomeWidget.saveWidgetData<bool>('habit_${i}_completed', habit.isCompletedToday);
        await HomeWidget.saveWidgetData<String>('habit_${i}_time', habit.timeOfDay ?? '');
      }

      // Write totals for progress line as Strings to prevent Kotlin ClassCastExceptions
      await HomeWidget.saveWidgetData<String>('total_today', todayHabits.length.toString());
      await HomeWidget.saveWidgetData<String>('completed_today', complete.length.toString());

      // Save date of this update to reset completion status on new days
      final dateStr = today.toIso8601String().substring(0, 10);
      await HomeWidget.saveWidgetData<String>('widget_last_update_date', dateStr);

      // Signal Android to redraw the widget
      await HomeWidget.updateWidget(name: androidWidgetName);

      debugPrint('[WidgetService] Widget updated: ${incomplete.length} incomplete, ${complete.length} complete today. Date: $dateStr');
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
          await HomeWidget.setAppGroupId(appGroupId);

          // Initialize DB before any database operations in background isolate
          await LocalDatabase.instance.init();

          // Find which slot this habit occupies so we can set its loading state
          int? loadingSlot;
          for (int i = 0; i < 4; i++) {
            final slotId = await HomeWidget.getWidgetData<String>('habit_${i}_id') ?? '';
            if (slotId == habitId) {
              loadingSlot = i;
              break;
            }
          }

          // Step 1: Show spinner immediately — before the API call
          if (loadingSlot != null) {
            await HomeWidget.saveWidgetData<bool>('habit_${loadingSlot}_loading', true);
            await HomeWidget.updateWidget(name: androidWidgetName);
          }

          // Step 2: Call API
          final api = HabitApiService.instance;
          await api.toggleHabit(habitId);

          // Step 3: Clear loading flag and do a full widget refresh
          if (loadingSlot != null) {
            await HomeWidget.saveWidgetData<bool>('habit_${loadingSlot}_loading', false);
          }
          await updateWidget();
        } catch (e) {
          debugPrint('[WidgetService] Background toggle failed: $e');
          // On error: clear all loading states to avoid stuck spinners
          for (int i = 0; i < 4; i++) {
            await HomeWidget.saveWidgetData<bool>('habit_${i}_loading', false);
          }
          await HomeWidget.updateWidget(name: androidWidgetName);
        }
      }
    }
  }
}
