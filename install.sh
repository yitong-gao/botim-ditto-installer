#!/usr/bin/env bash
# botim-ditto standalone installer
# Compresses ONBOARDING.md Steps 2–6 into one interactive script.
# Designed for macOS, no admin/sudo required.
#
# Usage (one-liner — served from the public installer repo, since this
# private repo's raw URLs require auth):
#   curl -fsSL https://raw.githubusercontent.com/yitong-gao/botim-ditto-installer/main/install.sh | bash
# Or after cloning manually:
#   bash install.sh

set -e

# ── Style ───────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  B=$(tput bold); R=$(tput sgr0); RED=$(tput setaf 1); GRN=$(tput setaf 2); YEL=$(tput setaf 3); BLU=$(tput setaf 4); DIM=$(tput dim)
else
  B=; R=; RED=; GRN=; YEL=; BLU=; DIM=
fi

step()  { echo "${B}${BLU}━━ $1 ━━${R}"; }
ok()    { echo "${GRN}✓${R} $1"; }
warn()  { echo "${YEL}!${R} $1"; }
fail()  { echo "${RED}✗${R} $1" >&2; exit 1; }
# Read from /dev/tty, not stdin — under `curl ... | bash` stdin is the script
# stream itself, so a plain `read` would silently eat script lines instead of
# waiting for the user.
ask()   { local _p="$1" _d="$2" _v; read -r -p "${B}? $_p${R}${_d:+ ${DIM}[default: $_d]${R}} " _v </dev/tty; echo "${_v:-$_d}"; }
asksec() { local _p="$1" _v; read -r -s -p "${B}? $_p${R} (input hidden) " _v </dev/tty; echo >&2; printf '%s' "$_v"; }

REPO_URL="https://github.com/Yitong-Gao_astg/botim-ditto.git"
DEFAULT_TARGET="$HOME/.claude/plugins/botim-ditto"

# ── 1. Prereqs ──────────────────────────────────────────────────────────────
step "1/8  Checking prerequisites"
command -v git >/dev/null     || fail "git not found. Install Xcode CLT: xcode-select --install"
command -v ssh >/dev/null     || warn "ssh not available — SSH auth path won't work, but HTTPS still does"
ok "git found ($(git --version | awk '{print $3}'))"
if command -v gh >/dev/null; then
  ok "gh CLI found"
  HAS_GH=1
else
  warn "gh CLI not installed — will use access token for auth"
  HAS_GH=0
fi

# Figma desktop app — step 8 needs its plugin DevTools (browser Figma won't do).
if [ -d "/Applications/Figma.app" ] || [ -d "$HOME/Applications/Figma.app" ]; then
  ok "Figma desktop app found"
else
  warn "Figma desktop app not found in /Applications — install it before step 8 (figma.com/downloads)"
fi

echo
echo "${B}Before we continue, confirm you have all of these${R} ${DIM}(the installer can't detect them)${R}:"
echo "  • ${B}Ditto workspace invite accepted${R} — you can log in at app.dittowords.com"
echo "    ${DIM}No invite yet? Ask Sherizan / Yitong, then come back — this installer resumes where it left off.${R}"
echo "  • ${B}Ditto plugin installed in Figma${R} — Community → search \"Ditto\" → run it once"
echo "  • ${B}GitHub repo invite accepted${R} — github.com/notifications"
if [ "$(ask "All set? (y/n)" "y")" != "y" ]; then
  fail "Finish the items above first, then re-run this installer — completed steps are skipped automatically."
fi

# ── 2. GitHub auth ──────────────────────────────────────────────────────────
step "2/8  GitHub authentication"
echo "Testing access to the repo..."
if git ls-remote "$REPO_URL" HEAD >/dev/null 2>&1; then
  ok "Already authenticated — git can reach the repo"
  echo "  ${DIM}(your machine already has GitHub credentials — no token needed)${R}"
