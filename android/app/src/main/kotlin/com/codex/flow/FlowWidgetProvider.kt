package com.codex.flow

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class FlowWidgetProvider : HomeWidgetProvider() {

    // Direct resource ID references to avoid getIdentifier() crashes
    private val rowIds     = intArrayOf(R.id.habit_row_0,      R.id.habit_row_1,      R.id.habit_row_2,      R.id.habit_row_3)
    private val checkIds   = intArrayOf(R.id.habit_checkbox_0, R.id.habit_checkbox_1, R.id.habit_checkbox_2, R.id.habit_checkbox_3)
    private val titleIds   = intArrayOf(R.id.habit_title_0,    R.id.habit_title_1,    R.id.habit_title_2,    R.id.habit_title_3)
    private val timeIds    = intArrayOf(R.id.habit_time_0,     R.id.habit_time_1,     R.id.habit_time_2,     R.id.habit_time_3)
    private val loadingIds = intArrayOf(R.id.habit_loading_0,  R.id.habit_loading_1,  R.id.habit_loading_2,  R.id.habit_loading_3)

    private fun getSafeInt(prefs: SharedPreferences, key: String, default: Int): Int {
        try {
            val strValue = prefs.getString(key, null)
            if (strValue != null) {
                return strValue.toIntOrNull() ?: default
            }
        } catch (e: Exception) {}
        try {
            return prefs.getInt(key, default)
        } catch (e: Exception) {}
        try {
            return prefs.getLong(key, default.toLong()).toInt()
        } catch (e: Exception) {}
        return default
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d("FlowWidget", "onUpdate called for ${appWidgetIds.size} widgets")
        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        val currentDateStr = dateFormat.format(Date())

        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout)

                // Check if user is logged in
                val isLoggedIn = widgetData.getBoolean("is_logged_in", false)
                Log.d("FlowWidget", "Widget ID $widgetId: isLoggedIn = $isLoggedIn")

                if (!isLoggedIn) {
                    views.setViewVisibility(R.id.widget_auth_text, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_progress_text, View.GONE)
                    views.setViewVisibility(R.id.widget_empty_text, View.GONE)
                    for (i in 0 until 4) {
                        views.setViewVisibility(rowIds[i], View.GONE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_auth_text, View.GONE)

                    // Check if day has changed since last widget sync
                    val widgetLastUpdateDate = widgetData.getString("widget_last_update_date", "") ?: ""
                    val isNewDay = widgetLastUpdateDate.isNotEmpty() && widgetLastUpdateDate != currentDateStr
                    Log.d("FlowWidget", "Widget ID $widgetId: isNewDay = $isNewDay")

                    // Load Overall Progress
                    val totalToday = getSafeInt(widgetData, "total_today", 0)
                    val completedToday = if (isNewDay) 0 else getSafeInt(widgetData, "completed_today", 0)
                    views.setTextViewText(R.id.widget_progress_text, "$completedToday/$totalToday done")

                    // Open App on root tap safely using custom PendingIntent
                    val rootIntent = Intent(context, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                    }
                    val rootFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    val rootPendingIntent = PendingIntent.getActivity(
                        context,
                        0,
                        rootIntent,
                        rootFlags
                    )
                    views.setOnClickPendingIntent(R.id.widget_root, rootPendingIntent)

                    var hasAnyHabit = false

                    // Populate 4 habits using direct R.id references
                    for (i in 0 until 4) {
                        val habitId        = widgetData.getString("habit_${i}_id",        "") ?: ""
                        val habitTitle     = widgetData.getString("habit_${i}_title",      "") ?: ""
                        val habitCompleted = if (isNewDay) false else widgetData.getBoolean("habit_${i}_completed", false)
                        val habitTime      = widgetData.getString("habit_${i}_time",       "") ?: ""
                        val isLoading      = widgetData.getBoolean("habit_${i}_loading",   false)

                        Log.d("FlowWidget", "  Slot $i: id='$habitId', completed=$habitCompleted, loading=$isLoading")

                        if (habitId.isEmpty() || habitTitle.isEmpty()) {
                            views.setViewVisibility(rowIds[i], View.GONE)
                        } else {
                            hasAnyHabit = true
                            views.setViewVisibility(rowIds[i], View.VISIBLE)
                            views.setTextViewText(titleIds[i], habitTitle)
                            views.setTextColor(
                                titleIds[i],
                                if (habitCompleted || isLoading) Color.parseColor("#8E94A6")
                                else Color.parseColor("#E3E5EB")
                            )

                            if (isLoading) {
                                // Show spinner, hide checkbox
                                views.setViewVisibility(checkIds[i],   View.GONE)
                                views.setViewVisibility(loadingIds[i], View.VISIBLE)
                            } else {
                                // Show checkbox in correct state, hide spinner
                                views.setViewVisibility(loadingIds[i], View.GONE)
                                views.setViewVisibility(checkIds[i],   View.VISIBLE)
                                views.setImageViewResource(
                                    checkIds[i],
                                    if (habitCompleted) R.drawable.ic_widget_checkbox_checked
                                    else R.drawable.ic_widget_checkbox_unchecked
                                )
                            }

                            // Show/hide target time
                            if (habitTime.isEmpty()) {
                                views.setViewVisibility(timeIds[i], View.GONE)
                            } else {
                                views.setViewVisibility(timeIds[i], View.VISIBLE)
                                views.setTextViewText(timeIds[i], habitTime)
                            }

                            // 1. Click on Row text → opens the full app
                            val intent = Intent(context, MainActivity::class.java).apply {
                                action = Intent.ACTION_VIEW
                                data = Uri.parse("flowWidget://completehabit?id=${Uri.encode(habitId)}")
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                            }
                            val launchFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            } else {
                                PendingIntent.FLAG_UPDATE_CURRENT
                            }
                            val tapPendingIntent = PendingIntent.getActivity(
                                context,
                                habitId.hashCode(),
                                intent,
                                launchFlags
                            )
                            views.setOnClickPendingIntent(rowIds[i], tapPendingIntent)

                            // 2. Click on Checkbox → background toggle (NO app launch)
                            val backgroundIntent = Intent(context, es.antonborri.home_widget.HomeWidgetBackgroundReceiver::class.java).apply {
                                action = "es.antonborri.home_widget.action.BACKGROUND"
                                data = Uri.parse("flowWidget://completehabit?id=${Uri.encode(habitId)}")
                            }
                            val backgroundFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                            } else {
                                PendingIntent.FLAG_UPDATE_CURRENT
                            }
                            val backgroundPendingIntent = PendingIntent.getBroadcast(
                                context,
                                habitId.hashCode() + 1,
                                backgroundIntent,
                                backgroundFlags
                            )
                            views.setOnClickPendingIntent(checkIds[i], backgroundPendingIntent)
                        }
                    }

                    // Show empty/loading state
                    if (!hasAnyHabit) {
                        views.setViewVisibility(R.id.widget_empty_text,    View.VISIBLE)
                        views.setViewVisibility(R.id.widget_progress_text, View.GONE)
                    } else {
                        views.setViewVisibility(R.id.widget_empty_text,    View.GONE)
                        views.setViewVisibility(R.id.widget_progress_text, View.VISIBLE)
                    }
                }

                appWidgetManager.updateAppWidget(widgetId, views)
                Log.d("FlowWidget", "Widget ID $widgetId: updated successfully")
            } catch (e: Exception) {
                Log.e("FlowWidget", "Widget ID $widgetId: Error in onUpdate", e)
            }
        }
        
        // Schedule the next update at midnight exactly
        scheduleMidnightUpdate(context)
    }

    private fun scheduleMidnightUpdate(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val appWidgetIds = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, FlowWidgetProvider::class.java)
        )
        if (appWidgetIds.isEmpty()) return

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        val intent = Intent(context, FlowWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = java.util.Calendar.getInstance().apply {
            timeInMillis = System.currentTimeMillis()
            add(java.util.Calendar.DAY_OF_YEAR, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 1)
        }

        Log.d("FlowWidget", "Scheduling midnight update for ${calendar.time}")

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            } else {
                // If permission is not granted, fallback to inexact scheduling
                alarmManager.set(android.app.AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(android.app.AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        } else {
            alarmManager.setExact(android.app.AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        }
    }
}
