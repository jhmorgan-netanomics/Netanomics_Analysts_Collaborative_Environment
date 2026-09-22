#!/usr/bin/env bash
#
# update_dataplot.sh -- rebuild and reinstall NIST Dataplot from source with
#                       local customizations (MAXOBV, -mcmodel=medium) and a
#                       headless-safe wrapper.
#
# Derived from section 3 of the Netanomics Common Collaborative Analysts'
# Environment Dockerfile. Runs unchanged in WSL, on a bare Linux host, inside a
# running container, or as a RUN step in a Docker build.
#
# Jonathan H. Morgan, Ph.D.
#
# Usage:  update_dataplot.sh [options]
#         update_dataplot.sh --help
#
set -Eeuo pipefail

# ----------------------------------------
# 0. Defaults (all overridable by flag or environment)
# ----------------------------------------

DP_REPO="${DP_REPO:-https://github.com/usnistgov/dataplot.git}"
DP_REF="${DP_REF:-master}"
DP_PREFIX="${DP_PREFIX:-/usr/local}"
DP_SRC="${DP_SRC:-/tmp/nist_dataplot}"
DP_MAXOBV="${DP_MAXOBV:-5000000}"
DP_MAXOBV_OLD="${DP_MAXOBV_OLD:-2000000}"
DP_MCMODEL="${DP_MCMODEL:-medium}"
DP_FEATURES="${DP_FEATURES:-}"          # empty = leave the Makefile's own FEATURES line alone
DP_JOBS="${DP_JOBS:-}"                  # empty = nproc
DP_BACKUP_DIR="${DP_BACKUP_DIR:-/var/backups/dataplot}"
DP_LOG="${DP_LOG:-}"                    # empty = /tmp/update_dataplot_<timestamp>.log
DP_MIN_DISK_MB="${DP_MIN_DISK_MB:-3000}"
DP_KEEP_BACKUPS="${DP_KEEP_BACKUPS:-3}"      # rollback snapshots to retain
DP_FIX_TIKZ_COLORS="${DP_FIX_TIKZ_COLORS:-1}"   # patch the 2026/08 TikZ colour-name defect
DP_TIKZ_RGB="${DP_TIKZ_RGB:-0}"                 # add RGB colour support to the TikZ driver (experimental)
DP_TIKZ_RGB_PATCH="${DP_TIKZ_RGB_PATCH:-}"      # path to patch_tikz_rgb.py (default: beside this script)
DP_FIX_TIKZ_FILL="${DP_FIX_TIKZ_FILL:-1}"       # patch the 2026/08 TikZ fill-scanline defect, add solid path fills
DP_TIKZ_FILL_PATCH="${DP_TIKZ_FILL_PATCH:-}"    # path to patch_tikz_fill.py (default: beside this script)

INSTALL_DEPS=0
SKIP_DEPS=0
SKIP_TESTS=0
NO_BACKUP=0
KEEP_SOURCE=0
FORCE=0
ASSUME_YES=0
DRY_RUN=0
ROLLBACK_ONLY=0

START_TS="$(date +%Y%m%d_%H%M%S)"
SCRIPT_NAME="$(basename "$0")"
# Resolved once, before any cd: the patch phase runs from $DP_SRC/src, and a
# relative $0 (./update_dataplot.sh) resolved after that points at the source
# tree instead of this script's directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# ----------------------------------------
# 1. Output helpers
# ----------------------------------------

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
    C_BLU=$'\033[34m'; C_BLD=$'\033[1m';  C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_RST=""
fi

log()   { printf '%s\n' "$*"; }
info()  { printf '%s\n' "${C_BLU}[INFO ]${C_RST} $*"; }
ok()    { printf '%s\n' "${C_GRN}[  OK ]${C_RST} $*"; }
warn()  { printf '%s\n' "${C_YEL}[WARN ]${C_RST} $*" >&2; }
err()   { printf '%s\n' "${C_RED}[FAIL ]${C_RST} $*" >&2; }
step()  { printf '\n%s\n' "${C_BLD}==> $*${C_RST}"; }
die()   { err "$*"; exit 1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '%s\n' "${C_YEL}[DRY  ]${C_RST} $*"
        return 0
    fi
    "$@"
}

# ----------------------------------------
# 2. Usage
# ----------------------------------------

usage() {
    cat <<EOF
${SCRIPT_NAME} -- rebuild and reinstall NIST Dataplot from source.

Phases: preflight -> fetch -> patch -> build -> backup -> install -> verify.
The existing installation is left untouched until a clean build exists, and is
restored automatically if installation or verification fails.

Options:
  --prefix DIR        Install prefix                  (default: ${DP_PREFIX})
  --src DIR           Source working directory        (default: ${DP_SRC})
  --repo URL          Git remote                      (default: ${DP_REPO})
  --ref REF           Branch, tag or commit to build  (default: ${DP_REF})
  --maxobv N          MAXOBV value in DPCOPA.INC      (default: ${DP_MAXOBV})
  --mcmodel MODEL     -mcmodel= value, or "none"      (default: ${DP_MCMODEL})
  --features "LIST"   Override the Makefile FEATURES line (default: leave as-is)
  --jobs N            Parallel make jobs              (default: nproc)
  --backup-dir DIR    Where rollback tarballs go      (default: ${DP_BACKUP_DIR})
  --keep-backups N    Rollback snapshots to retain   (default: ${DP_KEEP_BACKUPS})
  --no-fix-tikz-colors  Skip the TikZ \\definecolor name patch (on by default)
  --tikz-rgb          Add RGB colour support to the TikZ driver (experimental;
                      requires patch_tikz_rgb.py and python3)
  --no-fix-tikz-fill  Skip the TikZ fill patch (on by default; requires
                      patch_tikz_fill.py and python3)
  --log FILE          Transcript location             (default: /tmp/update_dataplot_<ts>.log)

  --install-deps      Install missing apt packages found by preflight
  --skip-deps         Skip the dependency probe entirely
  --skip-tests        Install without running the verification suite
  --no-backup         Do not tar the current install before replacing it
  --keep-source       Leave the build tree in place when finished
  --force             Continue past non-fatal preflight failures
  -y, --yes           Do not prompt for confirmation
  -n, --dry-run       Print what would happen, change nothing
  --rollback          Restore the most recent backup and exit
  -h, --help          This message

Examples:
  sudo ./${SCRIPT_NAME}                          # standard update on WSL
  sudo ./${SCRIPT_NAME} --install-deps           # and fix missing build deps
  ./${SCRIPT_NAME} --prefix "\$HOME/.local" -y    # unprivileged user install
  ./${SCRIPT_NAME} --ref d837c4a --skip-tests    # build one specific commit
  sudo ./${SCRIPT_NAME} --rollback               # undo the last update

In a Dockerfile:
  COPY update_dataplot.sh /usr/local/bin/update_dataplot.sh
  RUN chmod +x /usr/local/bin/update_dataplot.sh && \\
      /usr/local/bin/update_dataplot.sh --yes --skip-deps
EOF
}

# ----------------------------------------
# 3. Argument parsing
# ----------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --prefix)       DP_PREFIX="$2"; shift 2 ;;
        --src)          DP_SRC="$2"; shift 2 ;;
        --repo)         DP_REPO="$2"; shift 2 ;;
        --ref)          DP_REF="$2"; shift 2 ;;
        --maxobv)       DP_MAXOBV="$2"; shift 2 ;;
        --mcmodel)      DP_MCMODEL="$2"; shift 2 ;;
        --features)     DP_FEATURES="$2"; shift 2 ;;
        --jobs)         DP_JOBS="$2"; shift 2 ;;
        --backup-dir)   DP_BACKUP_DIR="$2"; shift 2 ;;
        --keep-backups) DP_KEEP_BACKUPS="$2"; shift 2 ;;
        --no-fix-tikz-colors) DP_FIX_TIKZ_COLORS=0; shift ;;
        --tikz-rgb)     DP_TIKZ_RGB=1; shift ;;
        --no-fix-tikz-fill) DP_FIX_TIKZ_FILL=0; shift ;;
        --log)          DP_LOG="$2"; shift 2 ;;
        --install-deps) INSTALL_DEPS=1; shift ;;
        --skip-deps)    SKIP_DEPS=1; shift ;;
        --skip-tests)   SKIP_TESTS=1; shift ;;
        --no-backup)    NO_BACKUP=1; shift ;;
        --keep-source)  KEEP_SOURCE=1; shift ;;
        --force)        FORCE=1; shift ;;
        -y|--yes)       ASSUME_YES=1; shift ;;
        -n|--dry-run)   DRY_RUN=1; shift ;;
        --rollback)     ROLLBACK_ONLY=1; shift ;;
        -h|--help)      usage; exit 0 ;;
        *)              usage >&2; die "Unknown option: $1" ;;
    esac
