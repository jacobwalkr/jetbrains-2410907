#!/bin/bash
# entrypoint.sh
# Used to wait for Postgres and LDAP and to ensure that the LDAP entries assumed by tests are
# available before executing a command. For use when launching the project with Docker Compose.
# Usage: wait-for-services.sh work_dir keyword [command]
# work_dir: the working directory to change to before executing the command
# keyword: dev|test|deploy_staging|deploy_production

set -e

function check_prepare {
    echo "# Checking database availability"
    mysql_check=0
    until mysql -h "$MYSQL_HOST" -u root -p$MYSQL_ROOT_PASSWORD -e '\q'; do
        >&2 echo "# Waiting for database (${mysql_check}/15)"
        (( mysql_check += 1 ))

        if [ $mysql_check -gt 15 ]; then
            >&2 echo "# Database unavailable after 30 seconds"
            exit 1
        fi

        sleep 2
    done

    echo "# Found the database"

    echo "# Checking LDAP availability"
    ldap_check=0
    until ldapsearch -x -h $LDAP_HOST -p 10389 -s base -b "" "objectclass=*" vendorVersion; do
        >&2 echo "# Waiting for LDAP (${ldap_check}/20)"
        (( ldap_check += 1 ))

        if [ $ldap_check -gt 20 ]; then
            >&2 echo "# LDAP unavailable after 40 seconds"
            exit 1
        fi

        sleep 2
    done

    echo "# Found LDAP"
    echo "# Making sure LDAP is seeded"
    if ! ldapsearch -x -h $LDAP_HOST -p 10389 "uid=staff_ai" | grep "numEntries: 1"; then
        echo "# Seeding LDAP"
        ldapadd -v -h $LDAP_HOST -p 10389 -c -x -D uid=admin,ou=system -w secret -f /app/db/ldap.ldif > /dev/null
    else
        echo "# LDAP already seeded"
    fi

    echo "# Done checking dependencies"
}

# just nuke directories that make issues - used after CI tasks
function clean_up {
    rm -rf node_modules/ public/packs-test/ tmp/
}

if [ -f /root/.ssh/id_rsa ]; then
    echo "# Initialising SSH agent"
    eval $(ssh-agent -s)
    ssh-add /root/.ssh/id_rsa
else
    echo "# No private key found - skipping"
fi

case $1 in
    dev)
        check_prepare
        yarn install --frozen-lockfile
        echo "# Deleting PID file"
        rm -f tmp/pids/server.pid
        echo "# Starting the dev server"
        bundle exec rails server -b 0.0.0.0
        ;;
    test)
        trap 'clean_up' ERR
        export RAILS_ENV=test RUN_COVERAGE=true
        check_prepare
        yarn install --frozen-lockfile
        bundle exec rails webpacker:compile
        bundle exec rake db:environment:set
        bundle exec rake db:drop
        bundle exec rake db:create
        bundle exec rake db:structure:load
        bundle exec rake rubocop reek spec
        >&2 echo "# Cleaning up"
        clean_up
        ;;
    deploy_staging)
        trap 'clean_up' ERR
        >&2 echo "# Skipping service dependency checks for deployment"
        bundle exec cap staging deploy
        >&2 echo "# Cleaning up"
        clean_up
        ;;
    deploy_production)
        trap 'clean_up' ERR
        >&2 echo "# Skipping service dependency checks for deployment"
        bundle exec cap production deploy
        >&2 echo "# Cleaning up"
        clean_up
        ;;
    *)
        echo "# No action matched: running directly as bash command"
        check_prepare
        yarn install --frozen-lockfile
        eval "$*"
esac
