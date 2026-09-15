#!/usr/bin/env bash
#
# Reload the kasaharacup staging app from production: copy the database with
# `heroku pg:copy`, then sync the Active Storage bucket across.
#
# Usage:
#   scripts/copy_prd_to_staging.sh [--dry-run]
#
#   --dry-run   Run the read-only checks for real, but print the mutating
#               commands instead of running them.
#
# Environment overrides:
#   PRD_APP           source Heroku app  (default: kasaharacup-production)
#   STAGING_APP       target Heroku app  (default: kasaharacup-staging)
#   AWS_SYNC_PROFILE  AWS CLI profile    (default: kasaharacup-dev-yannis)
#
# WARNING: this DESTROYS the staging database, and afterwards staging holds
# real entrants' names, emails and addresses. Treat it as production-
# confidential.

set -euo pipefail

PRD_APP="${PRD_APP:-kasaharacup-production}"
STAGING_APP="${STAGING_APP:-kasaharacup-staging}"
AWS_SYNC_PROFILE="${AWS_SYNC_PROFILE:-kasaharacup-dev-yannis}"
DRY_RUN=false

# Primary Postgres attachment on both apps. Used to build the SOURCE/TARGET
# config-var names passed to `pg:copy`, and as its confirmation string.
DB_ATTACHMENT=DATABASE

ENCRYPTION_VARS=(
  ENCRYPTION_PRIMARY_KEY
  ENCRYPTION_DETERMINISTIC_KEY
  ENCRYPTION_KEY_DERIVATION_SALT
)

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
preflight() {
  heading "PREFLIGHT"

  [[ -f config/application.rb ]] ||
    abort "run this script from the app root directory"

  command -v heroku >/dev/null ||
    abort "the Heroku CLI is not installed — https://devcenter.heroku.com/articles/heroku-cli"
  command -v aws >/dev/null ||
    abort "the AWS CLI is not installed — https://aws.amazon.com/cli/"

  heroku auth:whoami </dev/null >/dev/null 2>&1 ||
    abort "not logged in to Heroku — run 'heroku login'"

  [[ "$PRD_APP" != "$STAGING_APP" ]] ||
    abort "PRD_APP and STAGING_APP are both '$PRD_APP' — refusing to copy an app onto itself"

  heroku apps:info --app "$PRD_APP" </dev/null >/dev/null 2>&1 ||
    abort "no access to the source app '$PRD_APP'"
  heroku apps:info --app "$STAGING_APP" </dev/null >/dev/null 2>&1 ||
    abort "no access to the target app '$STAGING_APP'"

  echo "Source: $PRD_APP"
  echo "Target: $STAGING_APP  (its database will be DESTROYED)"
}

check_encryption_keys() {
  heading "ENCRYPTION KEYS"

  echo "PersonalInfo columns are encrypted at rest. Staging can only read the"
  echo "copied rows if it holds the same keys as production."
  echo

  local mismatch=false
  local var prd_value staging_value

  for var in "${ENCRYPTION_VARS[@]}"; do
    prd_value="$(heroku config:get "$var" --app "$PRD_APP" </dev/null)"
    staging_value="$(heroku config:get "$var" --app "$STAGING_APP" </dev/null)"

    if [[ -z "$prd_value" || -z "$staging_value" ]]; then
      echo "  $var: MISSING — unset on at least one app"
      mismatch=true
    elif [[ "$prd_value" == "$staging_value" ]]; then
      echo "  $var: match"
    else
      echo "  $var: DIFFER"
      mismatch=true
    fi
  done

  unset prd_value staging_value

  if [[ "$mismatch" == true ]]; then
    echo
    echo "At least one key does not match. After the copy, every PersonalInfo read"
    echo "on '$STAGING_APP' will raise on decrypt."
    echo
    echo "This script will not copy production key material onto staging — that is"
    echo "your call to make by hand."
    echo
    local reply
    read -r -p "Continue anyway? (y/N) " reply
    [[ "$reply" == [Yy]* ]] || abort "encryption keys do not match"
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

  local reply
  read -r -p "Type the target app name to continue: " reply

  [[ "$reply" == "$STAGING_APP" ]] ||
    abort "expected '$STAGING_APP', got '$reply'"
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
  echo "Its database may be half-copied, so it has deliberately been left" >&2
  echo "behind the maintenance page rather than serving broken pages." >&2
  echo >&2
  echo "Once you have checked it, lift maintenance mode with:" >&2
  echo >&2
  echo "  heroku maintenance:off --app $STAGING_APP" >&2
}

