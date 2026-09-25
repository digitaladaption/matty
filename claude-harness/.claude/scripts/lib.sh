# Shared helpers for the harness scripts. Source it, don't run it.

# run_claude <prompt-file> <output-file>
# Runs headless claude from an empty directory with only user settings and no tools, so
# the project's hooks don't fire (and log the run as a session) and Claude can only
# return text. Strips code fences from the reply.
# Env: CLAUDE_BIN (default: claude), LESSONS_MODEL (optional)
run_claude() {
  local prompt=$1 out=$2 dir rc=0
  dir=$(mktemp -d)
  (cd "$dir" && HARNESS_NO_MEMORY=1 "${CLAUDE_BIN:-claude}" -p \
    --setting-sources user --no-session-persistence \
    ${LESSONS_MODEL:+--model "$LESSONS_MODEL"} \
    --tools "" <"$prompt" >"$dir/raw") || rc=$?
  [[ $rc -eq 0 ]] && sed -E '/^```/d' "$dir/raw" >"$out"
  rm -rf "$dir"
  return $rc
}
