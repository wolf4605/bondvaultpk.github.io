import 'package:flutter/material.dart';

class DrawSchedulesTab extends StatelessWidget {
  const DrawSchedulesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(
          'Upcoming Draw Schedules',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.event,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Rs. 1,500 Prize Bond Draw'),
            subtitle: const Text('Date: 15-Nov-2026 | City: Lahore'),
          ),
        ),
        Card(
          child: ListTile(
            leading: Icon(
              Icons.event,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Rs. 750 Prize Bond Draw'),
            subtitle: const Text('Date: 15-Dec-2026 | City: Karachi'),
          ),
        ),
      ],
    );
  }
}
