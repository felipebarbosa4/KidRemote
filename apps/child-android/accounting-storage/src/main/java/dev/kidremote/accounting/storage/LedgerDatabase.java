package dev.kidremote.accounting.storage;
import androidx.room.*;
import androidx.room.migration.Migration;
import androidx.sqlite.db.SupportSQLiteDatabase;
import androidx.annotation.NonNull;
@Database(entities={LedgerRow.class},version=2,exportSchema=false)
public abstract class LedgerDatabase extends RoomDatabase {
    public abstract LedgerDao ledger();
    // Initial local schema v1 -> v2 adds only a transaction revision; never destructive fallback.
    public static final Migration MIGRATION_1_2=new Migration(1,2) {
        @Override public void migrate(@NonNull SupportSQLiteDatabase db) {
            db.execSQL("ALTER TABLE ledger ADD COLUMN revision INTEGER NOT NULL DEFAULT 0");
        }
    };
}