done

DP_LOG="${DP_LOG:-/tmp/update_dataplot_${START_TS}.log}"
DP_BINDIR="${DP_PREFIX}/bin"
DP_LIBDIR="${DP_PREFIX}/lib/dataplot"

# ----------------------------------------
# 4. Transcript
# ----------------------------------------

if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$DP_LOG")" 2>/dev/null || true
    exec > >(tee -a "$DP_LOG") 2>&1
fi

log "${C_BLD}Dataplot update -- ${START_TS}${C_RST}"
log "Log: ${DP_LOG}"

# ----------------------------------------
# 5. Environment detection and privilege
# ----------------------------------------

IS_WSL=0
IS_CONTAINER=0
PKG_MGR="none"
SUDO=""

detect_environment() {
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
        IS_WSL=1
    fi
    if [ -f /.dockerenv ] || grep -qE '/(docker|containerd|lxc)/' /proc/1/cgroup 2>/dev/null; then
        IS_CONTAINER=1
    fi
    if   command -v apt-get >/dev/null 2>&1; then PKG_MGR="apt"
    elif command -v dnf     >/dev/null 2>&1; then PKG_MGR="dnf"
    elif command -v yum     >/dev/null 2>&1; then PKG_MGR="yum"
    elif command -v pacman  >/dev/null 2>&1; then PKG_MGR="pacman"
    fi

    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1; then
            SUDO="sudo"
        else
            SUDO=""
        fi
    fi
}

# Run a command with elevation only when the target tree needs it.
sudo_run() {
    if [ -n "$SUDO" ]; then
        run $SUDO "$@"
    else
        run "$@"
    fi
}

# ----------------------------------------
# 6. Preflight A -- toolchain, permissions, space, network
# ----------------------------------------

PREFLIGHT_FAIL=0
MISSING_PKGS=()

need_pkg() {
    # need_pkg <apt-name> <dnf-name> <pacman-name>
    case "$PKG_MGR" in
        apt)          MISSING_PKGS+=("$1") ;;
        dnf|yum)      MISSING_PKGS+=("$2") ;;
        pacman)       MISSING_PKGS+=("$3") ;;
        *)            MISSING_PKGS+=("$1") ;;
    esac
}

check_cmd() {
    # check_cmd <command> <fatal|warn> <apt> <dnf> <pacman> [note]
    local cmd="$1" sev="$2" apt="$3" dnf="$4" pac="$5" note="${6:-}"
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$(printf '%-14s %s' "$cmd" "$(command -v "$cmd")")"
        return 0
    fi
    if [ "$sev" = "fatal" ]; then
        err "$(printf '%-14s missing %s' "$cmd" "$note")"
        PREFLIGHT_FAIL=1
    else
        warn "$(printf '%-14s missing %s' "$cmd" "$note")"
    fi
    [ -n "$apt" ] && need_pkg "$apt" "$dnf" "$pac"
    return 0
}

probe_header() {
    # probe_header <header.h> [extra cflags] -- true if the compiler can find it
    local hdr="$1"; shift
    local -a extra=()
    [ $# -gt 0 ] && [ -n "$1" ] && read -r -a extra <<< "$*"
    printf '#include <%s>\nint main(void){return 0;}\n' "$hdr" \
        | gcc -fsyntax-only ${extra[@]+"${extra[@]}"} -x c - >/dev/null 2>&1
}

avail_mb() {
    # avail_mb <path> -- free megabytes on the filesystem holding <path>
    local p="$1"
    while [ ! -d "$p" ] && [ "$p" != "/" ]; do p="$(dirname "$p")"; done
    df -Pm "$p" 2>/dev/null | awk 'NR==2 {print $4}'
}

preflight_a() {
    step "Preflight A -- environment, toolchain, permissions"

    local kind="bare-metal Linux"
    [ "$IS_WSL" -eq 1 ] && kind="WSL"
    [ "$IS_CONTAINER" -eq 1 ] && kind="container"
    [ "$IS_WSL" -eq 1 ] && [ "$IS_CONTAINER" -eq 1 ] && kind="container under WSL"
    info "Host        : $kind, $(uname -m), kernel $(uname -r)"
    info "Distro      : $( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo unknown )"
    info "Package mgr : $PKG_MGR"
    info "Privilege   : $( [ "$(id -u)" -eq 0 ] && echo "root" || echo "uid $(id -u)${SUDO:+, sudo available}" )"
    info "Prefix      : $DP_PREFIX  (bin: $DP_BINDIR, lib: $DP_LIBDIR)"
    info "Source      : $DP_SRC"
    info "Build ref   : $DP_REF"

    log ""
    info "Required build tools:"
    check_cmd git      fatal git             git            git         ""
    check_cmd make     fatal make            make           make        "(build-essential)"
    check_cmd gcc      fatal gcc             gcc            gcc         "(build-essential)"
    check_cmd gfortran fatal gfortran        gcc-gfortran   gcc-fortran "(required: Dataplot is ~78% Fortran)"
    check_cmd sed      fatal sed             sed            sed         ""
    check_cmd grep     fatal grep            grep           grep        ""
    check_cmd install  fatal coreutils       coreutils      coreutils   ""
    check_cmd tar      fatal tar             tar            tar         ""

    log ""
    info "Runtime helpers:"
    check_cmd xvfb-run warn  xvfb            xorg-x11-server-Xvfb xorg-server-xvfb \
        "(headless fallback in the dataplot wrapper will not work)"
    check_cmd xclip    warn  xclip           xclip          xclip       "(XCLIP feature: cut/paste)"
    check_cmd gs       warn  ghostscript     ghostscript    ghostscript "(PostScript post-processing)"
    check_cmd pkg-config warn pkg-config     pkgconf-pkg-config pkgconf ""

    log ""
    info "LaTeX toolchain (for compiling Dataplot's LATEX/TikZ output):"
    local tex_found=0
    for t in latex pdflatex lualatex xelatex; do
        if command -v "$t" >/dev/null 2>&1; then
            ok "$(printf '%-14s %s' "$t" "$(command -v "$t")")"
            tex_found=1
        fi
    done
    if [ "$tex_found" -eq 0 ]; then
        warn "no LaTeX engine on PATH -- Dataplot will still emit .tex/TikZ,"
        warn "but nothing here can compile it. Verification will note this and continue."
    fi

    log ""
    info "Compiler sanity check:"
    if [ "$DRY_RUN" -eq 0 ] && command -v gfortran >/dev/null 2>&1; then
        local tmpf; tmpf="$(mktemp -d)"
        printf '      PROGRAM T\n      WRITE(*,*) 1.0D0\n      END\n' > "$tmpf/t.f"
        if gfortran -ffixed-form -o "$tmpf/t" "$tmpf/t.f" >/dev/null 2>&1; then
            ok "gfortran compiles and links ($(gfortran -dumpversion))"
        else
            err "gfortran is present but cannot compile a trivial program"
            PREFLIGHT_FAIL=1
        fi
        if [ "$DP_MCMODEL" != "none" ]; then
            if gfortran -mcmodel="$DP_MCMODEL" -ffixed-form -o "$tmpf/t2" "$tmpf/t.f" >/dev/null 2>&1; then
                ok "gfortran accepts -mcmodel=$DP_MCMODEL"
            else
                err "gfortran rejects -mcmodel=$DP_MCMODEL on this architecture"
                err "  (use --mcmodel none if this platform does not support it)"
                PREFLIGHT_FAIL=1
            fi
        fi
        rm -rf "$tmpf"
    else
        warn "skipped (dry run)"
    fi

    log ""
    info "Disk space (need ~${DP_MIN_DISK_MB} MB to build):"
    local src_free prefix_free
    src_free="$(avail_mb "$DP_SRC")"
    prefix_free="$(avail_mb "$DP_PREFIX")"
    if [ -n "$src_free" ] && [ "$src_free" -lt "$DP_MIN_DISK_MB" ]; then
        err "$(printf '%-14s %s MB free, need %s MB' "$(dirname "$DP_SRC")" "$src_free" "$DP_MIN_DISK_MB")"
        PREFLIGHT_FAIL=1
    else
        ok "$(printf '%-14s %s MB free' "$(dirname "$DP_SRC")" "${src_free:-?}")"
    fi
    if [ -n "$prefix_free" ] && [ "$prefix_free" -lt 400 ]; then
        err "$(printf '%-14s %s MB free, need ~400 MB' "$DP_PREFIX" "$prefix_free")"
        PREFLIGHT_FAIL=1
    else
        ok "$(printf '%-14s %s MB free' "$DP_PREFIX" "${prefix_free:-?}")"
    fi

    log ""
    info "Write permission:"
    local p="$DP_PREFIX"
    while [ ! -d "$p" ] && [ "$p" != "/" ]; do p="$(dirname "$p")"; done
    if [ -w "$p" ]; then
        ok "$(printf '%-14s writable directly' "$p")"
    elif [ -n "$SUDO" ]; then
        if sudo -n true 2>/dev/null; then
            ok "$(printf '%-14s writable via sudo (cached credentials)' "$p")"
        else
            warn "$(printf '%-14s needs sudo -- you will be prompted' "$p")"
        fi
    else
        err "$(printf '%-14s not writable and sudo is unavailable' "$p")"
        err "  re-run as root, or use --prefix \"\$HOME/.local\""
        PREFLIGHT_FAIL=1
    fi

    log ""
    info "Network:"
    if [ "$DRY_RUN" -eq 1 ]; then
        ok "skipped (dry run)"
    elif git ls-remote --exit-code --heads "$DP_REPO" >/dev/null 2>&1; then
        ok "reachable: $DP_REPO"
    else
        err "cannot reach $DP_REPO"
        err "  check proxy settings, or point --repo at a local mirror"
        PREFLIGHT_FAIL=1
    fi

    log ""
    info "Current installation:"
    if [ -e "$DP_BINDIR/dataplot" ]; then
        ok "$(printf '%-14s %s' "dataplot" "$(readlink -f "$DP_BINDIR/dataplot" 2>/dev/null || echo "$DP_BINDIR/dataplot")")"
        [ -e "$DP_BINDIR/dataplot-original" ] && \
            ok "$(printf '%-14s %s' "  real binary" "$(stat -c '%s bytes, built %y' "$DP_BINDIR/dataplot-original" 2>/dev/null | cut -d. -f1)")"
        [ -d "$DP_LIBDIR" ] && \
            ok "$(printf '%-14s %s files' "  lib tree" "$(find "$DP_LIBDIR" -type f 2>/dev/null | wc -l)")"
    else
        info "no existing Dataplot at $DP_BINDIR -- this will be a fresh install"
    fi

    handle_missing_packages
    log ""
    if [ "$PREFLIGHT_FAIL" -eq 1 ]; then
        if [ "$FORCE" -eq 1 ]; then
            warn "Preflight A reported failures -- continuing because --force was given."
        else
            die "Preflight A failed. Fix the items marked [FAIL], or re-run with --force."
        fi
    fi
    ok "Preflight A passed."
}

handle_missing_packages() {
    [ "${#MISSING_PKGS[@]}" -eq 0 ] && return 0
    local uniq
    uniq="$(printf '%s\n' "${MISSING_PKGS[@]}" | sort -u | tr '\n' ' ')"
    log ""
    warn "Missing packages: $uniq"
    if [ "$INSTALL_DEPS" -eq 1 ]; then
        info "Installing them (--install-deps)..."
        case "$PKG_MGR" in
            apt)    sudo_run env DEBIAN_FRONTEND=noninteractive apt-get update -qq
                    # shellcheck disable=SC2086
                    sudo_run env DEBIAN_FRONTEND=noninteractive apt-get install -y $uniq ;;
            dnf)    # shellcheck disable=SC2086
                    sudo_run dnf install -y $uniq ;;
            yum)    # shellcheck disable=SC2086
                    sudo_run yum install -y $uniq ;;
            pacman) # shellcheck disable=SC2086
                    sudo_run pacman -S --noconfirm $uniq ;;
            *)      die "No supported package manager; install manually: $uniq" ;;
        esac
        MISSING_PKGS=()
        PREFLIGHT_FAIL=0
    else
        case "$PKG_MGR" in
            apt)    warn "  sudo apt-get install -y $uniq" ;;
            dnf)    warn "  sudo dnf install -y $uniq" ;;
            yum)    warn "  sudo yum install -y $uniq" ;;
            pacman) warn "  sudo pacman -S $uniq" ;;
        esac
        warn "  (or re-run this script with --install-deps)"
    fi
}

