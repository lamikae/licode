#!/bin/bash

SCRIPT=`pwd`/$0
FILENAME=`basename $SCRIPT`
PATHNAME=`dirname $SCRIPT`
ROOT=$PATHNAME/..
BUILD_DIR=$ROOT/build
CURRENT_DIR=`pwd`
DB_DIR="$BUILD_DIR"/db

cd $PATHNAME

cd nuveAPI

echo [nuve] Installing node_modules for nuve

npm install --loglevel error express@3.4 node-uuid
if [ "$AMQP" != "0" ]; then
    npm install --loglevel error amqp
else
    npm install --loglevel error dnode deferred
fi
if [ "$MONGODB" != "0" ]; then
    npm install --loglevel error mongojs
fi
if [ "$AWS" != "0" ]; then
    npm install --loglevel error aws-lib
fi

echo [nuve] Done, node_modules installed

cd ../nuveClient/tools

./compile.sh

echo [nuve] Done, nuve.js compiled

cd $CURRENT_DIR
