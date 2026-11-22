package com.unizoy.splitify.capture

import org.json.JSONArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** TC-X4-02 (dedup) and the store's import protocol (S-222, S-224). */
class CaptureStoreTest {
    private class MapKv : KeyValue {
        val m = mutableMapOf<String, String>()
        override fun get(key: String) = m[key]
        override fun put(key: String, value: String) {
            m[key] = value
        }
    }

    private var now = 1_800_000_000_000L
    private val store = CaptureStore(MapKv()) { now }

    private fun cap(
        id: String,
        amount: Long = 50000,
        payee: String? = "Rahul Sharma",
        ref: String? = null,
        at: Long = now,
        source: CaptureSource = CaptureSource.NOTIFICATION,
    ) = Capture(id, amount, payee, null, ref, "com.google.android.apps.nbu.paisa.user", "Google Pay", source, at)

    @Test
    fun `same ref is one payment, different refs are two`() {
        assertTrue(Dedup.isDuplicate(cap("a", ref = "612345678901"), cap("b", ref = "612345678901", at = now + 3_600_000)))
        assertFalse(Dedup.isDuplicate(cap("a", ref = "612345678901"), cap("b", ref = "612345678902")))
    }

    @Test
    fun `no ref - same amount within 10 minutes and compatible payees`() {
        val a = cap("a")
        assertTrue(Dedup.isDuplicate(a, cap("b", payee = "RAHUL SHARMA", ref = "6123", at = now + 9 * 60_000)))
        assertTrue(Dedup.isDuplicate(a, cap("b", payee = "rahul@okaxis", at = now + 60_000)))
        assertTrue(Dedup.isDuplicate(a, cap("b", payee = null, at = now + 60_000)))
        assertTrue(Dedup.isDuplicate(a, cap("b", payee = "Rahul", at = now + 60_000)))
        assertFalse("too late", Dedup.isDuplicate(a, cap("b", at = now + 11 * 60_000)))
        assertFalse("other amount", Dedup.isDuplicate(a, cap("b", amount = 50100)))
        assertFalse("other person", Dedup.isDuplicate(a, cap("b", payee = "Priya Nair")))
    }

    @Test
    fun `notification then bank SMS gives one capture with the ref filled in`() {
        val first = store.add(cap("n1"))
        assertTrue(first is CaptureStore.AddResult.Added)
        val sms = cap("s1", payee = "RAHUL SHARMA", ref = "612345678901", at = now + 90_000, source = CaptureSource.SMS)
        val second = store.add(sms)
        assertTrue(second is CaptureStore.AddResult.Merged)
        assertEquals(1, store.pending().size)
        assertEquals("612345678901", store.pending().single().ref)
        assertEquals("n1", store.pending().single().id)
        // The screen capture of the same payment adds nothing new.
        assertEquals(CaptureStore.AddResult.Duplicate, store.add(cap("x1", ref = "612345678901", source = CaptureSource.SCREEN)))
        assertEquals(1, store.pending().size)
    }

    @Test
    fun `a dismissed or imported capture still blocks its duplicates`() {
        store.add(cap("n1", ref = "612345678901"))
        store.dismiss("n1")
        assertEquals(emptyList<Capture>(), store.pending())
        assertEquals(listOf("n1"), store.dismissed())
        assertEquals(CaptureStore.AddResult.Duplicate, store.add(cap("s1", ref = "612345678901")))
        store.add(cap("n2", amount = 999))
        store.ack(listOf("n2"), listOf("n1"))
        assertEquals(emptyList<Capture>(), store.pending())
        assertEquals(emptyList<String>(), store.dismissed())
        assertEquals(CaptureStore.AddResult.Duplicate, store.add(cap("n3", amount = 999)))
    }

    @Test
    fun `captures older than 7 days and ledger entries older than 24 h go`() {
        store.add(cap("old", amount = 100, ref = "111111"))
        now += CaptureStore.KEEP_MS + 1
        assertEquals(emptyList<Capture>(), store.pending())
        assertTrue("ledger expired, so the same ref is new again", store.add(cap("again", amount = 100, ref = "111111")) is CaptureStore.AddResult.Added)
    }

    @Test
    fun `export holds parsed fields only`() {
        store.add(cap("n1", ref = "612345678901"))
        val e = store.export()
        val c = e.getJSONArray("captures").getJSONObject(0)
        assertEquals(setOf("id", "amount", "currency", "payee", "note", "ref", "app_package", "app_name", "source", "captured_at"), c.keys().asSequence().toSet())
        assertEquals(50000L, c.getLong("amount"))
        assertEquals("INR", c.getString("currency"))
        assertEquals(0, e.getJSONArray("dismissed").length())
    }

    @Test
    fun `config is off by default and per-app switches follow the recipe default`() {
        val c = store.config()
        assertFalse(c.enabled)
        assertFalse(c.smart)
        val whatsapp = RecipeApp("com.whatsapp", "WhatsApp", AppKind.UPI, defaultOn = false, debugOnly = false)
        val gpay = RecipeApp("com.google.android.apps.nbu.paisa.user", "Google Pay", AppKind.UPI, defaultOn = true, debugOnly = false)
        assertFalse(c.appOn(whatsapp))
        assertTrue(c.appOn(gpay))
        store.setConfig(c.copy(enabled = true, apps = mapOf("com.whatsapp" to true, gpay.packageName to false), theme = "dark"))
        val back = store.config()
        assertTrue(back.enabled)
        assertTrue(back.appOn(whatsapp))
        assertFalse(back.appOn(gpay))
        assertEquals("dark", back.theme)
    }

    @Test
    fun `reset forgets captures, tombstones, ledger and chips but keeps the switches`() {
        store.setConfig(CaptureConfig(enabled = true))
        store.add(cap("n1", ref = "612345678901"))
        store.add(cap("n2", amount = 999))
        store.dismiss("n2")
        store.setRecents("[{\"id\":\"g1\",\"name\":\"Goa\"}]")
        store.reset()
        assertEquals(emptyList<Capture>(), store.pending())
        assertEquals(emptyList<String>(), store.dismissed())
        assertEquals(emptyList<RecentChip>(), store.recents())
        assertTrue(store.config().enabled)
        assertTrue("ledger cleared: the same payment is new again", store.add(cap("again", ref = "612345678901")) is CaptureStore.AddResult.Added)
    }

    @Test
    fun `recent chips round-trip`() {
        store.setRecents(JSONArray().put(org.json.JSONObject().put("id", "g1").put("name", "Goa trip").put("friend", false)).toString())
        assertEquals(listOf(RecentChip("g1", "Goa trip", false)), store.recents())
    }
}
