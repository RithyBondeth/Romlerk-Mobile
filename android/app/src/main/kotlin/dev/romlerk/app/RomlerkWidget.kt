package dev.romlerk.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import android.app.PendingIntent
import android.content.Intent
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

            // topTasks is empty when the user hides task text or uses App
            // Lock; the widget then shows counts under the app name.
            var titleText = context.getString(R.string.widget_title)
            var countsText = context.getString(R.string.widget_nothing_due)

            if (jsonPayload != null) {
                try {
                    val obj = JSONObject(jsonPayload)
                    val overdue = obj.optInt("overdueCount", 0)
                    val today = obj.optInt("todayCount", 0)
                    if (overdue + today > 0) {
                        countsText = context.getString(R.string.widget_counts, overdue, today)
                    }

                    val topTasks = obj.optJSONArray("topTasks")
                    if (topTasks != null && topTasks.length() > 0) {
                        titleText = topTasks.getJSONObject(0).optString("title", titleText)
                    }
                } catch (e: Exception) {
                    // A malformed payload leaves the defaults showing.
                }
            }

            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_title, titleText)
            views.setTextViewText(R.id.widget_counts, countsText)
            val capture = Intent(context, MainActivity::class.java).apply {
                action = "dev.romlerk.app.CAPTURE"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            views.setOnClickPendingIntent(R.id.widget_capture, PendingIntent.getActivity(
                context, 1, capture, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
