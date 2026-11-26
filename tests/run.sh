#!/bin/sh
# Run every offline check (needs lua5.1). Simulations: a few seeds per dungeon, entrance start, compass facing.
set -e
cd "$(dirname "$0")/.."
lua5.1 tests/unit.lua
lua5.1 tests/smoke.lua
for m in 389 43 48 34 90 70 349 109 230 229 429; do
  START=entrance lua5.1 tests/sim.lua $m 1 facing 240 | tail -1
done
