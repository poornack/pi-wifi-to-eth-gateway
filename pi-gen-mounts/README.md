# pi-gen-mounts

Files that build.sh bind-mounts into the pi-gen build container, so that the
`pi-gen/` submodule itself is never modified by a build.

| file | mounted at | why |
|---|---|---|
| `stage2/SKIP_IMAGES` | `/pi-gen/stage2/SKIP_IMAGES` | pi-gen exports a `.img` from every stage that has an `EXPORT_IMAGE` file. stage2 has one (that is the stock "Lite" image). An empty `SKIP_IMAGES` file next to it tells pi-gen not to export it, so the build produces only our gateway image and saves ~10 minutes and 2.6 GB. |