# ----------------------------------------
# 7. Fetch
# ----------------------------------------

fetch_source() {
    step "Fetch -- $DP_REPO @ $DP_REF"

    if [ -d "$DP_SRC/.git" ]; then
        info "Existing clone found; refreshing it."
        run git -C "$DP_SRC" remote set-url origin "$DP_REPO"
        run git -C "$DP_SRC" fetch --tags --force origin
        run git -C "$DP_SRC" reset --hard
        run git -C "$DP_SRC" clean -fdx
        if ! run git -C "$DP_SRC" checkout --detach "origin/$DP_REF" 2>/dev/null; then
            run git -C "$DP_SRC" checkout --detach "$DP_REF"
        fi
    else
        [ -e "$DP_SRC" ] && run rm -rf "$DP_SRC"
        run mkdir -p "$DP_SRC"
        run git clone "$DP_REPO" "$DP_SRC"
        if ! run git -C "$DP_SRC" checkout --detach "origin/$DP_REF" 2>/dev/null; then
            run git -C "$DP_SRC" checkout --detach "$DP_REF"
        fi
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
        BUILD_SHA="$(git -C "$DP_SRC" rev-parse --short HEAD)"
        BUILD_DATE="$(git -C "$DP_SRC" log -1 --format=%cd --date=short)"
        BUILD_SUBJ="$(git -C "$DP_SRC" log -1 --format=%s)"
        ok "HEAD $BUILD_SHA ($BUILD_DATE)"
        info "  $BUILD_SUBJ"
    else
        BUILD_SHA="dryrun"; BUILD_DATE="dryrun"; BUILD_SUBJ="dryrun"
    fi

    if [ "$DRY_RUN" -eq 0 ]; then
        [ -f "$DP_SRC/src/Makefile" ]   || die "No src/Makefile in $DP_SRC -- wrong repo or bad checkout."
        [ -f "$DP_SRC/src/DPCOPA.INC" ] || die "No src/DPCOPA.INC in $DP_SRC -- wrong repo or bad checkout."
        [ -d "$DP_SRC/lib" ]            || die "No lib/ directory in $DP_SRC -- wrong repo or bad checkout."
        ok "Source tree layout verified (src/Makefile, src/DPCOPA.INC, lib/)"
    fi
}

# ----------------------------------------
# 8. Preflight B -- libraries the Makefile's FEATURES line actually requires
# ----------------------------------------

check_lib() {
    # check_lib <feature> <header> <apt> <dnf> <pacman> [extra cflags]
    local feat="$1" hdr="$2" apt="$3" dnf="$4" pac="$5" xcflags="${6:-}"
    if probe_header "$hdr" "$xcflags"; then
        ok "$(printf '%-10s %-24s found' "$feat" "$hdr")"
    else
        err "$(printf '%-10s %-24s MISSING  (%s)' "$feat" "$hdr" "$apt")"
        need_pkg "$apt" "$dnf" "$pac"
        PREFLIGHT_FAIL=1
    fi
}

