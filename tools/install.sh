#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/tools/bin"

mkdir -p "$BIN"

: "${ACTIONLINT_VERSION:?ACTIONLINT_VERSION required}"
: "${HADOLINT_VERSION:?HADOLINT_VERSION required}"
: "${SHELLCHECK_VERSION:?SHELLCHECK_VERSION required}"
: "${TRIVY_VERSION:?TRIVY_VERSION required}"

INSTALLED=0

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Linux) OS=linux ;;
    Darwin) OS=darwin ;;
    *)
        echo "❌ Unsupported OS: $OS" >&2
        exit 1
        ;;
esac

case "$ARCH" in
    x86_64 | amd64) ARCH=amd64 ;;
    arm64 | aarch64) ARCH=arm64 ;;
    *)
        echo "❌ Unsupported architecture: $ARCH" >&2
        exit 1
        ;;
esac

expected_sha() {
    local prefix="$1"
    local os_upper arch_upper var value
    case "$OS" in
        linux) os_upper=LINUX ;;
        darwin) os_upper=DARWIN ;;
    esac
    case "$ARCH" in
        amd64) arch_upper=AMD64 ;;
        arm64) arch_upper=ARM64 ;;
    esac
    var="${prefix}_SHA256_${os_upper}_${arch_upper}"
    value="${!var:-}"
    if [[ -z "$value" ]]; then
        echo "❌ ERROR: ${var} is not exported in environment." >&2
        exit 1
    fi
    printf '%s' "$value"
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    local actual
    if command -v sha256sum >/dev/null 2>&1; then
        actual="$(sha256sum "$file" | awk '{print $1}')"
    else
        actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    fi
    if [[ "$actual" != "$expected" ]]; then
        echo "❌ ERROR: SHA256 checksum mismatch for $(basename "$file")" >&2
        echo "  expected: ${expected}" >&2
        echo "  actual:   ${actual}" >&2
        exit 1
    fi
    echo "  [OK] SHA-256 verified for $(basename "$file")"
}

download() {
    curl -fsSL "$1" -o "$2"
}

# ═══════════════════════════════════════════════════════════════════════════
# 1. ACTIONLINT
# ═══════════════════════════════════════════════════════════════════════════
install_actionlint() {
    [[ "${REINSTALL:-}" = "1" ]] && rm -f "$BIN/actionlint"

    if [[ -x "$BIN/actionlint" ]]; then
        local current_ver
        current_ver="$("$BIN/actionlint" -version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")"
        if [[ "$current_ver" == "$ACTIONLINT_VERSION" ]]; then
            echo "  ✓ actionlint v${ACTIONLINT_VERSION} already installed."
            return 0
        fi
        echo "  ⚠️ Outdated actionlint found (${current_ver} != ${ACTIONLINT_VERSION}), replacing..."
        rm -f "$BIN/actionlint"
    fi

    INSTALLED=1
    echo "  ⬇️ Downloading actionlint v${ACTIONLINT_VERSION} (${OS}/${ARCH})..."
    TMP="$(mktemp -d)"
    TARBALL="$TMP/actionlint.tar.gz"

    download \
        "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_${OS}_${ARCH}.tar.gz" \
        "$TARBALL"

    verify_sha256 "$TARBALL" "$(expected_sha ACTIONLINT)"
    tar -xz -C "$TMP" -f "$TARBALL"
    install -m 0755 "$TMP/actionlint" "$BIN/actionlint"
    rm -rf "$TMP"
}

# ═══════════════════════════════════════════════════════════════════════════
# 2. HADOLINT
# ═══════════════════════════════════════════════════════════════════════════
install_hadolint() {
    [[ "${REINSTALL:-}" = "1" ]] && rm -f "$BIN/hadolint"

    if [[ -x "$BIN/hadolint" ]]; then
        local current_ver
        current_ver="$("$BIN/hadolint" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")"
        if [[ "$current_ver" == "$HADOLINT_VERSION" ]]; then
            echo "  ✓ hadolint v${HADOLINT_VERSION} already installed."
            return 0
        fi
        echo "  ⚠️ Outdated hadolint found (${current_ver} != ${HADOLINT_VERSION}), replacing..."
        rm -f "$BIN/hadolint"
    fi

    INSTALLED=1
    echo "  ⬇️ Downloading hadolint v${HADOLINT_VERSION} (${OS}/${ARCH})..."
    local file_name
    case "$OS-$ARCH" in
        linux-amd64) file_name="hadolint-linux-x86_64" ;;
        linux-arm64) file_name="hadolint-linux-arm64" ;;
        darwin-amd64) file_name="hadolint-macos-x86_64" ;;
        darwin-arm64) file_name="hadolint-macos-arm64" ;;
    esac

    TMP="$(mktemp -d)"
    download \
        "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/${file_name}" \
        "$TMP/hadolint"

    verify_sha256 "$TMP/hadolint" "$(expected_sha HADOLINT)"
    install -m 0755 "$TMP/hadolint" "$BIN/hadolint"
    rm -rf "$TMP"
}

