package com.bsmart.app

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Explicit registration avoids release-only auto-registration misses.
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        val contentView = findViewById<View>(android.R.id.content)
        if (contentView is ViewGroup) {
            contentView.isMotionEventSplittingEnabled = false
        }
    }

    override fun onResume() {
        super.onResume()
        val root = window.decorView.rootView
        if (root is ViewGroup) {
            root.isMotionEventSplittingEnabled = false
        }
    }
}
