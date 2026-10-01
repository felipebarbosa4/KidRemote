# Fixed OD-51 diagnostic: one bounded base-file read; never repair AtomicFile.
set -u
fail() { printf 'OD51RETRY|%s\n' "$1"; exit 0; }
p=no_backup/sync-retry
[ ! -L no_backup ] && [ ! -L "$p" ] || fail NONREGULAR
[ -e no_backup ] || fail MISSING
[ -d no_backup ] || fail NONREGULAR
[ -r no_backup ] && [ -x no_backup ] || fail UNREADABLE
[ -e "$p" ] || fail MISSING
[ -f "$p" ] || fail NONREGULAR
[ -r "$p" ] || fail UNREADABLE
size=$(stat -c '%s' "$p" 2>/dev/null) || fail UNREADABLE
case "$size" in ''|*[!0-9]*) fail UNREADABLE ;; esac
[ "$size" -le 1024 ] || fail TOO_LARGE
before=$(stat -c '%i:%s:%Y:%Z' "$p" 2>/dev/null) || fail UNREADABLE
printf 'OD51RETRY|DATA\n'
head -c 1025 "$p" 2>/dev/null || { printf '\nOD51RETRY|READ_FAILED\n'; exit 0; }
after=$(stat -c '%i:%s:%Y:%Z' "$p" 2>/dev/null) || { printf '\nOD51RETRY|CHANGED\n'; exit 0; }
if [ -L "$p" ] || [ "$before" != "$after" ]; then printf '\nOD51RETRY|CHANGED\n'; else printf '\nOD51RETRY|END\n'; fi