# ═══════════════════════════════════════════════════════════════════════════
# 3. SHELLCHECK
# ═══════════════════════════════════════════════════════════════════════════
install_shellcheck() {
    [[ "${REINSTALL:-}" = "1" ]] && rm -f "$BIN/shellcheck"

    if [[ -x "$BIN/shellcheck" ]]; then
        local current_ver
        current_ver="$("$BIN/shellcheck" --version 2>/dev/null | grep "version:" | awk '{print $2}' || echo "")"
        if [[ "$current_ver" == "$SHELLCHECK_VERSION" ]]; then
            echo "  ✓ shellcheck v${SHELLCHECK_VERSION} already installed."
            return 0
        fi
        echo "  ⚠️ Outdated shellcheck found (${current_ver} != ${SHELLCHECK_VERSION}), replacing..."
        rm -f "$BIN/shellcheck"
    fi

    INSTALLED=1
    echo "  ⬇️ Downloading shellcheck v${SHELLCHECK_VERSION} (${OS}/${ARCH})..."
    local arch_name
    case "$ARCH" in
        amd64) arch_name="x86_64" ;;
        arm64) arch_name="aarch64" ;;
    esac

    TMP="$(mktemp -d)"
    TARBALL="$TMP/shellcheck.tar.xz"

    download \
        "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.${OS}.${arch_name}.tar.xz" \
        "$TARBALL"

    verify_sha256 "$TARBALL" "$(expected_sha SHELLCHECK)"
    tar -xJ -C "$TMP" -f "$TARBALL"
    install -m 0755 "$TMP/shellcheck-v${SHELLCHECK_VERSION}/shellcheck" "$BIN/shellcheck"
    rm -rf "$TMP"
}

# ═══════════════════════════════════════════════════════════════════════════
# 4. TRIVY
# ═══════════════════════════════════════════════════════════════════════════
install_trivy() {
    [[ "${REINSTALL:-}" = "1" ]] && rm -f "$BIN/trivy"

    if [[ -x "$BIN/trivy" ]]; then
        local current_ver
        current_ver="$("$BIN/trivy" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")"
        if [[ "$current_ver" == "$TRIVY_VERSION" ]]; then
            echo "  ✓ trivy v${TRIVY_VERSION} already installed."
            return 0
        fi
        echo "  ⚠️ Outdated trivy found (${current_ver} != ${TRIVY_VERSION}), replacing..."
        rm -f "$BIN/trivy"
    fi

    INSTALLED=1
    echo "  ⬇️ Downloading trivy v${TRIVY_VERSION} (${OS}/${ARCH})..."
    local os_title arch_title
    case "$OS" in
        linux) os_title="Linux" ;;
        darwin) os_title="macOS" ;;
    esac
    case "$ARCH" in
        amd64) arch_title="64bit" ;;
        arm64) arch_title="ARM64" ;;
    esac

    TMP="$(mktemp -d)"
    TARBALL="$TMP/trivy.tar.gz"

    download \
        "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_${os_title}-${arch_title}.tar.gz" \
        "$TARBALL"

    verify_sha256 "$TARBALL" "$(expected_sha TRIVY)"
    tar -xz -C "$TMP" -f "$TARBALL"
    install -m 0755 "$TMP/trivy" "$BIN/trivy"
    rm -rf "$TMP"
}

echo "🔧 Checking and provisioning development binaries in tools/bin..."
install_actionlint
install_hadolint
install_shellcheck
install_trivy

if [[ "$INSTALLED" -eq 1 ]]; then
    echo "✓ Development binaries verified and ready in tools/bin."
fi
