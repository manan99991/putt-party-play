package com.handytools.app.tools.builder

/**
 * The pure field map behind the thinking tools' "Save contact" hand-off: a task's person as a name
 * (guessed from the task), plus any number and email it names. Deterministic and unit-tested; the iOS twin
 * (`ThinkingContacts.swift`) uses the same rules. On Android the save itself is an ACTION_INSERT intent
 * that opens the contact editor prefilled (the person confirms), so this object holds only the mapping.
 */
object ThinkingContacts {
    data class Field(val name: String, val phone: String?, val email: String?)

    /** Lead verbs and filler stripped before guessing a name, so "call the dentist" → "Dentist". */
    private val filler = setOf(
        "call", "text", "phone", "ring", "dial", "email", "message", "ask", "contact", "reach", "follow",
        "up", "with", "the", "to", "a", "about", "re",
    )

    /** A best-effort contact from a task, or null when there's no number or email to save. */
    fun field(task: ThinkingEngine.Task): Field? {
        val phone = task.actions.phone
        val email = ThinkingActions.emailIn(task.text)
        if (phone == null && email == null) return null
        return Field(guessName(task.text, phone, email), phone, email)
    }

    /** Guess a contact name: the email's local part when there is an email (landlord@… → "Landlord"),
     * otherwise the first meaningful word left after dropping the lead verb, the number and the email. */
    fun guessName(task: String, phone: String?, email: String?): String {
        if (email != null) {
            val letters = email.substringBefore("@").split(Regex("[^A-Za-z]+")).filter { it.isNotEmpty() }
            letters.firstOrNull()?.let { return it.replaceFirstChar { c -> c.uppercase() } }
        }
        var s = task
        if (phone != null) s = s.replace(phone, " ")
        if (email != null) s = s.replace(email, " ")
        val words = s.split(Regex("[^A-Za-z]+")).filter { it.isNotEmpty() && it.lowercase() !in filler }
        words.firstOrNull()?.let { return it.replaceFirstChar { c -> c.uppercase() } }
        return "New contact"
    }
}
