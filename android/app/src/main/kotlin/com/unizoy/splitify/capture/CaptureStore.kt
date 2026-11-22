package com.unizoy.splitify.capture

import org.json.JSONArray
import org.json.JSONObject

/** Tiny key-value seam so the store runs on the JVM in tests (SharedPreferences on the phone). */
interface KeyValue {
    fun get(key: String): String?
    fun put(key: String, value: String)
}

/** Feature settings written by the app's settings screen (all off until the user opts in, X4). */
data class CaptureConfig(
    val enabled: Boolean = false,
    val notifications: Boolean = true,
    val smart: Boolean = false,
    val bubble: Boolean = true,
    val duringPayment: Boolean = false,
    /** Per-app switches the user changed; others follow the recipe's `defaultOn`. */
    val apps: Map<String, Boolean> = emptyMap(),
    /** "system" | "light" | "dark": the app's theme setting, used for the bubble colours. */
    val theme: String = "system",
) {
    fun toJson(): JSONObject = JSONObject()
        .put("enabled", enabled)
        .put("notifications", notifications)
        .put("smart", smart)
        .put("bubble", bubble)
        .put("during_payment", duringPayment)
        .put("apps", JSONObject(apps.toSortedMap()))
        .put("theme", theme)

    /** Is [app] switched on? */
    fun appOn(app: RecipeApp): Boolean = apps[app.packageName] ?: app.defaultOn

    companion object {
        fun fromJson(o: JSONObject?): CaptureConfig {
            if (o == null) return CaptureConfig()
            val apps = o.optJSONObject("apps")
            return CaptureConfig(
                enabled = o.optBoolean("enabled", false),
                notifications = o.optBoolean("notifications", true),
                smart = o.optBoolean("smart", false),
                bubble = o.optBoolean("bubble", true),
                duringPayment = o.optBoolean("during_payment", false),
                apps = if (apps == null) emptyMap() else apps.keys().asSequence().associateWith { apps.getBoolean(it) },
                theme = o.optString("theme", "system"),
            )
        }
    }
}

/** Recent group / friend for the bubble's chips, written by the app (like the home widget does). */
data class RecentChip(val id: String, val name: String, val friend: Boolean)

/**
 * The phone-side capture store (S-224), one JSON document per key: pending captures, dismissed ids the app
 * still has to forget, a 24 h dedup ledger, the config and the recent chips. Captures older than 7 days go.
 */
class CaptureStore(private val kv: KeyValue, private val clock: () -> Long = System::currentTimeMillis) {

    sealed interface AddResult {
        data class Added(val capture: Capture) : AddResult
        data class Merged(val capture: Capture) : AddResult
        data object Duplicate : AddResult
    }

    @Synchronized
    fun add(candidate: Capture): AddResult {
        val now = clock()
        val pending = load(PENDING).filter { now - it.capturedAt < KEEP_MS }.toMutableList()
        val ledger = load(LEDGER).filter { now - it.capturedAt < LEDGER_MS }.toMutableList()
        val seen = ledger.firstOrNull { Dedup.isDuplicate(it, candidate) }
        if (seen != null) {
            val i = pending.indexOfFirst { it.id == seen.id }
            val merged = Dedup.merge(seen, candidate)
            ledger[ledger.indexOf(seen)] = merged
            save(LEDGER, ledger)
            if (i < 0) {
                save(PENDING, pending)
                return AddResult.Duplicate
            }
            pending[i] = Dedup.merge(pending[i], candidate)
            save(PENDING, pending)
            return if (pending[i] != seen) AddResult.Merged(pending[i]) else AddResult.Duplicate
        }
        pending += candidate
        ledger += candidate
        save(PENDING, pending)
        save(LEDGER, ledger)
        return AddResult.Added(candidate)
    }

    @Synchronized
    fun pending(): List<Capture> {
        val now = clock()
        return load(PENDING).filter { now - it.capturedAt < KEEP_MS }
    }

    @Synchronized
    fun get(id: String): Capture? = pending().firstOrNull { it.id == id }

    /** "Not now": forget it here and tell the app to forget its copy too. */
    @Synchronized
    fun dismiss(id: String) {
        save(PENDING, load(PENDING).filter { it.id != id })
        val gone = dismissed().toMutableSet().apply { add(id) }
        kv.put(DISMISSED, JSONArray(gone.sorted()).toString())
    }

    @Synchronized
    fun dismissed(): List<String> {
        val a = kv.get(DISMISSED)?.let { JSONArray(it) } ?: return emptyList()
        return (0 until a.length()).map { a.getString(it) }
    }

    /** What the app imports: `{captures: [...], dismissed: [...]}`. */
    @Synchronized
    fun export(): JSONObject = JSONObject()
        .put("captures", JSONArray(pending().map { it.toJson() }))
        .put("dismissed", JSONArray(dismissed()))

    /** The app has stored [captureIds] and forgotten [dismissedIds]: drop them here. */
    @Synchronized
    fun ack(captureIds: Collection<String>, dismissedIds: Collection<String>) {
        save(PENDING, load(PENDING).filter { it.id !in captureIds })
        kv.put(DISMISSED, JSONArray(dismissed().filter { it !in dismissedIds }).toString())
    }

    @Synchronized
    fun config(): CaptureConfig = CaptureConfig.fromJson(kv.get(CONFIG)?.let { JSONObject(it) })

    @Synchronized
    fun setConfig(c: CaptureConfig) = kv.put(CONFIG, c.toJson().toString())

    @Synchronized
    fun recents(): List<RecentChip> {
        val a = kv.get(RECENTS)?.let { JSONArray(it) } ?: return emptyList()
        return (0 until a.length()).map {
            val o = a.getJSONObject(it)
            RecentChip(o.getString("id"), o.getString("name"), o.optBoolean("friend", false))
        }
    }

    @Synchronized
    fun setRecents(json: String) {
        JSONArray(json) // validate
        kv.put(RECENTS, json)
    }

    private fun load(key: String): List<Capture> {
        val a = kv.get(key)?.let { JSONArray(it) } ?: return emptyList()
        return (0 until a.length()).map { Capture.fromJson(a.getJSONObject(it)) }
    }

    private fun save(key: String, list: List<Capture>) = kv.put(key, JSONArray(list.map { it.toJson() }).toString())

    companion object {
        const val PREFS = "splitify_capture"
        const val KEEP_MS = 7L * 24 * 60 * 60 * 1000
        const val LEDGER_MS = 24L * 60 * 60 * 1000
        private const val PENDING = "pending"
        private const val LEDGER = "ledger"
        private const val DISMISSED = "dismissed"
        private const val CONFIG = "config"
        private const val RECENTS = "recents"
    }
}
