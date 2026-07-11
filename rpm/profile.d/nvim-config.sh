# shellcheck shell=sh
# Bundled Neovim toolchain (nvim, node, rg) from the nvim-config RPM.
# Sourced by login shells; must stay POSIX sh compatible.
# NVIM_OFFLINE tells the editor config to skip startup install checks —
# everything is pre-installed and there is no network.
case ":$PATH:" in
  *:/opt/nvim-config/bin:*) ;;
  *) PATH="/opt/nvim-config/bin:$PATH" ;;
esac
export PATH
export NVIM_OFFLINE=1
