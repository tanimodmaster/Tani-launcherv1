#!/usr/bin/env bash
# Puts the iOS Java runtimes into ./depends/java-N-openjdk (run from the source root).
# Sources, in order:
#   1. the official AngelAuraMC asset server
#   2. java_runtimes inside the newest official Amethyst-iOS / PojavLauncher_iOS release IPA
#   3. GitHub releases: this repo (made by build-java.yml), then the iOS OpenJDK build repos
#   4. GitHub Actions artifacts of those repos
# Java 8 and 17 are required. A runtime that can't be found (e.g. 25) is removed
# from the Makefile so the build still succeeds; the versions that need it won't launch.
set -uo pipefail

ROOT="$(pwd)"
DEP="$ROOT/depends"
TMP="$(mktemp -d)"
mkdir -p "$DEP"
VERSIONS=(8 17 21 25)
REQUIRED=(8 17)

have() { [ -f "$DEP/java-$1-openjdk/release" ]; }

from_tarball_zip() { # $1=version $2=zip file containing jreN-*.tar.xz
  local d="$TMP/z$1"; rm -rf "$d"; mkdir -p "$d"
  unzip -q -o "$2" -d "$d" || return 1
  local tx; tx="$(find "$d" -name "jre$1-*.tar.xz" | head -1)"
  [ -n "$tx" ] || return 1
  mkdir -p "$DEP/java-$1-openjdk"
  tar xf "$tx" -C "$DEP/java-$1-openjdk" || return 1
  have "$1"
}

echo "== 1) official asset server"
for v in "${VERSIONS[@]}"; do
  have "$v" && continue
  if curl -fsSL --retry 2 -o "$TMP/jre$v.zip" "https://assets.angelauramc.dev/openjdk/ios-arm64/jre$v-ios-aarch64.zip"; then
    from_tarball_zip "$v" "$TMP/jre$v.zip" && echo "  java $v: ok"
  else
    echo "  java $v: not available"
  fi
done

echo "== 2) official release IPAs"
for repo in AngelAuraMC/Amethyst-iOS PojavLauncherTeam/PojavLauncher_iOS; do
  missing=0; for v in "${VERSIONS[@]}"; do have "$v" || missing=1; done
  [ $missing = 1 ] || break
  urls="$(gh api "repos/$repo/releases?per_page=15" \
    --jq '.[].assets[] | select(.name|test("\\.(ipa|tipa)$")) | select(.name|test("slimmed")|not) | .browser_download_url' 2>/dev/null | head -4)"
  for url in $urls; do
    echo "  trying $url"
    rm -rf "$TMP/ipa" && mkdir -p "$TMP/ipa"
    curl -fsSL --retry 2 -o "$TMP/app.ipa" "$url" || continue
    unzip -q -o "$TMP/app.ipa" 'Payload/*/java_runtimes/*' -d "$TMP/ipa" 2>/dev/null || continue
    for v in "${VERSIONS[@]}"; do
      have "$v" && continue
      src="$(find "$TMP/ipa" -type d -path "*/java_runtimes/java-$v-openjdk" | head -1)"
      if [ -n "$src" ]; then
        rm -rf "$DEP/java-$v-openjdk"; cp -R "$src" "$DEP/java-$v-openjdk"
        [ -f "$DEP/java-$v-openjdk/release" ] || echo "JAVA_VERSION=\"$v\"" > "$DEP/java-$v-openjdk/release"
        echo "  java $v: ok (from $repo)"
      fi
    done
    missing=0; for v in "${VERSIONS[@]}"; do have "$v" || missing=1; done
    [ $missing = 1 ] || break
  done
done

echo "== 3) openjdk build releases"
for v in "${VERSIONS[@]}"; do
  have "$v" && continue
  for repo in ${GITHUB_REPOSITORY:-} AngelAuraMC/angelauramc-openjdk-build PojavLauncherTeam/android-openjdk-build-multiarch; do
    have "$v" && break
    urls="$(gh api "repos/$repo/releases?per_page=50" \
      --jq ".[].assets[] | select(.name|test(\"ios\";\"i\")) | select(.name|test(\"(jre|jdk|java)-?$v([^0-9]|\$)\";\"i\")) | .browser_download_url" 2>/dev/null)"
    for url in $urls; do
      echo "  trying $url"
      f="$TMP/r$v.${url##*.}"
      curl -fsSL --retry 2 -o "$f" "$url" || continue
      case "$f" in
        *.zip) from_tarball_zip "$v" "$f" && echo "  java $v: ok" && break ;;
        *.xz)
          rm -rf "$DEP/java-$v-openjdk"; mkdir -p "$DEP/java-$v-openjdk"
          tar xf "$f" -C "$DEP/java-$v-openjdk" || continue
          [ -d "$DEP/java-$v-openjdk/lib" ] && [ ! -f "$DEP/java-$v-openjdk/release" ] && echo "JAVA_VERSION=\"$v\"" > "$DEP/java-$v-openjdk/release"
          have "$v" && echo "  java $v: ok (from $repo)" && break ;;
      esac
    done
  done
done

echo "== 4) openjdk build artifacts"
for v in "${VERSIONS[@]}"; do
  for repo in AngelAuraMC/angelauramc-openjdk-build PojavLauncherTeam/android-openjdk-build-multiarch; do
    have "$v" && break
    id="$(gh api "repos/$repo/actions/artifacts?name=jre$v-ios-aarch64&per_page=20" \
      --jq '[.artifacts[] | select(.expired|not)][0].id' 2>/dev/null)"
    if [ -n "$id" ] && [ "$id" != "null" ]; then
      gh api "repos/$repo/actions/artifacts/$id/zip" > "$TMP/a$v.zip" 2>/dev/null \
        && from_tarball_zip "$v" "$TMP/a$v.zip" && echo "  java $v: ok ($repo artifact $id)"
    else
      echo "  java $v: no artifact in $repo"
    fi
  done
done

echo "== result"
fail=0
for v in "${REQUIRED[@]}"; do
  if have "$v"; then echo "  java $v: present"; else echo "::error::Java $v runtime could not be downloaded from any source"; fail=1; fi
done
[ $fail = 0 ] || exit 1

for v in "${VERSIONS[@]}"; do
  if ! have "$v"; then
    echo "::warning::Java $v not found - building without it (Minecraft versions that need Java $v won't launch)"
    sed -i.bak -e "/jre$v-ios-aarch64/d" -e "/AME_JRE${v}_DIR)/d" -e "/java-$v-openjdk\/lib/d" Makefile
  else
    echo "  java $v: present"
  fi
done
rm -rf "$TMP"
