# pi-gen patches

Small fixes to upstream pi-gen that the build needs. They are applied **by
you, once, by hand** so that `build.sh` never modifies source code:

```bash
git -C pi-gen apply ../patches/*.patch
```

`git -C pi-gen status` will then show the patched files as modified. That is
expected. To undo: `git -C pi-gen checkout -- .`

Patches are numbered and applied in filename order.

| patch | what it fixes |
|---|---|
| `0001-dockerfile-add-gpgv.patch` | adds `gpgv` to the build container. Without it debootstrap cannot verify the Raspbian archive signature and stage0 fails. |