else
  echo
  echo "${B}First-time GitHub setup on this machine.${R} Two options:"
  echo "  ${B}A${R}) Run 'gh auth login' (easiest if gh CLI is installed)"
  echo "  ${B}B${R}) Generate a GitHub access token (classic) at https://github.com/settings/tokens"
  echo "      → scope: repo  → save it (starts with ghp_...)"
  echo "      ${DIM}GitHub's settings page calls these 'Personal access tokens'.${R}"
  echo

  if [ "$HAS_GH" = 1 ]; then
    if [ "$(ask "Run 'gh auth login' now?" "y")" = "y" ]; then
      gh auth login || fail "gh auth login failed"
    fi
  else
    echo "Generate a token (https://github.com/settings/tokens → 'Generate new token (classic)' → scope 'repo')"
    GH_TOKEN=$(asksec "Paste your GitHub access token here")
    [ -z "$GH_TOKEN" ] && fail "No token provided"
    git -c credential.helper='!f() { echo username=x-access-token; echo password='"$GH_TOKEN"'; }; f' \
        ls-remote "$REPO_URL" HEAD >/dev/null 2>&1 \
        || fail "Token failed to authenticate. Check scopes (repo) and that the value is correct."
    printf 'protocol=https\nhost=github.com\nusername=x-access-token\npassword=%s\n\n' "$GH_TOKEN" \
      | git credential-osxkeychain store 2>/dev/null || true
  fi
  git ls-remote "$REPO_URL" HEAD >/dev/null 2>&1 \
    || fail "Still can't reach repo. Have you accepted the GitHub invite at https://github.com/notifications ?"
  ok "Authenticated"
fi

# ── 3. Clone ─────────────────────────────────────────────────────────────────
step "3/8  Cloning the plugin"
TARGET=$(ask "Where to install?" "$DEFAULT_TARGET")
TARGET="${TARGET/#\~/$HOME}"

if [ -d "$TARGET/.git" ]; then
  warn "Already cloned at $TARGET — pulling latest"
  git -C "$TARGET" pull
else
  mkdir -p "$(dirname "$TARGET")"
  git clone "$REPO_URL" "$TARGET" \
    || fail "Clone failed. Have you accepted the GitHub invite at https://github.com/notifications ?"
fi

[ -f "$TARGET/figma-ditto-sync/sync.sh" ] \
  || fail "sync.sh missing at $TARGET/figma-ditto-sync/sync.sh — the clone is incomplete."
ok "Cloned at $TARGET"

# ── 4. Symlinks ──────────────────────────────────────────────────────────────
step "4/8  Activating skills (symlinks)"
mkdir -p "$HOME/.claude/skills"
SKILLS_TO_ENABLE=(botim-ditto botim-ditto-ar)
for s in "${SKILLS_TO_ENABLE[@]}"; do
  src="$TARGET/skills/$s"
  dst="$HOME/.claude/skills/$s"
  if [ ! -d "$src" ]; then
    warn "Skill source missing: $src — skipping"
    continue
  fi
  ln -sfn "$src" "$dst"
  ok "$s → $dst"
done

# ── 5. config.yaml (Ditto project template) ─────────────────────────────────
step "5/8  Writing config.yaml template"
CONFIG_PATH="$TARGET/figma-ditto-sync/ditto/config.yaml"
mkdir -p "$(dirname "$CONFIG_PATH")"

if [ -f "$CONFIG_PATH" ] && grep -q '^[[:space:]]*-[[:space:]]*id:' "$CONFIG_PATH"; then
  ok "$CONFIG_PATH already has projects configured — leaving in place"
else
  # If install.sh ran from a clone of a freshly published standalone, the
  # template config.yaml is already in place. Don't overwrite it.
  ok "$CONFIG_PATH ready — register your first project with:"
  echo "    bash $TARGET/figma-ditto-sync/register-project.sh <name> <ditto-url>"
fi

# ── 6. .env (Figma access token) ────────────────────────────────────────────
step "6/8  Setting up Figma access token"
ENV_PATH="$TARGET/figma-ditto-sync/ditto/.env"
if [ -f "$ENV_PATH" ] && grep -q '^Figma_Token=.\+' "$ENV_PATH"; then
  ok "$ENV_PATH already has a Figma access token — leaving in place"
