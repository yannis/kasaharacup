#!/bin/sh
echo "-----------------------------------------"
echo "import Heroku PRD database into local DEV"

if [[ $UID != 0 ]]; then
  echo "Please run this script with sudo:"
  echo "sudo bash $0 $*"
  exit 1
fi

if [[ ${PWD##*/} != 'kasaharacup' ]]; then
  echo "Please run this script from the your app root directory"
  exit 1
fi

set -x
curl -o tmp/kasaharacup.dmp `heroku pg:backups public-url --app kasaharacup`
su $SUDO_USER <<'EOF'
set -x
dropdb kasaharacup2_development
createdb kasaharacup2_development
pg_restore -O -d kasaharacup2_development tmp/kasaharacup.dmp
EOF
rm tmp/kasaharacup.dmp

bin/rake db/migrate
set +x
echo "DEV database refresh completed"



echo "------------------------------"
echo "|     REFRESH COMPLETED      |"
echo "------------------------------"
