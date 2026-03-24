#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BINICA_SUPPORT_DIR="${SCRIPT_DIR}/eeglab_binica_support"
EEGLAB_SIGPROC_DIR="/home/marcos/MATLAB Add-Ons/Collections/EEGLAB/functions/sigprocfunc"
EEGLAB_SUPPORTFILES_DIR="/home/marcos/MATLAB Add-Ons/Collections/EEGLAB/functions/supportfiles"
MATLAB_BIN="/usr/local/MATLAB/R2025b/bin/matlab"
SYSTEM_LIBSTDCPP="/usr/lib/x86_64-linux-gnu/libstdc++.so.6"

mkdir -p "${BINICA_SUPPORT_DIR}"

if [[ -f "${EEGLAB_SUPPORTFILES_DIR}/ica_linux" ]]; then
    ln -sf "${EEGLAB_SUPPORTFILES_DIR}/ica_linux" "${BINICA_SUPPORT_DIR}/ica_linux"
fi

if [[ -f "${EEGLAB_SIGPROC_DIR}/binica.sc" ]]; then
    ln -sf "${EEGLAB_SIGPROC_DIR}/binica.sc" "${BINICA_SUPPORT_DIR}/binica.sc"
fi

if [[ ! -f "${SYSTEM_LIBSTDCPP}" ]]; then
    echo "Missing ${SYSTEM_LIBSTDCPP}" >&2
    exit 1
fi

if [[ ! -x "${MATLAB_BIN}" ]]; then
    echo "Missing MATLAB binary at ${MATLAB_BIN}" >&2
    exit 1
fi

if [[ -f "${BINICA_SUPPORT_DIR}/ica_linux" ]]; then
    chmod +x "${BINICA_SUPPORT_DIR}/ica_linux"
fi

export SHELL="/bin/bash"
export LD_PRELOAD="${SYSTEM_LIBSTDCPP}${LD_PRELOAD:+:${LD_PRELOAD}}"
exec "${MATLAB_BIN}" "$@"
