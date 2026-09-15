#!/usr/bin/env bash
#
# Reload the kasaharacup staging app from production: copy the database with
# `heroku pg:copy`, then sync the Active Storage bucket across.
#
# Run `scripts/copy_prd_to_staging.sh --help` for usage.
#
# WARNING: this DESTROYS the staging database, and afterwards staging holds
# real entrants' names, emails and addresses. Treat it as production-
# confidential.

set -euo pipefail

PRD_APP="${PRD_APP:-kasaharacup-production}"
STAGING_APP="${STAGING_APP:-kasaharacup-staging}"
AWS_SYNC_PROFILE="${AWS_SYNC_PROFILE:-kasaharacup-dev-yannis}"
DRY_RUN=false

# Apps this script must never destroy, whatever PRD_APP/STAGING_APP are set to.
# A transposed pair is the one operator slip the typed-name confirmation cannot
# catch, because it echoes the target before asking: the operator types back
# exactly what they were just shown.
PROTECTED_APPS=(kasaharacup-production)

# Primary Postgres attachment on both apps. Used to build the SOURCE/TARGET
# config-var names passed to `pg:copy`.
DB_ATTACHMENT=DATABASE

ENCRYPTION_VARS=(
  ENCRYPTION_PRIMARY_KEY
  ENCRYPTION_DETERMINISTIC_KEY
  ENCRYPTION_KEY_DERIVATION_SALT
)

# Set by resolve_buckets, read by sync_assets and the closing report.
PRD_BUCKET=""
STAGING_BUCKET=""
SYNC_CMD=()

# skipped | synced | failed | dry-run
ASSET_SYNC_STATUS=skipped
ASSET_SYNC_PRECHECK_FAILED=false

# Which step is in flight, so the EXIT trap can say what actually happened
# rather than guessing.
PHASE=""

# Last answer read by `ask`.
REPLY_VALUE=""

usage() {
  cat <<'USAGE'
Reload the kasaharacup staging app from production.

Usage:
  scripts/copy_prd_to_staging.sh [--dry-run]

  --dry-run   Run the read-only checks for real, but print the mutating
              commands instead of running them.

Environment overrides:
  PRD_APP           source Heroku app  (default: kasaharacup-production)
  STAGING_APP       target Heroku app  (default: kasaharacup-staging)
  AWS_SYNC_PROFILE  AWS CLI profile    (default: kasaharacup-dev-yannis)

Exit status:
  0  everything succeeded
  1  aborted, before or during the copy
  2  the database copy succeeded but the asset sync failed
USAGE
}

heading() {
  echo
  echo "------------------------------------------------------------"
  echo "  $1"
  echo "------------------------------------------------------------"
}

abort() {
  echo >&2
  echo "ABORTED: $1" >&2
  exit 1
}

# Prompts read from the terminal rather than inherited stdin: a child process
# that drains stdin would otherwise swallow the answer, and the `read` would
# then fail at EOF and kill the script under `set -e` without printing anything.
# An unreadable terminal is reported rather than silently taken as "no".
ask() {
  REPLY_VALUE=""
  read -r -p "$1 " REPLY_VALUE </dev/tty ||
    abort "could not read an answer from the terminal — this script is interactive"
}

confirmed() {
  [[ "$REPLY_VALUE" == [Yy]* ]]
}

# Run a mutating command, or print it when --dry-run is set.
run() {
  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] $*"
  else
    echo "+ $*"
    "$@"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# Every non-interactive helper below reads from /dev/null. Without that, a child
# process that drains stdin swallows the operator's answer to a later prompt, and
# the `read` then fails at EOF — taking the whole script down under `set -e`.
check_workdir() {
  [[ -f config/application.rb ]] ||
    abort "run this script from the app root directory"
}

check_tools() {
  command -v heroku >/dev/null ||
    abort "the Heroku CLI is not installed — https://devcenter.heroku.com/articles/heroku-cli"
  command -v aws >/dev/null ||
    abort "the AWS CLI is not installed — https://aws.amazon.com/cli/"

  heroku auth:whoami </dev/null >/dev/null 2>&1 ||
    abort "not logged in to Heroku — run 'heroku login'"
}

