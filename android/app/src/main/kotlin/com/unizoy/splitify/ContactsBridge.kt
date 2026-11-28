package com.unizoy.splitify

import android.net.Uri
import android.provider.ContactsContract
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * "From contacts" (W2-X F15, lib/features/friends/application/contact_picker.dart): opens the system contact
 * picker (ACTION_PICK) and answers with the picked contact's display name only. No READ_CONTACTS permission:
 * the picker grants read access to the one contact the person chose; no number is read and nothing is stored.
 */
class ContactsBridge(private val activity: ComponentActivity, messenger: BinaryMessenger) {
    private var pending: MethodChannel.Result? = null
    private val launcher: ActivityResultLauncher<Void?> =
        activity.activityResultRegistry.register("splitify-contact-pick", ActivityResultContracts.PickContact()) { uri ->
            val result = pending ?: return@register
            pending = null
            result.success(uri?.let { nameOf(it) })
        }

    init {
        MethodChannel(messenger, "splitify/contacts").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickName" -> pick(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        // One picker at a time: a second tap while it is open gets no name.
        pending?.success(null)
        pending = result
        try {
            launcher.launch(null)
        } catch (e: RuntimeException) {
            pending = null
            result.error("UNAVAILABLE", e.message, null)
        }
    }

    private fun nameOf(uri: Uri): String? = try {
        activity.contentResolver.query(
            uri,
            arrayOf(ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
            null,
            null,
            null,
        )?.use { c -> if (c.moveToFirst()) c.getString(0)?.trim()?.takeIf { it.isNotEmpty() } else null }
    } catch (_: RuntimeException) {
        null
    }
}
