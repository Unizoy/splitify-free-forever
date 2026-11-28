import 'package:flutter/widgets.dart';
import 'package:splitify/app/bootstrap.dart';
import 'package:splitify/app/startup_trace.dart';

Future<void> main() async {
  StartupTrace.start();
  final app = await bootstrap();
  StartupTrace.runApp();
  runApp(app);
}
