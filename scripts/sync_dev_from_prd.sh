#!/bin/bash

echo "------------------------------"
echo "|    HEROKU PROD -> DEV      |"
echo "------------------------------\n"

echo "Please check you already installed :"
echo " - aws, the AWS command-line tool,"
echo "   -> https://aws.amazon.com/en/cli/"
echo "   with a 'kasaharacup-dev' profile that allows you to copy assets from kasaharacup-heroku-production to your dev bucket"

echo

if [[ $UID != 0 ]]; then
  echo "Please run this script with sudo:"
  echo "sudo bash $0 $*"
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
echo "\nCAPTURE DUMP"
echo "------------------------------"
if [[ ARGV[0] == "-auto" ]]; then
  capture=$(ruby -ryaml -e "puts YAML::load(open(ARGV.first).read)['capture_dump']" config/prd_to_dev.yml)
  if [[ "$capture" == "true" ]]; then
    capture_dump
  fi
else
  echo "Capture a new dump on Heroku? (y/n)"
  read capture
  if [[ "$capture" != "${capture#[Yy]}" ]]; then
    capture_dump
  fi
fi

# Here we download the latest backup of the DB
download_dump() {
  set -x
  curl -o tmp/kasaharacup-production.dmp `heroku pg:backups:url --app kasaharacup-production`
}

set +x
echo "\nDOWNLOAD DUMP"
echo "------------------------------"

if test -f "tmp/kasaharacup-production.dmp"; then
  echo "Dump detected in tmp folder ($(ls -l tmp/kasaharacup-production.dmp | cut -d ' ' -f '9-11')). Re-download it? (y/n)"
  read fresh_dump
  if [[ "$fresh_dump" != "${fresh_dump#[Yy]}" ]]; then
    download_dump
  fi
else
  download_dump
fi

set +x
echo "\nDATABASE CREATION"
echo "------------------------------"

su $SUDO_USER <<'EOF'
  set -x
  bundle exec rails db:drop db:create
EOF

set +x
echo "\nDATABASE RESTORATION"
echo "------------------------------"

su $SUDO_USER <<'EOF'
  set -x
  psql kasaharacup_development -c "CREATE SCHEMA IF NOT EXISTS heroku_ext; CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA heroku_ext;"
EOF

su $SUDO_USER <<'EOF'
  set -x
  pg_restore -O -d kasaharacup_development tmp/kasaharacup-production.dmp
  bundle exec rails db:migrate
EOF

delete_dump() {
  set -x
  if test -f "tmp/kasaharacup-production.dmp"; then
    rm tmp/kasaharacup-production.dmp
  fi
}

echo "Delete dump file? (y/n)"
read delete
if [[ "$delete" != "${delete#[Yy]}" ]]; then
  delete_dump
fi

set +x
echo "\nASSETS SYNC"
echo "------------------------------"

sync_assets() {
  echo "Sync development assets from s3://kasaharacup-heroku-production"
  set -x
  aws s3 sync s3://kasaharacup-heroku-production s3://kasaharacup-dev-yannis --profile kasaharacup-dev-yannis
  set +x
}


echo "Sync S3 development assets from production? (y/n)"
read sync
if [[ "$sync" != "${sync#[Yy]}" ]]; then
  sync_assets
fi

set +x
echo "\n------------------------------"
echo "|     REFRESH COMPLETED      |"
echo "------------------------------"
