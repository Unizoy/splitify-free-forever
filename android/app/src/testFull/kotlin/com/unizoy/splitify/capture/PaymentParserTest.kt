package com.unizoy.splitify.capture

import java.io.File
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** TC-X4-01: every shared vector (test/fixtures/payment_capture_vectors.json) through the real recipes. */
class PaymentParserTest {
    private val recipes = Recipes.parse(File("src/main/assets/${Recipes.ASSET}").readText())
    private val parser = PaymentParser(recipes)
    private val vectors = JSONObject(File("../../test/fixtures/payment_capture_vectors.json").readText())
        .getJSONArray("vectors")

    @Test
    fun `shared vectors give the expected result`() {
        assertTrue("at least 40 vectors", vectors.length() >= 40)
        val failures = mutableListOf<String>()
        var ignores = 0
        for (i in 0 until vectors.length()) {
            val v = vectors.getJSONObject(i)
            val id = v.getString("id")
            val debug = v.optString("build", "debug") == "debug"
            val e = v.getJSONObject("expect")
            val got: String = if (v.getString("channel") == "screen") {
                val r = parser.parseScreen(v.getString("package"), v.getString("text"), debug)
                if (r.payment != null) describe(r.payment) else "stage:${r.stage.name.lowercase()}"
            } else {
                when (val r = parser.parseNotification(v.getString("package"), v.optString("title"), v.optString("text"), debug)) {
                    is ParseResult.Debit -> describe(r.payment)
                    is ParseResult.Ignored -> "ignore:${r.reason}"
                }
            }
            val want = when (e.getString("kind")) {
                "debit" -> listOf(
                    e.getLong("amount"),
                    e.opt("payee").takeUnless { it == JSONObject.NULL },
                    e.opt("ref").takeUnless { it == JSONObject.NULL },
                    e.getString("source"),
                    e.getString("rule"),
                ).joinToString("|")
                "ignore" -> "ignore:${e.getString("reason")}".also { ignores++ }
                else -> "stage:${e.getString("stage")}"
            }
            if (got != want) failures += "$id: got $got, want $want"
        }
        assertTrue("ignore cases ≥ 15 (TC-X4-07)", ignores >= 15)
        assertEquals(failures.joinToString("\n"), 0, failures.size)
    }

    @Test
    fun `amounts become integer paise without floats`() {
        assertEquals(123450L, TextNorm.toPaise("1,234.50"))
        assertEquals(123450L, TextNorm.toPaise("1234.5"))
        assertEquals(123400L, TextNorm.toPaise("1,234"))
        assertEquals(50000L, TextNorm.toPaise("500.00"))
        assertEquals(12345650L, TextNorm.toPaise("1,23,456.50"))
        assertEquals(1L, TextNorm.toPaise("0.01"))
        assertNull(TextNorm.toPaise("12.345"))
        assertNull(TextNorm.toPaise("1.2.3"))
        assertNull(TextNorm.toPaise(""))
        assertNull(TextNorm.toPaise(null))
        assertNull(TextNorm.toPaise("12345678901"))
    }

    @Test
    fun `text is normalised the same way as in Dart`() {
        assertEquals("Paid ₹500 to Rahul", TextNorm.normalize("  Paid ₹500\n\nto Rahul "))
        assertEquals("Paid. Details", TextNorm.joinTitle("Paid", "Details"))
        assertEquals("Paid: Details", TextNorm.joinTitle("Paid:", "Details"))
        assertEquals("Only", TextNorm.joinTitle("", "Only"))
        assertEquals("Rahul Sharma", TextNorm.cleanPayee("RAHUL SHARMA."))
        assertEquals("Game On", TextNorm.cleanPayee("..GAME ON"))
        assertEquals("rahul@okaxis", TextNorm.cleanPayee("rahul@okaxis"))
        assertEquals("ACME Stores", TextNorm.cleanPayee("ACME Stores"))
        assertNull(TextNorm.cleanPayee(" .. "))
        assertEquals(60, TextNorm.cleanPayee("x".repeat(80))!!.length)
    }

    @Test
    fun `allow-list hides debug-only apps in release`() {
        assertTrue("dev.splitify.fakeupi" in recipes.packages(debug = true))
        assertTrue("dev.splitify.fakeupi" !in recipes.packages(debug = false))
        assertTrue("com.google.android.apps.nbu.paisa.user" in recipes.packages(debug = false))
        assertEquals(1, recipes.version)
    }

    private fun describe(p: ParsedPayment) = listOf(p.amountPaise, p.payee, p.ref, p.source.wire, p.rule).joinToString("|")
}
