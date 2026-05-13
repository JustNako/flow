import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../api/api_service.dart';

class TimeTrackingService with WidgetsBindingObserver {
  static final TimeTrackingService instance = TimeTrackingService._internal();

  TimeTrackingService._internal();

  DateTime? _sessionStartTime;
  bool _isInitialized = false;

  // Notifier so UI can update live
  final ValueNotifier<int> totalSecondsToday = ValueNotifier<int>(0);

  Timer? _activeTimer;

  Future<void> initialize() async {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;

    await _loadTodaySeconds();
    _startSession();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopSession();
    _activeTimer?.cancel();
  }

  String get _todayKey {
    final now = DateTime.now();
    return 'time_spent_${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTodaySeconds() async {
    final prefs = await SharedPreferences.getInstance();
    totalSecondsToday.value = prefs.getInt(_todayKey) ?? 0;
  }

  void _startSession() {
    _sessionStartTime = DateTime.now();
    _activeTimer?.cancel();
    // Update the ValueNotifier every minute so the UI can tick up while active
    _activeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _saveCurrentSession();
    });
  }

  Future<void> _saveCurrentSession() async {
    if (_sessionStartTime == null) return;

    final now = DateTime.now();
    final elapsedSeconds = now.difference(_sessionStartTime!).inSeconds;

    if (elapsedSeconds > 0) {
      final prefs = await SharedPreferences.getInstance();
      final currentTotal = prefs.getInt(_todayKey) ?? 0;
      final newTotal = currentTotal + elapsedSeconds;

      await prefs.setInt(_todayKey, newTotal);
      totalSecondsToday.value = newTotal;

      // Sync to backend (fire and forget)
      ApiService().updateAppUsage(
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        newTotal,
      );
    }

    // Reset start time for the next chunk
    _sessionStartTime = now;
  }

  Future<void> _stopSession() async {
    _activeTimer?.cancel();
    await _saveCurrentSession();
    _sessionStartTime = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _loadTodaySeconds().then((_) {
        _startSession();
      });
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App went to background
      _stopSession();
    }
  }
}
