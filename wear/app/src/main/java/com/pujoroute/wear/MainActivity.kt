package com.pujoroute.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.pujoroute.wear.data.PujoRepository
import com.pujoroute.wear.data.UserStore
import com.pujoroute.wear.ui.PujoApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val repo = PujoRepository.get(this)
        val store = UserStore.get(this)
        setContent { PujoApp(repo, store) }
    }
}
