package dev.kidremote.accounting.storage;
import androidx.annotation.NonNull;
import androidx.room.Entity;
import androidx.room.PrimaryKey;
import androidx.room.ColumnInfo;
@Entity(tableName="ledger")
public class LedgerRow {
    @PrimaryKey public int id=1;
    @NonNull public byte[] payload=new byte[0];
    @ColumnInfo(defaultValue="0") public long revision=0;
}
