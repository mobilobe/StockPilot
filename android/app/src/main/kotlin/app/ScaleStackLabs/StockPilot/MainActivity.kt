package app.ScaleStackLabs.StockPilot

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "app.ScaleStackLabs.StockPilot/file_saver"
    private var fileSaverHelper: FileSaverHelper? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            // Initialize helper
            fileSaverHelper = FileSaverHelper(this)

            MethodChannel(messenger, channelName).setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveFileWithPicker" -> {
                        val fileName = call.argument<String>("fileName")
                        val bytes = call.argument<ByteArray>("bytes")
                        val mimeType = call.argument<String>("mimeType")

                        if (fileName == null || bytes == null || mimeType == null) {
                            result.error(
                                "INVALID_ARGS",
                                "fileName, bytes, and mimeType are required",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        fileSaverHelper?.saveFileWithPicker(
                            fileName,
                            bytes,
                            mimeType,
                            result
                        )
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Forward to helper
        fileSaverHelper?.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        fileSaverHelper = null
        super.onDestroy()
    }
}
