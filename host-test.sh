#!/bin/sh
exec uv run --directory "$(dirname "$0")" --isolated --frozen --quiet python -m sbx.host_test "$@"
