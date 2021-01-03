#!/usr/bin/env bash

declare -A _keep

_keep=(
  [frequent]='4'
  [hourly]='48'
  [daily]='14'
  [weekly]='8'
  [monthly]='12'
)

ret=0

usage() {
  echo "Usage: $0 <$(printf '%s | ' ${!_keep[@]} | head -c -3)>"
}


err() {
  echo $* > /dev/stderr
}


failcode() {
  ret=$1
  shift
  err $*
  exit $ret
}


fail() {
  failcode 1 $*
}


_zfs=`which zfs &>/dev/null`
[ $? -gt 0 ] && fail '`zfs` command not found.'

which tail &>/dev/null
[ $? -gt 0 ] && fail '`tail` command not found.'


[ -z $1 ] && fail "Syntax error." `usage`

[ -z "${_keep[$1]}" ] && fail "Syntax error." `usage`


label=$1

DATASETS=$(env LC_ALL=C zfs list -Ht filesystem,volume -o name,com.sun:auto-snapshot,com.sun:auto-snapshot:${label})
[ $? -gt 0 ] && fail 'Error enumerating zfs datasets.'


while read name snap keep; do
  if [ ${keep,,} = "true" ]; then keep=${_keep[$label]}; fi

  if [[ "${snap,,}" = "true" && "$keep" =~ ^[0-9]+$ ]]; then
    if [ $keep -gt 0 ]; then
      SNAPPROPS="-o eznap:label=$label"
      SNAPNAME="$name@eznap-${label}_$(date -u +"%Y-%d-%m_%H:%M:%S")"
      zfs snapshot $SNAPPROPS "$SNAPNAME" 2>/dev/null
      [ $? -gt 0 ] && err "Create snapshot failed for '$SNAPNAME'." && ret=2
    fi

    SNAPSHOTS=$(env LC_ALL=C zfs list -H -t snapshot -S creation -o name,eznap:label)
    [ $? -gt 0 ] && err "Error enumerating zfs snapshots. No old snapshots deleted for dataset '$name'." && ret=2

    DESTROY=$(
      while read sname slabel; do
        if [ "${sname%%@*}" = "$name" -a "$slabel" = "$label" ]; then
          echo $sname
        fi
      done <<< $SNAPSHOTS | tail -n +$(( $keep + 1 ))
    )

    for sn in $DESTROY; do
      zfs destroy "$sn" 2>/dev/null
      [ $? -gt 0 ] && err "Destroy snapshot failed for '$sn'." && ret=2
    done

  fi
done <<< $DATASETS

exit $ret

