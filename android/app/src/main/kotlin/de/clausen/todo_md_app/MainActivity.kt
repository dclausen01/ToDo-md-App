package de.clausen.todo_md_app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Hosts a [MethodChannel] exposing the Android Storage Access Framework to the
 * Flutter app: pick the vault folder once (with a persistable permission) and
 * then read/write files inside it by vault-relative path.
 */
class MainActivity : FlutterActivity() {

    private val channelName = "de.clausen.todo_md_app/saf"
    private val openTreeRequest = 4201

    private var pendingPick: MethodChannel.Result? = null
    private val main = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickVault" -> pickVault(result)
                    "vaultName" -> vaultName(call.argument<String>("tree"), result)
                    "hasAccess" -> result.success(hasAccess(call.argument<String>("tree")))
                    "readFile" -> runIo(result) {
                        readFile(call.argument("tree")!!, call.argument("path")!!)
                    }
                    "writeFile" -> runIo(result) {
                        writeFile(
                            call.argument("tree")!!,
                            call.argument("path")!!,
                            call.argument("content")!!,
                        )
                        null
                    }
                    "exists" -> runIo(result) {
                        resolve(call.argument("tree")!!, call.argument("path")!!, false) != null
                    }
                    "deleteFile" -> runIo(result) {
                        resolve(call.argument("tree")!!, call.argument("path")!!, false)?.delete()
                        null
                    }
                    "listFiles" -> runIo(result) { listFiles(call.argument("tree")!!) }
                    else -> result.notImplemented()
                }
            }
    }

    // ---- vault picking ----------------------------------------------------

    private fun pickVault(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("busy", "A folder picker is already open", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        startActivityForResult(intent, openTreeRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != openTreeRequest) return
        val result = pendingPick
        pendingPick = null
        if (resultCode == Activity.RESULT_OK && data?.data != null) {
            val uri = data.data!!
            val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: SecurityException) {
                // Some providers don't support persistable perms; continue anyway.
            }
            result?.success(uri.toString())
        } else {
            result?.success(null)
        }
    }

    private fun vaultName(tree: String?, result: MethodChannel.Result) {
        if (tree == null) {
            result.success(null); return
        }
        val doc = DocumentFile.fromTreeUri(this, Uri.parse(tree))
        result.success(doc?.name)
    }

    private fun hasAccess(tree: String?): Boolean {
        if (tree == null) return false
        val uri = Uri.parse(tree)
        return contentResolver.persistedUriPermissions.any {
            it.uri == uri && it.isReadPermission && it.isWritePermission
        }
    }

    // ---- file IO ----------------------------------------------------------

    private fun root(tree: String): DocumentFile =
        DocumentFile.fromTreeUri(this, Uri.parse(tree))
            ?: throw IllegalStateException("Vault tree not accessible")

    /** Resolves [path] (vault-relative, `/`-separated) into a DocumentFile. */
    private fun resolve(tree: String, path: String, create: Boolean): DocumentFile? {
        val segments = path.split('/').filter { it.isNotEmpty() }
        if (segments.isEmpty()) return null
        var current = root(tree)
        for (i in 0 until segments.size - 1) {
            val name = segments[i]
            var child = current.findFile(name)
            if (child == null || !child.isDirectory) {
                if (!create) return null
                child = current.createDirectory(name) ?: return null
            }
            current = child
        }
        val fileName = segments.last()
        var file = current.findFile(fileName)
        if (file == null && create) {
            file = current.createFile("text/markdown", fileName)
        }
        return file
    }

    private fun readFile(tree: String, path: String): String {
        val file = resolve(tree, path, false)
            ?: throw NoSuchElementException("not_found")
        contentResolver.openInputStream(file.uri).use { input ->
            requireNotNull(input)
            val buffer = ByteArrayOutputStream()
            val chunk = ByteArray(8192)
            while (true) {
                val read = input.read(chunk)
                if (read < 0) break
                buffer.write(chunk, 0, read)
            }
            return buffer.toByteArray().toString(Charsets.UTF_8)
        }
    }

    private fun writeFile(tree: String, path: String, content: String) {
        val file = resolve(tree, path, true)
            ?: throw IllegalStateException("could not create $path")
        // "wt" truncates the existing file before writing.
        contentResolver.openOutputStream(file.uri, "wt").use { out ->
            requireNotNull(out)
            out.write(content.toByteArray(Charsets.UTF_8))
            out.flush()
        }
    }

    private fun listFiles(tree: String): List<Map<String, Any>> {
        val out = ArrayList<Map<String, Any>>()
        fun walk(dir: DocumentFile, prefix: String) {
            for (child in dir.listFiles()) {
                val name = child.name ?: continue
                val rel = if (prefix.isEmpty()) name else "$prefix/$name"
                out.add(mapOf("path" to rel, "name" to name, "isDir" to child.isDirectory))
                if (child.isDirectory) walk(child, rel)
            }
        }
        walk(root(tree), "")
        return out
    }

    // ---- helpers ----------------------------------------------------------

    private fun <T> runIo(result: MethodChannel.Result, block: () -> T) {
        Thread {
            try {
                val value = block()
                main.post { result.success(value) }
            } catch (e: NoSuchElementException) {
                main.post { result.error("not_found", e.message, null) }
            } catch (e: Exception) {
                main.post { result.error("io_error", e.message, null) }
            }
        }.start()
    }
}
