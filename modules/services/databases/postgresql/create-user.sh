#!/bin/bash

################################################################################
set -e

################################################################################
option_username=""
option_password_file=""
option_sqlfile="@out@/sql/create-user.sql"
option_superuser=0

################################################################################
usage () {
cat <<EOF
Usage: create-user.sh [options]

  -h      This message
  -p FILE File containing USER's password
  -s FILE The SQL template file (pg-create-user.sql)
  -S      Give USER super powers
  -u USER Username to create
EOF
}

################################################################################
while getopts "hp:s:Su:" o; do
  case "${o}" in
    h) usage
       exit
       ;;

    p) option_password_file=$OPTARG
       ;;

    s) option_sqlfile=$OPTARG
       ;;

    S) option_superuser=1
       ;;

    u) option_username=$OPTARG
       ;;

    *) exit 1
       ;;
  esac
done

shift $((OPTIND-1))

################################################################################
tmp_sql_file=$(mktemp --suffix=.sql --tmpdir new-user.XXXXXXXXX)

cleanup() {
  rm -f "$tmp_sql_file"
}

trap cleanup EXIT

################################################################################
_psql() {
  @sudo@ -u @superuser@ -H psql "$@"
}

################################################################################
mksql() {
  # FIXME: Passwords can't contain single quotes due to this simple logic:
  if head -n 1 "$option_password_file" | grep -q "'"; then
    >&2 echo "ERROR: password for $option_username contains single quote!"
    exit 1
  fi

  password=$(head -n 1 "$option_password_file")

  awk -v 'USERNAME'="$option_username" \
      -v 'PASSWORD'="$password" \
      ' { gsub(/@@USERNAME@@/, USERNAME);
          gsub(/@@PASSWORD@@/, PASSWORD);
          print;
        }
      ' < "$option_sqlfile" > "$tmp_sql_file"

  # Let the database user read the generated file.
  chmod go+r "$tmp_sql_file"
}

################################################################################
create_user() {
  local superuser

  if [ "$option_superuser" -eq 1 ]; then
    superuser="SUPERUSER"
  else
    superuser="NOSUPERUSER"
  fi

  mksql
  _psql -d postgres -f "$tmp_sql_file" > /dev/null
  _psql -d postgres -c "ALTER ROLE $option_username $superuser"
}

################################################################################
create_user
