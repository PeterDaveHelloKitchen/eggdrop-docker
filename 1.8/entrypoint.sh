#!/bin/bash
set -e

if [[ "$1" = *".conf" ]]; then
  # allow the container to be started with `--user`
  if [ "$(id -u)" = '0' ]; then
    chown -R eggdrop /home/eggdrop/eggdrop .
    exec su-exec eggdrop "$BASH_SOURCE" "$@"
  fi

  if [ -z ${CONFIG} ]; then
    CONFIG="eggdrop.conf"
  fi

  cd /home/eggdrop/eggdrop
  if ! [ -e /home/eggdrop/eggdrop/data/${CONFIG} ] && ([ -z ${SERVER} ] || [ -z ${NICK} ]); then
    cat <<EOS >&2

--------------------------------------------------
You have not set one of the required variables.
The following variables must be set via the
-e command line argument in order to run eggdrop
for the first time:

NICK   - set IRC nickname
SERVER - set IRC server to connect to

Example:
docker run -ti -e NICK=DockerBot -e SERVER=irc.freenode.net eggdrop

If you wish to telnet or DCC to your bot, you will
need to expose the docker port to your host by
adding -p 3333:3333 (or whatever port eggdrop is
listening on) to your docker run command.

These variables only need to be used the first
time you run the container- after the first use,
you can edit the config file created, directly.
--------------------------------------------------

EOS
    exit 1
  else
    sed -i \
      -e "/set nick \"Lamestbot\"/c\set nick \"$NICK\"" \
      -e "/another.example.com:7000:password/d" \
      -e "/you.need.to.change.this:6667/c\ ${SERVER}" \
      -e "/#listen 3333 all/c\listen ${LISTEN} all" \
      -e "s/^#set dns-servers/set dns-servers/" \
      -e "/#set owner \"MrLame, MrsLame\"/c\set owner \"${OWNER}\"" \
      -e "/set userfile \"LamestBot.user\"/c\set userfile ${USERFILE}" \
      -e "/set chanfile \"LamestBot.chan\"/c\set chanfile ${CHANFILE}" \
      -e "/set realname \"\/msg LamestBot hello\"/c\set realname \"Docker Eggdrop!\"" \
      -e '/edit your config file completely like you were told/d' \
      -e '/Please make sure you edit your config file completely/d' eggdrop.conf
  fi

  if ! mountpoint -q /home/eggdrop/eggdrop/data; then
    cat <<EOS

#####################################################
#####################################################
You did not specify a location on the host machine
to store your data. This means NOTHING will persist
if this docker container is deleted or updated, such
as user lists, chan lists, or ban lists.

In other words, you will likely LOSE YOUR DATA!

Mounting a datastore on the host system will also
give you easy access to edit your configuration file.

If you wish to add the data store, simply run the
container again, but this time adding the option:
----------------------------------------------------
-v /path/to/your/saved/data/:/home/eggdrop/eggdrop/data
----------------------------------------------------
to your 'docker run' command.
####################################################
####################################################

EOS
  fi

### Check if previous config file is present and, if not, create one
  mkdir -p /home/eggdrop/eggdrop/data
  if ! [ -e /home/eggdrop/eggdrop/data/${CONFIG} ]; then
    echo "Previous Eggdrop config file not detected, creating new persistent data file..."
    mv /home/eggdrop/eggdrop/eggdrop.conf /home/eggdrop/eggdrop/data/${CONFIG}
  else
    rm /home/eggdrop/eggdrop/eggdrop.conf
  fi
  ln -s /home/eggdrop/eggdrop/data/${CONFIG} /home/eggdrop/eggdrop/${CONFIG}

### Check for existing userfile and create link to data dir
  USERFILE=$(grep "set userfile " ${CONFIG} |cut -d " " -f 3|cut -d "\"" -f 2)
  if ! [ -e /home/eggdrop/eggdrop/${USERFILE} ]; then
   ln -sf /home/eggdrop/eggdrop/data/${USERFILE} /home/eggdrop/eggdrop/${USERFILE}
  fi

### Check for existing channel file and create link to data dir
  CHANFILE=$(grep "set chanfile " ${CONFIG} |cut -d " " -f 3|cut -d "\"" -f 2)
  if ! [ -e /home/eggdrop/eggdrop/${CHANFILE} ]; then
    ln -sf /home/eggdrop/eggdrop/data/${CHANFILE} /home/eggdrop/eggdrop/${CHANFILE}
  fi

  echo "source scripts/docker.tcl" >> eggdrop.conf

  exec ./eggdrop -nt -m $1
fi
exec "$@"
