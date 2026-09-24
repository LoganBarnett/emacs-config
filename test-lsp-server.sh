#!/usr/bin/env bash
# The smallest stdio LSP server that lets lsp-mode reach `initialized'.
# Used by test-lsp.el as a stand-in for rust-analyzer, so the test can drive
# lsp-mode's real start-up path (client registration, command resolution and
# the emacs-lsp-booster wrapper, process filter, JSON/bytecode parsing)
# without a language toolchain on PATH.
#
# Reads Content-Length framed JSON-RPC from stdin.  Answers `initialize' with
# empty capabilities and `shutdown' with null, exits on `exit', and ignores
# every other message.  Bodies are ASCII, so bash's character count is the
# byte count the framing needs.

set -o errexit -o nounset -o pipefail

# command: -v prints the resolved command; the builtin has no long form.
if ! command -v jq > /dev/null; then
  echo "test-lsp-server.sh: jq is required but not on PATH" >&2
  exit 1
fi

respond() {
  local body=$1
  printf 'Content-Length: %d\r\n\r\n%s' "${#body}" "$body"
}

length=0
# read: -r keeps backslashes literal; the builtin has no long form.
while IFS= read -r line; do
  # Header lines end in CRLF; strip the CR so the blank-line test below works.
  line=${line%$'\r'}
  case $line in
    Content-Length:*)
      length=${line#Content-Length: }
      ;;
    "")
      # End of headers: the body is exactly $length bytes.  bash's `read'
      # consumes a pipe one byte at a time, so `head' sees the body intact.
      # -c (byte count) is the only spelling both BSD head (macOS) and GNU
      # head accept; GNU's --bytes is not portable.
      body=$(head -c "$length")
      id=$(jq --raw-output '.id // empty' <<< "$body")
      method=$(jq --raw-output '.method // empty' <<< "$body")
      case $method in
        initialize)
          result='{"capabilities":{}}'
          respond "{\"jsonrpc\":\"2.0\",\"id\":${id},\"result\":${result}}"
          ;;
        shutdown)
          respond "{\"jsonrpc\":\"2.0\",\"id\":${id},\"result\":null}"
          ;;
        exit)
          exit 0
          ;;
      esac
      ;;
  esac
done
