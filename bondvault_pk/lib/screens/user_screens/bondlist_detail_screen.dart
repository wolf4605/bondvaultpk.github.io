import 'dart:convert';

import 'package:flutter/material.dart';

import '../../utils/api_service.dart';

class BondlistDetailScreen extends StatefulWidget {
  final int denomination;
  final List<dynamic> initialBonds;
  final String accessToken;
  final VoidCallback onBondsUpdated;

  const BondlistDetailScreen({
    super.key,
    required this.denomination,
    required this.initialBonds,
    required this.accessToken,
    required this.onBondsUpdated,
  });

  @override
  State<BondlistDetailScreen> createState() => _BondlistDetailScreenState();
}

class _BondlistDetailScreenState extends State<BondlistDetailScreen> {
  late List<String> _bonds;
  bool _isLoadingWinnings = true;
  Map<String, List<Map<String, dynamic>>> _winningsMap = {};

  @override
  void initState() {
    super.initState();
    _bonds = widget.initialBonds.map((b) => b.toString()).toList();
    _fetchWinnings();
  }

  Future<void> _fetchWinnings() async {
    setState(() => _isLoadingWinnings = true);
    try {
      final data = await ApiService.fetchBondWinnings(widget.accessToken);
      if (data != null) {
        final results = data['results'] ?? [];
        final map = <String, List<Map<String, dynamic>>>{};
        for (final item in results) {
          if (item['denomination'] == widget.denomination) {
            final num = item['bond_number'].toString();
            map.putIfAbsent(num, () => []).add(item);
          }
        }
        setState(() {
          _winningsMap = map;
        });
      }
    } catch (_) {
      // Handle network error
    } finally {
      if (mounted) setState(() => _isLoadingWinnings = false);
    }
  }

  Future<void> _deleteBond(String bondNumber) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bond'),
        content: Text('Are you sure you want to delete bond $bondNumber?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final res = await ApiService.deleteBonds(
        accessToken: widget.accessToken,
        denomination: widget.denomination,
        bonds: [bondNumber],
      );

      if (res.statusCode == 200) {
        setState(() {
          _bonds.remove(bondNumber);
        });
        widget.onBondsUpdated();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bond $bondNumber deleted successfully.')),
        );
      } else {
        final data = jsonDecode(res.body);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['detail'] ?? 'Failed to delete bond.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Connection error: $e')));
    }
  }

  void _showWinningDetails(
    String bondNumber,
    List<Map<String, dynamic>> winnings,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Winning Bond: $bondNumber',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...winnings.map(
              (w) => Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prize: ${w['prize_name']} (Position ${w['prize_position']})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF012F21),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Amount: Rs. ${w['prize_amount']}'),
                      const SizedBox(height: 4),
                      Text('Draw Date: ${w['draw_date']}'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rs. ${widget.denomination} Bond List'),
        backgroundColor: const Color(0xFF012F21),
        foregroundColor: Colors.white,
      ),
      body: _isLoadingWinnings
          ? const Center(child: CircularProgressIndicator())
          : _bonds.isEmpty
          ? const Center(child: Text('No bonds in this list.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _bonds.length,
              itemBuilder: (context, index) {
                final bond = _bonds[index];
                final isWinner = _winningsMap.containsKey(bond);
                final winnings = _winningsMap[bond] ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWinner
                          ? Colors.green.shade700
                          : const Color(0xFF012F21),
                      child: Icon(
                        isWinner
                            ? Icons.emoji_events
                            : Icons.confirmation_number,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      bond,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isWinner
                            ? Colors.green.shade800
                            : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      isWinner ? '🎉 Winner! Tap for details' : 'Not drawn yet',
                      style: TextStyle(
                        color: isWinner ? Colors.green.shade700 : Colors.grey,
                        fontWeight: isWinner
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBond(bond),
                    ),
                    onTap: isWinner
                        ? () => _showWinningDetails(bond, winnings)
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
