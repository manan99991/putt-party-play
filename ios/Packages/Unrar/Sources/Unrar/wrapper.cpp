// Tenzy's small C bridge to UnRAR's DLL interface: list a .rar and read one file from it into memory, nothing
// written to disk. UnRAR source code may be used in any software to handle RAR archives without limitations free
// of charge, but cannot be used to develop RAR (WinRAR) compatible archiver and to re-create RAR compression
// algorithm, which is proprietary. Distribution of modified UnRAR source code in separate form or as a part of
// other software is permitted, provided that full text of this paragraph, starting from "UnRAR source code" words,
// is included in license, or in documentation if license is not available, and in source code comments of
// resulting package.
#include "rar.hpp"
#include "dll.hpp"
#include "TenzyUnrar.h"
#include <stdlib.h>
#include <string.h>

struct Collect { unsigned char *buf; unsigned long long len, cap, limit; int overflow; };

static int CALLBACK collect(UINT msg, LPARAM user, LPARAM p1, LPARAM p2) {
  if (msg == UCM_NEEDPASSWORD || msg == UCM_NEEDPASSWORDW) return -1;   // locked: stop, never guess
  if (msg == UCM_CHANGEVOLUME || msg == UCM_CHANGEVOLUMEW) return p2 == RAR_VOL_NOTIFY ? 1 : -1;
  if (msg != UCM_PROCESSDATA) return 1;
  Collect *c = (Collect *)user;
  if (!c) return 1;
  unsigned long long n = (unsigned long long)p2;
  if (c->len + n > c->limit) { c->overflow = 1; return -1; }
  if (c->len + n > c->cap) {
    unsigned long long nc = c->cap ? c->cap : 65536;
    while (nc < c->len + n) nc *= 2;
    unsigned char *nb = (unsigned char *)realloc(c->buf, (size_t)nc);
    if (!nb) { c->overflow = 1; return -1; }
    c->buf = nb; c->cap = nc;
  }
  memcpy(c->buf + c->len, (const void *)p1, (size_t)n);
  c->len += n;
  return 1;
}

static HANDLE openArc(const char *path, unsigned int mode, int *result) {
  struct RAROpenArchiveDataEx d;
  memset(&d, 0, sizeof(d));
  d.ArcName = (char *)path;
  d.OpenMode = mode;
  HANDLE h = RAROpenArchiveEx(&d);
  *result = (int)d.OpenResult;
  return h;
}

int tz_rar_list(const char *path, TzRarEntry **out, int *count) {
  *out = NULL; *count = 0;
  int r = 0;
  HANDLE h = openArc(path, RAR_OM_LIST, &r);
  if (!h || r != ERAR_SUCCESS) { if (h) RARCloseArchive(h); return r == ERAR_MISSING_PASSWORD || r == ERAR_BAD_PASSWORD ? TZ_RAR_LOCKED : TZ_RAR_BAD; }
  int cap = 64, n = 0, status = TZ_RAR_OK;
  TzRarEntry *list = (TzRarEntry *)calloc((size_t)cap, sizeof(TzRarEntry));
  struct RARHeaderDataEx hd;
  for (;;) {
    memset(&hd, 0, sizeof(hd));
    int rh = RARReadHeaderEx(h, &hd);
    if (rh == ERAR_END_ARCHIVE) break;
    if (rh != ERAR_SUCCESS) { status = rh == ERAR_MISSING_PASSWORD ? TZ_RAR_LOCKED : (n ? TZ_RAR_OK : TZ_RAR_BAD); break; }
    if (n == cap) { cap *= 2; TzRarEntry *nl = (TzRarEntry *)realloc(list, (size_t)cap * sizeof(TzRarEntry)); if (!nl) break; list = nl; }
    TzRarEntry *e = &list[n++];
    memset(e, 0, sizeof(*e));
    WideToUtf(hd.FileNameW, e->name, sizeof(e->name));
    if (!e->name[0]) strncpy(e->name, hd.FileName, sizeof(e->name) - 1);
    e->size = ((unsigned long long)hd.UnpSizeHigh << 32) | hd.UnpSize;
    e->isDir = (hd.Flags & RHDF_DIRECTORY) ? 1 : 0;
    e->locked = (hd.Flags & RHDF_ENCRYPTED) ? 1 : 0;
    if (RARProcessFile(h, RAR_SKIP, NULL, NULL) != ERAR_SUCCESS) break;
  }
  RARCloseArchive(h);
  *out = list; *count = n;
  return status;
}

int tz_rar_read(const char *path, const char *entry, unsigned long long limit, unsigned char **data, unsigned long long *size) {
  *data = NULL; *size = 0;
  int r = 0;
  HANDLE h = openArc(path, RAR_OM_EXTRACT, &r);
  if (!h || r != ERAR_SUCCESS) { if (h) RARCloseArchive(h); return TZ_RAR_BAD; }
  Collect c = {NULL, 0, 0, limit, 0};
  int status = TZ_RAR_BAD;
  struct RARHeaderDataEx hd;
  for (;;) {
    memset(&hd, 0, sizeof(hd));
    if (RARReadHeaderEx(h, &hd) != ERAR_SUCCESS) break;
    char name[2048];
    WideToUtf(hd.FileNameW, name, sizeof(name));
    if (!name[0]) strncpy(name, hd.FileName, sizeof(name) - 1);
    if (strcmp(name, entry) == 0) {
      RARSetCallback(h, collect, (LPARAM)&c);
      int pr = RARProcessFile(h, RAR_TEST, NULL, NULL);   // decode to the callback only; nothing touches disk
      status = c.overflow ? TZ_RAR_TOO_BIG : (pr == ERAR_SUCCESS ? TZ_RAR_OK : (pr == ERAR_MISSING_PASSWORD || pr == ERAR_BAD_PASSWORD ? TZ_RAR_LOCKED : TZ_RAR_BAD));
      break;
    }
    RARSetCallback(h, NULL, 0);
    if (RARProcessFile(h, RAR_SKIP, NULL, NULL) != ERAR_SUCCESS) break;
  }
  RARCloseArchive(h);
  if (status == TZ_RAR_OK) { *data = c.buf; *size = c.len; } else free(c.buf);
  return status;
}

void tz_rar_free(void *p) { free(p); }
