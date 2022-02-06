#!/bin/bash

echo "---------------------------------------------------"
echo "|    Rotate Heroku PostgreSQL DB credentials      |"
echo "---------------------------------------------------\n"

echo "This script leverages the Heroku CLI. If you haven't set it up yet, please follow the instructions"
echo "available here: https://devcenter.heroku.com/articles/heroku-cli"

echo

echo "For which environment would you like to rotate DB credentials?"

PS3='Please enter your choice: '
options=("development" "staging" "production" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "development")
            app="kasaharacup-$opt";
            echo "you chose $opt"
            break
            ;;
        "staging")
            app="kasaharacup-$opt";
            echo "you chose $opt"
            break
            ;;
        "production")
            app="kasaharacup-$opt";
            echo "you chose choice $REPLY which is $opt"
            break
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

echo
echo "For which credentials would you like to rotate DB credentials?"
echo "default: The default credentials, recommended"
echo "all: All credentials including read-only, not always recommended"

PS3='Please enter your choice: '
options=("default" "all" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "default")
            echo "you chose default"
            break
            ;;
        "all")
            credentials="--all";
            echo "you chose all"
            break
            ;;
        "Quit")
            exit
            ;;
        *) echo "invalid option $REPLY";;
    esac
done

set -x
heroku pg:credentials:rotate DATABASE $credentials -a $app
set +x

echo "\n-----------------------------"
echo "|     Rotation Completed      |"
echo "-------------------------------"
