package dev.kidremote.accounting.storage;
import androidx.room.*;
@Dao public interface LedgerDao {
    @Query("SELECT * FROM ledger WHERE id=1") LedgerRow read();
    @Insert(onConflict=OnConflictStrategy.REPLACE) void write(LedgerRow row);
    @Query("DELETE FROM ledger") void clear();
}
