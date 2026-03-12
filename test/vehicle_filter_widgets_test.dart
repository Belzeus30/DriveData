import 'package:drivedata/models/car.dart';
import 'package:drivedata/widgets/vehicle_filter_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final vehicles = [
    Car(
      id: '1',
      vehicleType: 'Auto',
      make: 'Skoda',
      model: 'Octavia',
      year: 2020,
      fuelType: 'Benzín',
      tankCapacity: 50,
      engineVolume: 1.5,
      enginePower: 110,
    ),
    Car(
      id: '2',
      vehicleType: 'Motorka / Skútr',
      make: 'Jawa',
      model: '50',
      year: 1980,
      fuelType: 'Benzín',
      tankCapacity: 8,
      engineVolume: 0.05,
      enginePower: 3,
    ),
  ];

  testWidgets('VehicleFilterMenuButton emits selected vehicle id', (
    WidgetTester tester,
  ) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              VehicleFilterMenuButton(
                vehicles: vehicles,
                selectedVehicleId: null,
                onSelected: (value) => selected = value,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Filtrovat podle vozidla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jawa 50 (1980)').last);
    await tester.pumpAndSettle();

    expect(selected, '2');
  });

  testWidgets('ActiveVehicleFilterBanner calls clear callback', (
    WidgetTester tester,
  ) async {
    var cleared = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActiveVehicleFilterBanner(
            vehicleName: 'Jawa 50 (1980)',
            onClear: () => cleared = true,
          ),
        ),
      ),
    );

    expect(find.text('Filtr: Jawa 50 (1980)'), findsOneWidget);

    await tester.tap(find.text('Zrušit filtr'));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets('VehicleDropdownField supports empty option and selection', (
    WidgetTester tester,
  ) async {
    String? selected = '1';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Form(
              child: VehicleDropdownField(
                vehicles: vehicles,
                value: selected,
                labelText: 'Pro vozidlo (volitelné)',
                emptyOptionText: 'Všechna vozidla',
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();

    expect(find.text('Všechna vozidla'), findsOneWidget);

    await tester.tap(find.text('Všechna vozidla').last);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}