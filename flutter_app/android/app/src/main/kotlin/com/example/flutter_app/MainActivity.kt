package com.example.flutter_app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channelName = "streamed/external_player"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openVideo" -> {
                    val url = call.argument<String>("url")
                    val title = call.argument<String>("title") ?: "Open stream"
                    if (url.isNullOrBlank()) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    result.success(openVideoUrl(url, title))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openVideoUrl(url: String, title: String): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(url), "video/*")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra(Intent.EXTRA_TITLE, title)
            }
            startActivity(Intent.createChooser(intent, "Open with"))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }
}
