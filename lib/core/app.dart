import 'package:flutter/material.dart';
import '../ui/home_options_screen.dart';

class TempScanApp extends StatelessWidget {
  const TempScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TempScan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeOptionsScreen(),
    );
  }
}