copy_database() {
  heading "DATABASE COPY"

  run heroku maintenance:on --app "$STAGING_APP"
  trap maintenance_trap EXIT

  # `pg:copy` confirms against the TARGET ATTACHMENT name ("DATABASE"), not the
  # app name — passing the app name fails with "Confirmation ... did not match
  # DATABASE". Which string it wants has changed between CLI versions, so if this
  # ever breaks again, ask the CLI rather than guessing; a wrong value aborts
  # safely, before any data is touched, and names what it expected:
  #
  #   heroku pg:copy "$PRD_APP::DATABASE_URL" DATABASE_URL \
  #     --app "$STAGING_APP" --confirm __wrong__
  #
  # Note "DATABASE" identifies no particular app, which is exactly why
  # confirm_target above asks for the app name instead: this flag only suppresses
  # a prompt whose safety value we have already provided ourselves.
  run heroku pg:copy "$PRD_APP::${DB_ATTACHMENT}_URL" "${DB_ATTACHMENT}_URL" \
    --app "$STAGING_APP" --confirm "$DB_ATTACHMENT"

  heading "MIGRATE"

  echo "The copied schema is production's. Staging's code is usually ahead of it."
  run heroku run --app "$STAGING_APP" --exit-code rails db:migrate

  run heroku maintenance:off --app "$STAGING_APP"
  trap - EXIT
}

sync_assets() {
  heading "ASSET SYNC"

  local prd_bucket staging_bucket
  prd_bucket="$(heroku config:get AWS_ACTIVE_STORAGE_BUCKET --app "$PRD_APP" </dev/null)"
  staging_bucket="$(heroku config:get AWS_ACTIVE_STORAGE_BUCKET --app "$STAGING_APP" </dev/null)"

  [[ -n "$prd_bucket" ]] ||
    abort "AWS_ACTIVE_STORAGE_BUCKET is unset on '$PRD_APP'"
  [[ -n "$staging_bucket" ]] ||
    abort "AWS_ACTIVE_STORAGE_BUCKET is unset on '$STAGING_APP'"
  [[ "$prd_bucket" != "$staging_bucket" ]] ||
    abort "both apps point at the same bucket ($prd_bucket) — refusing to sync it onto itself"

  echo "The copied attachment rows point at objects in s3://$prd_bucket."
  echo "Without this sync they will 404 on staging."
  echo
  echo "  from:    s3://$prd_bucket"
  echo "  to:      s3://$staging_bucket"
  echo "  profile: $AWS_SYNC_PROFILE"
  echo

  local reply
  read -r -p "Sync the bucket now? (y/N) " reply

  if [[ "$reply" != [Yy]* ]]; then
    echo "Skipped. Run it later with:"
    echo "  aws s3 sync s3://$prd_bucket s3://$staging_bucket --profile $AWS_SYNC_PROFILE"
    return
  fi

  if run aws s3 sync "s3://$prd_bucket" "s3://$staging_bucket" --profile "$AWS_SYNC_PROFILE"; then
    echo "Assets synced."
  else
    echo >&2
    echo "WARNING: the asset sync failed. The database copy is intact and staging" >&2
    echo "is serving — only attachments are missing. Re-run it by hand with:" >&2
    echo >&2
    echo "  aws s3 sync s3://$prd_bucket s3://$staging_bucket --profile $AWS_SYNC_PROFILE" >&2
    echo >&2
    echo "On AccessDenied, the profile needs s3:ListBucket on the target bucket and" >&2
    echo "s3:PutObject on its contents, plus s3:GetObject on the source. Grant them" >&2
    echo "in IAM, or push the objects with the credentials the target app uses." >&2
  fi
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

  heading "DONE"
  echo "'$STAGING_APP' now runs a copy of '$PRD_APP'."
  echo
  echo "It holds real personal data. Treat it as production-confidential."
}

main
