package com.unizoy.splitify.capture

import org.json.JSONArray
import org.json.JSONObject

/** Kind of app a payment alert comes from (S-221). `sms` = a messaging app showing bank SMS. */
enum class AppKind { UPI, SMS, BANK }

/** One allow-listed app from `payment_recipes.json`. */
data class RecipeApp(
    val packageName: String,
    val name: String,
    val kind: AppKind,
    val defaultOn: Boolean,
    val debugOnly: Boolean,
)

/** A regex rule; [unless] (ignore rules only) cancels the rule when it also matches. */
class RecipeRule(val id: String, pattern: String, unless: String? = null) {
    val regex = Regex(pattern, RegexOption.IGNORE_CASE)
    val unless = unless?.let { Regex(it, RegexOption.IGNORE_CASE) }
    val hasPayee = pattern.contains("(?<payee>")
    val hasRef = pattern.contains("(?<ref>")
}

/**
 * Parsed `android/app/src/full/assets/payment_recipes.json` (versioned data, so wording can be fixed without
 * code). The same file is evaluated by the Dart vector test, so patterns avoid inline flags (S-221).
 */
class Recipes(
    val version: Int,
    val maxAmountPaise: Long,
    val apps: List<RecipeApp>,
    val ignore: List<RecipeRule>,
    val debit: List<RecipeRule>,
    val refs: List<Regex>,
    val payeeReject: Regex,
    val pin: Regex,
    val paying: Regex,
    val success: List<RecipeRule>,
) {
    private val byPackage = apps.associateBy { it.packageName }

    /** The allow-listed app for [pkg], or null. Debug-only apps (fake UPI app, adb shell) need [debug]. */
    fun app(pkg: String, debug: Boolean): RecipeApp? = byPackage[pkg]?.takeIf { debug || !it.debugOnly }

    /** Every package the services may read in this build. */
    fun packages(debug: Boolean): List<String> = apps.filter { debug || !it.debugOnly }.map { it.packageName }

    companion object {
        const val ASSET = "payment_recipes.json"

        fun parse(json: String): Recipes {
            val o = JSONObject(json)
            val screen = o.getJSONObject("screen")
            return Recipes(
                version = o.getInt("version"),
                maxAmountPaise = o.getLong("maxAmountPaise"),
                apps = o.getJSONArray("apps").objects().map {
                    RecipeApp(
                        packageName = it.getString("package"),
                        name = it.getString("name"),
                        kind = AppKind.valueOf(it.getString("kind").uppercase()),
                        defaultOn = it.optBoolean("defaultOn", true),
                        debugOnly = it.optBoolean("debugOnly", false),
                    )
                },
                ignore = o.getJSONArray("ignore").rules(),
                debit = o.getJSONArray("debit").rules(),
                refs = o.getJSONArray("refs").strings().map { Regex(it, RegexOption.IGNORE_CASE) },
                payeeReject = Regex(o.getString("payeeReject"), RegexOption.IGNORE_CASE),
                pin = Regex(screen.getString("pin"), RegexOption.IGNORE_CASE),
                paying = Regex(screen.getString("paying"), RegexOption.IGNORE_CASE),
                success = screen.getJSONArray("success").rules(),
            )
        }

        private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }

        private fun JSONArray.strings(): List<String> = (0 until length()).map { getString(it) }

        private fun JSONArray.rules(): List<RecipeRule> = objects().map {
            RecipeRule(it.getString("id"), it.getString("pattern"), if (it.has("unless")) it.getString("unless") else null)
        }
    }
}