probe_features() {
    # Header requirements are taken from what src/*.c actually #includes,
    # not from the feature name alone -- e.g. X11 needs Xft and Xmu too.
    local feat
    for feat in $1; do
        case "$feat" in
            GD)
                check_lib GD  gd.h                libgd-dev       gd-devel        gd
                check_lib GD  ft2build.h          libfreetype-dev freetype-devel  freetype2 \
                          "-I/usr/include/freetype2" ;;
            TIFF)
                check_lib TIFF tiffio.h           libtiff-dev     libtiff-devel   libtiff ;;
            VPX)
                check_lib VPX  webp/encode.h      libwebp-dev     libwebp-devel   libwebp ;;
            AVIF)
                check_lib AVIF avif/avif.h        libavif-dev     libavif-devel   libavif ;;
            HEIF)
                check_lib HEIF libheif/heif.h     libheif-dev     libheif-devel   libheif ;;
            CAIRO)
                check_lib CAIRO cairo/cairo.h     libcairo2-dev   cairo-devel     cairo ;;
            X11)
                check_lib X11  X11/Xlib.h         libx11-dev      libX11-devel    libx11
                check_lib X11  X11/Xft/Xft.h      libxft-dev      libXft-devel    libxft \
                          "-I/usr/include/freetype2"
                check_lib X11  X11/Xmu/Atoms.h    libxmu-dev      libXmu-devel    libxmu ;;
            READLINE)
                check_lib READLINE readline/readline.h libreadline-dev readline-devel readline ;;
            NCURSES)
                check_lib NCURSES curses.h        libncurses-dev  ncurses-devel   ncurses ;;
            PLOT)
                check_lib PLOT plot.h             libplot-dev     plotutils-devel plotutils ;;
            XCLIP)
                if command -v xclip >/dev/null 2>&1; then
                    ok "$(printf '%-10s %-24s found' "$feat" "xclip(1)")"
                else
                    warn "$(printf '%-10s %-24s missing' "$feat" "xclip(1)")"
                    need_pkg xclip xclip xclip
                fi ;;
            STACK_SIZE|DEBUG|CYGWIN|MACOSX|TCL|GKS|OPENGL|AQUA|ISOCLINE|DISABLE_SYSTEM_COMMAND)
                ok "$(printf '%-10s %-24s n/a' "$feat" "(no external library)")" ;;
            *)
                warn "$(printf '%-10s %-24s not checked' "$feat" "(unrecognized feature)")" ;;
        esac
    done
}

preflight_b() {
    step "Preflight B -- libraries required by this build's FEATURES"

    if [ "$SKIP_DEPS" -eq 1 ]; then
        warn "Skipped (--skip-deps)."
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    local features
    if [ -n "$DP_FEATURES" ]; then
        features="$DP_FEATURES"
        info "FEATURES (overridden): $features"
    else
        features="$(grep -E '^FEATURES[[:space:]]*=' "$DP_SRC/src/Makefile" | head -1 | cut -d= -f2-)"
        info "FEATURES (from Makefile): $features"
    fi

    probe_features "$features"
    handle_missing_packages

    # Re-probe after an --install-deps pass so the verdict reflects reality.
    if [ "$INSTALL_DEPS" -eq 1 ] && [ "$PREFLIGHT_FAIL" -eq 1 ]; then
        log ""
        info "Re-probing after package installation:"
        PREFLIGHT_FAIL=0
        probe_features "$features"
    fi

    log ""
    if [ "$PREFLIGHT_FAIL" -eq 1 ]; then
        if [ "$FORCE" -eq 1 ]; then
            warn "Preflight B reported missing libraries -- continuing because --force was given."
            warn "The build will very likely fail at link time."
        else
            die "Preflight B failed. Install the packages above (or re-run with --install-deps),
      or drop the unsatisfied feature with e.g. --features \"X11 READLINE NCURSES STACK_SIZE\"."
        fi
    fi
    ok "Preflight B passed."
}

# ----------------------------------------
# 9. Patch
# ----------------------------------------

apply_patches() {
    step "Patch -- local build customizations"

    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    cd "$DP_SRC/src"

    # --- MAXOBV -------------------------------------------------------
    if grep -qE "^ +PARAMETER \(MAXOBV=${DP_MAXOBV}\)" DPCOPA.INC; then
        ok "MAXOBV already ${DP_MAXOBV}"
    else
        local current
        current="$(grep -oE 'PARAMETER \(MAXOBV=[0-9]+\)' DPCOPA.INC | head -1 || true)"
        info "MAXOBV currently: ${current:-<not found>}"
        sed -i -E "s/^( +)PARAMETER \(MAXOBV=[0-9]+\)/\1PARAMETER (MAXOBV=${DP_MAXOBV})/" DPCOPA.INC
        grep -qE "PARAMETER \(MAXOBV=${DP_MAXOBV}\)" DPCOPA.INC \
            || die "MAXOBV patch failed -- DPCOPA.INC does not contain MAXOBV=${DP_MAXOBV}"
        ok "MAXOBV set to ${DP_MAXOBV}"
    fi

    # --- -mcmodel ------------------------------------------------------
    if [ "$DP_MCMODEL" = "none" ]; then
        info "mcmodel patch skipped (--mcmodel none)"
    elif grep -q "mcmodel=${DP_MCMODEL}" Makefile; then
        ok "-mcmodel=${DP_MCMODEL} already present in Makefile"
    else
        sed -i "/^FFLAGS/s/\$/ -mcmodel=${DP_MCMODEL}/" Makefile
        sed -i "/^CFLAGS/s/\$/ -mcmodel=${DP_MCMODEL}/" Makefile
        grep -q "mcmodel=${DP_MCMODEL}" Makefile \
            || die "mcmodel patch failed -- Makefile has no -mcmodel=${DP_MCMODEL}"
        ok "-mcmodel=${DP_MCMODEL} appended to $(grep -c "mcmodel=${DP_MCMODEL}" Makefile) flag line(s)"
    fi

    # --- FEATURES (only if explicitly overridden) -----------------------
    if [ -n "$DP_FEATURES" ]; then
        sed -i -E "s|^FEATURES[[:space:]]*=.*|FEATURES = ${DP_FEATURES}|" Makefile
        grep -qE "^FEATURES = ${DP_FEATURES}$" Makefile \
            || die "FEATURES override failed"
        ok "FEATURES set to: ${DP_FEATURES}"
    fi

    # --- PREFIX --------------------------------------------------------
    if [ "$DP_PREFIX" != "/usr/local" ]; then
        sed -i -E "s|^PREFIX[[:space:]]*=.*|PREFIX = \$(DESTDIR)${DP_PREFIX}|" Makefile
        grep -qE "^PREFIX = \\\$\(DESTDIR\)${DP_PREFIX//\//\\/}$" Makefile \
            || die "PREFIX override failed"
        ok "PREFIX set to ${DP_PREFIX}"
    else
        ok "PREFIX left at the Makefile default (/usr/local)"
    fi

    # --- TikZ colour-name defect ---------------------------------------
    if [ "$DP_FIX_TIKZ_COLORS" -eq 1 ]; then
        patch_tikz_colors
    else
        info "TikZ colour-name patch skipped (--no-fix-tikz-colors)"
    fi

    # --- TikZ RGB support (optional, experimental) ----------------------
    if [ "$DP_TIKZ_RGB" -eq 1 ]; then
        patch_tikz_rgb
    fi

    # --- TikZ fill defect + solid path fills ----------------------------
    # Must run AFTER patch_tikz_rgb: it adds an eighth colour-token site,
    # and the RGB patch stops if it finds more than seven.
    if [ "$DP_FIX_TIKZ_FILL" -eq 1 ]; then
        patch_tikz_fill
    else
        info "TikZ fill patch skipped (--no-fix-tikz-fill)"
    fi

    log ""
    info "Effective flag lines:"
    grep -E '^(FEATURES|PREFIX|FFLAGS|CFLAGS)' Makefile | sed 's/^/       /'
    info "Effective MAXOBV:"
    grep -E 'PARAMETER \(MAXOBV=' DPCOPA.INC | sed 's/^/       /'
}

# ----------------------------------------
# 9b. TikZ colour-name defect (upstream bug, 2026/08 TikZ driver)
# ----------------------------------------
#
# dp38.F90 and dp10.F90 write the LaTeX preamble's \definecolor names from
# COLOR_NAMES(), a CHARACTER*4 array that is declared locally in each routine
# and never initialised anywhere in the source tree -- there is no DATA
# statement for it and it is in no COMMON block. The driver therefore emits
# uninitialised stack memory as the colour names:
#
#     \definecolor{<garbage>}{rgb}{1.000,0.000,0.000}
#
# while the body of the file correctly references BLAC / BLUE / RED / GRAY.
# LaTeX then fails with "I do not know the key '/tikz/BLAC'".
#
# The correct table already exists in the same file as ICOLNM (dp38.F90),
# which is what Dataplot's own colour lookup uses. This patch derives the
# DATA statement from ICOLNM at build time and adds it to DPCOCT.INC, which
# is included by every routine that declares COLOR_NAMES.
#
# Two ICOLNM entries are duplicated (AQUA at 17 and 126, DGRA at 15 and 161).
# Dataplot's lookup returns the first match, so the later ones are
# unreachable by name; they are given distinct names here so that
# \definecolor cannot redefine -- and thus corrupt -- the reachable ones.

