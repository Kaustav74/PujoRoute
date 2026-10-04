package com.pujoroute.wear.data

/** Badges ported from the phone app's Pandal Passport (pandal_passport_screen.dart). */
data class Badge(val id: String, val icon: String, val title: String, val rule: String, val unlocked: Boolean)

object Passport {
    fun badges(visited: Set<String>, byId: Map<String, Pandal>): List<Badge> {
        val v = visited.mapNotNull { byId[it] }
        fun count(f: (Pandal) -> Boolean) = v.count(f)
        return listOf(
            Badge("dhunuchi_master", "🪔", "Dakshin Kolkata Dhunuchi Master", "5 South mega pandals",
                count { it.zone == "South" && !it.isHeritage } >= 5),
            Badge("bonedi_explorer", "🏛", "Bonedi Bari Heritage Explorer", "3 heritage baris",
                count { it.isHeritage } >= 3),
            Badge("uttar_kolkata_sholoana", "🌊", "Uttar Kolkata Sholoana Bangali", "4 North pandals",
                count { it.zone == "North" } >= 4),
            Badge("saltlake_cosmo", "🏙", "Salt Lake Cosmopolitan Hopping", "3 Salt Lake pandals",
                count { it.zone == "Salt Lake" } >= 3),
            Badge("midnight_legend", "🔥", "Midnight All-Night Hopping Legend", "8 check-ins",
                visited.size >= 8),
            Badge("food_addabaaj", "🥟", "Kolkata Street Food Addabaaj", "Maddox / College Sq / Kumartuli / Ballygunge",
                visited.any { id -> listOf("maddox", "college", "kumartuli", "ballygunge").any { it in id } }),
        )
    }

    fun level(visitedCount: Int): String = when {
        visitedCount >= 15 -> "Maha Pandal Samrat"
        visitedCount >= 10 -> "Kolkata Street Legend"
        visitedCount >= 6 -> "Dhunuchi Master"
        visitedCount >= 3 -> "Active Pujo Explorer"
        else -> "Pujo Newcomer"
    }
}
