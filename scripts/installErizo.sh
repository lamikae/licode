#!/bin/bash
source $(dirname "${BASH_SOURCE[0]}")/common-debian-functions

PREFIX_DIR=/opt/share/licode


install_erizo(){
  cd $ROOT/erizo
  ./generateProject.sh && \
  ./buildProject.sh || fail
  export ERIZO_HOME=`pwd`
  cd $CURRENT_DIR
}

install_erizo_api(){
  cd $ROOT/erizoAPI
  ./build.sh || fail
  cd $CURRENT_DIR
}

install_erizo_controller(){
  cd $ROOT/erizo_controller
  ./installErizo_controller.sh || fail
  cd $CURRENT_DIR
}

info 'Installing erizo...'
install_erizo
info 'Installing erizoAPI...'
install_erizo_api
info 'Installing erizoController...'
install_erizo_controller
