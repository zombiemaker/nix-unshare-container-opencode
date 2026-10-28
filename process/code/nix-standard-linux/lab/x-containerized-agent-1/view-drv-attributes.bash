#!/usr/bin/env bash
nix eval --impure --expr "builtins.attrNames (import ./shell.nix {})"
