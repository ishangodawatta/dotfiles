#!/bin/sh
set -eu
set +x

. "$HOME/.config/mcp-agent-mail/environment.sh"

case "${HTTP_BEARER_TOKEN:-}" in
    ''|*[!A-Za-z0-9._~+/=-]*)
        printf '%s\n' 'Agent Mail bearer token is missing or invalid.' >&2
        exit 1
        ;;
esac

printf '{"Authorization":"Bearer %s"}\n' "$HTTP_BEARER_TOKEN"
