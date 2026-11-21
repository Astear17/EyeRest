# EyeRest website

This directory is the static GitHub Pages site for EyeRest. It has no build step and makes no runtime requests for fonts, analytics, or application data.

The configured Pages URL is `https://astear17.sino.tw/EyeRest/`; the project base path is `/EyeRest/`. All in-site links are relative so the same files work on the custom Pages path and in a local static server.

Run the dependency-free checks from the repository root:

```bash
node scripts/verify-website.mjs
```

Serve `website/` as the document root for browser review. Do not publish from a local machine; `.github/workflows/pages.yml` deploys the directory after verification when changes reach `main`.

The bundled DM Sans and Instrument Serif files come from Google Fonts under the SIL Open Font License. Copies are in `assets/licenses/`.
