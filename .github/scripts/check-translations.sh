#!/usr/bin/env bash

set -euxo pipefail

# Check that all POs are formatted the way gettext writes them. Otherwise
# the next `zig build update-translations` reformats them, which shows up
# as unrelated changes in that PR. This must run before we update them.
for f in po/*.po; do
  if ! msgcat "$f" | diff -u "$f" -; then
    echo "error: $f isn't formatted by gettext, run: msgcat -o $f $f" >&2
    exit 1
  fi
done

old_pot=$(mktemp)
cp po/com.mitchellh.ghostty.pot "$old_pot"
zig build update-translations

# Compare previous POT to current POT
msgcmp "$old_pot" po/com.mitchellh.ghostty.pot --use-untranslated

# Compare all other POs to current POT
for f in po/*.po; do
  # Ignore untranslated entries
  msgcmp --use-untranslated "$f" po/com.mitchellh.ghostty.pot;
done
