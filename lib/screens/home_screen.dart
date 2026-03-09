import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/insurance_provider.dart';
import '../providers/service_provider.dart';
import '../providers/trailer_provider.dart';
import '../providers/trip_provider.dart';
import 'insurance/insurances_screen.dart';
import 'trailers/trailers_screen.dart';
import 'cars/cars_screen.dart';
import 'trips/trips_screen.dart';
import 'analytics/analytics_screen.dart';
import 'service/service_screen.dart';
import 'goals/goals_screen.dart';
import 'settings/settings_screen.dart';

/// Shared navigation data — used by both NavigationRail (wide) and NavigationBar (narrow).
const _navItems = [
  (icon: Icons.directions_car_outlined, active: Icons.directions_car, label: 'Jízdy'),
  (icon: Icons.garage_outlined, active: Icons.garage, label: 'Auta'),
  (icon: Icons.rv_hookup_outlined, active: Icons.rv_hookup, label: 'Vozíky'),
  (icon: Icons.build_circle_outlined, active: Icons.build_circle, label: 'Servis'),
  (icon: Icons.shield_outlined, active: Icons.shield, label: 'Pojistky'),
  (icon: Icons.flag_outlined, active: Icons.flag, label: 'Cíle'),
  (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Analýza'),
];

/// Root navigation shell of the app.
///
/// Wraps the 7 main sections (Trips, Cars, Trailers, Service, Insurance,
/// Goals, Analytics) in an [IndexedStack] so every screen stays alive and
/// preserves scroll/filter state while the user switches tabs.
///
/// Layout adapts to screen width:
/// - **≥ 600 px** – persistent [NavigationRail] on the left (tablets / foldables).
/// - **< 600 px**  – [NavigationBar] at the bottom (phones).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// State for [HomeScreen].
///
/// Holds [_currentIndex] (the active tab) and the fixed [_screens] list
/// whose order must match [_navItems].
class _HomeScreenState extends State<HomeScreen> {
  /// Index of the currently visible tab (0 = Trips … 6 = Analytics).
  int _currentIndex = 0;

  /// Ordered list of full-screen content widgets kept alive by [IndexedStack].
  final _screens = const [
    TripsScreen(),
    CarsScreen(),
    TrailersScreen(),
    ServiceScreen(),
    InsurancesScreen(),
    GoalsScreen(),
    AnalyticsScreen(),
  ];

  /// Triggers an initial data load from the database for all providers.
  ///
  /// Uses [WidgetsBinding.addPostFrameCallback] so the Provider tree is fully
  /// mounted before the first [loadCars] / [loadTrips] etc. calls are made.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CarProvider>().loadCars();
      context.read<TripProvider>().loadTrips();
      context.read<ServiceProvider>().loadRecords();
      context.read<GoalProvider>().loadGoals();
      context.read<InsuranceProvider>().loadPolicies();
      context.read<TrailerProvider>().loadTrailers();
    });
  }

  /// Builds the adaptive navigation shell.
  ///
  /// Switches between a [NavigationRail] (wide) and a [NavigationBar] (narrow)
  /// based on [LayoutBuilder] constraints. Both variants share the same
  /// [IndexedStack] of [_screens].
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        // --- WIDE: NavigationRail (foldables, tablets) ---
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (i) =>
                      setState(() => _currentIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: _navItems.map((d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.active),
                    label: Text(d.label),
                  )).toList(),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          tooltip: 'Nastavení',
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())),
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }

        // --- NARROW: bottom NavigationBar (phones) ---
        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: _navItems.map((d) => NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.active),
              label: d.label,
            )).toList(),
          ),
        );
      },
    );
  }
}
