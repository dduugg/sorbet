#!/bin/bash

# Runs a single srb init test from gems/sorbet/test/snapshot/{partial,total}/*

shopt -s dotglob

# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library https://github.com/bazelbuild/bazel/blob/defd737761be2b154908646121de47c30434ed51/tools/bash/runfiles/runfiles.bash
set -euo pipefail
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  # shellcheck disable=SC1090
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  # shellcheck disable=SC1090
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---

# ----- Option parsing -----

# these positional arguments are supplied in snapshot.bzl
ruby_package=$1
test_name=$2

if [[ "${test_name}" =~ partial/* ]]; then
  is_partial=1
else
  is_partial=
fi

echo "test_name:  ${test_name}"
echo "is_partial: ${is_partial:-0}"

# ----- Environment setup -----

# Add ruby to the path
PATH="$(dirname "$(rlocation "${ruby_package}/ruby")"):$PATH"

# Put the bundler library into RUBYLIB
source $(rlocation "gems/bundler/bundle-env")

# Add bundler to the path
BUNDLER_LOC=$(dirname "$(rlocation "gems/bundler/bundle")")
GEMS_LOC="$BUNDLER_LOC/../gems"
PATH="$BUNDLER_LOC:$PATH"

export PATH

repo_root="$PWD"

source "gems/sorbet/test/snapshot/logging.sh"

test_dir="${repo_root}/gems/sorbet/test/snapshot/$2"

srb="${repo_root}/gems/sorbet/bin/srb"

# Use the sorbet executable built by bazel
SRB_SORBET_EXE="$PWD/main/sorbet"

HOME=$test_dir
export HOME

XDG_CACHE_HOME="${test_dir}/cache"
export XDG_CACHE_HOME


(
  cd $test_dir

  echo "output"
  ls
  echo "output"

  # ----- Check out.log -----

  info "Checking output log"
  if [ "$is_partial" = "" ] || [ -f "expected/out.log" ]; then
    out_filtered="$(mktemp)"
    sed -e 's/with [0-9]* modules and [0-9]* aliases/with X modules and Y aliases/' \
      -e "s,${TMPDIR}[^ ]*/\([^/]*\),<tmp>/\1,g" \
      -e "s,${XDG_CACHE_HOME},<cache>,g" \
      -e "s,${HOME},<home>,g" \
      < "actual/out.log" \
      > "$out_filtered"
    mv "$out_filtered" "actual/out.log"
    if ! diff -u "expected/out.log" "actual/out.log"; then
      error "├─ expected out.log did not match actual out.log"
      error "└─ see output above."
      exit 1
    fi
  fi

  # ----- Check err.log -----

  if [ "$is_partial" = "" ] || [ -f "expected/err.log" ]; then
    err_filtered="$(mktemp)"
    sed -e "s,${TMPDIR}[^ ]*/\([^/]*\),<tmp>/\1,g" \
      -e "s,${XDG_CACHE_HOME},<cache>,g" \
      -e "s,${HOME},<home>,g" \
      < "actual/err.log" > "$err_filtered"
    mv "$err_filtered" "actual/err.log"
    if ! diff -u "expected/err.log" "actual/err.log"; then
      error "├─ expected err.log did not match actual err.log"
      error "└─ see output above."
      exit 1
    fi
  fi

  # ----- Check sorbet/ -----

  # FIXME: Removing hidden-definitions in actual to hide them from diff output.
  rm -rf "actual/sorbet/rbi/hidden-definitions"

  diff_total() {
    info "├─ checking for total match"
    if ! diff -ur "expected/sorbet" "actual/sorbet"; then
      error "├─ expected sorbet/ folder did not match actual sorbet/ folder"
      error "└─ see output above."
      exit 1
    fi
  }

  diff_partial() {
    info "├─ checking for partial match"

    set +e
    diff -ur "expected/sorbet" "actual/sorbet" | \
      grep -vF "Only in actual" > "partial-diff.log"
    set -e

    # File exists and is non-empty
    if [ -s "partial-diff.log" ]; then
      cat "partial-diff.log"
      error "├─ expected sorbet/ folder did not match actual sorbet/ folder"
      error "└─ see output above."
      exit 1
    fi
  }

  if [ "$is_partial" = "" ]; then
    diff_total
  elif [ -d "expected/sorbet" ]; then
    diff_partial
  else
    # It's fine for a partial test to not have an expected dir.
    # It means the test only cares about the exit code of srb init.
    true
  fi

  success "└─ test passed."
)
