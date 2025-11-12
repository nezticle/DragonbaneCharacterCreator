#ifndef SQLITE_SNAPSHOT_SHIMS_H
#define SQLITE_SNAPSHOT_SHIMS_H

#include <sqlite3.h>

// Declare the fallback snapshot APIs so SwiftPM has a public header for the C target.

#if defined(__linux__) && !defined(SQLITE_ENABLE_SNAPSHOT)
int sqlite3_snapshot_get(sqlite3 *db, const char *zDb, sqlite3_snapshot **ppSnapshot);
int sqlite3_snapshot_open(sqlite3 *db, const char *zDb, sqlite3_snapshot *pSnapshot);
void sqlite3_snapshot_free(sqlite3_snapshot *pSnapshot);
int sqlite3_snapshot_cmp(sqlite3_snapshot *p1, sqlite3_snapshot *p2);
int sqlite3_snapshot_recover(sqlite3 *db, const char *zDb);
#endif

#endif /* SQLITE_SNAPSHOT_SHIMS_H */
