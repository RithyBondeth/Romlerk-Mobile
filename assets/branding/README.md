# Romlerk mascot branding

The mobile mascot source is `romlerk-doodle-logo-blue-source.png`: the original mascot with its orange accents recolored cobalt blue. The original source is preserved as `romlerk-doodle-logo-source.png`. `romlerk-logo.png` is the UI export used by onboarding and Settings; `romlerk-app-icon.png` is an opaque 1024px blue-white-backed app icon master.

Platform exports include iOS and macOS app icon catalogs, iOS launch images, Android legacy and adaptive launcher icons, Android launch images, and Flutter web icons. Android adaptive foregrounds keep the artwork inside the central safe region. Android notifications use a separate monochrome bell resource because a notification small icon cannot use the full-color mascot.

Regenerate on macOS from the mobile repository root:

```sh
swift tool/export-branding.swift tool/branding-exports.json
```

The exporter resamples the existing artwork without redrawing it. Only the UI logo is bundled as a Flutter asset; source and platform masters are build-time inputs. Rebuild/reinstall the app to refresh launcher icons and native launch screens; hot reload updates Flutter UI only.

The blue source was created with the built-in image-generation edit tool.
Edit prompt: preserve the original mascot, pose, bell, outlines, shading, and
transparent background; change only orange accents to cobalt blue (#285CC4).
The website keeps its own branding assets.
