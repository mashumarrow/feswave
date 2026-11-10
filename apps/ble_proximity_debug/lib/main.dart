import 'package:flutter/material.dart';
import 'debug_screen.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    home: const DebugScreen(),
  ),
);