check_protected_target() {
  [[ "$PRD_APP" != "$STAGING_APP" ]] ||
    abort "PRD_APP and STAGING_APP are both '$PRD_APP' — refusing to copy an app onto itself"

  local protected
  for protected in "${PROTECTED_APPS[@]}"; do
    [[ "$STAGING_APP" != "$protected" ]] ||
      abort "STAGING_APP is '$STAGING_APP', a protected app — refusing to destroy it. Check for a transposed PRD_APP/STAGING_APP pair in your environment."
  done

  [[ "$STAGING_APP" != *production* ]] ||
    abort "STAGING_APP ('$STAGING_APP') looks like a production app — refusing to destroy it"
}

check_app_access() {
  heroku apps:info --app "$PRD_APP" </dev/null >/dev/null 2>&1 ||
    abort "no access to the source app '$PRD_APP'"
  heroku apps:info --app "$STAGING_APP" </dev/null >/dev/null 2>&1 ||
    abort "no access to the target app '$STAGING_APP'"
}

# HasHttpAuth gates the whole app, but only when both config vars are present;
# with them unset there is no gate at all, and robots.txt disallows nothing.
check_staging_gate() {
  local username password
  username="$(heroku config:get HTTP_AUTH_USERNAME --app "$STAGING_APP" </dev/null)"
  password="$(heroku config:get HTTP_AUTH_PASSWORD --app "$STAGING_APP" </dev/null)"

  if [[ -z "$username" && -z "$password" ]]; then
    echo
    echo "WARNING: '$STAGING_APP' has no HTTP_AUTH_USERNAME/HTTP_AUTH_PASSWORD."
    echo "Nothing gates it, so after this copy every page — real names, emails"
    echo "and postal addresses — is served to anyone with the URL, and it is"
    echo "crawlable."
    echo
    ask "Continue anyway? (y/N)"
    confirmed || abort "'$STAGING_APP' is not behind HTTP auth"
  fi
}

# Resolved before anything destructive happens: a missing or misconfigured
# bucket used to abort only after the database had already been replaced.
resolve_buckets() {
  PRD_BUCKET="$(heroku config:get AWS_ACTIVE_STORAGE_BUCKET --app "$PRD_APP" </dev/null)"
  STAGING_BUCKET="$(heroku config:get AWS_ACTIVE_STORAGE_BUCKET --app "$STAGING_APP" </dev/null)"

  [[ -n "$PRD_BUCKET" ]] ||
    abort "AWS_ACTIVE_STORAGE_BUCKET is unset on '$PRD_APP'"
  [[ -n "$STAGING_BUCKET" ]] ||
    abort "AWS_ACTIVE_STORAGE_BUCKET is unset on '$STAGING_APP'"
  [[ "$PRD_BUCKET" != "$STAGING_BUCKET" ]] ||
    abort "both apps point at the same bucket ($PRD_BUCKET) — refusing to sync it onto itself"

  # Built once so the command that runs and the ones printed as fallback
  # instructions cannot drift apart. --delete keeps staging a true mirror:
  # without it, objects from earlier copies linger as stale personal data.
  SYNC_CMD=(
    aws s3 sync "s3://$PRD_BUCKET" "s3://$STAGING_BUCKET"
    --delete --profile "$AWS_SYNC_PROFILE"
  )
}

# Probed up front: the sync is the step most likely to fail on credentials, and
# finding that out after the copy is too late to be useful.
check_asset_sync_access() {
  if aws s3 ls "s3://$STAGING_BUCKET" --profile "$AWS_SYNC_PROFILE" </dev/null >/dev/null 2>&1; then
    return
  fi

  ASSET_SYNC_PRECHECK_FAILED=true
  echo
  echo "WARNING: profile '$AWS_SYNC_PROFILE' cannot list s3://$STAGING_BUCKET."
  echo "The database copy will still work, but the asset sync will probably"
  echo "fail. It needs s3:ListBucket and s3:PutObject on the target bucket, and"
  echo "s3:GetObject on the source."
}

preflight() {
  heading "PREFLIGHT"

  check_workdir
  check_tools
  check_protected_target
  check_app_access
  resolve_buckets
  check_asset_sync_access
  check_staging_gate

  echo
  echo "Source: $PRD_APP"
  echo "Target: $STAGING_APP  (its database will be DESTROYED)"
}

