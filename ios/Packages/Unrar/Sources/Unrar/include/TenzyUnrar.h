#ifndef TENZY_UNRAR_H
#define TENZY_UNRAR_H
#ifdef __cplusplus
extern "C" {
#endif

enum { TZ_RAR_OK = 0, TZ_RAR_BAD = 1, TZ_RAR_LOCKED = 2, TZ_RAR_TOO_BIG = 3 };

typedef struct { char name[2048]; unsigned long long size; int isDir; int locked; } TzRarEntry;

/// Every entry in a .rar (free the list with tz_rar_free). Returns TZ_RAR_OK, TZ_RAR_LOCKED or TZ_RAR_BAD.
int tz_rar_list(const char *path, TzRarEntry **entries, int *count);
/// One entry's bytes, decoded in memory (free with tz_rar_free). Stops past `limit` bytes with TZ_RAR_TOO_BIG.
int tz_rar_read(const char *path, const char *entry, unsigned long long limit, unsigned char **data, unsigned long long *size);
void tz_rar_free(void *p);

#ifdef __cplusplus
}
#endif
#endif
