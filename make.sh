#!/bin/bash

set -e

HOST_DIR=`pwd`
DK_DIR=/usr/src/app

ENV_BACKEND=csci-e39.herokuapp.com
ENV_PORT=3000
ENV_STUDENT_ID=`cat .id`

REPO=tshelburne/csci-e39
TAG=master
IMAGE=$REPO:$TAG

function mount() {
	MOUNTED=""
	for TARGET in "$@"; do
		MOUNTED="$MOUNTED -v $HOST_DIR/$TARGET:$DK_DIR/$TARGET"
	done
	echo $MOUNTED
}

DK_MOUNT_DEBUG=`mount build public`
DK_MOUNT=`mount src .id dev.sqlite3 package.json package-lock.json`
DK_ENV="-e PORT=$ENV_PORT -e STUDENT_ID=$ENV_STUDENT_ID -e DATABASE_URL=$DATABASE_URL"
DK_PORTS="--expose $ENV_PORT -p $ENV_PORT:$ENV_PORT --expose 35729 -p 35729:35729"
DK_DEBUG="-e DEBUG=knex:*,socket.io:*,csci-e39:*"

function all() {
	clean
	migrate
	start
}

function clean() {
	stop
	rm -rf build node_modules public dev.sqlite3
	docker rmi -f `docker images -qa $REPO`
}

function build() {
	touch dev.sqlite3
	docker build -t $IMAGE .
}

function activate() {
	local ASSIGNMENT=$1
	build
	docker run $DK_MOUNT $DK_ENV $IMAGE sed -i -e "s/assignments\/.*\//assignments\/$ASSIGNMENT\//g" src/ui/app.jsx.js src/ui/index.pug
}

function start() {
	build
	docker run $DK_MOUNT $DK_ENV $DK_PORTS $IMAGE
}

function stop() {
	docker stop `docker ps -qa --filter="ancestor=$IMAGE"` || true
}

function watch() {
	build
	docker run $DK_MOUNT $DK_ENV $DK_PORTS $DK_DEBUG $IMAGE npm run watch
}

function live() {
	build
	docker run $DK_MOUNT $DK_ENV $DK_PORTS -e BACKEND=$ENV_BACKEND $IMAGE
}

function migrate() {
	build
	docker run $DK_MOUNT $DK_ENV $IMAGE npm run migrate
	docker run $DK_MOUNT $DK_ENV $IMAGE npx knex seed:run
}

CMD=$1; shift
case $CMD in
	'all') all;;
	'clean') clean;;
	'build') build;;
	'activate')
		ASSIGNMENT=$1
		activate $ASSIGNMENT;;
	'start') start;;
	'stop') stop;;
	'watch') watch;;
	'live') live;;
	'migrate') migrate;;
esac