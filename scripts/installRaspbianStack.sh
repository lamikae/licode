#!/bin/bash
#
# Licode WebRTC stack install script, raspbian flavour.
# MongoDB and RabbitMQ are not installed.
#

source $(dirname "${BASH_SOURCE[0]}")/common-debian-functions

PREFIX_DIR=/opt/share/licode
LICODE_LIBDIR=/opt/share/licode/lib
ASSETS_DIR=/opt/share/licode/assets
NGINX_DIR=/opt/nginx
NODEJS_DIR=/opt/node

install_nginx() {
  package="nginx"
  version="1.5.9"
  url="http://nginx.org/download/nginx-1.5.9.tar.gz"
  install_package $package $version $url $NGINX_DIR \
    '--with-http_ssl_module'
    #'--with-cc-opt=-m64 --with-ld-opt=-m64'
}

install_openssl() {
  install_package "libssl-licode" "1.0.1f" \
    "http://www.openssl.org/source/openssl-1.0.1f.tar.gz" \
    $PREFIX_DIR \
    "-fPIC"
}

# Patch libnice to bypass symmetric NAT
install_libnice() {
  package="libnice-licode"
  version="0.1.4"
  url="http://nice.freedesktop.org/releases/libnice-0.1.4.tar.gz"

  check_package $package $version
  if [ $? == 0 ]; then return 0; fi
  check_deb_build $package $version
  if [ $? != 0 ]; then
    info "Compiling $package to $PREFIX_DIR"
    dirname=$(download_and_unpack $url)
    cd ${dirname} || fail
    echo " * Applying libnice-014.patch0"
    patch -R ./agent/conncheck.c < ${SCRIPTSDIR}/libnice-014.patch0
    ./configure --prefix=$PREFIX_DIR || fail
    make -s V=0 || fail
    build_deb $package $version || fail
  fi
  install_deb "${package}_${version}*.deb" || fail
}

build_libsrtp() {
  package="libsrtp-licode"
  version="1.4.4"

  check_package $package $version
  if [ $? == 0 ]; then return 0; fi
  check_deb_build $package $version
  if [ $? != 0 ]; then
    info "Compiling $package to $PREFIX_DIR"
    cd ${ROOT}/third_party/srtp || fail
    CFLAGS="-fPIC" ./configure --prefix=$PREFIX_DIR && \
    make -s V=0 || fail

    # scrub old files, otherwise checkinstall won't run
    make uninstall &>/dev/null
    build_deb $package $version || fail
  fi
  install_deb "${package}_${version}*.deb" || fail
}

install_mediadeps() {
  install_mediadeps_nogpl
}

install_mediadeps_nogpl() {
  package="libav-licode"
  version="9.9"
  url="https://www.libav.org/releases/libav-9.9.tar.gz"

  check_package $package $version
  if [ $? == 0 ]; then return 0; fi
  check_deb_build $package $version
  if [ $? != 0 ]; then
    info "Compiling $package to $PREFIX_DIR"
    dirname=$(download_and_unpack $url)

    # This is a minimal install, without media transcoding
    cd ${dirname} || fail
    ./configure --prefix=$PREFIX_DIR \
      --extra-cflags="-fPIC" \
      --extra-ldflags="-lpthread" \
      --extra-libs="-ldl" \
      --disable-debug \
      --enable-pic --enable-memalign-hack --enable-pthreads \
      --enable-shared --disable-static \
      --disable-network --disable-protocols --disable-devices \
      --disable-filters --disable-bsfs --disable-hwaccels \
      --disable-avserver --disable-filters \
      --disable-muxers --disable-demuxers \
      --disable-encoders --disable-decoders \
      --disable-parsers --disable-programs \
      --disable-neon && \
    make -s V=0 || fail

    build_deb $package $version || fail
  fi
  install_deb "${package}_${version}*.deb" || fail
}

