import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:romlerk_mobile/core/design/app_theme.dart';
import 'package:romlerk_mobile/core/widgets/illustration.dart';

void main() {
  /// Rebuilding an [Illustration] must resolve to the same picture.
  ///
  /// `SvgPicture` reloads whenever its loader compares unequal to the previous
  /// one, and `SvgAssetLoader.==` includes the colour mapper. A mapper without
  /// value equality therefore made every rebuild look like a brand new image:
  /// cache miss, asynchronous re-parse, and the drawing rendering as nothing
  /// until it finished — visible as the illustration vanishing and snapping
  /// back, most obviously when switching tabs.
  ///
  /// Asserting on the loader rather than on pixels is deliberate: it pins the
  /// actual cause, and it cannot flake the way sampling frames for a flash can.
  testWidgets('survives a rebuild without invalidating its cache key', (
    tester,
  ) async {
    late StateSetter rebuild;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              // Deliberately not const. EmptyState builds its illustration
              // from a runtime name, so the real app constructs a fresh
              // instance on every rebuild and re-runs `build` — which is
              // exactly the path that used to mint a new colour mapper. A
              // const widget here would be short-circuited by the framework
              // and the test would pass without proving anything.
              // ignore: prefer_const_constructors
              return Illustration(name: 'chilling');
            },
          ),
        ),
      ),
    );

    BytesLoader loaderNow() =>
        tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader;

    final before = loaderNow();

    rebuild(() {});
    await tester.pump();

    expect(
      loaderNow(),
      equals(before),
      reason:
          'The loader changed across a rebuild, so flutter_svg will drop the '
          'cached picture and re-parse the asset — the illustration will blink.',
    );
  });

  testWidgets('two illustrations of the same drawing share one cache key', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Column(
            children: <Widget>[
              Illustration(name: 'chilling'),
              Illustration(name: 'chilling'),
            ],
          ),
        ),
      ),
    );

    final loaders = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => picture.bytesLoader)
        .toList();

    expect(loaders, hasLength(2));
    expect(loaders.first, equals(loaders.last));
  });
}
