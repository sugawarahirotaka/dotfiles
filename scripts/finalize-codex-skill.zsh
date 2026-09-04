#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

if (( $# != 1 )); then
  echo "usage: ${0:t} <skill-name>" >&2
  exit 2
fi

SKILL_NAME="$1"
if [[ ! "$SKILL_NAME" =~ '^[a-z0-9]+(-[a-z0-9]+)*$' ]]; then
  echo "[error] invalid skill name: $SKILL_NAME" >&2
  exit 1
fi

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${CODEX_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${CODEX_SKILLS_REGISTRY:-$DOTFILES_DIR/.codex/skills-registry.json}"
CODEX_SKILLS_HOME="${CODEX_SKILLS_HOME:-$TARGET_HOME/.codex/skills}"
HELPER="$SCRIPT_DIR/codex-skills-registry.py"
SKILL_REL=".codex/skills/$SKILL_NAME"
SKILL_PATH="$DOTFILES_DIR/$SKILL_REL"
REGISTRY_REL=".codex/skills-registry.json"

if ! git -C "$DOTFILES_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "[error] dotfiles directory is not a Git worktree: $DOTFILES_DIR" >&2
  exit 1
fi
GIT_ROOT="$(git -C "$DOTFILES_DIR" rev-parse --show-toplevel)"
if [[ "${GIT_ROOT:A}" != "${DOTFILES_DIR:A}" ]]; then
  echo "[error] expected dotfiles Git root $DOTFILES_DIR, got $GIT_ROOT" >&2
  exit 1
fi

python3 "$HELPER" --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" validate >/dev/null
KIND="$(python3 "$HELPER" --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" field "$SKILL_NAME" kind)"
if [[ "$KIND" != "owned" && "$KIND" != "vendored" ]]; then
  echo "[error] finalize only commits owned or vendored skills; $SKILL_NAME is $KIND" >&2
  exit 1
fi

python3 "$HELPER" --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" \
  validate-skill "$SKILL_NAME" "$SKILL_PATH"

DESTINATION="$CODEX_SKILLS_HOME/$SKILL_NAME"
if [[ ! -L "$DESTINATION" ]]; then
  echo "[error] skill destination is not a symlink: $DESTINATION" >&2
  exit 1
fi
if [[ ! -e "$DESTINATION" ]]; then
  echo "[error] skill destination is a broken symlink: $DESTINATION -> $(readlink "$DESTINATION")" >&2
  exit 1
fi
if [[ "${DESTINATION:A}" != "${SKILL_PATH:A}" ]]; then
  echo "[error] skill destination points elsewhere: $DESTINATION -> $(readlink "$DESTINATION")" >&2
  exit 1
fi

if [[ -d "$SKILL_PATH/tests" ]]; then
  if [[ -f "$SKILL_PATH/pyproject.toml" ]] && command -v uv >/dev/null 2>&1; then
    TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/finalize-codex-skill.XXXXXX")"
    trap 'rm -rf -- "$TEST_TMP"' EXIT INT TERM
    cp -R "$SKILL_PATH" "$TEST_TMP/skill"
    UV_CACHE_DIR="$TEST_TMP/uv-cache" \
      PYTHONDONTWRITEBYTECODE=1 \
      uv run --directory "$TEST_TMP/skill" pytest -q -p no:cacheprovider
  elif [[ -x "$SKILL_PATH/tests/run.zsh" ]]; then
    "$SKILL_PATH/tests/run.zsh"
  elif find "$SKILL_PATH/tests" -maxdepth 1 -name 'test_*.py' -type f | grep -q .; then
    (cd "$SKILL_PATH" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests)
  else
    echo "[error] tests exist but no supported test runner was found: $SKILL_PATH/tests" >&2
    exit 1
  fi
fi

"$SCRIPT_DIR/check-codex-skills.zsh"

SHARED_PATHS=(
  "$REGISTRY_REL"
  ".codex/AGENTS.md"
  "deploy.sh"
  "docs/codex-skills.md"
  "scripts/codex-skills-registry.py"
  "scripts/deploy-codex-skills.zsh"
  "scripts/check-codex-skills.zsh"
  "scripts/finalize-codex-skill.zsh"
  "tests/test-codex-skills.zsh"
  ".gitignore"
)

is_allowed_path() {
  local candidate="$1"
  local shared
  if [[ "$candidate" == "$SKILL_REL" || "$candidate" == "$SKILL_REL/"* ]]; then
    return 0
  fi
  for shared in "${SHARED_PATHS[@]}"; do
    [[ "$candidate" == "$shared" ]] && return 0
  done
  return 1
}

reject_unrelated_staged() {
  local candidate
  local -a staged_paths
  staged_paths=("${(@f)$(git -C "$DOTFILES_DIR" diff --cached --name-only --diff-filter=ACMRD)}")
  for candidate in "${staged_paths[@]}"; do
    [[ -z "$candidate" ]] && continue
    if ! is_allowed_path "$candidate"; then
      echo "[error] unrelated staged change prevents finalize: $candidate" >&2
      return 1
    fi
  done
}

reject_unrelated_staged
git -C "$DOTFILES_DIR" add -A -- "$SKILL_REL" "$REGISTRY_REL"
for shared in "${SHARED_PATHS[@]}"; do
  [[ "$shared" == "$REGISTRY_REL" ]] && continue
  if [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain -- "$shared")" ]]; then
    git -C "$DOTFILES_DIR" add -A -- "$shared"
  fi
done
reject_unrelated_staged

if git -C "$DOTFILES_DIR" diff --cached --quiet; then
  echo "[ok] no changes to commit for $SKILL_NAME"
  exit 0
fi

if git -C "$DOTFILES_DIR" diff --cached --quiet -- "$SKILL_REL"; then
  COMMIT_MESSAGE="update: update Codex skill registry"
elif git -C "$DOTFILES_DIR" cat-file -e "HEAD:$SKILL_REL/SKILL.md" 2>/dev/null; then
  COMMIT_MESSAGE="update: update $SKILL_NAME Codex skill"
elif [[ "$KIND" == "vendored" ]]; then
  COMMIT_MESSAGE="add: vendor $SKILL_NAME Codex skill"
else
  COMMIT_MESSAGE="add: add $SKILL_NAME Codex skill"
fi

git -C "$DOTFILES_DIR" commit -m "$COMMIT_MESSAGE"
echo "[ok] committed without push: $COMMIT_MESSAGE"