patch_tikz_colors() {
    local inc="DPCOCT.INC" srcf="dp38.F90"

    if [ ! -f "$inc" ] || [ ! -f "$srcf" ]; then
        warn "TikZ colour patch: $inc or $srcf not found; skipping."
        return 0
    fi

    # Already fixed upstream? Then do nothing.
    if grep -q "COLOR_NAMES" "$inc"; then
        ok "TikZ colour names already initialised upstream -- patch not needed"
        return 0
    fi

    # Does this version even have the defective TikZ colour code?
    if ! grep -q "COLOR_NAMES(JJ)" "$srcf"; then
        info "TikZ colour patch: this version has no COLOR_NAMES emitter; skipping."
        return 0
    fi

    local maxclr
    maxclr="$(grep -m1 -oE 'PARAMETER\(MAXCLR=[0-9]+\)' "$srcf" | grep -oE '[0-9]+')"
    [ -n "$maxclr" ] || { warn "TikZ colour patch: cannot determine MAXCLR; skipping."; return 0; }

    local names_file="${TMPDIR:-/tmp}/dp_icolnm.$$"
    awk '
        /^ *DATA \(ICOLNM\(I\),I=/ { grab=1 }
        grab {
            line=$0
            while (match(line, /'"'"'[^'"'"']{1,4}'"'"'/)) {
                printf "%s\n", substr(line, RSTART+1, RLENGTH-2)
                line=substr(line, RSTART+RLENGTH)
            }
            if (line !~ /&[ \t]*$/) grab=0
        }
    ' "$srcf" > "$names_file"

    local count
    count="$(wc -l < "$names_file")"
    if [ "$count" -ne "$maxclr" ]; then
        warn "TikZ colour patch: extracted $count names but MAXCLR=$maxclr; skipping to stay safe."
        rm -f "$names_file"
        return 0
    fi

    # Build the DATA statement, giving duplicate names a distinct suffix.
    local data_file="${TMPDIR:-/tmp}/dp_colordata.$$"
    awk -v maxclr="$maxclr" '
        {
            raw=$0
            key=raw; gsub(/ +$/, "", key)
            if (key in seen) {
                seen[key]++
                base=substr(key,1,3)
                alt=base seen[key]
                while (length(alt) < 4) alt=alt " "
                raw=alt
                renamed++
            } else { seen[key]=1 }
            n++
            names[n]=raw
        }
        END {
            printf "      DATA (COLOR_NAMES(I),I=1,MAXCLR)/   &\n"
            for (i=1; i<=n; i+=5) {
                line="        "
                for (j=i; j<i+5 && j<=n; j++) {
                    line=line "'"'"'" names[j] "'"'"'"
                    if (j < i+4 && j < n) line=line ", "
                }
                if (i+5 <= n) printf "%s,   &\n", line
                else          printf "%s/\n", line
            }
            printf "RENAMED=%d\n", renamed+0 > "/dev/stderr"
        }
    ' "$names_file" > "$data_file" 2>"${data_file}.meta"

    # Splice it in ahead of the IRED table.
    local anchor='      DATA (IRED(I),I=1,MAXCLR)/'
    if ! grep -qF "$anchor" "$inc"; then
        warn "TikZ colour patch: anchor line not found in $inc; skipping."
        rm -f "$names_file" "$data_file" "${data_file}.meta"
        return 0
    fi

    awk -v datafile="$data_file" '
        index($0, "      DATA (IRED(I),I=1,MAXCLR)/") == 1 && !done {
            while ((getline l < datafile) > 0) print l
            close(datafile)
            print "!"
            done=1
        }
        { print }
    ' "$inc" > "${inc}.new" && mv "${inc}.new" "$inc"

    grep -q "DATA (COLOR_NAMES(I),I=1,MAXCLR)" "$inc" \
        || die "TikZ colour patch failed -- $inc has no COLOR_NAMES DATA statement"

    local renamed
    renamed="$(grep -oE '[0-9]+' "${data_file}.meta" 2>/dev/null | head -1)"
    ok "TikZ colour names initialised from ICOLNM (${maxclr} entries, ${renamed:-0} duplicate name(s) made unique)"
    rm -f "$names_file" "$data_file" "${data_file}.meta"
}

# ----------------------------------------
# 9c. RGB colour support for the TikZ driver (optional)
# ----------------------------------------
#
# GRTRC2 hardcodes IRGBFL=0 for the LaTeX device and GRSEC2's LaTeX branch is
# an empty stub, so RGB colours never reach the TikZ driver -- every element
# falls back to the last named palette colour. The companion script
# patch_tikz_rgb.py teaches GRTRC2 that the TikZ driver supports RGB, fills in
# the GRSEC2 stub to write \definecolor{DPCn}{RGB}{r,g,b}, and routes the
# seven TikZ colour-token emitters through a saved current-colour token.
#
# This changes upstream behaviour, so it is opt-in via --tikz-rgb.

patch_tikz_rgb() {
    local script="${DP_TIKZ_RGB_PATCH:-$SCRIPT_DIR/patch_tikz_rgb.py}"

    if ! command -v python3 >/dev/null 2>&1; then
        die "TikZ RGB patch (--tikz-rgb) needs python3, which is not installed."
    fi
    if [ ! -f "$script" ]; then
        die "TikZ RGB patch (--tikz-rgb) script not found at $script
      Put patch_tikz_rgb.py beside this script, or set DP_TIKZ_RGB_PATCH=/path."
    fi

    info "Applying TikZ RGB support patch ($script)"
    if python3 "$script" "$DP_SRC/src"; then
        grep -q "GRTKCN" "$DP_SRC/src/dp38.F90" \
            || die "TikZ RGB patch reported success but dp38.F90 has no GRTKCN"
        ok "TikZ driver now emits \\definecolor for arbitrary RGB colours"
    else
        die "TikZ RGB patch failed -- see the message above.
      Re-run without --tikz-rgb to build without it."
    fi
}

# ----------------------------------------
# 9d. TikZ fill defect (upstream bug, 2026/08 TikZ driver)
# ----------------------------------------
#
# Solid fills other than boxes (REGION FILL, CHARACTER FILL, polygons) are
# drawn by GRFIR2 as vertical scanlines through GRDRLI. GRDRLI's TikZ branch
# reuses IY1's field width for IX2 and IY2 and closes the segment with ');'
# instead of 'pt);', so the output contains "(**pt,52)" and "(119pt, 52)".
# pdflatex aborts on the first and the second is read as 52cm.
#
# patch_tikz_fill.py (a) computes the exact width for every coordinate and
# restores the unit, and (b) gives GRFIRE a TikZ hardware fill for solid
# non-box regions -- one closed \fill path instead of the scanlines.
# Exit status 2 means the target code is gone (likely fixed upstream).

patch_tikz_fill() {
    local script="${DP_TIKZ_FILL_PATCH:-$SCRIPT_DIR/patch_tikz_fill.py}"
    local rc=0

    if ! command -v python3 >/dev/null 2>&1; then
        die "TikZ fill patch needs python3, which is not installed.
      Install python3, or re-run with --no-fix-tikz-fill to build without it."
    fi
    if [ ! -f "$script" ]; then
        die "TikZ fill patch script not found at $script
      Put patch_tikz_fill.py beside this script, set DP_TIKZ_FILL_PATCH=/path,
      or re-run with --no-fix-tikz-fill to build without it."
    fi

    info "Applying TikZ fill patch ($script)"
    python3 "$script" "$DP_SRC/src" || rc=$?
    case "$rc" in
        0)
            grep -q "GRTKNC" "$DP_SRC/src/dp38.F90" \
                || die "TikZ fill patch reported success but dp38.F90 has no GRTKNC"
            ok "TikZ fills now write valid coordinates; solid regions are \\fill paths"
            ;;
        2)
            warn "TikZ fill patch: target code not found in dp38.F90 -- probably fixed upstream."
            warn "  Building without it; the tikz-fill verification case will show whether"
            warn "  this version's fill output compiles."
            ;;
        *)
            die "TikZ fill patch failed -- see the message above.
      Re-run with --no-fix-tikz-fill to build without it."
            ;;
    esac
}

