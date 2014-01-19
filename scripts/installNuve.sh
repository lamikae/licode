#!/bin/bash
source $(dirname "${BASH_SOURCE[0]}")/common-debian-functions

DB_DIR="$BUILD_DIR"/db

install_nuve(){
  cd $ROOT/nuve && ./installNuve.sh || fail
}

populate_mongo(){

  echo [licode] Starting mongodb
  if [ ! -d "$DB_DIR" ]; then
    mkdir -p "$DB_DIR"/db
  fi
  mongod --repair --dbpath $DB_DIR
  mongod --dbpath $DB_DIR --logpath $BUILD_DIR/mongo.log --fork
  sleep 5

  dbURL=`grep "config.nuve.dataBaseURL" $PATHNAME/licode_default.js`

  dbURL=`echo $dbURL| cut -d'"' -f 2`
  dbURL=`echo $dbURL| cut -d'"' -f 1`

  echo [licode] Creating superservice in $dbURL
  mongo $dbURL --eval "db.services.insert({name: 'superService', key: '$RANDOM', rooms: []})"
  SERVID=`mongo $dbURL --quiet --eval "db.services.findOne()._id"`
  SERVKEY=`mongo $dbURL --quiet --eval "db.services.findOne().key"`

  SERVID=`echo $SERVID| cut -d'"' -f 2`
  SERVID=`echo $SERVID| cut -d'"' -f 1`

  echo "Mongo Logs: "
  cat $BUILD_DIR/mongo.log

  echo [licode] SuperService ID $SERVID
  echo [licode] SuperService KEY $SERVKEY
  cd $BUILD_DIR
  replacement=s/_auto_generated_ID_/${SERVID}/
  sed $replacement $PATHNAME/licode_default.js > $BUILD_DIR/licode_1.js
  replacement=s/_auto_generated_KEY_/${SERVKEY}/
  sed $replacement $BUILD_DIR/licode_1.js > $ROOT/licode_config.js
  rm $BUILD_DIR/licode_1.js
}

install_nuve

# Using env var MONGODB=0 you can bypass this
if [ "$MONGODB" != "0" ]; then
  populate_mongo
fi
