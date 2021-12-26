#!/bin/bash
#
# Creates a static binary distribution of Tor. Downloads the source code of Tor
# and its depencencies, builds them statically in the build path and moves the
# generated files to the target directory.

set -e


#############
# Variables #
#############

# Script paths
rp="$(readlink -f ${PWD})"  # Root path
bp="$(mktemp -d)"  # Build path
dp="${rp}"  # Destination path

# Default options
libevent_ver="2.1.12-stable"
openssl_ver="1.0.2u"
tor_ver="0.4.6.8"
zlib_ver="1.2.11"
keep=false

# Package names without extension
libevent_pkg="libevent-${libevent_ver}"
openssl_pkg="openssl-${openssl_ver}"
tor_pkg="tor-${tor_ver}"
zlib_pkg="zlib-${zlib_ver}"


#############
# Functions #
#############

# Prints log level and message in a different color depending on the log level.
log() {
    level="${1}"
    message="${2}"
    reset_col="\e[0m"

    case "${level}" in
        info) color="\033[01;32m"; level="[INFO] ";;
        warn|warning) color="\033[01;33m"; level="[WARN] ";;
        err|error) color="\033[01;31m"; level="[ERR] ";;
        *) unset level
    esac
    echo -e "${color}${level^^}${message}${reset_col}"
}


# Checks if the destination directory exists. If exists, this script assumes
# that target directory was created previously by itself so stops its execution.
is_built() {
     source_dir=${1}
     source_url=${2}
     build_dir=$(dirname ${source_dir})
     source_zip=${source_url##*/}

    if [[ -d "${source_dir}" ]]; then
        log "warn" "Skipping to build ${source_zip}: Directory ${source_dir} already exists."
        return 0
    else
        if [[ -f "${build_dir}/${source_zip}" ]]; then
            log warn "Skipping to download ${source_zip}: File ${build_dir}/${source_zip} already exists."
        else
            log info "Downloading ${source_zip}"
            wget --no-check-certificate --directory-prefix=${build_dir} ${source_url}
        fi
        if [[ ${build_dir}/${source_zip} == *".tar.gz" ]]; then tar xfv ${build_dir}/${source_zip} -C ${build_dir}; fi
        return 1
    fi
}


#############
# Arguments #
#############

args=$(getopt -l "build-path:,dest-path:,help,keep,verbose,libevent:,openssl:,tor:,zlib:" -o "b:,d:,h,k,v" -- "${@}")
eval set -- "${args}"
while [ ${#} -ge 1 ]; do
    case "${1}" in
        --) shift; break;;
        --libevent) libevent_ver="${2}"; shift;;
        --openssl) openssh_ver="${2}"; shift;;
        --tor) tor_ver="${2}"; shift;;
        --zlib) zlib_ver="${2}"; shift;;
        -b|--build-path) rmdir ${bp}; bp="$(readlink -f ${2})"; shift;;
        -k|--keep) keep=true;;
        -v|--verbose) set -x;;
        -h|--help)
            echo "Usage: ${0} [options...]"
            echo "Options:"
            echo "    -b, --build-path <build-path>      (Default: Randomly named directory under /tmp)"
            echo "    -d, --dest-path <dest-path>        (Default: Directory the script was called from)"
            echo "    -h, --help                         Show this help message"
            echo "    -k, --keep                         Do not remove build directory"
            echo "    -v, --verbose                      Shows more detailed output"
            echo "        --libevent <version-num>  (Default: ${libevent_ver})"
            echo "        --openssl <version-num>    (Default: ${openssl_ver})"
            echo "        --tor <version-num>            (Default: ${tor_ver})"
            echo "        --zlib <version-num>          (Default: ${zlib_ver})"
            exit 0;;
    esac
    shift
done


###############
# Check paths #
###############

if [[ -d ${dp}/static-${tor_pkg} ]]; then log error "Directory ${dp}/static-${tor_pkg} already exists"; exit 1; fi
if [[ ! -d "${bp}" ]]; then mkdir ${bp}; fi
log info "Build path: ${bp}"
cd ${bp}


#####################
#    Build Zlib     #
# Dependency of Tor #
#####################