# Only a digest of each key ever reaches this machine: equality is all the
# script needs, and a plaintext key in a shell variable would be printed by any
# operator running with `bash -x`.
key_digest() {
  local value
  value="$(heroku config:get "$1" --app "$2" </dev/null)"
  [[ -n "$value" ]] || return 0
  printf '%s' "$value" | shasum -a 256 | cut -d' ' -f1
}

check_encryption_keys() {
  heading "ENCRYPTION KEYS"

  echo "PersonalInfo columns are encrypted at rest. Staging can only read the"
  echo "copied rows if it holds the same keys as production. Only SHA-256"
  echo "digests of the keys are read, never the keys themselves."
  echo

  local mismatch=false
  local var prd_digest staging_digest

  for var in "${ENCRYPTION_VARS[@]}"; do
    prd_digest="$(key_digest "$var" "$PRD_APP")"
    staging_digest="$(key_digest "$var" "$STAGING_APP")"

    # config/application.rb reads all three with ENV.fetch, so one missing on
    # staging is not a decryption problem — the app cannot boot at all, and the
    # migrate step below would die with a KeyError on an already-replaced
    # database.
    [[ -n "$staging_digest" ]] ||
      abort "$var is unset on '$STAGING_APP'. config/application.rb reads it with ENV.fetch, so the app cannot boot without it — set it before copying."

    if [[ -z "$prd_digest" ]]; then
      echo "  $var: MISSING on $PRD_APP"
      mismatch=true
    elif [[ "$prd_digest" == "$staging_digest" ]]; then
      echo "  $var: match"
    else
      echo "  $var: DIFFER"
      mismatch=true
    fi
  done

  if [[ "$mismatch" == true ]]; then
    echo
    echo "At least one key does not match. After the copy, every PersonalInfo read"
    echo "on '$STAGING_APP' will raise on decrypt."
    echo
    echo "This script will not copy production key material onto staging — that is"
    echo "your call to make by hand."
    echo
    ask "Continue anyway? (y/N)"
    confirmed || abort "encryption keys do not match"
  fi
}

confirm_target() {
  heading "CONFIRMATION"

  echo "This DESTROYS the database of '$STAGING_APP' and replaces it with a copy"
  echo "of '$PRD_APP'. It cannot be undone."
  echo
  echo "Afterwards '$STAGING_APP' holds real entrants' names, emails and postal"
  echo "addresses. Treat it as production-confidential."
  echo

  ask "Type the target app name to continue:"

  [[ "$REPLY_VALUE" == "$STAGING_APP" ]] ||
    abort "expected '$STAGING_APP', got '$REPLY_VALUE'"
}

maintenance_trap() {
  if [[ "$DRY_RUN" == true ]]; then
    echo >&2
    echo "FAILED during a dry run — nothing was changed." >&2
    return
  fi

  echo >&2
  echo "------------------------------------------------------------" >&2
  echo "  FAILED — '$STAGING_APP' IS STILL IN MAINTENANCE MODE" >&2
  echo "------------------------------------------------------------" >&2

  case "$PHASE" in
    copy)
      echo "It failed during the database copy, so the database may be half-" >&2
      echo "copied. Re-run this script to copy it again." >&2
      ;;
    migrate)
      echo "The database copy finished — the data is intact. It failed while" >&2
      echo "migrating. Fix the migration, then run:" >&2
      echo >&2
      echo "  heroku run --app $STAGING_APP --no-tty --exit-code rails db:migrate" >&2
      ;;
    restart | maintenance-off)
      echo "The database copy and the migration both finished. Only the restart" >&2
      echo "or the lifting of maintenance mode failed." >&2
      ;;
    *)
      echo "It failed before the database copy started — no data was changed." >&2
      ;;
  esac

  echo >&2
  echo "Once you have checked it, lift maintenance mode with:" >&2
  echo >&2
  echo "  heroku maintenance:off --app $STAGING_APP" >&2
}

