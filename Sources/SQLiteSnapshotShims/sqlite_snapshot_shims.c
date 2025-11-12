#include <stddef.h>
#include <sqlite3.h>

#if defined(__linux__) && !defined(SQLITE_ENABLE_SNAPSHOT)

// Provide weak stub implementations of the snapshot APIs when the
// Linux system SQLite library is built without SQLITE_ENABLE_SNAPSHOT.
// GRDB references these symbols on Linux, but many distributions ship
// SQLite without snapshot support which results in missing symbols at
// link time. Returning SQLITE_ERROR mirrors SQLite's behavior when the
// feature is unavailable and lets GRDB gracefully fall back to its
// non-snapshot code paths.

__attribute__((weak))
int sqlite3_snapshot_get(sqlite3 *db, const char *zDb, sqlite3_snapshot **ppSnapshot) {
    if (ppSnapshot) {
        *ppSnapshot = NULL;
    }
    (void)db;
    (void)zDb;
    return SQLITE_ERROR;
}

__attribute__((weak))
int sqlite3_snapshot_open(sqlite3 *db, const char *zDb, sqlite3_snapshot *pSnapshot) {
    (void)db;
    (void)zDb;
    (void)pSnapshot;
    return SQLITE_ERROR;
}

__attribute__((weak))
void sqlite3_snapshot_free(sqlite3_snapshot *pSnapshot) {
    (void)pSnapshot;
}

__attribute__((weak))
int sqlite3_snapshot_cmp(sqlite3_snapshot *p1, sqlite3_snapshot *p2) {
    (void)p1;
    (void)p2;
    return 0;
}

__attribute__((weak))
int sqlite3_snapshot_recover(sqlite3 *db, const char *zDb) {
    (void)db;
    (void)zDb;
    return SQLITE_ERROR;
}

#endif
