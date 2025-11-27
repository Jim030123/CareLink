package com.example.carelink_mobile

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterFragmentActivity() {
	// Ensure plugins are registered with the engine. This helps guarantee
	// native plugin implementations are available at runtime.
	override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
		GeneratedPluginRegistrant.registerWith(flutterEngine)
	}
}