if ! is_built ${bp}/${zlib_pkg} http://zlib.net/${zlib_pkg}.tar.gz; then
    log info "Building ${zlib_pkg}"
    cd ${bp}/${zlib_pkg}
    ./configure --static --prefix="${bp}/${zlib_pkg}/install"
    make -j $(nproc) 
    make BINARY_PATH=$PREFIXDIR/bin INCLUDE_PATH=$PREFIXDIR/include LIBRARY_PATH=$PREFIXDIR/lib SHARED_MODE=1 install
    cd ..
fi


##################### 
#   Build libevent  #
# Dependency of Tor #
#####################

if ! is_built ${bp}/${libevent_pkg} https://github.com/libevent/libevent/releases/download/release-${libevent_ver}/${libevent_pkg}.tar.gz; then
    log info "Building ${libevent_pkg}"
    cd ${bp}/${libevent_pkg}
    ./configure --prefix="${bp}/${libevent_pkg}/install" --enable-static --disable-shared
    make -j $(nproc)
    make install
    cd ..
fi


##################### 
#   Build OpenSSL   #
# Dependency of Tor #
#####################

if ! is_built ${bp}/${openssl_pkg} https://www.openssl.org/source/${openssl_pkg}.tar.gz; then
    log info "Building ${openssl_pkg}"
    arch=$(lscpu | grep 'Arch' | awk '{print $2}')
    if [[ "${arch}" == "x86_64" ]]; then nistp="enable-ec_nistp_64_gcc_128"; else nistp="enable-ec_nistp"; fi
    cd ${bp}/${openssl_pkg}
    export LDFLAGS="-static -static-libgcc"
    ./config no-dso no-shared no-zlib no-asm $nistp --prefix="${bp}/${openssl_pkg}/install/" -static -static-libgcc
    make -j $(nproc)
    make install_sw
    cd ..
fi
	

###################### 
#     Build Tor      #
# Target application #
######################

if ! is_built ${bp}/${tor_pkg} https://dist.torproject.org/${tor_pkg}.tar.gz; then
    log info "Building ${tor_pkg}"
    cd ${bp}/${tor_pkg}
    export LIBS="-lssl -lcrypto -lpthread -ldl"
    export LDFLAGS="-static -static-libgcc -L/usr/lib/gcc/x86_64-linux-gnu/8/ -L${openssl_pkg}/install/lib/"
    ./configure \
        --prefix="${bp}/${tor_pkg}/install" \
        --disable-html-manual \
        --disable-asciidoc \
        --enable-static-tor \
        --with-libevent-dir="${bp}/${libevent_pkg}/install/" \
        --with-openssl-dir="${bp}/${openssl_pkg}/install/" \
        --with-zlib-dir="${bp}/${zlib_pkg}"
    make -j $(nproc)
    make install
    cd ..
fi


############################# 
# Build static distribution #
#############################

log info "Building static distribution of ${tor_pkg}"
cp -rp ${bp}/${tor_pkg}/install ${dp}/static-${tor_pkg}
cp -rp ${bp}/${tor_pkg}/install/etc/tor/torrc.sample ${dp}/static-${tor_pkg}/etc/torrc
cp -rp ${bp}/${tor_pkg}/install/etc/tor/torrc.sample ${dp}/static-${tor_pkg}/etc/torrc.defaults
mkdir -p ${dp}/static-${tor_pkg}/data/hidden-services
cat << 'EOF' > ${dp}/static-${tor_pkg}/tor.sh
#!/bin/bash

rp="$(dirname $(readlink -f ${0}))"  # Root path

${rp}/bin/tor \
    --defaults-torrc ${rp}/etc/torrc-defaults \
    -f ${rp}/etc/torrc \
    --DataDirectory ${rp}/data \
    --GeoIPFile ${rp}/share/tor/geoip \
    --GeoIPv6File ${rp}/share/tor/geoip6 \
    --SocksPort 9050
EOF
cp ${dp}/static-${tor_pkg}/tor.sh ${dp}/static-${tor_pkg}/tord.sh
sed -i '$i--RunAsDaemon 1 \\' ${dp}/static-${tor_pkg}/tord.sh


###########
# Cleanup #
###########

if [[ ${keep} == true ]]; then
    log info "Keeping build directory ${bp}" 
else
    log info "Removing build directory ${bp}" 
    rm -rf ${bp}
fi


##########
# Output #
##########

log info "Static distribution of ${tor_pkg} built successfully"
log info "Path: ${dp}/static-${tor_pkg}"
