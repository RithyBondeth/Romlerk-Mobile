package com.example.romlerk_mobile

import android.os.Build
import android.util.Log
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

/**
 * Android side of the `dev.romlerk/local_ai` channel.
 *
 * Backed by Gemini Nano through ML Kit's GenAI Prompt API where the device
 * supports it. Everywhere else it reports that state honestly and the Dart
 * capability router runs the deterministic parser instead.
 *
 * Unlike the iOS adapter, this asks the model for JSON and parses it rather
 * than using ML Kit's typed structured output, which currently needs a KSP
 * plugin plus an alpha schema compiler. `DraftCodec` on the Dart side already
 * validates this payload as untrusted input, so malformed JSON simply becomes
 * `OUTPUT_INVALID` and the rules parser takes over — the designed behaviour,
 * not a workaround.
 */
class LocalAiBridge(messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {

    private companion object {
        const val CHANNEL = "dev.romlerk/local_ai"
        const val TAG = "RomlerkLocalAi"

        /** Bumped in lockstep with `TaskParseResult.currentSchemaVersion`. */
        const val SCHEMA_VERSION = 1

        const val MAX_INPUT_CHARACTERS = 1000
        const val MAX_TITLE_LENGTH = 200
        const val MAX_TASKS = 8

        // Wire values of LocalAiErrorCode. Every one degrades to tier C.
        const val MODEL_UNAVAILABLE = "MODEL_UNAVAILABLE"
        const val MODEL_NOT_READY = "MODEL_NOT_READY"
        const val BUSY_OR_QUOTA = "BUSY_OR_QUOTA"
        const val BACKGROUND_BLOCKED = "BACKGROUND_BLOCKED"
        const val OUTPUT_INVALID = "OUTPUT_INVALID"
        const val CANCELLED = "CANCELLED"
        const val INPUT_TOO_LONG = "INPUT_TOO_LONG"
        const val UNKNOWN = "UNKNOWN"

        /**
         * ML Kit GenAI declares minSdk 26 while the app supports 24. The
         * library is force-merged in the manifest, so this guard is what
         * actually keeps an older device from ever loading those classes.
         */
        val ML_KIT_SUPPORTED = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
    }

    private val channel = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler(this@LocalAiBridge)
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val inFlight = mutableMapOf<String, Job>()

    /**
     * ML Kit GenAI is foreground-only, and the BRD forbids background
     * generative work outright. MainActivity keeps this in step with the
     * activity lifecycle.
     */
    @Volatile
    var isForeground: Boolean = true

    fun dispose() {
        inFlight.values.forEach(Job::cancel)
        inFlight.clear()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> capabilities(result)
            "parseTasks" -> parseTasks(call, result)
            // Not offered: the capability payload never advertises
            // durationEstimate, so Dart does not route here.
            "estimateDuration" -> result.success(null)
            "cancel" -> {
                inFlight.remove(call.argument<String>("requestId"))?.cancel()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // ---------------------------------------------------------- capabilities

    private fun capabilities(result: MethodChannel.Result) {
        scope.launch {
            val payload = mutableMapOf<String, Any?>(
                "provider" to "mlKitGenAI",
                "features" to listOf("structuredText"),
                // Gemini Nano's own language coverage is narrower than the
                // device locale list, and ML Kit does not expose it, so this
                // stays empty (unrestricted) rather than claiming support the
                // runtime has not confirmed.
                "languages" to emptyList<String>(),
                "constraints" to mapOf(
                    "foregroundOnly" to true,
                    "quotaPossible" to true,
                    "maxInputCharacters" to MAX_INPUT_CHARACTERS,
                ),
            )

            if (!ML_KIT_SUPPORTED) {
                payload["availability"] = "notEligible"
                payload["reason"] = "OS_TOO_OLD"
                result.success(payload)
                return@launch
            }

            try {
                val status = withContext(Dispatchers.IO) {
                    Generation.getClient().checkStatus()
                }
                when (status) {
                    FeatureStatus.AVAILABLE ->
                        payload["availability"] = "available"

                    // Downloadable and downloading are both "eligible but not
                    // ready" (tier B): recoverable, worth a retry, and never
                    // presented as the device being unsupported.
                    FeatureStatus.DOWNLOADABLE -> {
                        payload["availability"] = "modelNotReady"
                        payload["reason"] = "MODEL_DOWNLOADABLE"
                    }

                    FeatureStatus.DOWNLOADING -> {
                        payload["availability"] = "modelNotReady"
                        payload["reason"] = "MODEL_DOWNLOADING"
                    }

                    FeatureStatus.UNAVAILABLE -> {
                        payload["availability"] = "notEligible"
                        payload["reason"] = "DEVICE_NOT_SUPPORTED"
                    }

                    else -> {
                        payload["availability"] = "unknown"
                        payload["reason"] = "UNKNOWN_STATUS"
                    }
                }
            } catch (error: Throwable) {
                // A missing AICore, an old Play services, a throwing vendor
                // call: all just mean no enhanced understanding here.
                payload["availability"] = "notEligible"
                payload["reason"] = "STATUS_CHECK_FAILED"
                Log.i(TAG, "capability check failed: ${error.javaClass.simpleName}")
            }

            result.success(payload)
        }
    }

    // --------------------------------------------------------------- parsing

    private fun parseTasks(call: MethodCall, result: MethodChannel.Result) {
        val text = call.argument<String>("text").orEmpty()
        val requestId = call.argument<String>("requestId") ?: return run {
            fail(result, UNKNOWN, "missing requestId")
        }

        if (text.isBlank()) {
            result.success(
                mapOf("schemaVersion" to SCHEMA_VERSION, "tasks" to emptyList<Any>()),
            )
            return
        }
        if (text.length > MAX_INPUT_CHARACTERS) {
            fail(result, INPUT_TOO_LONG, "length=${text.length}")
            return
        }
        if (!isForeground) {
            fail(result, BACKGROUND_BLOCKED, "app not in foreground")
            return
        }
        if (!ML_KIT_SUPPORTED) {
            fail(result, MODEL_UNAVAILABLE, "os too old")
            return
        }

        val referenceNow = call.argument<String>("referenceNow").orEmpty()
        val timezone = call.argument<String>("timezone").orEmpty()
        val locale = call.argument<String>("locale").orEmpty()
        val knownTags = call.argument<List<String>>("knownTags").orEmpty()
        val allowMultiple = call.argument<Boolean>("allowMultipleTasks") ?: true

        val job = scope.launch {
            try {
                val client = Generation.getClient()
                val status = withContext(Dispatchers.IO) { client.checkStatus() }
                if (status != FeatureStatus.AVAILABLE) {
                    // Deliberately not triggering a download here: that is a
                    // metered, user-visible action and capture is not the
                    // moment to start one silently.
                    fail(
                        result,
                        if (status == FeatureStatus.UNAVAILABLE) MODEL_UNAVAILABLE
                        else MODEL_NOT_READY,
                        "status=$status",
                    )
                    return@launch
                }

                val prompt = buildPrompt(
                    text = text,
                    referenceNow = referenceNow,
                    timezone = timezone,
                    locale = locale,
                    knownTags = knownTags,
                    allowMultiple = allowMultiple,
                )

                val raw = withContext(Dispatchers.IO) {
                    client.generateContent(prompt)
                        .candidates
                        .firstOrNull()
                        ?.text
                        .orEmpty()
                }

                val payload = encode(raw, timezone, allowMultiple)
                result.success(payload)
            } catch (error: kotlinx.coroutines.CancellationException) {
                fail(result, CANCELLED, null)
            } catch (error: Throwable) {
                fail(result, translate(error), error.javaClass.simpleName)
            } finally {
                inFlight.remove(requestId)
            }
        }
        inFlight[requestId] = job
    }

    /**
     * Asks for JSON and nothing else.
     *
     * The upcoming dates are computed here and supplied as a lookup table:
     * a small on-device model is unreliable at calendar arithmetic, and a
     * wrong date on a reminder is the single worst failure this product has.
     */
    private fun buildPrompt(
        text: String,
        referenceNow: String,
        timezone: String,
        locale: String,
        knownTags: List<String>,
        allowMultiple: Boolean,
    ): String = buildString {
        appendLine("Convert the note into task JSON. Reply with JSON only, no prose.")
        appendLine()
        appendLine("Shape:")
        appendLine(
            """{"tasks":[{"title":"","dueAt":"","priority":"none|low|medium|high",""" +
                """"tags":[],"ambiguities":[{"field":"dueAt","reason":""}]}]}""",
        )
        appendLine()
        appendLine("Rules:")
        appendLine("- title: short, actionable, sentence case, no dates or #tags in it.")
        appendLine("- dueAt: copy a date from the calendar below. Never compute one.")
        appendLine("  Format yyyy-MM-dd'T'HH:mm:ss. Empty if no date was given.")
        appendLine("- If the time is vague (\"later\", \"sometime\"), leave dueAt empty")
        appendLine("  and add an ambiguity saying what is unclear.")
        appendLine("- Never use a past date.")
        appendLine("- tags: only words the person typed with a # prefix. Otherwise [].")
        appendLine("- priority: only if signalled with words like \"urgent\" or \"!\".")
        appendLine(
            if (allowMultiple) {
                "- Split genuinely separate commitments into separate tasks."
            } else {
                "- Produce exactly one task."
            },
        )
        appendLine()
        appendLine("Now: $referenceNow ($timezone, $locale)")
        appendLine("Calendar:")
        appendLine(calendarAnchor(referenceNow, timezone))
        if (knownTags.isNotEmpty()) {
            appendLine("Existing tags: ${knownTags.joinToString(", ")}")
        }
        appendLine()
        append("Note: $text")
    }

    private fun calendarAnchor(referenceNow: String, timezone: String): String {
        val zone = runCatching { TimeZone.getTimeZone(timezone) }
            .getOrDefault(TimeZone.getDefault())
        val start = parseTimestamp(referenceNow, zone) ?: Date()

        val labels = SimpleDateFormat("EEEE yyyy-MM-dd", Locale.US)
            .apply { this.timeZone = zone }
        val calendar = Calendar.getInstance(zone).apply { time = start }

        return (0..8).joinToString("\n") { offset ->
            val line = labels.format(calendar.time)
            val suffix = when (offset) {
                0 -> " (today)"
                1 -> " (tomorrow)"
                else -> ""
            }
            calendar.add(Calendar.DAY_OF_YEAR, 1)
            "- $line$suffix"
        }
    }

    // -------------------------------------------------------------- decoding

    /**
     * Pulls the JSON object out of whatever the model said and reshapes it to
     * the channel contract.
     *
     * Only structural repair happens here — trimming, clamping, dropping
     * empties. Anything that cannot be read at all throws, which becomes
     * `OUTPUT_INVALID` and hands over to the deterministic parser.
     */
    private fun encode(
        raw: String,
        timezone: String,
        allowMultiple: Boolean,
    ): Map<String, Any?> {
        // Models frequently wrap JSON in prose or a ``` fence, so the object is
        // extracted by brace matching rather than trusting the whole string.
        val start = raw.indexOf('{')
        val end = raw.lastIndexOf('}')
        if (start < 0 || end <= start) {
            throw IllegalArgumentException("no JSON object in response")
        }

        val root = JSONObject(raw.substring(start, end + 1))
        val rawTasks = root.optJSONArray("tasks") ?: JSONArray()
        val zone = runCatching { TimeZone.getTimeZone(timezone) }
            .getOrDefault(TimeZone.getDefault())

        val tasks = mutableListOf<Map<String, Any?>>()
        val limit = if (allowMultiple) minOf(rawTasks.length(), MAX_TASKS) else 1

        for (index in 0 until minOf(rawTasks.length(), limit)) {
            val entry = rawTasks.optJSONObject(index) ?: continue
            val title = entry.optString("title").trim()
            if (title.isEmpty()) continue

            val encoded = mutableMapOf<String, Any?>(
                "title" to title.take(MAX_TITLE_LENGTH),
                "priority" to normalizePriority(entry.optString("priority")),
            )

            normalizeTimestamp(entry.optString("dueAt"), zone)?.let { dueAt ->
                encoded["dueAt"] = dueAt
                encoded["reminderAt"] = dueAt
            }

            val tags = entry.optJSONArray("tags")
            if (tags != null) {
                val cleaned = (0 until tags.length())
                    .mapNotNull { tags.optString(it).trim().removePrefix("#").ifEmpty { null } }
                    .distinct()
                    .take(10)
                if (cleaned.isNotEmpty()) encoded["tags"] = cleaned
            }

            val ambiguities = entry.optJSONArray("ambiguities")
            if (ambiguities != null) {
                val cleaned = (0 until ambiguities.length()).mapNotNull { position ->
                    val item = ambiguities.optJSONObject(position) ?: return@mapNotNull null
                    val reason = item.optString("reason").trim()
                    if (reason.isEmpty()) return@mapNotNull null
                    mapOf(
                        "field" to normalizeField(item.optString("field")),
                        "reason" to reason.take(200),
                    )
                }
                if (cleaned.isNotEmpty()) encoded["ambiguities"] = cleaned
            }

            tasks.add(encoded)
        }

        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "provider" to "mlKitGenAI",
            "tasks" to tasks,
        )
    }

    private fun normalizePriority(raw: String): String = when (raw.trim().lowercase()) {
        "low" -> "low"
        "medium" -> "medium"
        "high" -> "high"
        else -> "none"
    }

    private fun normalizeField(raw: String): String = when (raw.trim()) {
        "reminderAt", "recurrence", "startAt", "priority", "duration", "tags",
        "title", "notes",
        -> raw.trim()
        else -> "dueAt"
    }

    /** Layouts the model plausibly emits, in preference order. */
    private val layouts = listOf(
        "yyyy-MM-dd'T'HH:mm:ssXXX",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
    )

    private fun parseTimestamp(raw: String, zone: TimeZone): Date? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        for (layout in layouts) {
            val parsed = runCatching {
                SimpleDateFormat(layout, Locale.US)
                    .apply {
                        timeZone = zone
                        isLenient = false
                    }
                    .parse(trimmed)
            }.getOrNull()
            if (parsed != null) return parsed
        }
        return null
    }

    /**
     * Returns null for "no date" and a normalized offset timestamp otherwise.
     * A value that is present but unreadable throws, discarding the result.
     */
    private fun normalizeTimestamp(raw: String, zone: TimeZone): String? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty() || trimmed.equals("null", ignoreCase = true)) return null
        val parsed = parseTimestamp(trimmed, zone)
            ?: throw IllegalArgumentException("unparseable timestamp")
        return SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ssXXX", Locale.US)
            .apply { timeZone = zone }
            .format(parsed)
    }

    // ---------------------------------------------------------------- errors

    private fun translate(error: Throwable): String {
        if (error is IllegalArgumentException || error is org.json.JSONException) {
            return OUTPUT_INVALID
        }
        val name = error.javaClass.simpleName
        return when {
            name.contains("Quota", true) || name.contains("RateLimit", true) ->
                BUSY_OR_QUOTA
            name.contains("NotFound", true) || name.contains("Unavailable", true) ->
                MODEL_UNAVAILABLE
            name.contains("Download", true) -> MODEL_NOT_READY
            else -> UNKNOWN
        }
    }

    /** Error shape only, never user task text: this reaches the audit log. */
    private fun fail(result: MethodChannel.Result, code: String, details: String?) {
        Log.i(TAG, "local_ai degraded: $code ${details ?: "-"}")
        result.error(code, null, details)
    }
}
