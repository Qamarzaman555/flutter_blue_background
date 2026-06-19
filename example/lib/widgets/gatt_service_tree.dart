import 'package:flutter/material.dart';
import 'package:flutter_blue_background/flutter_blue_background.dart';

/// Colored chips for GATT characteristic property flags.
class CharacteristicPropertyChips extends StatelessWidget {
  const CharacteristicPropertyChips({
    super.key,
    required this.properties,
  });

  final List<String> properties;

  static const _colors = {
    'read': Colors.blue,
    'write': Colors.deepPurple,
    'writeWithoutResponse': Colors.purple,
    'notify': Colors.teal,
    'indicate': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Text(
        'no properties',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: properties.map((prop) {
        final color = _colors[prop] ?? Theme.of(context).colorScheme.outline;
        return Chip(
          visualDensity: VisualDensity.compact,
          label: Text(prop),
          labelStyle: TextStyle(color: color, fontSize: 11),
          side: BorderSide(color: color),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }
}

/// Expandable tree of [BleGattService] and their characteristics.
class GattServiceTree extends StatelessWidget {
  const GattServiceTree({
    super.key,
    required this.services,
    this.isLoading = false,
  });

  final List<BleGattService> services;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No services discovered yet.\n'
          'Connect to the device, then tap Discover services.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(
              'Service',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            subtitle: SelectableText(
              service.uuid,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            children: service.characteristics.map((char) {
              return ListTile(
                dense: true,
                leading: const Icon(Icons.settings_ethernet, size: 20),
                title: Text(
                  'Characteristic',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(char.uuid),
                    const SizedBox(height: 6),
                    CharacteristicPropertyChips(properties: char.properties),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
