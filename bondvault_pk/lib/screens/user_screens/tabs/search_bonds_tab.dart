import 'package:flutter/material.dart';

import '../bond_ocr_parser.dart';

class SearchBondsTab extends StatefulWidget {
  final bool isVerified;
  const SearchBondsTab({super.key, required this.isVerified});

  @override
  State<SearchBondsTab> createState() => _SearchBondsTabState();
}

class _SearchBondsTabState extends State<SearchBondsTab> {
  int _selectedDenomination = 750;
  final _bondNumberController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Prize Bond Draws',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _selectedDenomination,
            decoration: const InputDecoration(
              labelText: 'Select Denomination',
              border: OutlineInputBorder(),
            ),
            items: BondOcrParser.denominations
                .map((d) => DropdownMenuItem(value: d, child: Text('Rs. $d')))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedDenomination = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bondNumberController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter Bond Number (e.g., 123456)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final number = _bondNumberController.text.trim();
                if (number.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a bond number.'),
                    ),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Searching Rs. $_selectedDenomination for $number...',
                    ),
                  ),
                );
              },
              child: const Text('Search Draw Results'),
            ),
          ),
        ],
      ),
    );
  }
}
