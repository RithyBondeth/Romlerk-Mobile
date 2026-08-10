import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:romlerk_mobile/main/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized;
  runApp(ProviderScope(child: App()));
}
