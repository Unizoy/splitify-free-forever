package com.unizoy.splitify.capture

/** Where a capture came from: a UPI/bank app notification, a bank SMS (via the SMS app) or the screen. */
enum class CaptureSource(val wire: String) { NOTIFICATION("notification"), SMS("sms"), SCREEN("screen") }

/** A parsed debit: integer paise (never floats), optional payee and UPI ref. No raw text is kept. */
data class ParsedPayment(
    val amountPaise: Long,
    val payee: String?,
    val ref: String?,
    val source: CaptureSource,
    val rule: String,
)

/** Result of reading one notification or one screen. */
sealed interface ParseResult {
    data class Debit(val payment: ParsedPayment) : ParseResult
    data class Ignored(val reason: String) : ParseResult
}

/** What a UPI app screen shows (smart capture, source ②). */
enum class ScreenStage { NONE, PAYING, PIN, SUCCESS }

data class ScreenResult(val stage: ScreenStage, val payment: ParsedPayment? = null)

/**
 * The payment-alert parser (phase 18b T1, S-221/S-223). Pure Kotlin: the services pass in text, this returns
 * parsed fields. The same algorithm runs in `test/features/capture/recipe_evaluator.dart`; keep them in step.
 */
class PaymentParser(private val recipes: Recipes) {

    /** A notification from [pkg]. For SMS apps [title] is the sender and only [text] is read. */
    fun parseNotification(pkg: String, title: String?, text: String?, debug: Boolean): ParseResult {
        val app = recipes.app(pkg, debug) ?: return ParseResult.Ignored("app")
        val body: String
        val source: CaptureSource
        if (app.kind == AppKind.SMS) {
            val sender = TextNorm.normalize(title.orEmpty())
            if (!debug && PHONE.matches(sender)) return ParseResult.Ignored("sender")
            body = TextNorm.normalize(text.orEmpty())
            source = CaptureSource.SMS
        } else {
            body = TextNorm.joinTitle(title.orEmpty(), text.orEmpty())
            source = CaptureSource.NOTIFICATION
        }
        return parseBody(body, source, recipes.debit)
    }

    /** The flattened visible text of a screen of [pkg] (editable/password nodes already left out). */
    fun parseScreen(pkg: String, text: String, debug: Boolean): ScreenResult {
        if (recipes.app(pkg, debug) == null) return ScreenResult(ScreenStage.NONE)
        val body = TextNorm.normalize(text)
        if (recipes.pin.containsMatchIn(body)) return ScreenResult(ScreenStage.PIN)
        return when (val r = parseBody(body, CaptureSource.SCREEN, recipes.success)) {
            is ParseResult.Debit -> ScreenResult(ScreenStage.SUCCESS, r.payment)
            // A pay sheet may carry promo words; only a failure headline stops it counting as "paying".
            is ParseResult.Ignored ->
                if (r.reason != "failed" && recipes.paying.containsMatchIn(body)) {
                    ScreenResult(ScreenStage.PAYING)
                } else {
                    ScreenResult(ScreenStage.NONE)
                }
        }
    }

    private fun parseBody(body: String, source: CaptureSource, rules: List<RecipeRule>): ParseResult {
        for (rule in recipes.ignore) {
            if (rule.regex.containsMatchIn(body) && rule.unless?.containsMatchIn(body) != true) {
                return ParseResult.Ignored(rule.id)
            }
        }
        for (rule in rules) {
            val m = rule.regex.find(body) ?: continue
            val amount = TextNorm.toPaise(m.groups["amount"]?.value)
            if (amount == null || amount <= 0 || amount > recipes.maxAmountPaise) return ParseResult.Ignored("amount")
            val payee = if (rule.hasPayee) TextNorm.cleanPayee(m.groups["payee"]?.value) else null
            if (payee != null && recipes.payeeReject.matches(payee)) return ParseResult.Ignored("payee")
            val ref = (if (rule.hasRef) m.groups["ref"]?.value else null) ?: firstRef(body)
            return ParseResult.Debit(ParsedPayment(amount, payee, ref, source, rule.id))
        }
        return ParseResult.Ignored("nomatch")
    }

    private fun firstRef(body: String): String? {
        for (r in recipes.refs) {
            r.find(body)?.groups?.get("ref")?.value?.let { return it }
        }
        return null
    }

    companion object {
        /** A phone number is never a bank sender (S-223). */
        val PHONE = Regex("^\\+?[0-9][0-9 ()-]{3,}$")
    }
}

/** Text rules shared with the Dart evaluator (S-221). */
object TextNorm {
    private val spaces = Regex("[ \\t\\r\\n\\f\\u000B\\u00A0\\u2007\\u2009\\u202F]+")
    private val tail = Regex("[ .,;:-]+$")

    /** NBSP, thin spaces and newlines → one space; trimmed. */
    fun normalize(s: String): String = spaces.replace(s, " ").trim()

    /** Title and text of an app notification as one sentence-separated string. */
    fun joinTitle(title: String, text: String): String {
        val t = normalize(title)
        val b = normalize(text)
        return when {
            t.isEmpty() -> b
            b.isEmpty() -> t
            t.last() in ".!?:" -> "$t $b"
            else -> "$t. $b"
        }
    }

    /** "1,23,456.5" → 12345650 paise by string arithmetic; null when not a plain amount. */
    fun toPaise(raw: String?): Long? {
        val s = raw?.replace(",", "") ?: return null
        val parts = s.split('.')
        if (parts.size > 2 || parts[0].isEmpty() || parts[0].length > 10 || !parts[0].all { it in '0'..'9' }) return null
        val frac = if (parts.size == 2) parts[1] else ""
        if (frac.length > 2 || !frac.all { it in '0'..'9' }) return null
        return parts[0].toLong() * 100 + frac.padEnd(2, '0').toLong()
    }

    /** Trims, drops trailing punctuation, limits to 60 chars; ALL-CAPS names become Title Case. */
    fun cleanPayee(raw: String?): String? {
        var s = normalize(raw.orEmpty()).trimStart('.', ' ')
        s = tail.replace(s, "")
        if (s.isEmpty()) return null
        if (s.length > 60) s = s.substring(0, 60).trimEnd()
        val shouty = s.any { it.isLetter() } && s.none { it.isLowerCase() } && !s.contains('@')
        return if (shouty) s.split(' ').joinToString(" ") { w -> w.lowercase().replaceFirstChar { it.uppercase() } } else s
    }
}
