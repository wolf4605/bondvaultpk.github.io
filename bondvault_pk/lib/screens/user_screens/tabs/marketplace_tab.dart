import 'package:flutter/material.dart';

class MarketplaceTab extends StatelessWidget {
  final bool isVerified;
  const MarketplaceTab({super.key, required this.isVerified});

  @override
  Widget build(BuildContext context) {
    if (!isVerified) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            'Feature Locked: Account is unverified.',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(
          'Prize Bond Marketplace',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.store, color: Colors.white),
            ),
            title: const Text('Rs. 750 Prize Bond (Series A)'),
            subtitle: const Text('Asking Price: Rs. 750 | Category: Sell'),
            trailing: Text(
              'Contact',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
