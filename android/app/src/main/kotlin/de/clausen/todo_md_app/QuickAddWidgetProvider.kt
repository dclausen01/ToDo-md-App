package de.clausen.todo_md_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/// Home-screen widget: a compact "＋ Neue Aufgabe" button that launches the app
/// straight into the quick-add overlay.
class QuickAddWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget)

            val intent = Intent(context, MainActivity::class.java).apply {
                action = actionQuickAdd
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            val pending = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pending)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    companion object {
        const val actionQuickAdd = "de.clausen.todo_md_app.QUICK_ADD"
    }
}
