import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/car_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/service_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/insurance_provider.dart';
import 'providers/trailer_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // SQLite FFI pro Windows a Linux desktop
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  // Inicializuj notifikace (Android only — ostatní platformy ignorují)
  await NotificationService.instance.init();
  await NotificationService.instance.requestPermissions();
  final themeProvider = ThemeProvider();
  await themeProvider.load();
  runApp(DriveDataApp(themeProvider: themeProvider));
}

class DriveDataApp extends StatelessWidget {
  final ThemeProvider themeProvider;
  const DriveDataApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => CarProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => ServiceProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => InsuranceProvider()),
        ChangeNotifierProvider(create: (_) => TrailerProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, theme, _) => MaterialApp(
          title: 'DriveData',
          debugShowCheckedModeBanner: false,
          theme: theme.buildTheme(Brightness.light),
          darkTheme: theme.buildTheme(Brightness.dark),
          themeMode: theme.themeMode,
          home: const HomeScreen(),
        ),
      ),
    );
  }
}
