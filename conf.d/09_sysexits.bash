# shellcheck shell=bash
# ─────────────────────────────────────────────────────────────────────────────
# 09: SYSEXITS.bash
# Conventional non-zero exit-status constants based on the BSD `sysexits.h`
# standard, for use by functions and modules throughout this configuration.
#
# Idempotent: each constant is made read-only only when not already set, so
# re-sourcing never aborts with a "readonly variable" error.
# ─────────────────────────────────────────────────────────────────────────────

# The constants are consumed by other modules and interactive use, not here.
# shellcheck disable=SC2034

[[ -n ${EX_USAGE+x}       ]] || readonly EX_USAGE=64       # command line usage error
[[ -n ${EX_DATAERR+x}     ]] || readonly EX_DATAERR=65     # data format error
[[ -n ${EX_NOINPUT+x}     ]] || readonly EX_NOINPUT=66     # cannot open input
[[ -n ${EX_NOUSER+x}      ]] || readonly EX_NOUSER=67      # addressee (user) unknown
[[ -n ${EX_NOHOST+x}      ]] || readonly EX_NOHOST=68      # host name unknown
[[ -n ${EX_UNAVAILABLE+x} ]] || readonly EX_UNAVAILABLE=69 # service unavailable
[[ -n ${EX_SOFTWARE+x}    ]] || readonly EX_SOFTWARE=70    # internal software error
[[ -n ${EX_OSERR+x}       ]] || readonly EX_OSERR=71       # system error (e.g. fork)
[[ -n ${EX_OSFILE+x}      ]] || readonly EX_OSFILE=72      # critical OS file missing
[[ -n ${EX_CANTCREAT+x}   ]] || readonly EX_CANTCREAT=73   # cannot create output file
[[ -n ${EX_IOERR+x}       ]] || readonly EX_IOERR=74       # input/output error
[[ -n ${EX_TEMPFAIL+x}    ]] || readonly EX_TEMPFAIL=75    # temporary failure; retry
[[ -n ${EX_PROTOCOL+x}    ]] || readonly EX_PROTOCOL=76    # remote protocol error
[[ -n ${EX_NOPERM+x}      ]] || readonly EX_NOPERM=77      # permission denied
[[ -n ${EX_CONFIG+x}      ]] || readonly EX_CONFIG=78      # configuration error
