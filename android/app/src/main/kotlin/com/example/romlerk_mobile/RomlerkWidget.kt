package com.example.romlerk_mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

class RomlerkWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val jsonPayload = widgetData.getString("today_payload", null)

            var titleText = "Romlerk"
            var countsText = "No tasks"

            if (jsonPayload != null) {
                try {
                    val obj = JSONObject(jsonPayload)
                    val overdue = obj.optInt("overdueCount", 0)
                    val today = obj.optInt("todayCount", 0)
                    countsText = "$overdue overdue, $today today"
                    
                    val topTasks = obj.optJSONArray("topTasks")
                    if (topTasks != null && topTasks.length() > 0) {
                        titleText = topTasks.getJSONObject(0).optString("title", titleText)
                    }
                } catch (e: Exception) {
                    // Ignore parsing errors
                }
            }

            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_title, titleText)
            views.setTextViewText(R.id.widget_counts, countsText)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