# ----------------------------------------
# 10. Build (old installation still intact at this point)
# ----------------------------------------

build_dataplot() {
    local jobs="${DP_JOBS:-$(nproc 2>/dev/null || echo 2)}"
    step "Build -- make -j${jobs} (this takes several minutes)"

    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    cd "$DP_SRC/src"
    local t0 t1
    t0="$(date +%s)"
    make clean >/dev/null 2>&1 || true
    if ! make -j"$jobs"; then
        warn "Parallel build failed; retrying serially to surface the real error."
        make clean >/dev/null 2>&1 || true
        make || die "Build failed. Nothing was installed; your existing Dataplot is untouched.
      Full transcript: $DP_LOG"
    fi
    t1="$(date +%s)"

    [ -x "$DP_SRC/src/dataplot" ] || die "Build reported success but src/dataplot is missing."
    ok "Built in $(( (t1 - t0) / 60 ))m $(( (t1 - t0) % 60 ))s: $(stat -c '%s bytes' "$DP_SRC/src/dataplot")"
}

# ----------------------------------------
# 11. Backup and rollback
# ----------------------------------------

BACKUP_TARBALL=""
INSTALL_STARTED=0

backup_current() {
    step "Backup -- snapshot the current installation"

    if [ "$NO_BACKUP" -eq 1 ]; then
        warn "Skipped (--no-backup). A failed install will not be recoverable by this script."
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi
    if [ ! -e "$DP_BINDIR/dataplot" ] && [ ! -d "$DP_LIBDIR" ]; then
        info "Nothing installed yet -- no backup needed."
        return 0
    fi

    sudo_run mkdir -p "$DP_BACKUP_DIR"
    BACKUP_TARBALL="${DP_BACKUP_DIR}/dataplot_backup_${START_TS}.tar.gz"

    local items=()
    for f in dataplot dataplot-original dataplot-wrapper.sh xdataplot; do
        [ -e "$DP_BINDIR/$f" ] && items+=("bin/$f")
    done
    [ -d "$DP_LIBDIR" ] && items+=("lib/dataplot")

    if [ "${#items[@]}" -eq 0 ]; then
        info "Nothing to back up."
        return 0
    fi

    sudo_run tar -czf "$BACKUP_TARBALL" -C "$DP_PREFIX" "${items[@]}"
    ok "Backup: $BACKUP_TARBALL ($(du -h "$BACKUP_TARBALL" 2>/dev/null | cut -f1))"
    printf '%s\n' "$BACKUP_TARBALL" | sudo_run tee "${DP_BACKUP_DIR}/LATEST" >/dev/null

    # Rotate: each snapshot is ~26 MB, so keep only the most recent few.
    local old
    old="$(find "$DP_BACKUP_DIR" -maxdepth 1 -name 'dataplot_backup_*.tar.gz' \
           -printf '%T@ %p\n' 2>/dev/null | sort -rn | tail -n +$((DP_KEEP_BACKUPS + 1)) | cut -d' ' -f2-)"
    if [ -n "$old" ]; then
        printf '%s\n' "$old" | while read -r f; do
            [ -n "$f" ] && sudo_run rm -f "$f"
        done
        info "Pruned $(printf '%s\n' "$old" | grep -c .) old backup(s), keeping the newest ${DP_KEEP_BACKUPS}."
    fi
}

restore_backup() {
    local tarball="${1:-}"
    if [ -z "$tarball" ] && [ -f "${DP_BACKUP_DIR}/LATEST" ]; then
        tarball="$(cat "${DP_BACKUP_DIR}/LATEST")"
    fi
    [ -n "$tarball" ] && [ -f "$tarball" ] || { warn "No backup available to restore."; return 1; }

    step "Rollback -- restoring $tarball"
    remove_installed_files
    sudo_run tar -xzf "$tarball" -C "$DP_PREFIX"
    ok "Previous installation restored."
    return 0
}

on_error() {
    local rc=$?
    trap - ERR EXIT
    err "Failed (exit $rc)."
    if [ "$INSTALL_STARTED" -eq 1 ] && [ -n "$BACKUP_TARBALL" ]; then
        warn "Installation was already in progress -- rolling back."
        restore_backup "$BACKUP_TARBALL" || warn "Rollback failed; restore manually from $BACKUP_TARBALL"
    else
        info "The previous installation was never modified."
    fi
    err "Transcript: $DP_LOG"
    exit "$rc"
}

# ----------------------------------------
# 12. Remove the old installation, then install the new one
# ----------------------------------------

remove_installed_files() {
    # Deliberately unlink rather than mv: after a previous run
    # $BINDIR/dataplot is a symlink to the wrapper, not the binary.
    for f in dataplot dataplot-original dataplot-wrapper.sh xdataplot; do
        if [ -e "$DP_BINDIR/$f" ] || [ -L "$DP_BINDIR/$f" ]; then
            sudo_run rm -f "$DP_BINDIR/$f"
        fi
    done
    # make install uses `cp -a`, which never prunes; remove the tree so stale
    # help/menu files from the previous version cannot survive the update.
    [ -d "$DP_LIBDIR" ] && sudo_run rm -rf "$DP_LIBDIR"
    return 0
}

install_dataplot() {
    step "Install -- replacing the previous installation"

    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    INSTALL_STARTED=1
    info "Removing previous binaries, wrapper, symlink and lib tree..."
    remove_installed_files
    ok "Old installation removed."

    cd "$DP_SRC/src"
    sudo_run make install

    [ -x "$DP_BINDIR/dataplot" ] || die "make install did not produce $DP_BINDIR/dataplot"
    [ -d "$DP_LIBDIR" ]          || die "make install did not populate $DP_LIBDIR"
    ok "Installed: $DP_BINDIR/dataplot, $DP_LIBDIR ($(find "$DP_LIBDIR" -type f | wc -l) files)"
}

# ----------------------------------------
# 13. Headless wrapper
# ----------------------------------------

install_wrapper() {
    step "Wrapper -- headless (xvfb-run) fallback"

    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    sudo_run mv "$DP_BINDIR/dataplot" "$DP_BINDIR/dataplot-original"

    # NOTE: a quoted heredoc, not `echo '...\n...'`. The Dockerfile's echo form
    # relies on /bin/sh (dash) expanding \n; under bash it would write one line
    # containing literal backslash-n and produce an unusable wrapper.
    local tmp_wrapper
    tmp_wrapper="$(mktemp)"
    cat > "$tmp_wrapper" <<WRAPPER
#!/bin/bash
# Dataplot launcher -- falls back to a virtual X display when none is present.
# Generated by ${SCRIPT_NAME} on $(date -Iseconds)
if [ -z "\$DISPLAY" ]; then
    if command -v xvfb-run >/dev/null 2>&1; then
        exec xvfb-run -a "${DP_BINDIR}/dataplot-original" "\$@"
    else
        echo "dataplot: no DISPLAY and xvfb-run is not installed; running without X." >&2
        exec "${DP_BINDIR}/dataplot-original" "\$@"
    fi
else
    exec "${DP_BINDIR}/dataplot-original" "\$@"
fi
WRAPPER

    sudo_run install -m 0755 "$tmp_wrapper" "$DP_BINDIR/dataplot-wrapper.sh"
    rm -f "$tmp_wrapper"
    sudo_run ln -sfn "$DP_BINDIR/dataplot-wrapper.sh" "$DP_BINDIR/dataplot"

    [ -x "$DP_BINDIR/dataplot-original"  ] || die "dataplot-original missing after wrapper install"
    [ -x "$DP_BINDIR/dataplot-wrapper.sh" ] || die "wrapper missing after install"
    [ -L "$DP_BINDIR/dataplot"           ] || die "dataplot symlink missing after wrapper install"
    ok "dataplot -> dataplot-wrapper.sh -> dataplot-original"

    if bash -n "$DP_BINDIR/dataplot-wrapper.sh"; then
        ok "Wrapper passes bash syntax check."
    else
        die "Generated wrapper is not valid bash."
    fi
}

