# EyeRest brand assets

`app-icon.svg` and the generated app-icon PNGs use the dotted-circle (`◌`) mark introduced by the EyeRest website in repository commit `5a6b161` and retained in `e2cf42d`. The first commit, `85dbbfa`, did not contain website artwork. The mark is rendered as eight evenly spaced dots so its identity does not depend on a platform font's glyph design.

Run `node scripts/generate-app-icon.mjs` from the repository root after changing the master artwork or palette. The generator is deterministic and dependency-free, uses 4×4 supersampling at each output pixel, and writes opaque 1024×1024 RGB PNGs.

The light-mode accent is `#3D6B00`. Its WCAG contrast is 6.36:1 on white and 5.86:1 on the app's `#F5F6F1` light background. Dark mode uses the original lime `#C9FF70`.
