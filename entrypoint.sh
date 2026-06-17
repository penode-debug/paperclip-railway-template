#!/bin/bash
set -e

# Fix ownership of the Railway volume mount at /paperclip
# Railway mounts volumes as root, but we need the paperclip user to write to it
if [ -d "/paperclip" ]; then
  chown -R paperclip:paperclip /paperclip 2>/dev/null || true
fi

# Cleanup old backups (keep last 5) and truncate large log to prevent ENOSPC
if [ -d "/paperclip/backups" ]; then
  ls -t /paperclip/backups/*.sql.gz 2>/dev/null | tail -n +6 | xargs rm -f || true
  fi
  if [ -f "/paperclip/logs/server.log" ] && [ $(stat -c%s /paperclip/logs/server.log) -gt 52428800 ]; then
    truncate -s 0 /paperclip/logs/server.log || true
    fi
# Cleanup old agent instance workspaces (keep last 10 per agent) to prevent ENOSPC
if [ -d "/paperclip/instances" ]; then
  for agent_dir in /paperclip/instances/*/; do
    if [ -d "$agent_dir" ]; then
      ls -dt "${agent_dir}"*/ 2>/dev/null | tail -n +11 | xargs rm -rf || true
    fi
  done
fi
# Drop privileges and run the actual command as the paperclip user
exec gosu paperclip "$@"