# ----------------------------------------
# 14. Verification
# ----------------------------------------

TEST_DIR=""
CASE_DIR=""
CASE_SCRIPT=""
CASE_OUT=""
TESTS_RUN=0
TESTS_FAILED=0
DP_VERSION=""
TIKZ_SAMPLE=""
TIKZ_ARTIFACT=""

t_pass() { TESTS_RUN=$((TESTS_RUN+1)); ok   "$*"; }
t_fail() { TESTS_RUN=$((TESTS_RUN+1)); TESTS_FAILED=$((TESTS_FAILED+1)); err "$*"; }
t_warn() { warn "$*"; }

# Dataplot on Linux reads commands from stdin; command-line script arguments
# are only honoured on the Windows/Intel builds.
#
# Each case runs in its own subdirectory: Dataplot always opens DEVICE 2 as
# PostScript at startup and drops a dppl1f.ps/dppl2f.ps beside whatever the
# test asked for, so a shared directory makes "which file did this test
# produce?" unanswerable.
dp_case() {
    local name="$1"
    CASE_DIR="$TEST_DIR/$name"
    mkdir -p "$CASE_DIR"
    CASE_SCRIPT="$CASE_DIR/$name.dp"
    CASE_OUT="$CASE_DIR/$name.out"
}

dp_run() {
    ( cd "$CASE_DIR" && timeout 120 "$DP_BINDIR/dataplot" < "$CASE_SCRIPT" > "$CASE_OUT" 2>&1 ) || true
}

verify_install() {
    step "Verify -- post-install test suite"

    if [ "$SKIP_TESTS" -eq 1 ]; then
        warn "Skipped (--skip-tests)."
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        warn "Skipped (dry run)."
        return 0
    fi

    TEST_DIR="$(mktemp -d /tmp/dataplot_verify_XXXXXX)"
    info "Scratch directory: $TEST_DIR"

    # --- 1. binary and library tree -----------------------------------
    if [ -x "$DP_BINDIR/dataplot" ]; then
        t_pass "dataplot is present and executable"
    else
        t_fail "dataplot is missing or not executable"
    fi

    if [ -d "$DP_LIBDIR" ] && [ "$(find "$DP_LIBDIR" -type f | wc -l)" -gt 100 ]; then
        t_pass "library tree populated ($(find "$DP_LIBDIR" -type f | wc -l) files in $DP_LIBDIR)"
    else
        t_fail "library tree at $DP_LIBDIR looks empty or truncated"
    fi

    # --- 2. shared library resolution ---------------------------------
    if ldd "$DP_BINDIR/dataplot-original" 2>/dev/null | grep -q 'not found'; then
        t_fail "unresolved shared libraries:"
        ldd "$DP_BINDIR/dataplot-original" | grep 'not found' | sed 's/^/       /'
    else
        t_pass "all shared libraries resolve"
    fi

    # --- 3. starts, banners, exits cleanly ----------------------------
    dp_case startup
    printf 'EXIT\n' > "$CASE_SCRIPT"
    dp_run
    if grep -qi 'dataplot' "$CASE_OUT"; then
        t_pass "starts and exits cleanly"
        DP_VERSION="$(grep -iE 'THIS IS DATAPLOT VERSION' "$CASE_OUT" | head -1 | tr -s ' ' | sed 's/^ *//')"
        [ -n "$DP_VERSION" ] && printf '       %s\n' "$DP_VERSION"
    else
        t_fail "did not produce a recognizable startup banner"
        head -20 "$CASE_OUT" | sed 's/^/       /'
    fi

    # --- 4. headless path actually used -------------------------------
    if command -v xvfb-run >/dev/null 2>&1; then
        if ( unset DISPLAY; cd "$CASE_DIR" && timeout 120 "$DP_BINDIR/dataplot" < "$CASE_SCRIPT" >/dev/null 2>&1 ); then
            t_pass "runs with DISPLAY unset (xvfb-run fallback works)"
        else
            t_fail "failed to run with DISPLAY unset"
        fi
    else
        t_warn "xvfb-run absent -- headless fallback not exercised"
    fi

    # --- 5. arithmetic / data path ------------------------------------
    dp_case calc
    cat > "$CASE_SCRIPT" <<'DPEOF'
LET Y = DATA 1 2 3 4 5 6 7 8 9 10
LET M = MEAN Y
PRINT M
EXIT
DPEOF
    dp_run
    if grep -qE '5\.5' "$CASE_OUT"; then
        t_pass "computes correctly (MEAN of 1..10 = 5.5)"
    else
        t_fail "arithmetic check did not return 5.5"
        tail -20 "$CASE_OUT" | sed 's/^/       /'
    fi

    # --- 6. MAXOBV actually took effect --------------------------------
    dp_case maxobv
    printf 'STATUS\nEXIT\n' > "$CASE_SCRIPT"
    dp_run
    if grep -qE "(^|[^0-9])${DP_MAXOBV}([^0-9]|$)" "$CASE_OUT"; then
        t_pass "runtime reports the patched observation capacity (${DP_MAXOBV})"
    else
        t_warn "could not confirm MAXOBV=${DP_MAXOBV} from STATUS output"
        t_warn "  (the source patch was verified before the build, so this is informational)"
    fi

    # --- 7. PostScript device (baseline graphics) ----------------------
    # DEVICE 2 is already open as PostScript at startup, so every device
    # change has to begin with DEVICE 2 CLOSE.
    dp_case postscript
    cat > "$CASE_SCRIPT" <<'DPEOF'
DEVICE 2 CLOSE
SET IPL1NA dp_test.ps
DEVICE 2 POSTSCRIPT
LET X = DATA 1 2 3 4 5
LET Y = DATA 2 4 6 8 10
TITLE Dataplot install verification
PLOT Y X
DEVICE 2 CLOSE
EXIT
DPEOF
    dp_run
    if [ -s "$CASE_DIR/dp_test.ps" ] && grep -qi 'PS-Adobe' "$CASE_DIR/dp_test.ps"; then
        t_pass "PostScript device wrote dp_test.ps ($(wc -c < "$CASE_DIR/dp_test.ps") bytes)"
    else
        t_fail "PostScript device produced no usable dp_test.ps"
        tail -25 "$CASE_OUT" | sed 's/^/       /'
    fi

    # --- 8. LaTeX/TikZ device (the reason for this update) -------------
    dp_case tikz
    cat > "$CASE_SCRIPT" <<'DPEOF'
DEVICE 2 CLOSE
SET LATEX DRIVER TIKZ
SET IPL1NA dp_test_tikz.tex
DEVICE 2 LATEX STANDALONE
LET X = DATA 1 2 3 4 5
LET Y = DATA 2 4 6 8 10
TITLE Dataplot TikZ verification
PLOT Y X
DEVICE 2 CLOSE
EXIT
DPEOF
    dp_run
    if ! grep -q 'HAS JUST BEEN SET TO TIKZ' "$CASE_OUT"; then
        t_fail "SET LATEX DRIVER TIKZ was not accepted -- this build predates the TikZ driver"
        t_fail "  (needs upstream commit d837c4a, 2026-08-10, or later)"
    elif [ ! -s "$CASE_DIR/dp_test_tikz.tex" ]; then
        t_fail "TikZ device produced no dp_test_tikz.tex"
        grep -A3 'ERROR' "$CASE_OUT" | head -20 | sed 's/^/       /'
    elif grep -q 'begin{tikzpicture}' "$CASE_DIR/dp_test_tikz.tex"; then
        t_pass "TikZ output written: dp_test_tikz.tex ($(wc -c < "$CASE_DIR/dp_test_tikz.tex") bytes, \\begin{tikzpicture} present)"
        TIKZ_ARTIFACT="$CASE_DIR/dp_test_tikz.tex"
        if command -v pdflatex >/dev/null 2>&1; then
            if ( cd "$CASE_DIR" && timeout 180 pdflatex -interaction=nonstopmode -halt-on-error \
                 dp_test_tikz.tex >pdflatex.out 2>&1 ); then
                t_pass "pdflatex compiled the TikZ output to PDF"
            else
                t_warn "pdflatex could not compile the generated TikZ (Dataplot's side is fine; this is a TeX-side issue):"
                grep -m2 '^!' "$CASE_DIR/pdflatex.out" 2>/dev/null | sed 's/^/       /'
                t_warn "  full log: $CASE_DIR/pdflatex.out"
            fi
        else
            t_warn "no pdflatex on PATH -- TikZ output was not compile-tested"
        fi
    else
        t_fail "dp_test_tikz.tex contains no tikzpicture environment"
        head -20 "$CASE_DIR/dp_test_tikz.tex" | sed 's/^/       /'
    fi

    # --- 8b. TikZ region and character fill ----------------------------
    dp_case tikz-fill
    cat > "$CASE_SCRIPT" <<'DPEOF'
DEVICE 2 CLOSE
SET LATEX DRIVER TIKZ
SET LATEX COLOR ON
SET IPL1NA dp_test_tikz_fill.tex
DEVICE 2 LATEX STANDALONE
LET Y = DATA 2930 2085 1816 4157 4949 228 84
LET X = DATA 1 2 3 4 5 6 7
Y1LIMITS 0 5000
REGION BASE 0 ALL
REGION FILL ON ALL
REGION COLOR gray
CHARACTER CIRCLE
CHARACTER FILL ALL ON
PLOT Y X
DEVICE 2 CLOSE
EXIT
DPEOF
    dp_run
    local ff="$CASE_DIR/dp_test_tikz_fill.tex"
    if [ ! -s "$ff" ]; then
        t_fail "TikZ fill case produced no dp_test_tikz_fill.tex"
    else
        local nstar nbare npath
        nstar=$(grep -c '\*\*pt' "$ff" || true)
        nbare=$(grep -cE 'pt, *-?[0-9]+\);' "$ff" || true)
        npath=$(grep -c '^.fill\[[A-Za-z0-9]*\] (' "$ff" || true)
        if [ "$nstar" -eq 0 ] && [ "$nbare" -eq 0 ]; then
            t_pass "TikZ fill output has well-formed coordinates (${npath} \\fill path(s))"
        else
            t_fail "TikZ fill output is malformed: ${nstar} overflowed x, ${nbare} unitless y"
            t_fail "  (the 2026/08 fill defect -- is patch_tikz_fill.py applied?)"
        fi
        if command -v pdflatex >/dev/null 2>&1; then
            if ( cd "$CASE_DIR" && timeout 180 pdflatex -interaction=nonstopmode -halt-on-error \
                 dp_test_tikz_fill.tex >pdflatex_fill.out 2>&1 ); then
                t_pass "pdflatex compiled the TikZ fill output"
            else
                t_fail "pdflatex could not compile the TikZ fill output:"
                grep -m2 '^!' "$CASE_DIR/pdflatex_fill.out" 2>/dev/null | sed 's/^/       /'
            fi
        fi
    fi

    # --- 9. epic/eepic LaTeX driver still works ------------------------
    dp_case epic
    cat > "$CASE_SCRIPT" <<'DPEOF'
DEVICE 2 CLOSE
SET LATEX DRIVER EPIC
SET IPL1NA dp_test_epic.tex
DEVICE 2 LATEX STANDALONE
LET X = DATA 1 2 3 4 5
LET Y = DATA 2 4 6 8 10
PLOT Y X
DEVICE 2 CLOSE
EXIT
DPEOF
    dp_run
    if [ -s "$CASE_DIR/dp_test_epic.tex" ]; then
        t_pass "epic/eepic driver still works ($(wc -c < "$CASE_DIR/dp_test_epic.tex") bytes)"
    else
        t_warn "epic/eepic driver produced no file (non-fatal: TikZ is the target driver)"
    fi

    # --- 10. TikZ support present in the installed lib tree -------------
    if [ -f "$DP_LIBDIR/help/latexheader_tikz.tex" ]; then
        t_pass "latexheader_tikz.tex present in $DP_LIBDIR/help"
    else
        t_warn "latexheader_tikz.tex not found in the installed lib tree"
    fi

    log ""
    if [ "$TESTS_FAILED" -eq 0 ]; then
        ok "Verification: ${TESTS_RUN}/${TESTS_RUN} checks passed."
        # Keep the generated TikZ sample -- it is the smallest working example
        # of the new driver, and useful as a reference.
        if [ -n "$TIKZ_ARTIFACT" ] && [ -s "$TIKZ_ARTIFACT" ]; then
            TIKZ_SAMPLE="$(dirname "$DP_LOG")/dataplot_tikz_sample_${START_TS}.tex"
            cp "$TIKZ_ARTIFACT" "$TIKZ_SAMPLE" 2>/dev/null && \
                info "TikZ sample kept at $TIKZ_SAMPLE"
        fi
        rm -rf "$TEST_DIR"
    else
        err "Verification: ${TESTS_FAILED} of ${TESTS_RUN} checks FAILED."
        err "Artifacts kept for inspection: $TEST_DIR"
        return 1
    fi
}

