# pi-gen patches

`build.sh` applies every `*.patch` in this directory to the `pi-gen` submodule
before building (idempotently, via `git apply`). Keep them minimal; upstream
pi-gen is tracked unmodified as a submodule.

`optional/` holds patches that are **not** applied automatically. Move one up a
level to enable it.
