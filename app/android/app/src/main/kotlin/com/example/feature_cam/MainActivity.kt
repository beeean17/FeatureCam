package com.example.feature_cam

import android.Manifest
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.view.OrientationEventListener
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val processingExecutor = Executors.newSingleThreadExecutor()
    private var pendingGalleryPermissionResult: MethodChannel.Result? = null
    private var orientationEventSink: EventChannel.EventSink? = null
    private var orientationListener: OrientationEventListener? = null
    private var lastQuarterTurns = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PROCESSING_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "health" -> runProcessing(result) {
                    python()
                    "ok"
                }
                "processPhoto" -> runProcessing(result) {
                    val inputPath = call.requiredString("inputPath")
                    val outputPath = call.requiredString("outputPath")
                    python().getModule("feature_processor").callAttr(
                        "process_photo",
                        inputPath,
                        outputPath,
                        call.requiredDouble("strength"),
                        call.requiredDouble("centerX"),
                        call.requiredDouble("centerY"),
                        call.requiredDouble("radius"),
                    )
                    outputPath
                }
                "processVideo" -> runProcessing(result) {
                    val inputPath = call.requiredString("inputPath")
                    val outputPath = call.requiredString("outputPath")
                    python().getModule("feature_processor").callAttr(
                        "process_video",
                        inputPath,
                        outputPath,
                        call.requiredDouble("strength"),
                        call.requiredDouble("centerX"),
                        call.requiredDouble("centerY"),
                        call.requiredDouble("radius"),
                    )
                    outputPath
                }
                "processPanorama" -> runProcessing(result) {
                    val inputPaths = call.requiredStringList("inputPaths")
                    val outputPath = call.requiredString("outputPath")
                    python().getModule("feature_processor").callAttr(
                        "process_panorama",
                        inputPaths,
                        outputPath,
                    )
                    outputPath
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_STORE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestGalleryAccess" -> requestGalleryAccess(result)
                "listFeatureCamMedia" -> runMediaStore(result) {
                    listFeatureCamMedia()
                }
                "loadMediaBytes" -> runMediaStore(result) {
                    loadMediaBytes(call.requiredString("uri"))
                }
                "openMedia" -> openMedia(
                    uri = call.requiredString("uri"),
                    mimeType = call.requiredString("mimeType"),
                    result = result,
                )
                "saveToDcim" -> runMediaStore(result) {
                    saveToDcim(
                        inputPath = call.requiredString("inputPath"),
                        displayName = call.requiredString("displayName"),
                        mimeType = call.requiredString("mimeType"),
                    ).toString()
                }
                "cropImageToAspect" -> runMediaStore(result) {
                    cropImageToAspect(
                        inputPath = call.requiredString("inputPath"),
                        outputPath = call.requiredString("outputPath"),
                        aspectRatio = call.requiredDouble("aspectRatio"),
                    )
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ORIENTATION_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    orientationEventSink = events
                    events?.success(lastQuarterTurns)
                    startOrientationListener()
                }

                override fun onCancel(arguments: Any?) {
                    orientationEventSink = null
                    orientationListener?.disable()
                }
            },
        )
    }

    override fun onDestroy() {
        orientationListener?.disable()
        processingExecutor.shutdown()
        super.onDestroy()
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == GALLERY_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingGalleryPermissionResult?.success(granted)
            pendingGalleryPermissionResult = null
        }
    }

    private fun python(): Python {
        if (!Python.isStarted()) {
            Python.start(AndroidPlatform(this))
        }
        return Python.getInstance()
    }

    private fun startOrientationListener() {
        val listener = orientationListener ?: object : OrientationEventListener(this) {
            override fun onOrientationChanged(orientation: Int) {
                if (orientation == ORIENTATION_UNKNOWN) {
                    return
                }
                val quarterTurns = orientation.toQuarterTurns()
                if (quarterTurns == lastQuarterTurns) {
                    return
                }
                lastQuarterTurns = quarterTurns
                mainHandler.post {
                    orientationEventSink?.success(quarterTurns)
                }
            }
        }.also {
            orientationListener = it
        }

        if (listener.canDetectOrientation()) {
            listener.enable()
        }
    }

    private fun Int.toQuarterTurns(): Int {
        return when {
            this >= 315 || this < 45 -> 0
            this < 135 -> 3
            this < 225 -> 2
            else -> 1
        }
    }

    private fun runProcessing(
        result: MethodChannel.Result,
        block: () -> String,
    ) {
        processingExecutor.execute {
            try {
                val output = block()
                mainHandler.post { result.success(output) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "PROCESSING_FAILED",
                        error.message ?: error.javaClass.simpleName,
                        error.stackTraceToString(),
                    )
                }
            }
        }
    }

    private fun runMediaStore(
        result: MethodChannel.Result,
        block: () -> Any?,
    ) {
        processingExecutor.execute {
            try {
                val output = block()
                mainHandler.post { result.success(output) }
            } catch (error: Throwable) {
                mainHandler.post {
                    result.error(
                        "MEDIA_STORE_FAILED",
                        error.message ?: error.javaClass.simpleName,
                        error.stackTraceToString(),
                    )
                }
            }
        }
    }

    private fun requestGalleryAccess(result: MethodChannel.Result) {
        val permissions = galleryPermissions()
        if (permissions.isEmpty() || permissions.all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            result.success(true)
            return
        }
        val pending = pendingGalleryPermissionResult
        if (pending != null) {
            pending.error("PERMISSION_BUSY", "A gallery permission request is already running.", null)
        }
        pendingGalleryPermissionResult = result
        requestPermissions(permissions, GALLERY_PERMISSION_REQUEST_CODE)
    }

    private fun galleryPermissions(): Array<String> {
        return when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> arrayOf(
                Manifest.permission.READ_MEDIA_IMAGES,
                Manifest.permission.READ_MEDIA_VIDEO,
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
            )
            else -> emptyArray()
        }
    }

    private fun listFeatureCamMedia(): List<Map<String, Any?>> {
        val items = mutableListOf<Map<String, Any?>>()
        items += queryFeatureCamCollection(
            uri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            isVideo = false,
        )
        items += queryFeatureCamCollection(
            uri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            isVideo = true,
        )
        return items.sortedByDescending { it["dateAdded"] as Long }
    }

    private fun queryFeatureCamCollection(
        uri: Uri,
        isVideo: Boolean,
    ): List<Map<String, Any?>> {
        val projection = mutableListOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.MIME_TYPE,
            MediaStore.MediaColumns.DATE_ADDED,
        )
        val selection: String
        val selectionArgs: Array<String>
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            projection += MediaStore.MediaColumns.RELATIVE_PATH
            selection = "${MediaStore.MediaColumns.RELATIVE_PATH} LIKE ?"
            selectionArgs = arrayOf("${Environment.DIRECTORY_DCIM}/FeatureCam%")
        } else {
            projection += MediaStore.MediaColumns.DATA
            selection = "${MediaStore.MediaColumns.DATA} LIKE ?"
            selectionArgs = arrayOf("%/${Environment.DIRECTORY_DCIM}/FeatureCam/%")
        }

        val items = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            uri,
            projection.toTypedArray(),
            selection,
            selectionArgs,
            "${MediaStore.MediaColumns.DATE_ADDED} DESC",
        )?.use { cursor ->
            val idIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns._ID)
            val nameIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DISPLAY_NAME)
            val mimeIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.MIME_TYPE)
            val dateIndex = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATE_ADDED)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIndex)
                val contentUri = ContentUris.withAppendedId(uri, id)
                val mimeType = cursor.getString(mimeIndex) ?: if (isVideo) "video/mp4" else "image/jpeg"
                items += mapOf(
                    "id" to id,
                    "uri" to contentUri.toString(),
                    "displayName" to cursor.getString(nameIndex),
                    "mimeType" to mimeType,
                    "isVideo" to isVideo,
                    "dateAdded" to cursor.getLong(dateIndex),
                    "thumbnail" to thumbnailBytes(contentUri, mimeType),
                )
            }
        }
        return items
    }

    private fun thumbnailBytes(uri: Uri, mimeType: String): ByteArray? {
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                contentResolver.loadThumbnail(uri, Size(360, 360), null)
            } else if (mimeType.startsWith("image/")) {
                contentResolver.openInputStream(uri)?.use { input ->
                    BitmapFactory.decodeStream(input)
                }
            } else {
                null
            }
        } catch (_: Throwable) {
            null
        } ?: return null

        return bitmap.scaleInside(360).useCompressedJpeg()
    }

    private fun loadMediaBytes(uriString: String): ByteArray {
        val uri = Uri.parse(uriString)
        return contentResolver.openInputStream(uri)?.use { input ->
            input.readBytes()
        } ?: throw IllegalStateException("Could not open media: $uriString")
    }

    private fun cropImageToAspect(
        inputPath: String,
        outputPath: String,
        aspectRatio: Double,
    ): String {
        val source = File(inputPath)
        require(source.exists()) { "Source image does not exist: $inputPath" }

        val decoded = BitmapFactory.decodeFile(inputPath)
            ?: throw IllegalStateException("Could not decode image: $inputPath")
        val bitmap = decoded.applyExifOrientation(inputPath)
        val targetRatio = aspectRatio.coerceAtLeast(0.01)
        val sourceRatio = bitmap.width.toDouble() / bitmap.height.toDouble()

        val cropWidth: Int
        val cropHeight: Int
        if (sourceRatio > targetRatio) {
            cropHeight = bitmap.height
            cropWidth = (cropHeight * targetRatio).toInt().coerceAtLeast(1)
        } else {
            cropWidth = bitmap.width
            cropHeight = (cropWidth / targetRatio).toInt().coerceAtLeast(1)
        }

        val cropLeft = ((bitmap.width - cropWidth) / 2).coerceAtLeast(0)
        val cropTop = ((bitmap.height - cropHeight) / 2).coerceAtLeast(0)
        val cropped = Bitmap.createBitmap(bitmap, cropLeft, cropTop, cropWidth, cropHeight)
        val output = File(outputPath)
        output.parentFile?.mkdirs()
        output.outputStream().use { stream ->
            cropped.compress(Bitmap.CompressFormat.JPEG, 95, stream)
        }
        if (cropped != bitmap) {
            cropped.recycle()
        }
        if (bitmap != decoded) {
            bitmap.recycle()
        }
        if (!decoded.isRecycled) {
            decoded.recycle()
        }
        return outputPath
    }

    private fun Bitmap.applyExifOrientation(path: String): Bitmap {
        val orientation = try {
            ExifInterface(path).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        } catch (_: Throwable) {
            ExifInterface.ORIENTATION_NORMAL
        }

        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> matrix.preScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> matrix.preScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.preScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.preScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            else -> return this
        }

        return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
    }

    private fun openMedia(
        uri: String,
        mimeType: String,
        result: MethodChannel.Result,
    ) {
        try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(Uri.parse(uri), mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            result.success(true)
        } catch (error: Throwable) {
            result.error(
                "OPEN_MEDIA_FAILED",
                error.message ?: error.javaClass.simpleName,
                error.stackTraceToString(),
            )
        }
    }

    private fun Bitmap.scaleInside(maxSize: Int): Bitmap {
        val longestSide = maxOf(width, height)
        if (longestSide <= maxSize) {
            return this
        }
        val scale = maxSize.toFloat() / longestSide.toFloat()
        return Bitmap.createScaledBitmap(
            this,
            (width * scale).toInt().coerceAtLeast(1),
            (height * scale).toInt().coerceAtLeast(1),
            true,
        )
    }

    private fun Bitmap.useCompressedJpeg(): ByteArray {
        val stream = ByteArrayOutputStream()
        compress(Bitmap.CompressFormat.JPEG, 82, stream)
        return stream.toByteArray()
    }

    private fun saveToDcim(
        inputPath: String,
        displayName: String,
        mimeType: String,
    ): Uri {
        val source = File(inputPath)
        require(source.exists()) { "Source file does not exist: $inputPath" }

        val isVideo = mimeType.startsWith("video/")
        val collection = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && isVideo ->
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q ->
                MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            isVideo -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            else -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    "${Environment.DIRECTORY_DCIM}/FeatureCam",
                )
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            } else {
                val directory = File(
                    Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM),
                    "FeatureCam",
                )
                directory.mkdirs()
                put(MediaStore.MediaColumns.DATA, File(directory, displayName).absolutePath)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(collection, values)
            ?: throw IllegalStateException("Could not create MediaStore item")

        try {
            resolver.openOutputStream(uri)?.use { output ->
                FileInputStream(source).use { input ->
                    input.copyTo(output)
                }
            } ?: throw IllegalStateException("Could not open MediaStore output stream")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.MediaColumns.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }
            return uri
        } catch (error: Throwable) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    private fun MethodCall.requiredString(key: String): String {
        return argument<String>(key) ?: throw IllegalArgumentException("$key is required")
    }

    private fun MethodCall.requiredDouble(key: String): Double {
        return when (val value = argument<Any>(key)) {
            is Double -> value
            is Float -> value.toDouble()
            is Int -> value.toDouble()
            is Long -> value.toDouble()
            else -> throw IllegalArgumentException("$key must be a number")
        }
    }

    private fun MethodCall.requiredStringList(key: String): List<String> {
        val value = argument<List<String>>(key)
        return value ?: throw IllegalArgumentException("$key is required")
    }

    companion object {
        private const val PROCESSING_CHANNEL = "feature_cam/processing"
        private const val MEDIA_STORE_CHANNEL = "feature_cam/media_store"
        private const val ORIENTATION_CHANNEL = "feature_cam/orientation"
        private const val GALLERY_PERMISSION_REQUEST_CODE = 2417
    }
}