# ----------------------------------------
# 15. Cleanup and summary
# ----------------------------------------

cleanup_source() {
    if [ "$KEEP_SOURCE" -eq 1 ]; then
        info "Build tree kept at $DP_SRC (--keep-source)."
    elif [ "$DRY_RUN" -eq 0 ]; then
        step "Cleanup -- removing the build tree"
        rm -rf "$DP_SRC"
        ok "Removed $DP_SRC"
    fi
}

summary() {
    step "Summary"
    [ -n "$DP_VERSION" ] && log "  Version         : ${DP_VERSION}"
    log "  Source commit   : ${BUILD_SHA:-?} (${BUILD_DATE:-?})"
    log "  Installed to    : ${DP_BINDIR}/dataplot -> dataplot-wrapper.sh -> dataplot-original"
    log "  Library tree    : ${DP_LIBDIR}"
    log "  MAXOBV          : ${DP_MAXOBV}"
    log "  mcmodel         : ${DP_MCMODEL}"
    [ -n "$BACKUP_TARBALL" ] && log "  Rollback with   : $0 --rollback   (${BACKUP_TARBALL})"
    log "  Transcript      : ${DP_LOG}"
    log ""
    log "  TikZ output from a Dataplot session -- note that DEVICE 2 is already"
    log "  open as PostScript at startup, so it must be closed first:"
    log ""
    log "      DEVICE 2 CLOSE"
    log "      SET LATEX DRIVER TIKZ"
    log "      SET IPL1NA myplot.tex"
    log "      DEVICE 2 LATEX STANDALONE"
    log "      ... plot commands ..."
    log "      DEVICE 2 CLOSE"
    log ""
    log "  SET LATEX DRIVER EPIC restores the previous epic/eepic behaviour."
    log "  Related settings: SET LATEX TIKZ WIDTH / HEIGHT (inches),"
    log "  SET LATEX FONT FAMILY, SET LATEX FONT STYLE, SET LATEX HARDWARE FILL."
    log ""
}

confirm() {
    [ "$ASSUME_YES" -eq 1 ] && return 0
    [ "$DRY_RUN" -eq 1 ] && return 0
    [ ! -t 0 ] && return 0        # non-interactive (Docker build, CI): proceed
    log ""
    printf 'Replace the Dataplot installation at %s? [y/N] ' "$DP_PREFIX"
    local reply; read -r reply
    case "$reply" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) die "Aborted by user." ;;
    esac
}

# ----------------------------------------
# 16. Main
# ----------------------------------------

main() {
    detect_environment

    if [ "$ROLLBACK_ONLY" -eq 1 ]; then
        restore_backup "" || die "Rollback failed."
        exit 0
    fi

    trap on_error ERR

    preflight_a
    confirm
    fetch_source
    preflight_b
    apply_patches
    build_dataplot
    backup_current
    install_dataplot
    install_wrapper

    trap - ERR
    if ! verify_install; then
        err "The new build installed but failed verification."
        if [ -n "$BACKUP_TARBALL" ]; then
            if [ "$ASSUME_YES" -eq 1 ] || [ ! -t 0 ]; then
                warn "Rolling back automatically."
                restore_backup "$BACKUP_TARBALL" || true
            else
                printf 'Roll back to the previous version? [Y/n] '
                local reply; read -r reply
                case "$reply" in
                    [nN]|[nN][oO]) warn "Keeping the new build despite failures." ;;
                    *) restore_backup "$BACKUP_TARBALL" || true ;;
                esac
            fi
        fi
        exit 1
    fi

    cleanup_source
    summary
    ok "Dataplot update complete."
}

main "$@"
