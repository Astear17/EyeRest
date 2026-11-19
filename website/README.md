# EyeRest

The public landing site for EyeRest, an in-development offline wellness reminder app for iOS.

## Run locally

This is a dependency-free static site. From this directory, serve it with any static server, for example:

```powershell
npx serve .
```

Then open the displayed local URL. No build step is required.

## Deploy to GitHub Pages

The included workflow publishes the root of `main` to GitHub Pages. In the repository Settings, choose **Pages → Build and deployment → Source: GitHub Actions** once. Pushes to `main` will then redeploy automatically.

All internal assets use relative paths, so the site works at the repository Pages base path (`/eyerest/`) without a framework-specific setting. It uses system font stacks rather than externally hosted fonts.

## Planned iOS app

See the repository [iOS development notes](../docs/IOS_DEVELOPMENT.md) for the future macOS/Xcode development plan, app architecture, local notification scheduling, offline model, build requirements, and unsigned IPA caveats.

## Project status

The landing page is complete. The native iOS app has not yet been built or validated on macOS; its planned capabilities are deliberately labeled as planned.