copy_database() {
  heading "DATABASE COPY"

  PHASE=pre-copy
  run heroku maintenance:on --app "$STAGING_APP"
  trap maintenance_trap EXIT

  if ! run heroku pg:backups:capture --app "$STAGING_APP"; then
    echo "WARNING: could not capture a safety backup of '$STAGING_APP' — its" >&2
    echo "current contents will be lost for good." >&2
  fi

  PHASE=copy
  # `pg:copy` asks for a confirmation string, and which string it wants changed
  # between CLI versions: clients up to 11.8 expect the app name, 11.9+ the
  # attachment name ("DATABASE"). Any hardcoded --confirm therefore aborts on
  # whichever version the operator is not running — after maintenance mode is
  # already on. So let the CLI prompt: it prints the string it wants, and it is
  # the only guard that names the target independently of this script's own
  # variables.
  run heroku pg:copy "$PRD_APP::${DB_ATTACHMENT}_URL" "${DB_ATTACHMENT}_URL" \
    --app "$STAGING_APP" </dev/tty

  PHASE=migrate
  heading "MIGRATE"

  echo "The copied schema is production's. Staging's code is usually ahead of it."
  run heroku run --app "$STAGING_APP" --no-tty --exit-code rails db:migrate </dev/null

  PHASE=restart
  # Maintenance mode only changes routing — the web dynos keep running, holding
  # connections and a schema cache for the database that has just been replaced
  # and migrated under them. Without a restart they serve "cached plan must not
  # change result type" as soon as traffic returns.
  run heroku restart --app "$STAGING_APP"

  PHASE=maintenance-off
  run heroku maintenance:off --app "$STAGING_APP"
  trap - EXIT
  PHASE=""
}

sync_assets() {
  heading "ASSET SYNC"

  echo "The copied attachment rows point at objects in s3://$PRD_BUCKET."
  echo "Without this sync they will 404 on staging."
  echo
  echo "  from:    s3://$PRD_BUCKET"
  echo "  to:      s3://$STAGING_BUCKET"
  echo "  profile: $AWS_SYNC_PROFILE"
  if [[ "$ASSET_SYNC_PRECHECK_FAILED" == true ]]; then
    echo
    echo "  NOTE: preflight could not list the target bucket with this profile."
  fi
  echo

  ask "Sync the bucket now? (y/N)"
  if ! confirmed; then
    ASSET_SYNC_STATUS=skipped
    echo "Skipped."
    return
  fi

  if [[ "$DRY_RUN" == true ]]; then
    run "${SYNC_CMD[@]}"
    ASSET_SYNC_STATUS=dry-run
    return
  fi

  if run "${SYNC_CMD[@]}"; then
    ASSET_SYNC_STATUS=synced
    echo "Assets synced."
  else
    ASSET_SYNC_STATUS=failed
    echo >&2
    echo "WARNING: the asset sync failed. The database copy is intact and staging" >&2
    echo "is serving — only attachments are missing." >&2
    echo >&2
    echo "On AccessDenied, the profile needs s3:ListBucket on the target bucket and" >&2
    echo "s3:PutObject on its contents, plus s3:GetObject on the source. Grant them" >&2
    echo "in IAM, or push the objects with the credentials the target app uses." >&2
  fi
}

report_done() {
  heading "DONE"

  echo "'$STAGING_APP' now runs a copy of '$PRD_APP'."
  echo

  case "$ASSET_SYNC_STATUS" in
    synced)
      echo "Attachments: synced."
      ;;
    dry-run)
      echo "Attachments: nothing was synced — this was a dry run."
      ;;
    skipped | failed)
      if [[ "$ASSET_SYNC_STATUS" == failed ]]; then
        echo "Attachments: THE SYNC FAILED — they will 404 until you run:"
      else
        echo "Attachments: NOT synced — they will 404 until you run:"
      fi
      echo
      echo "  ${SYNC_CMD[*]}"
      ;;
  esac

  echo
  echo "It holds real personal data. Treat it as production-confidential."
  echo "Staging boots config/environments/production.rb, so its mailers use live"
  echo "Mailjet credentials: anything that sends mail now delivers to the real"
  echo "addresses just copied in."

  [[ "$ASSET_SYNC_STATUS" != failed ]] || exit 2
}

main() {
  heading "HEROKU PRODUCTION -> STAGING"
  if [[ "$DRY_RUN" == true ]]; then
    echo "DRY RUN — the read-only checks are real, mutating commands are only printed."
  fi

  preflight
  check_encryption_keys
  confirm_target
  copy_database
  sync_assets
  report_done
}

main
