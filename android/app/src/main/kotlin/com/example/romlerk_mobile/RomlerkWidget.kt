package com.example.romlerk_mobile

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * AppWidgetProvider for native Romlerk Today widget on Android.
 */
class RomlerkWidget : AppWidgetProvider() {

    override fn onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val jsonPayload = prefs.getString("flutter.romlerk_today_widget_json", null)

            var overdueCount = 0
            var todayCount = 0
            var topTaskTitle = "No tasks due today"

            if (jsonPayload != null) {
                try {
                    val obj = JSONObject(jsonPayload)
                    overdueCount = obj.optInt("overdueCount", 0)
                    todayCount = obj.optInt("todayCount", 0)
                    val topTasks = obj.optJSONArray("topTasks")
                    if (topTasks != null && topTasks.length() > 0) {
                        topTaskTitle = topTasks.getJSONObject(0).optString("title", topTaskTitle)
                    }
                } catch (e: Exception) {
                    // Fallback to default
                }
            }

            val views = RemoteViews(context.packageName, android.R.layout.simple_list_item_2)
            views.setTextViewText(android.R.id.text1, "Romlerk ($overdueCount overdue, $todayCount today)")
            views.setTextViewText(android.R.id.text2, topTaskTitle)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
