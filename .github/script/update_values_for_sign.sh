#!/bin/sh

key_id=$KEY_ID_OF_SIGN
password=$PASSWORD_OF_SIGN
root_path=$(pwd)
sed -i 's#MY_KEY_ID#'$key_id'#g' $1
sed -i 's#MY_PASSWORD#'$password'#g' $1
sed -i 's#MY_KEY_RING_FILE#'$root_path'/secring.gpg#g' $1
