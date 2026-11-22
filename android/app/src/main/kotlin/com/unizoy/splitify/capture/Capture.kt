package com.unizoy.splitify.capture

import org.json.JSONObject

/**
 * One captured payment waiting on this phone (S-224): parsed fields only, never the alert's text. Amount in
 * paise (rule 1), always INR (UPI). [capturedAt] is epoch milliseconds.
 */
data class Capture(
    val id: String,
    val amountPaise: Long,
    val payee: String?,
    val note: String?,
    val ref: String?,
    val appPackage: String,
    val appName: String,
    val source: CaptureSource,
    val capturedAt: Long,
    val currency: String = "INR",
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("amount", amountPaise)
        .put("currency", currency)
        .put("payee", payee ?: JSONObject.NULL)
        .put("note", note ?: JSONObject.NULL)
        .put("ref", ref ?: JSONObject.NULL)
        .put("app_package", appPackage)
        .put("app_name", appName)
        .put("source", source.wire)
        .put("captured_at", capturedAt)

    companion object {
        fun fromJson(o: JSONObject): Capture = Capture(
            id = o.getString("id"),
            amountPaise = o.getLong("amount"),
            payee = o.optStringOrNull("payee"),
            note = o.optStringOrNull("note"),
            ref = o.optStringOrNull("ref"),
            appPackage = o.getString("app_package"),
            appName = o.getString("app_name"),
            source = CaptureSource.entries.first { it.wire == o.getString("source") },
            capturedAt = o.getLong("captured_at"),
            currency = o.optString("currency", "INR"),
        )

        private fun JSONObject.optStringOrNull(key: String): String? =
            if (isNull(key)) null else optString(key).takeIf { it.isNotEmpty() }
    }
}

/**
 * De-duplication across sources (S-222): the same UPI ref, or the same amount within [windowMs] when one side
 * has no ref and the payees are compatible. A VPA or a missing name is compatible with any name, because a
 * notification says "Rahul Sharma" where the bank SMS says "rahul@okaxis".
 */
object Dedup {
    const val WINDOW_MS = 10 * 60 * 1000L

    fun isDuplicate(a: Capture, b: Capture, windowMs: Long = WINDOW_MS): Boolean {
        if (a.ref != null && b.ref != null) return a.ref == b.ref
        if (a.amountPaise != b.amountPaise) return false
        if (kotlin.math.abs(a.capturedAt - b.capturedAt) > windowMs) return false
        return payeesCompatible(a.payee, b.payee)
    }

    fun payeesCompatible(x: String?, y: String?): Boolean {
        if (x == null || y == null) return true
        if (x.contains('@') || y.contains('@')) return true
        val p = key(x)
        val q = key(y)
        return p.isEmpty() || q.isEmpty() || p == q || p.contains(q) || q.contains(p)
    }

    /** Lower-case letters and digits only. */
    fun key(s: String): String = s.lowercase().filter { it.isLetterOrDigit() }

    /** [first] with the gaps filled from [later] (keeps the first id, app and time). */
    fun merge(first: Capture, later: Capture): Capture = first.copy(
        ref = first.ref ?: later.ref,
        payee = when {
            first.payee == null -> later.payee
            first.payee.contains('@') && later.payee != null && !later.payee.contains('@') -> later.payee
            else -> first.payee
        },
        note = first.note ?: later.note,
    )
}
