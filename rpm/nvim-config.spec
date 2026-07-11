# nvim-config.spec — offline Neovim development environment for EL8.
# Built by rpm/build-rpm.sh, which passes:
#   --define "payload_root <staged / tree>"
#   --define "pkg_version  <version>"
#   --define "python_dep   <python3.1x>"   (must match the debugpy venv python)

# The payload is ~1 GB of third-party binaries (Neovim, Node.js, codelldb,
# clangd, …). Disable everything that would rewrite or introspect them:
# stripping and shebang mangling corrupt bundled tools, and automatic
# dependency generation would emit unresolvable Requires/Provides.
%global debug_package %{nil}
%global __os_install_post %{nil}
%global __brp_mangle_shebangs %{nil}
%global _build_id_links none
# zstd payload: much faster to build than xz at this size; EL8 rpm (4.14+) reads it
%define _binary_payload w19.zstdio

Name:           nvim-config
Version:        %{?pkg_version}%{!?pkg_version:1.0.0}
Release:        1%{?dist}
Summary:        Offline Neovim development environment (editor, plugins, LSP, DAP)
License:        Apache-2.0 and MIT and various (bundled third-party tools)
URL:            https://github.com/christopherhagler/nvim
AutoReqProv:    no

Requires:       git
Requires:       %{?python_dep}%{!?python_dep:python3.11}

%description
Self-contained Neovim setup for air-gapped RHEL 8 / Rocky 8 systems.
Bundles Neovim (built against EL8 glibc), Node.js, ripgrep, the editor
configuration, all plugins, compiled treesitter parsers, and every Mason
tool (LSP servers, formatters, linters, debug adapters) — no network
access required at any point after installation.

Per-user activation: run `nvim-config-install` once after installing.

%install
cp -a %{payload_root}/. %{buildroot}/

%files
/opt/nvim-config
/usr/bin/nvim-config-install
/etc/profile.d/nvim-config.sh

%changelog
* Fri Jul 11 2026 Christopher Hagler <haglerchristopher@gmail.com>
- Initial offline package: Neovim, Node.js, ripgrep, config, plugins,
  treesitter parsers, and Mason toolchain in one artifact.
