#!/bin/bash

echo "------------------------------"
echo "|    HEROKU PROD -> DEV      |"
echo -e "------------------------------\n"

echo "Please check you already installed :"
echo " - aws, the AWS command-line tool,"
echo "   -> https://aws.amazon.com/en/cli/"
echo "   with a 'kasaharacup-dev' profile that allows you to copy assets from kasaharacup-heroku-production to your dev bucket"

echo

if [[ $UID != 0 ]]; then
  echo "Please run this script with sudo:"
  echo "sudo bash $0"
  exit 1
fi

if [[ ${PWD##*/} != "kasaharacup" ]]; then
  echo "Please run this script from the your app root directory"
  exit 1
fi

# Here we capture a new backup of the DB
capture_dump() {
  set -x
  heroku pg:backups:capture -a kasaharacup-production
  set +x
}

set +x
echo -e "\nCAPTURE DUMP"
echo "------------------------------"
echo "Capture a new dump on Heroku? (y/n)"
read -r capture
if [[ "$capture" != "${capture#[Yy]}" ]]; then
  capture_dump
fi

# Here we download the latest backup of the DB
download_dump() {
  set -x
  curl -o tmp/kasaharacup-production.dmp `heroku pg:backups:url --app kasaharacup-production`
}

set +x
echo -e "\nDOWNLOAD DUMP"
echo "------------------------------"

if test -f "tmp/kasaharacup-production.dmp"; then
  echo "Dump detected in tmp folder ($(ls -l tmp/kasaharacup-production.dmp | cut -d ' ' -f '9-11')). Re-download it? (y/n)"
  read -r fresh_dump
  if [[ "$fresh_dump" != "${fresh_dump#[Yy]}" ]]; then
    download_dump
  fi
else
  download_dump
fi

set +x
echo -e "\nDATABASE CREATION"
echo "------------------------------"

su $SUDO_USER <<'EOF'
  set -x
  bundle exec rails db:drop db:create
EOF

set +x
echo -e "\nDATABASE RESTORATION"
echo "------------------------------"

su $SUDO_USER <<'EOF'
  set -x
  psql kasaharacup_development -c "CREATE SCHEMA IF NOT EXISTS heroku_ext" -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA heroku_ext"
EOF

su $SUDO_USER <<'EOF'
  set -x
  pg_restore -O -d kasaharacup_development tmp/kasaharacup-production.dmp
EOF

# The heroku_ext schema created above exists only so pg_restore can resolve the
# dump's references to it — Heroku installs its extensions there. With the data
# in, move the extension into public and drop the now-empty schema.
#
# This has to happen BEFORE db:migrate. Rails re-dumps db/schema.rb after every
# migration, and it qualifies any extension sitting outside the search path, so
# the dump comes out as enable_extension "heroku_ext.pg_stat_statements". That
# line cannot load into the test database, which has no such schema: the load
# aborts, schema_migrations is left empty, and rspec then reports every
# migration as pending — the misleading "you have N pending migrations" error.
# Relocating first keeps the dumped line unqualified, matching what is committed.
#
# Each statement gets its own -c. psql sends a single -c string to the server as
# one transaction, so pairing them would roll the relocation back whenever the
# drop failed — silently undoing the fix. Split, the relocation commits on its
# own and only the cleanup can fail; a leftover heroku_ext is cosmetic, since
# db/schema.rb never mentions the schema itself. SET SCHEMA is a no-op when the
# extension already sits in public, so a re-run is harmless, and RESTRICT
# refuses rather than destroys, should a dump put something else in there.
#
# set -e stops the block if the relocation fails, so db:migrate can never re-dump
# the qualified name from a database that was never fixed up.
su $SUDO_USER <<'EOF'
  set -e
  set -x
  psql kasaharacup_development -c "ALTER EXTENSION pg_stat_statements SET SCHEMA public"
  psql kasaharacup_development -c "DROP SCHEMA IF EXISTS heroku_ext RESTRICT" ||
    echo "NOTE: heroku_ext still holds objects and was left in place"
  bundle exec rails db:migrate
  set +x
  git diff --quiet db/schema.rb ||
    echo "WARNING: the sync rewrote db/schema.rb — review it before committing"
EOF

delete_dump() {
  set -x
  if test -f "tmp/kasaharacup-production.dmp"; then
    rm tmp/kasaharacup-production.dmp
  fi
}

echo "Delete dump file? (y/n)"
read -r delete
if [[ "$delete" != "${delete#[Yy]}" ]]; then
  delete_dump
fi

set +x
echo -e "\nASSETS SYNC"
echo "------------------------------"

sync_assets() {
  echo "Sync development assets from s3://kasaharacup-heroku-production"
  set -x
  aws s3 sync s3://kasaharacup-heroku-production s3://kasaharacup-dev-yannis --profile kasaharacup-dev-yannis
  set +x
}


echo "Sync S3 development assets from production? (y/n)"
read -r sync
if [[ "$sync" != "${sync#[Yy]}" ]]; then
  sync_assets
fi

set +x
echo -e "\n------------------------------"
echo "|     REFRESH COMPLETED      |"
echo "------------------------------"
