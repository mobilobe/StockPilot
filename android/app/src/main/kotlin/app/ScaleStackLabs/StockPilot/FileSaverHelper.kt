package app.ScaleStackLabs.StockPilot

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import android.util.Log
import io.flutter.plugin.common.MethodChannel
import java.io.IOException

private const val SAVE_FILE_REQUEST_CODE = 886325064

class FileSaverHelper(private val activity: Activity) {
    
    private var result: MethodChannel.Result? = null
    private var bytesToSave: ByteArray? = null
    private val tag = "FileSaverHelper"

    fun saveFileWithPicker(
        fileName: String,
        bytes: ByteArray,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        this.result = result
        this.bytesToSave = bytes

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
            putExtra(
                DocumentsContract.EXTRA_INITIAL_URI,
                Environment.getExternalStorageDirectory().path
            )
        }

        activity.startActivityForResult(intent, SAVE_FILE_REQUEST_CODE)
    }

    fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        if (requestCode != SAVE_FILE_REQUEST_CODE) {
            return false
        }

        if (resultCode == Activity.RESULT_OK && data?.data != null) {
            val uri = data.data!!
            saveToUri(uri)
        } else {
            Log.d(tag, "Save cancelled by user")
            result?.success(null)
            result = null
            bytesToSave = null
        }

        return true
    }

    private fun saveToUri(uri: Uri) {
        val bytes = bytesToSave
        if (bytes == null) {
            result?.error("NO_DATA", "No bytes available to save", null)
            result = null
            return
        }

        try {
            activity.contentResolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
                // Stream is automatically closed by 'use'
            }
            
            Log.d(tag, "File saved successfully: ${bytes.size} bytes")
            result?.success(uri.toString())
        } catch (e: IOException) {
            Log.e(tag, "Failed to write file", e)
            result?.error("WRITE_ERROR", "Failed to write file: ${e.message}", null)
        } catch (e: Exception) {
            Log.e(tag, "Unexpected error while saving", e)
            result?.error("ERROR", "Error: ${e.message}", null)
        } finally {
            result = null
            bytesToSave = null
        }
    }
}
