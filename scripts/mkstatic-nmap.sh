#!/bin/bash
#
# Creates a static binary distribution of Nmap. Downloads the source code of Nmap
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
nmap_ver="7.92"
openssl_ver="1.1.1m"
#openssl_ver="1.0.2u"
zlib_ver="1.2.11"
keep=false

# Package names without extension
openssl_pkg="openssl-${openssl_ver}"
nmap_pkg="nmap-${nmap_ver}"
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
        if [[ ${build_dir}/${source_zip} == *".tar.bz2" ]]; then tar xfv ${build_dir}/${source_zip} -C ${build_dir}; fi
        return 1
    fi
}


#############
# Arguments #
#############

args=$(getopt -l "build-path:,dest-path:,help,keep,verbose,openssl:,nmap:,zlib:" -o "b:,d:,h,k,v" -- "${@}")
eval set -- "${args}"
while [ ${#} -ge 1 ]; do
    case "${1}" in
        --) shift; break;;
        --nmap) tor_ver="${2}"; shift;;
        --openssl) openssh_ver="${2}"; shift;;
        --zlib) zlib_ver="${2}"; shift;;
        -b|--build-path) rmdir ${bp}; bp="$(readlink -f ${2})"; shift;;
        -d|--dest-path) dp="$(readlink -f ${2})"; shift;;
        -k|--keep) keep=true;;
        -v|--verbose) set -x;;
        -h|--help)
            echo "Usage: ${0} [options...]"
            echo "Options:"
            echo "    -b, --build-path <build-path>  (Default: Randomly named directory under /tmp)"
            echo "    -d, --dest-path <dest-path>    (Default: Directory the script was called from)"
            echo "    -h, --help                     Show this help message"
            echo "    -k, --keep                     Do not remove build directory"
            echo "    -v, --verbose                  Shows more detailed output"
            echo "        --openssl <version-num>    (Default: ${openssl_ver})"
            echo "        --nmap <nmap-version>      (Default: ${nmap_ver})"
            exit 0;;
    esac
    shift
done


###############
# Check paths #
###############

if [[ -d ${dp}/static-${nmap_pkg} ]]; then log error "Directory ${dp}/static-${nmap_pkg} already exists"; exit 1; fi
if [[ ! -d "${bp}" ]]; then mkdir ${bp}; fi
log info "Build path: ${bp}"
cd ${bp}


###################### 
#   Build OpenSSL    #
# Dependency of Nmap #
######################

if ! is_built ${bp}/${openssl_pkg} https://www.openssl.org/source/${openssl_pkg}.tar.gz; then
    log info "Building ${openssl_pkg}"
    arch=$(lscpu | grep 'Arch' | awk '{print $2}')
    cd ${bp}/${openssl_pkg}
    export LDFLAGS="-static -static-libgcc"
    ./config \
        no-dso no-shared no-zlib no-asm $nistp \
        --prefix="${bp}/${openssl_pkg}/install/" \
        -static \
        -static-libgcc
    make -j $(nproc)
    make install_sw
    cd ..
fi


###################### 
#     Build Nmap     #
# Target application #
######################

if ! is_built ${bp}/${nmap_pkg} http://nmap.org/dist/${nmap_pkg}.tar.bz2; then
    log info "Building ${nmap_pkg}"
    cd ${bp}/${nmap_pkg}
    LDFLAGS="-L${bd}/openssl-${OPENSSL_VERSION}/install" \
    ./configure \
        --prefix="${bp}/${nmap_pkg}/install" \
        --without-zenmap \
        --without-nmap-update \
        --with-pcap=linux \
        --with-libz=included \
        --with-openssl="${bp}/${openssl_pkg}/install" 
    sed -i -e 's/shared\: /shared\: #/' ${bp}/${nmap_pkg}/libpcap/Makefile
    make -j $(nproc)
    make install
    cd ..
fi


############################# 
# Build static distribution #
#############################

log info "Building static distribution of ${nmap_pkg}"
cp -rp ${bp}/${nmap_pkg}/install ${dp}/static-${nmap_pkg}


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

log info "Static distribution of ${nmap_pkg} built successfully"
log info "Path: ${dp}/static-${nmap_pkg}"
