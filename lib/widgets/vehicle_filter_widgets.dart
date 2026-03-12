import 'package:flutter/material.dart';

import '../models/car.dart';

const _allVehiclesMenuValue = '__all__';

class VehicleFilterMenuButton extends StatelessWidget {
  final List<Car> vehicles;
  final String? selectedVehicleId;
  final ValueChanged<String?> onSelected;

  const VehicleFilterMenuButton({
    super.key,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isFiltered = selectedVehicleId != null;
    return PopupMenuButton<String>(
      icon: Icon(
        isFiltered ? Icons.filter_alt : Icons.filter_list,
        color: isFiltered ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: isFiltered
          ? 'Filtr aktivní — klikni pro změnu'
          : 'Filtrovat podle vozidla',
      onSelected: (value) => onSelected(
        value == _allVehiclesMenuValue ? null : value,
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _allVehiclesMenuValue,
          child: Text('Všechna vozidla'),
        ),
        ...vehicles.map(
          (vehicle) => PopupMenuItem(
            value: vehicle.id,
            child: Text(vehicle.fullName),
          ),
        ),
      ],
    );
  }
}

class ActiveVehicleFilterBanner extends StatelessWidget {
  final String vehicleName;
  final VoidCallback onClear;

  const ActiveVehicleFilterBanner({
    super.key,
    required this.vehicleName,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 16, color: cs.onPrimaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Filtr: $vehicleName',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: cs.onPrimaryContainer,
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Zrušit filtr'),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleDropdownField extends StatelessWidget {
  final List<Car> vehicles;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final String? hintText;
  final String? emptyOptionText;
  final Widget? prefixIcon;
  final FormFieldValidator<String?>? validator;

  const VehicleDropdownField({
    super.key,
    required this.vehicles,
    required this.value,
    required this.onChanged,
    this.labelText = 'Vozidlo',
    this.hintText,
    this.emptyOptionText,
    this.prefixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
      ),
      items: [
        if (emptyOptionText != null)
          DropdownMenuItem<String?>(
            value: null,
            child: Text(emptyOptionText!),
          ),
        ...vehicles.map(
          (vehicle) => DropdownMenuItem<String?>(
            value: vehicle.id,
            child: Text(vehicle.fullName),
          ),
        ),
      ],
      onChanged: onChanged,
      validator: validator,
    );
  }
}