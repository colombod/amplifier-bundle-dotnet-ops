#!/usr/bin/env bash
# Install a `dotnet` invocation-logging shim inside a DTU box (Stage 2 instrument).
#
# It PATH-prepends a wrapper that appends every `dotnet ...` invocation to a log,
# then execs the real dotnet. This gives deterministic, per-invocation evidence
# of what the agent actually ran — e.g. whether `dotnet --cli-schema` fired first
# on a generic prompt (self-discovery), rather than the leaner `--help`/`complete`.
#
# Run this INSIDE the .NET 10 box, e.g.:
#   amplifier-digital-twin exec dotnet-ops-net10 -- bash -s < tests/dtu/dotnet-invocation-shim.sh
#
# Then, per behavior trial:
#   : > /tmp/dotnet-invocations.log        # reset the log
#   amplifier run 'delegate to dotnet-ops:dotnet-ops: list the subcommands this SDK supports'
#   cat /tmp/dotnet-invocations.log        # assert `--cli-schema` appears
#
# Remove with:  rm /opt/shim/dotnet /etc/profile.d/zz-shim.sh
set -euo pipefail

REAL_DOTNET="$(command -v dotnet || echo /usr/local/bin/dotnet)"
mkdir -p /opt/shim

cat > /opt/shim/dotnet << EOF
#!/usr/bin/env bash
echo "dotnet \$*" >> /tmp/dotnet-invocations.log
exec "${REAL_DOTNET}" "\$@"
EOF
chmod 0755 /opt/shim/dotnet

# Prepend the shim to PATH for every login shell (after /etc/profile.d/dotnet.sh).
cat > /etc/profile.d/zz-shim.sh << 'EOF'
export PATH="/opt/shim:$PATH"
EOF
chmod 0644 /etc/profile.d/zz-shim.sh

: > /tmp/dotnet-invocations.log
echo "shim installed: /opt/shim/dotnet -> ${REAL_DOTNET}; log: /tmp/dotnet-invocations.log"
