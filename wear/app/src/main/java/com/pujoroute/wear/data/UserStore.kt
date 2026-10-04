package com.pujoroute.wear.data

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.edit

/** Tiny SharedPreferences-backed store (passport stamps, bookmarks, active route, Panjika mode). */
class UserStore private constructor(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("pujoroute_wear", Context.MODE_PRIVATE)
    private val onChange = mutableListOf<() -> Unit>()

    var visited by mutableStateOf(prefs.getStringSet(K_VISITED, emptySet())!!.toSet()); private set
    var bookmarks by mutableStateOf(prefs.getStringSet(K_BOOKMARKS, emptySet())!!.toSet()); private set
    var route by mutableStateOf(prefs.getString(K_ROUTE, "")!!.split(',').filter { it.isNotBlank() }); private set
    var routeDone by mutableStateOf(prefs.getStringSet(K_ROUTE_DONE, emptySet())!!.toSet()); private set
    var beniMadhab by mutableStateOf(prefs.getBoolean(K_BENI, false)); private set

    fun addListener(l: () -> Unit) { onChange += l }

    private fun changed() = onChange.forEach { it() }

    fun toggleVisited(id: String) {
        visited = visited.toggle(id); prefs.edit { putStringSet(K_VISITED, visited) }; changed()
    }

    fun toggleBookmark(id: String) {
        bookmarks = bookmarks.toggle(id); prefs.edit { putStringSet(K_BOOKMARKS, bookmarks) }
    }

    fun saveRoute(ids: List<String>) {
        route = ids; routeDone = emptySet()
        prefs.edit { putString(K_ROUTE, ids.joinToString(",")); putStringSet(K_ROUTE_DONE, emptySet()) }
        changed()
    }

    /** Marking a stop done also stamps it in the passport. */
    fun toggleDone(id: String) {
        val nowDone = id !in routeDone
        routeDone = routeDone.toggle(id)
        if (nowDone && id !in visited) {
            visited = visited + id; prefs.edit { putStringSet(K_VISITED, visited) }
        }
        prefs.edit { putStringSet(K_ROUTE_DONE, routeDone) }
        changed()
    }

    fun updateBeniMadhab(on: Boolean) {
        beniMadhab = on; prefs.edit { putBoolean(K_BENI, on) }
    }

    /** First stop on the active route that is not done yet. */
    fun nextStopId(): String? = route.firstOrNull { it !in routeDone }

    private fun Set<String>.toggle(id: String) = if (id in this) this - id else this + id

    companion object {
        private const val K_VISITED = "visited"
        private const val K_BOOKMARKS = "bookmarks"
        private const val K_ROUTE = "route"
        private const val K_ROUTE_DONE = "route_done"
        private const val K_BENI = "beni_madhab"

        @Volatile private var instance: UserStore? = null
        fun get(context: Context): UserStore =
            instance ?: synchronized(this) { instance ?: UserStore(context).also { instance = it } }
    }
}
