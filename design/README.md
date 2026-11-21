# EyeRest brand assets

`source/eye-clock.png` is the owner's concept reference. Its varying alpha channel measures artwork bounds of x=94...1159 and y=282...964 on a 1254 square, with centre (627, 623), eye-corner strokes of 70 px, iris-ring strokes of 58 to 59 px, and hand width of about 60 px. The iris outer radius is about 255 px. Run `node scripts/analyze-eye-clock.mjs` to reproduce those measurements.

`app-icon.svg` rebuilds that concept as clean geometry for small sizes. The final 1024 artwork uses an 820 px outer eye width, a 61 px eye/ring/hand stroke, a 417 px outer iris diameter, and hands pointing to twelve and about four o'clock. The slightly stronger normalized stroke preserves the concept at 60 px, where the source's visual artifacts and thinner geometry would blur together.

Run `node scripts/generate-app-icon.mjs` from the repository root after changing the master artwork or palette. The generator is deterministic and dependency-free, uses 4×4 supersampling at each output pixel, writes opaque 1024×1024 RGB PNGs, and creates ignored local previews at 180, 120, 60 and 29 px under `.ai/previews/app-icon`.

The light-mode accent is `#3D6B00`. Its WCAG contrast is 6.36:1 on white and 5.86:1 on the app's `#F5F6F1` light background. Dark mode uses the original lime `#C9FF70`.
