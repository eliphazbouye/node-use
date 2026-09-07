# node-use

Install and switch Node.js versions on Linux without a version manager.

No shell hooks on every `cd`, no multi-thousand-line runtime — one Bash script,
plus a four-line shell function. Downloads come from `nodejs.org` and are
verified with SHA-256 **and** the GPG signature on the official checksum file.

```console
$ node-use
active: v26.8.1  (~/.local/bin/node)

upstream (~/.local/share/node):
    24   (24.20.0)
  * 26   (26.8.1)

system (dnf):
    22   (v22.23.1)
```

## Why

`nvm` and `fnm` are good tools, but they hook your shell to switch versions
automatically per directory. If you don't want that — if you'd rather switch
explicitly and keep your distro's Node installed and patched underneath —
this is a smaller thing that does only that.

It also coexists with a package-managed Node instead of replacing it. On Fedora
`node-22` keeps meaning the dnf build; `node-use system` hands control back to it.

## Install

```sh
git clone https://github.com/soophoo/node-use.git
cd node-use
./install.sh
```

Or manually:

```sh
install -Dm755 node-use ~/.local/bin/node-use
mkdir -p ~/.bashrc.d && cat > ~/.bashrc.d/node.sh <<'EOF'
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0
node-use() {
    command node-use "$@" || return $?
    hash -r 2>/dev/null || true
}
EOF
```

The shell function is **not optional** — see [Why a function](#why-a-function).
Make sure `~/.local/bin` is on your `PATH` and that your `.bashrc` sources
`~/.bashrc.d/*` (Fedora does by default).

## Usage

```
node-use                      list installed versions and the active one
node-use <major|version>      switch to that version; if it is not installed
                              yet, ask before downloading it
node-use latest | lts         switch to the newest (or newest LTS) release,
                              downloading it first if needed
node-use system               switch back to the distro-packaged Node

node-use remote [what]        list versions available on nodejs.org
                              what: lts | all | <major>   (default: recent)
node-use install <what>       download, verify, install, then switch
                              what: latest | lts | <major> | <full version>
node-use update               upgrade the active major to its newest release
node-use remove <major|ver>   delete one installed version
node-use prune [--all] [-y]   delete superseded builds (dry run unless -y)

node-use --yes <cmd>          assume yes; never ask for confirmation
node-use --refresh <cmd>      bypass the cached release index
```

Switching implies installing. `node-use 24` on a machine with no 24.x asks
first, because a pinned version is as likely to be a typo as an intent:

```console
$ node-use 24
Node 24.20.0 is not installed. Download and install it now? [y/N] y
Installing Node 24.20.0 (linux-x64)
```

`latest` and `lts` never ask — they name whatever is newest rather than a
specific build, so fetching it *is* the answer. Non-interactive runs never
prompt either: with no tty they refuse and point at `node-use install`, so a
script can't be silently blocked on a question nobody will see. `--yes`
answers up front.

Examples:

```sh
node-use install lts          # newest LTS
node-use install 24.19.0      # an exact version
node-use remote lts           # every LTS line
node-use latest               # newest release, downloading it if needed
node-use 24                   # switch to 24.x, offering to fetch it
node-use prune                # show what could be freed
```

Per-major shortcuts are version-pinned, so they keep meaning one version
regardless of which is active:

```sh
node-26 --version   # v26.8.1
node-24 --version   # v24.20.0
```

## How it works

```
~/.local/share/node/node-v26.8.1-linux-x64/   extracted builds
~/.local/share/node/current -> node-v26.8.1…  the active one
~/.local/bin/{node,npm,npx} -> current/bin/*  what PATH sees
~/.local/bin/node-26        -> the 26 build   version-pinned shortcut
```

Switching repoints `current`. Selecting `system` deletes the three shims so the
distro's `/usr/bin/node` wins on `PATH` again. Nothing is installed outside
`$HOME`, and no `sudo` is ever used.

### Verification

Every install checks, in order:

1. **SHA-256** of the tarball against `SHASUMS256.txt` — a mismatch aborts.
2. **GPG** signature of `SHASUMS256.txt` itself. Note it is *clearsigned*, so
   the check is `gpg --verify SHASUMS256.txt.asc` alone, not a detached verify.
3. The signing key's fingerprint against the official
   [`nodejs/release-keys`](https://github.com/nodejs/release-keys) list —
   the key is imported from a keyserver *only after* it appears there.

A checksum mismatch is fatal. A GPG failure warns and falls back to the
checksum, so a keyserver outage doesn't block you.

### Why a function

Switching versions changes which path `node` resolves to, and Bash caches
command locations in a hash table. A script cannot fix that: it runs in a child
process and cannot clear its parent shell's cache. So the function calls the
script and then runs `hash -r` in *your* shell.

Without it you get one of two failures — `No such file or directory` for a path
that was deleted, or, worse, silently running the old version. This is the same
reason `nvm` ships as a shell function.

### Caching

The release index is cached in `~/.cache/node-use/` for an hour
(`NODE_USE_TTL` in seconds to change it, `--refresh` to force). This is the
difference between ~130 ms and ~14 ms per command, since the HTTP fetch is ~85%
of the runtime. If the network is down, a stale cache is used with a warning.

## Requirements

- `bash` 4+, `curl`, `jq`, `tar`, `sed`, `awk`
- `gpg` optional — without it, installs verify by SHA-256 only
- Linux on x64, arm64, armv7l, ppc64le or s390x

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `NODE_USE_TTL` | `3600` | Release-index cache lifetime, in seconds |
| `NODE_USE_DIST` | `https://nodejs.org/dist` | Download base URL |
| `XDG_CACHE_HOME` | `~/.cache` | Where the index cache lives |

## License

MIT — see [LICENSE](LICENSE).