# The log4cxx logger is available as a .tar.gz package directly
# from Apache, but does not compile on relatively recent 4.x GCC
# without a few (trivial) patches. The SVN trunk version has fixed
# these bugs, but does not compile on Raspberry due to other problems.
#
# Using the deb package itself is problematic due to very complex
# chain of dependencies that easily breaks on some installations.
# This install script should also work on x86* installs.
#
# So, the solution here is to download and patch the source package.
install_liblog4cxx() {
  package="liblog4cxx-licode"
  version="0.10.0"
  url="http://mirror.netinch.com/pub/apache/logging/log4cxx/0.10.0/apache-log4cxx-0.10.0.tar.gz"

  check_package $package $version
  if [ $? == 0 ]; then return 0; fi
  check_deb_build $package $version
  if [ $? != 0 ]; then
    info "Compiling $package to $PREFIX_DIR"
    dirname=$(download_and_unpack $url)

    cd ${dirname} || fail
    # patch the sources
    for patch in ${ROOT}/third_party/log4cxx-patches/*patch; do
      patch -N -p1 < $patch
    done

    info "This will take a while, go grab some coffee or take a nap"

    ./autogen.sh && \
    ./configure --prefix=$PREFIX_DIR \
      --with-apr=$PREFIX_DIR \
      --with-apr-util=$PREFIX_DIR && \
    make -s V=0 || fail

    build_deb $package $version || fail
  fi
  install_deb "${package}_${version}*.deb" || fail
}

# Dependency for log4cxx
install_libapr() {
  package="libapr-licode"
  version="1.5.0"
  url="http://mirror.netinch.com/pub/apache/apr/apr-1.5.0.tar.gz"
  install_package $package $version $url
}

# Dependency for log4cxx
install_libaprutil() {
  package="libaprutil-licode"
  version="1.5.3"
  url="http://mirror.netinch.com/pub/apache/apr/apr-util-1.5.3.tar.gz"
  install_package $package $version $url $PREFIX_DIR \
    "--with-apr=$PREFIX_DIR"
}


#
#   BEGIN
#
notice "Installing licode raspbian stack"

parse_arguments $*

# Create directories for user.
# Halt with insufficient privileges.
mkdir -p $PREFIX_DIR &>/dev/null
mkdir -p $ASSETS_DIR &>/dev/null
sudo mkdir -p $NGINX_DIR  &>/dev/null
sudo chown `whoami` $NGINX_DIR
touch $PREFIX_DIR || fail
touch $ASSETS_DIR || fail
touch $NGINX_DIR  || fail
if [ -z $(which node) ]; then
  sudo mkdir $NODEJS_DIR &>/dev/null
  sudo chown `whoami` $NODEJS_DIR
  touch $NODEJS_DIR || fail
fi

# This installs build essentials and boost libraries.
install_apt_deps

# Iptables is not part of the licode stack.
# "Force" iptables-persistent install dialog to hide
# by creating /etc/iptables/rules.v4
sudo mkdir /etc/iptables &>/dev/null
sudo sh -c "iptables-save > /etc/iptables/rules.v4" || fail
sudo apt-get -y install iptables-persistent

# Install node.js and nginx
install_nodejs && install_nginx || fail

# Install dependencies
install_libapr && install_libaprutil && install_liblog4cxx
install_libsrtp
install_libnice
install_openssl

if [ "$ENABLE_GPL" = "true" ]; then
  # info "GPL libraries enabled"
  install_mediadeps
else
  # info "No GPL libraries enabled, this disables h264 transcoding, to enable gpl please use the --enable-gpl option"
  install_mediadeps_nogpl
fi


# List packages
notice "All debian packages are ready and installed"
du -h ${DEB_DIR}/*.deb
dpkg-query -l nodejs nginx '*-licode'

info "Installing node-gyp into root"
install_nodegyp

notice \
  "Building erizo and installing npm resources from the web." \
  "Try again if an npm failure halts the install script."
sleep 2
AMQP=0 ${ROOT}/scripts/installErizo.sh || fail

notice \
  "Building nuve and installing npm resources from the web." \
  "Try again if an npm failure halts the install script."
sleep 2
AMQP=0 MONGODB=0 AWS=0 ${ROOT}/scripts/installNuve.sh  || fail

# Everything built, copy libraries and assets

cp ${ROOT}/nuve/nuveClient/dist/nuve.js ${LICODE_LIBDIR}/
cp ${ROOT}/erizo/build/erizo/liberizo.so ${LICODE_LIBDIR}/
mkdir -p ${LICODE_LIBDIR}/erizoAPI &>/dev/null
cp ${ROOT}/erizoAPI/build/Release/addon.node ${LICODE_LIBDIR}/erizoAPI/
cp ${ROOT}/erizo_controller/erizoClient/dist/* ${ASSETS_DIR}/

notice "READY."

du -h ${LICODE_LIBDIR}/liberizo.so \
      ${LICODE_LIBDIR}/erizoAPI/* \
      ${LICODE_LIBDIR}/nuve.js \
      ${ASSETS_DIR}/erizo.js

