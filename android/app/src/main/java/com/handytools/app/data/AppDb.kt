package com.handytools.app.data

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Delete
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

// ---------- Tool 1: clipboard stack ----------
@Entity(tableName = "clips")
data class Clip(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val text: String,
    val sourceApp: String?,
    val createdAt: Long = System.currentTimeMillis(),
    val pinned: Boolean = false
)

@Dao
interface ClipDao {
    @Query("SELECT * FROM clips ORDER BY pinned DESC, createdAt DESC LIMIT 200")
    fun all(): Flow<List<Clip>>
    @Query("SELECT * FROM clips ORDER BY pinned DESC, createdAt DESC LIMIT 200")
    suspend fun allOnce(): List<Clip>
    @Query("SELECT text FROM clips ORDER BY createdAt DESC LIMIT 1")
    suspend fun latestText(): String?
    @Insert suspend fun insert(c: Clip): Long
    @Update suspend fun update(c: Clip)
    @Delete suspend fun delete(c: Clip)
    @Query("DELETE FROM clips WHERE pinned = 0") suspend fun clearUnpinned()
}

// ---------- Tool 5: alarms ----------
@Entity(tableName = "alarms")
data class Alarm(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val hour: Int,
    val minute: Int,
    val label: String = "",
    val enabled: Boolean = true,
    /** Bitmask Sun=1, Mon=2, Tue=4, Wed=8, Thu=16, Fri=32, Sat=64. 0 = one-shot. */
    val repeatDays: Int = 0,
    /** 0..100, independent of system alarm volume. */
    val volume: Int = 80,
    /** Minutes. The feature iOS still doesn't have. */
    val snoozeMinutes: Int = 9,
    /** Max snoozes allowed (0 = unlimited). */
    val maxSnoozes: Int = 0,
    /** Ramp volume from quiet to [volume] over this many seconds. 0 = off. */
    val gradualSeconds: Int = 30,
    val vibrate: Boolean = true,
    /** URI string; null = default alarm sound. */
    val soundUri: String? = null,
    /** Require a quick math problem to dismiss. */
    val mathToDismiss: Boolean = false,
    /** Auto-stop after this many minutes of ringing. */
    val timeoutMinutes: Int = 10,
    /** Snooze count for the currently ringing instance. */
    val snoozedCount: Int = 0,
    /** If set, the next ring is this exact time (snooze), not the schedule. */
    val snoozeUntil: Long? = null
)

@Dao
interface AlarmDao {
    @Query("SELECT * FROM alarms ORDER BY hour, minute") fun all(): Flow<List<Alarm>>
    @Query("SELECT * FROM alarms") suspend fun allOnce(): List<Alarm>
    @Query("SELECT * FROM alarms WHERE id = :id") suspend fun byId(id: Long): Alarm?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(a: Alarm): Long
    @Delete suspend fun delete(a: Alarm)
}

// ---------- Tool 8: notification history ----------
@Entity(tableName = "notifs")
data class NotifEntry(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val pkg: String,
    val appName: String,
    val title: String,
    val text: String,
    val postedAt: Long,
    val dismissedAt: Long? = null
)

@Dao
interface NotifDao {
    @Query("SELECT * FROM notifs ORDER BY postedAt DESC LIMIT 500") fun all(): Flow<List<NotifEntry>>
    @Insert suspend fun insert(n: NotifEntry)
    @Query("UPDATE notifs SET dismissedAt = :t WHERE pkg = :pkg AND title = :title AND text = :text AND dismissedAt IS NULL")
    suspend fun markDismissed(pkg: String, title: String, text: String, t: Long)
    @Query("DELETE FROM notifs") suspend fun clear()
    @Query("DELETE FROM notifs WHERE postedAt < :before") suspend fun prune(before: Long)
}

// ---------- Tool 9: scratchpad ----------
@Entity(tableName = "notes")
data class Note(
    @PrimaryKey val id: Int = 1,
    val text: String = "",
    val updatedAt: Long = System.currentTimeMillis()
)

@Dao
interface NoteDao {
    @Query("SELECT * FROM notes WHERE id = 1") fun get(): Flow<Note?>
    @Query("SELECT * FROM notes WHERE id = 1") suspend fun getOnce(): Note?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun save(n: Note)
}

@Database(entities = [Clip::class, Alarm::class, NotifEntry::class, Note::class], version = 1, exportSchema = false)
abstract class AppDb : RoomDatabase() {
    abstract fun clips(): ClipDao
    abstract fun alarms(): AlarmDao
    abstract fun notifs(): NotifDao
    abstract fun notes(): NoteDao

    companion object {
        @Volatile private var inst: AppDb? = null
        fun get(ctx: Context): AppDb = inst ?: synchronized(this) {
            inst ?: Room.databaseBuilder(ctx.applicationContext, AppDb::class.java, "handytools.db")
                .fallbackToDestructiveMigration()
                .build().also { inst = it }
        }
    }
}