else
  echo "Generate a Figma access token at:"
  echo "  ${BLU}https://www.figma.com/settings → Security → Personal access tokens → Generate${R}"
  echo "  ${DIM}Figma calls these 'Personal access tokens'; same thing.${R}"
  echo "Required scopes: File content (read) + Library content (write)"
  while :; do
    FIGMA_TOKEN_INPUT=$(asksec "Paste your Figma access token (starts with figd_...)")
    if [ -z "$FIGMA_TOKEN_INPUT" ]; then
      warn "A Figma token is required — sync can't read your files without it. (Ctrl+C aborts; re-running resumes here.)"
      continue
    fi
    if curl -sf --max-time 10 -H "X-Figma-Token: $FIGMA_TOKEN_INPUT" \
         https://api.figma.com/v1/me >/dev/null 2>&1; then
      ok "Token verified with the Figma API"
      break
    fi
    warn "The Figma API rejected that token — re-copy it from figma.com/settings and paste again."
  done
  cat > "$ENV_PATH" <<ENV
Figma_Token=$FIGMA_TOKEN_INPUT
Ditto_Backend_Token=
ENV
  chmod 600 "$ENV_PATH"
  ok "Wrote $ENV_PATH (chmod 600)"
fi

# ── 7. Register your first Ditto project ───────────────────────────────────
step "7/8  Registering your first Ditto project"
if grep -Eq '^\s*-\s*id:' "$CONFIG_PATH" 2>/dev/null; then
  ok "$CONFIG_PATH already has at least one project — skipping"
else
  echo "Before we can sync, you need to register one Ditto project. The toolkit"
  echo "supports many — start with one (you can add more later)."
  echo
  echo "  ${B}1.${R} Open Ditto Web: ${BLU}https://app.dittowords.com${R}"
  echo "  ${B}2.${R} Create your project (or pick an existing one). ${DIM}Your own new project is"
  echo "     the safest place for a first sync — only avoid experimenting inside a"
  echo "     shared project whose strings other people already handed to devs.${R}"
  echo "  ${B}3.${R} Copy the URL from your browser's address bar — it looks like:"
  echo "         https://app.dittowords.com/projects-beta/<24-char-hex>"
  echo
  while :; do
    PROJ_RAW=$(ask "Project name — type it however you like (e.g. Aani request to pay)" "")
    if [ -z "$PROJ_RAW" ]; then
      warn "You need one registered project before the first sync. (Ctrl+C aborts; re-running resumes here.)"
      continue
    fi
    # Same normalisation register-project.sh applies — shown here so the user
    # sees the final name before we commit it.
    PROJ_SHORT=$(printf '%s' "$PROJ_RAW" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
    [ "$PROJ_SHORT" != "$PROJ_RAW" ] && echo "  ${DIM}Will be registered as: ${R}${B}$PROJ_SHORT${R}"
    PROJ_URL=$(ask "Paste the Ditto Web URL (or the bare 24-char hex)" "")
    if [ -z "$PROJ_URL" ]; then
      warn "No URL — open your project in Ditto Web and copy the address bar."
      continue
    fi
    if bash "$TARGET/figma-ditto-sync/register-project.sh" "$PROJ_SHORT" "$PROJ_URL" >/tmp/.register-out.$$ 2>&1; then
      grep -E '^(✓|  added|  updated)' /tmp/.register-out.$$ || true
      ok "Registered '$PROJ_SHORT'"
      rm -f /tmp/.register-out.$$
      break
    fi
    warn "Registration failed:"
    cat /tmp/.register-out.$$
    rm -f /tmp/.register-out.$$
    echo "  Let's try again."
  done
fi

# ── 8. Capture Ditto session token (the only manual-paste step) ────────────
step "8/8  Capturing your Ditto session token"
if grep -Eq '^Ditto_Backend_Token=Bearer\s+ey[A-Za-z0-9_-]+' "$ENV_PATH"; then
  ok "$ENV_PATH already has a Ditto session token — leaving in place"
else
  cat <<EOH
This is the only manual step. Ditto's backend issues a short-lived session
token via SSO — you grab it from the Ditto plugin's DevTools. Takes ~30
seconds. You'll repeat it every ~3 days (re-run this installer, or just ask
Claude: "refresh ditto token").

  ${B}1.${R} Open the Figma ${B}desktop app${R} — any file you're working on is fine.
     ${DIM}(The file does NOT need to be connected to Ditto — the token is yours,
     not the file's.)${R}
  ${B}2.${R} Run the ${B}Ditto plugin${R} from the plugin menu.
  ${B}3.${R} Inside the plugin window, press ${B}Cmd+Opt+I${R} → DevTools opens.
  ${B}4.${R} Click the ${B}Network${R} tab. In the filter box, type ${B}ditto${R}.
  ${B}5.${R} List empty? Normal — close the plugin and run it again (keep DevTools
     open). Its startup requests appear immediately; ${B}any of them${R} works.
  ${B}6.${R} Click any request → ${B}Headers${R} → Request Headers → ${B}Authorization${R}
     → right-click the value → ${B}Copy value${R}
     (long string starting with ${B}Bearer eyJ...${R}). Paste it below.

EOH
  while :; do
    BEARER=$(asksec "Paste your Ditto session token (Bearer eyJ...)")
    if [ -z "$BEARER" ]; then
      warn "The session token is required — nothing can reach Ditto without it."
      echo "  ${DIM}Can't get it right now? Ctrl+C to stop — re-running this installer"
      echo "  resumes exactly here (steps 1–7 are skipped once done).${R}"
      continue
    fi
    if ! [[ "$BEARER" =~ ^Bearer\ ey ]]; then
      warn "That didn't look right — copy the WHOLE header value, starting with 'Bearer ey'. Try again."
      continue
    fi
    # Replace the Ditto_Backend_Token line in place
    python3 - "$ENV_PATH" "$BEARER" <<'PYEOF'
import sys, pathlib
env_path, new_token = sys.argv[1], sys.argv[2]
lines = pathlib.Path(env_path).read_text().splitlines()
out, seen = [], False
for ln in lines:
    if ln.startswith("Ditto_Backend_Token="):
        out.append(f"Ditto_Backend_Token={new_token}"); seen = True
    else:
        out.append(ln)
if not seen:
    out.append(f"Ditto_Backend_Token={new_token}")
pathlib.Path(env_path).write_text("\n".join(out) + "\n")
PYEOF
    echo "  Verifying with Ditto backend..."
    HTTP=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 \
      "https://backend.dittowords.com/workspace" \
      -H "Authorization: $BEARER")
    if [ "$HTTP" = "200" ]; then
      ok "Session token verified (HTTP 200) — ready to sync"
      break
    fi
    warn "Ditto returned HTTP $HTTP — the token is probably stale or truncated."
    echo "  Close and re-run the Ditto plugin (keep DevTools open), copy the fresh value, paste again."
  done
