# Illustrations

Source: Open Doodles by Pablo Stanley — https://www.opendoodles.com/
License: CC0 / public domain. Free for commercial use, no attribution required.
This note is provenance for us, not a licence obligation.

Files are unmodified downloads. Each uses exactly two colours:

  #000000  line art   -> mapped to the theme's ink
  #FF5678  accent     -> mapped to the theme's ember

The mapping happens at runtime in `lib/core/widgets/illustration.dart` via
flutter_svg's ColorMapper, so one asset serves light and dark and the drawings
stay inside the app's colour discipline. Do not hand-edit the colours here —
change the mapper instead.
