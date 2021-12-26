# static-binaries

This repository aims to release tools for building static binaries.

Static binary status:

| Application    | Binary                    | Status  | Script                                                             |
|----------------|---------------------------|---------|--------------------------------------------------------------------|
| Nmap           | ncat                      | Dynamic | [mkstatic-nmap.sh](./scripts/mkstatic-nmap.sh)                     |
| Nmap           | ndiff                     | Static  | [mkstatic-nmap.sh](./scripts/mkstatic-nmap.sh)                     |
| Nmap           | nmap                      | Dynamic | [mkstatic-nmap.sh](./scripts/mkstatic-nmap.sh)                     |
| Nmap           | nping                     | Dynamic | [mkstatic-nmap.sh](./scripts/mkstatic-nmap.sh)                     |
| Nmap           | uninstall_ndiff           | Static  | [mkstatic-nmap.sh](./scripts/mkstatic-nmap.sh)                     |
| ProxyChains-NG | proxychains4              | Static  | [mkstatic-proxychains-ng.sh](./scripts/mkstatic-proxychains-ng.sh) |
| ProxyChains-NG | proxychains4-daemon       | Static  | [mkstatic-proxychains-ng.sh](./scripts/mkstatic-proxychains-ng.sh) |
| Tor            | tor                       | Static  | [mkstatic-tor.sh](./scripts/mkstatic-tor.sh)                       |
| Tor            | tor-gencert               | Static  | [mkstatic-tor.sh](./scripts/mkstatic-tor.sh)                       |
| Tor            | torify                    | Static  | [mkstatic-tor.sh](./scripts/mkstatic-tor.sh)                       |
| Tor            | tor-print-ed-signing-cert | Static  | [mkstatic-tor.sh](./scripts/mkstatic-tor.sh)                       |
| Tor            | tor-resolve               | Static  | [mkstatic-tor.sh](./scripts/mkstatic-tor.sh)                       |
| Torsocks       | torsocks                  | Static  | [mkstatic-torsocks.sh](./scripts/mkstatic-torsocks.sh)             |

Some binaries are not built statically even the build process is configured to build them in a static way, most of these binaries have problems to include the GLib libraries statically. It seems that this problem could be solved using [musl](https://musl.libc.org/), another implementation of the C standard library.
