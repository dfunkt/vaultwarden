#!/bin/bash

export PATH=$PATH:/opt/keycloak/bin

CANARY=/tmp/keycloak_setup_done

if [ -f $CANARY ]
then
	echo "Setup should already be done. Will not run."
	exit 0
fi

while true; do
	sleep 5
    kcadm.sh config credentials --server "http://${KC_HTTP_HOST}:${KC_HTTP_PORT}" --realm master --user "$KEYCLOAK_ADMIN" --password "$KEYCLOAK_ADMIN_PASSWORD" --client admin-cli
    EC=$?
    if [ $EC -eq 0 ]; then
        break
    fi
    echo "Will retry in 5 seconds"
done

set -e

kcadm.sh create realms -s realm="$TEST_REALM" -s enabled=true -s "accessTokenLifespan=600"
kcadm.sh create clients -r test -s "clientId=$SSO_CLIENT_ID" -s "secret=$SSO_CLIENT_SECRET" -s "redirectUris=[\"$DOMAIN/*\"]" -i

TEST_USER_ID=$(kcadm.sh create users -r "$TEST_REALM" -s "username=$TEST_USER" -s "firstName=$TEST_USER" -s "lastName=$TEST_USER" -s "email=$TEST_USER_MAIL"  -s emailVerified=true -s enabled=true -i)
kcadm.sh update users/$TEST_USER_ID/reset-password -r "$TEST_REALM" -s type=password -s "value=$TEST_USER_PASSWORD" -n

TEST_USER2_ID=$(kcadm.sh create users -r "$TEST_REALM" -s "username=$TEST_USER2" -s "firstName=$TEST_USER2" -s "lastName=$TEST_USER2" -s "email=$TEST_USER2_MAIL"  -s emailVerified=true -s enabled=true -i)
kcadm.sh update users/$TEST_USER2_ID/reset-password -r "$TEST_REALM" -s type=password -s "value=$TEST_USER2_PASSWORD" -n

TEST_USER3_ID=$(kcadm.sh create users -r "$TEST_REALM" -s "username=$TEST_USER3" -s "firstName=$TEST_USER3" -s "lastName=$TEST_USER3" -s "email=$TEST_USER3_MAIL"  -s emailVerified=true -s enabled=true -i)
kcadm.sh update users/$TEST_USER3_ID/reset-password -r "$TEST_REALM" -s type=password -s "value=$TEST_USER3_PASSWORD" -n

touch $CANARY
