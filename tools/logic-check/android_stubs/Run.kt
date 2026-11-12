fun main() {
    val c = Class.forName("com.handytools.app.tools.builder.BuilderLogicTest")
    var pass = 0; var fail = 0
    for (m in c.declaredMethods.filter { it.isAnnotationPresent(org.junit.Test::class.java) }.sortedBy { it.name }) {
        try { m.invoke(c.getDeclaredConstructor().newInstance()); pass++ } catch (e: java.lang.reflect.InvocationTargetException) { fail++; println("FAIL ${m.name}: ${e.targetException}") }
    }
    println("passed $pass failed $fail")
}
