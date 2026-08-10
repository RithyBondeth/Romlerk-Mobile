import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'main/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // No async setup here on purpose: the database opens lazily and notification
  // permissions are requested at the moment of value, so first paint is not
  // waiting on either (NFR-02).
  runApp(const ProviderScope(child: App()));
}
