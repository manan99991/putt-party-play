package org.json
class JSONException(m: String) : RuntimeException(m)
private class P(val s: String) { var i = 0
    fun ws() { while (i < s.length && s[i].isWhitespace()) i++ }
    fun value(): Any? { ws(); return when (s[i]) { '{' -> obj(); '[' -> arr(); '"' -> str()
        't' -> { i += 4; true }; 'f' -> { i += 5; false }; 'n' -> { i += 4; null }
        else -> { val st = i; while (i < s.length && (s[i].isDigit() || s[i] in "+-.eE")) i++; val t = s.substring(st, i); t.toIntOrNull() ?: t.toLongOrNull() ?: t.toDouble() } } }
    fun str(): String { i++; val b = StringBuilder(); while (s[i] != '"') { if (s[i] == '\\') { i++; when (s[i]) { 'n' -> b.append('\n'); 't' -> b.append('\t'); 'r' -> b.append('\r'); 'u' -> { b.append(s.substring(i + 1, i + 5).toInt(16).toChar()); i += 4 }; else -> b.append(s[i]) } } else b.append(s[i]); i++ }; i++; return b.toString() }
    fun obj(): JSONObject { i++; val o = JSONObject(); ws(); if (s[i] == '}') { i++; return o }; while (true) { ws(); val k = str(); ws(); i++; o.put(k, value()); ws(); if (s[i] == ',') { i++; continue }; i++; return o } }
    fun arr(): JSONArray { i++; val a = JSONArray(); ws(); if (s[i] == ']') { i++; return a }; while (true) { a.put(value()); ws(); if (s[i] == ',') { i++; continue }; i++; return a } }
}
private fun q(v: Any?): String = when (v) { null -> "null"; is String -> "\"" + v.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n") + "\""; else -> v.toString() }
class JSONObject() {
    val m = LinkedHashMap<String, Any?>()
    constructor(src: String) : this() { try { m.putAll(P(src).obj().m) } catch (e: Exception) { throw JSONException("bad json") } }
    constructor(map: Map<*, *>) : this() { map.forEach { (k, v) -> m[k.toString()] = v } }
    fun put(k: String, v: Any?): JSONObject { m[k] = v; return this }
    fun put(k: String, v: Boolean): JSONObject { m[k] = v; return this }
    fun put(k: String, v: Int): JSONObject { m[k] = v; return this }
    fun getString(k: String): String = m[k] as? String ?: throw JSONException(k)
    fun getJSONArray(k: String): JSONArray = m[k] as? JSONArray ?: throw JSONException(k)
    fun getJSONObject(k: String): JSONObject = m[k] as? JSONObject ?: throw JSONException(k)
    fun optJSONObject(k: String): JSONObject? = m[k] as? JSONObject
    fun optJSONArray(k: String): JSONArray? = m[k] as? JSONArray
    fun optString(k: String, d: String = ""): String = m[k]?.toString() ?: d
    fun optString(k: String): String = optString(k, "")
    fun optBoolean(k: String, d: Boolean = false): Boolean = m[k] as? Boolean ?: d
    fun optInt(k: String, d: Int = 0): Int = (m[k] as? Number)?.toInt() ?: d
    fun keys(): Iterator<String> = m.keys.iterator()
    override fun toString() = m.entries.joinToString(",", "{", "}") { q(it.key) + ":" + q(it.value) }
}
class JSONArray() {
    val l = ArrayList<Any?>()
    constructor(c: Collection<*>) : this() { l.addAll(c) }
    constructor(src: String) : this() { l.addAll(P(src).arr().l) }
    fun put(v: Any?): JSONArray { l.add(v); return this }
    fun length() = l.size
    fun getJSONObject(i: Int) = l[i] as JSONObject
    fun optInt(i: Int): Int = (l[i] as? Number)?.toInt() ?: 0
    override fun toString() = l.joinToString(",", "[", "]") { q(it) }
}
