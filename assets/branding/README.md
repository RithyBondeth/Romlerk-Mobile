# Romlerk mascot branding

The approved mascot source is `romlerk-doodle-logo-source.png`, identical to version 2 used by the website. `romlerk-logo.png` is the UI export used by onboarding and Settings; `romlerk-app-icon.png` is an opaque 1024px paper-backed app icon master.

Platform exports include iOS and macOS app icon catalogs, iOS launch images, Android legacy and adaptive launcher icons, Android launch images, and Flutter web icons. Android adaptive foregrounds keep the artwork inside the central safe region. Android notifications use a separate monochrome bell resource because a notification small icon cannot use the full-color mascot.

Regenerate on macOS from the mobile repository root:

```sh
swift tool/export-branding.swift tool/branding-exports.json
```

The exporter resamples the existing artwork without redrawing it. Only the UI logo is bundled as a Flutter asset; source and platform masters are build-time inputs. Rebuild/reinstall the app to refresh launcher icons and native launch screens; hot reload updates Flutter UI only.
