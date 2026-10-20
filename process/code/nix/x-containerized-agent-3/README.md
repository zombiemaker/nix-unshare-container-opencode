# Separate GNU Bash script from flake.nix
This iteration target is to move the Bash script out of the flake.nix

It worked.

What works
- Buildah

What does not work:
- opencode (patched version)

```bash
export LD_DEBUG=libs

opencode
      1210:     find library=libc.so.6 [0]; searching
      1210:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v4:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v3:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v2:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib           (system search path)
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v4/libc.so.6
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v3/libc.so.6
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v2/libc.so.6
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libc.so.6
      1210:
      1210:     find library=libpthread.so.0 [0]; searching
      1210:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libpthread.so.0
      1210:
      1210:     find library=libdl.so.2 [0]; searching
      1210:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libdl.so.2
      1210:
      1210:     find library=libm.so.6 [0]; searching
      1210:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
      1210:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libm.so.6
      1210:
      1210:
      1210:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/ld-linux-x86-64.so.2
      1210:
      1210:
      1210:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libc.so.6
      1210:
      1210:
      1210:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libm.so.6
      1210:
      1210:
      1210:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libdl.so.2
      1210:
      1210:
      1210:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libpthread.so.0
      1210:
      1210:
      1210:     initialize program: opencode
      1210:
      1210:
      1210:     transferring control: opencode
      1210:
      1210:     opencode: error: symbol lookup error: undefined symbol: __asan_init (fatal)
      1210:     opencode: error: symbol lookup error: undefined symbol: __tsan_init (fatal)
============================================================
Bun v1.4.2 (744846f84) Linux x64
Linux Kernel v6.18.45 | glibc v2.42
CPU: sse42 popcnt avx avx2 avx512
Args: "opencode" "--smol" "--user-agent=opencode/latest/2.0.26/cli" "--use-system-ca" "--no-warnings" "--"
Features: jsc standalone_executable 

Elapsed: 1ms | User: 1ms | Sys: 1ms
RSS: 8.47 MB | Peak: 8.39 MB | Commit: 23.92 MB | Faults: 0

panic(main thread): abort() called
oh no: Bun has crashed. This indicates a bug in Bun, not your code.

To send a redacted crash report to Bun's team,
please file a GitHub issue using the link below:

 https://bun.report/1.4.2/la1744846fEggggC28+nB6lzQ+0pKw/nhrCy560wB2060wB2m30wB8zvzwBkzuzwB04mzwB8l3pwBy116iDk8/4oC0+9hvB2y4hvBoo5Kuz5K6i0+uBAa
 ```

 This is a trace in a Bubblewrap container where opencode works:

 ```bash
 opencode
       581:     find library=libc.so.6 [0]; searching
       581:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v4:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v3:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v2:/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib               (system search path)
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v4/libc.so.6
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v3/libc.so.6
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/glibc-hwcaps/x86-64-v2/libc.so.6
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libc.so.6
       581:
       581:     find library=libpthread.so.0 [0]; searching
       581:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libpthread.so.0
       581:
       581:     find library=libdl.so.2 [0]; searching
       581:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libdl.so.2
       581:
       581:     find library=libm.so.6 [0]; searching
       581:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib              (system search path)
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libm.so.6
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/ld-linux-x86-64.so.2
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libc.so.6
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libm.so.6
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libdl.so.2
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/libpthread.so.0
       581:
       581:
       581:     initialize program: opencode
       581:
       581:
       581:     transferring control: opencode
       581:
       581:     opencode: error: symbol lookup error: undefined symbol: __asan_init (fatal)
       581:     opencode: error: symbol lookup error: undefined symbol: __tsan_init (fatal)
       581:     find library=librt.so.1 [0]; searching
       581:      search cache=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/etc/ld.so.cache
       581:      search path=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib:/nix/store/g54b6ghpnn98hfdz4yqw87w10c3hx8bv-xgcc-15.2.0-libgcc/lib/glibc-hwcaps/x86-64-v4:/nix/store/g54b6ghpnn98hfdz4yqw87w10c3hx8bv-xgcc-15.2.0-libgcc/lib/glibc-hwcaps/x86-64-v3:/nix/store/g54b6ghpnn98hfdz4yqw87w10c3hx8bv-xgcc-15.2.0-libgcc/lib/glibc-hwcaps/x86-64-v2:/nix/store/g54b6ghpnn98hfdz4yqw87w10c3hx8bv-xgcc-15.2.0-libgcc/lib             (system search path)
       581:       trying file=/nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/librt.so.1
       581:
       581:
       581:     calling init: /nix/store/57iz36553175g3178pvxjij8z5rcsd4n-glibc-2.42-61/lib/librt.so.1
       581:
       581:
       581:     calling init: /tmp/.bun-1000-e83060072c005618.so
       581:
       ```