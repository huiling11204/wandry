import 'package:flutter/material.dart';

class ResourcesTab extends StatelessWidget {
  const ResourcesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Travel Resources',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Helpful links and tools for your trip',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        const SizedBox(height: 24),
        _buildResourceCard(
          context,
          icon: Icons.flight,
          title: 'Flights',
          subtitle: 'Search for flights to your destination',
          color: Colors.blue,
        ),
        const SizedBox(height: 12),
        _buildResourceCard(
          context,
          icon: Icons.hotel,
          title: 'Accommodation',
          subtitle: 'Find hotels and places to stay',
          color: Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildResourceCard(
          context,
          icon: Icons.directions_car,
          title: 'Transportation',
          subtitle: 'Car rentals and local transport options',
          color: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildResourceCard(
          context,
          icon: Icons.local_activity,
          title: 'Tours & Activities',
          subtitle: 'Book tours and experiences',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildResourceCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required Color color,
      }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title integration coming soon')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}