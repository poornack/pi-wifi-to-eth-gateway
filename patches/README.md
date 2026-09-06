# pi-gen patches

Small fixes to upstream pi-gen that the build needs. They are applied **by
you, once, by hand** so that `build.sh` never modifies source code:

```bash
(cd pi-gen && git apply ../patches/*.patch)
```

The parentheses run the command in a subshell, so your shell stays in the repo
root afterwards. (`git -C pi-gen apply ../patches/*.patch` does not work: the
shell expands the `*` from the current directory, before git changes into
`pi-gen`.)

`git -C pi-gen status` will then show the patched files as modified. That is
expected. To undo: `git -C pi-gen checkout -- .`

Patches are numbered and applied in filename order.

| patch | what it fixes |
|---|---|
| `0001-dockerfile-add-gpgv.patch` | adds `gpgv` to the build container. Without it debootstrap cannot verify the Raspbian archive signature and stage0 fails. |
| `0002-build-docker-portable-sed-regex.patch` | makes `build-docker.sh` work on macOS. It rewrites the `-c <config>` option with a `sed` regex using `\s`, which BSD sed (macOS) does not support; the config path ends up mangled to `pi-gen-c` and the build fails inside the container. Uses `[[:space:]]` instead, which works everywhere. |
