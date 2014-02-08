#!/bin/bash

echo [erizo_controller] Installing node_modules for erizo_controller

cd erizoController

npm install --loglevel error socket.io@0.9 winston@0.7
if [ "$AMQP" != "0" ]; then
    npm install --loglevel error amqp
else
    npm install --loglevel error dnode deferred
fi

echo [erizo_controller] Done, node_modules installed

cd ../erizoClient/tools

./compile.sh
./compilefc.sh

echo [erizo_controller] Done, erizo.js compiled