fi

# ── Final: run your first sync ──────────────────────────────────────────────
cat <<EOM

${B}${GRN}✓ All 8 steps done — setup is complete.${R}

${B}➡️  Last step: run your first sync (~2 min)${R}

  ${B}1.${R} Restart Claude Code so it picks up the new skills
     ${DIM}(Cmd+Q to fully quit, then reopen)${R}
  ${B}2.${R} In Figma, open the file you're designing and connect it to your
     Ditto project: ${B}Ditto plugin → Connect this file to a project${R}
     → pick ${B}${PROJ_SHORT:-the project you registered}${R}
  ${B}3.${R} Copy the file's URL from the address bar
  ${B}4.${R} Tell Claude:   ${B}sync ditto <your-figma-url>${R}
     ${DIM}Claude extracts the copy, creates Ditto strings with stable dev_ids,
     links every Figma text node, then reports back with numbers.${R}

  ${DIM}Need Arabic? After a sync, say "translate to Arabic" — you'll get
  ditto-ar-review.md, an EN/AR side-by-side table with uncertain rows
  flagged ⚠️, ready to forward to an AR-native colleague for review
  before anything is pushed.${R}

  From here on you just talk to Claude — no more Terminal commands.

${DIM}Docs: https://github.com/Yitong-Gao_astg/botim-ditto/blob/main/ONBOARDING.md
      (also on disk: $TARGET/ONBOARDING.md)${R}
EOM
