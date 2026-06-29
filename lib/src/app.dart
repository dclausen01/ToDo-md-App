import 'package:flutter/material.dart';

import 'ui/root_screen.dart';

class TodoMdApp extends StatelessWidget {
  const TodoMdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ToDo.md',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7E57C2)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7E57C2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const RootScreen(),
    );
  }
}
