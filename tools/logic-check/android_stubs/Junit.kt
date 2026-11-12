package org.junit
@Retention(AnnotationRetention.RUNTIME) annotation class Test
object Assert {
    @JvmStatic fun assertEquals(a: Any?, b: Any?) { if (a != b) throw AssertionError("expected <$a> but was <$b>") }
    @JvmStatic fun assertEquals(a: Double, b: Double, d: Double) { if (Math.abs(a - b) > d) throw AssertionError("expected <$a> but was <$b>") }
    @JvmStatic fun assertEquals(a: Float, b: Float, d: Float) { if (Math.abs(a - b) > d) throw AssertionError("expected <$a> but was <$b>") }
    @JvmStatic fun assertTrue(b: Boolean) { if (!b) throw AssertionError("expected true") }
    @JvmStatic fun assertFalse(b: Boolean) { if (b) throw AssertionError("expected false") }
    @JvmStatic fun assertNull(a: Any?) { if (a != null) throw AssertionError("expected null but was <$a>") }
    @JvmStatic fun assertNull(m: String, a: Any?) { if (a != null) throw AssertionError("$m: expected null but was <$a>") }
    @JvmStatic fun assertTrue(m: String, b: Boolean) { if (!b) throw AssertionError("$m: expected true") }
    @JvmStatic fun assertEquals(m: String, a: Any?, b: Any?) { if (a != b) throw AssertionError("$m: expected <$a> but was <$b>") }
    @JvmStatic fun assertNotNull(a: Any?) { if (a == null) throw AssertionError("expected not null") }
}
