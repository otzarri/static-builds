#!/bin/bash
#
# Creates a static binary distribution of ProxyChains-NG. Downloads the source
# code of ProxyChains-NG and its depencencies, builds them statically in the
# build path and moves the generated files to the target directory.

set -e


#############
# Variables #
#############

# Script paths
rp="$(readlink -f ${PWD})"  # Root path
bp="$(mktemp -d)"  # Build path
dp="${rp}" # Destination path

# Default options
pcng_ver="4.15"

# Package names without extension
pcng_pkg="proxychains-ng-${pcng_ver}"


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

args=$(getopt -l "build-path:,dest-path:,help,keep,verbose,proxychains-ng:" -o "b:,d:,h,k,v" -- "${@}")
eval set -- "${args}"
while [ ${#} -ge 1 ]; do
    case "${1}" in
        --) shift; break;;
        --libevent) libevent_ver="${2}"; shift;;
        --openssl) openssh_ver="${2}"; shift;;
        --tor) tor_ver="${2}"; shift;;
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
            echo "    --proxychains-ng <version-num> (Default: ${pcng_ver})"
            exit 0;;
    esac
    shift
done


###############
# Check paths #
###############

if [[ -d ${dp}/static-${pcng_pkg} ]]; then log error "Directory ${dp}/static-${pcng_pkg} already exists"; exit 1; fi
if [[ ! -d "${bp}" ]]; then mkdir ${bp}; fi
log info "Build path: ${bp}"
cd ${bp}


######################## 
# Build ProxyChains-NG #
########################

if ! is_built ${bp}/${pcng_pkg} https://github.com/rofl0r/proxychains-ng/archive/refs/tags/v${pcng_ver}.tar.gz; then
    log info "Building ${pcng_pkg}"
    cd ${bp}/proxychains-ng-${pcng_ver}
    export LDFLAGS="-static -static-libgcc"
    ./configure \
        --prefix="${bp}/${pcng_pkg}/install/" \
        -static -static-libgcc
    make -j $(nproc)
    make install
    cd ..
fi


############################# 
# Build static distribution #
#############################

log info "Building static distribution of ${pcng_pkg}"
cp -rp ${bp}/${pcng_pkg}/install ${dp}/static-${pcng_pkg}
mkdir ${dp}/static-${pcng_pkg}/etc
cat << 'EOF' > ${dp}/static-${pcng_pkg}/etc/proxychains.conf
strict_chain
proxy_dns
[ProxyList]
socks5 	127.0.0.1 9050
EOF


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

log info "Static distribution of ${pcng_pkg} built successfully"
log info "Path: ${dp}/static-${pcng_pkg}"
