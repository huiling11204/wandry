import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utilities/currency_helper.dart';

class RestaurantTab extends StatefulWidget {
  final String tripId;

  const RestaurantTab({super.key, required this.tripId});

  @override
  State<RestaurantTab> createState() => _RestaurantTabState();
}

class _RestaurantTabState extends State<RestaurantTab> with SingleTickerProviderStateMixin {
  late TabController _restaurantTabController;

  @override
  void initState() {
    super.initState();
    _restaurantTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _restaurantTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _restaurantTabController,
            labelColor: Colors.orange[700],
            unselectedLabelColor: Colors.grey[600],
            indicatorColor: Colors.orange[700],
            indicatorWeight: 3,
            tabs: const [
              Tab(icon: Icon(Icons.free_breakfast, size: 20), text: 'Breakfast'),
              Tab(icon: Icon(Icons.lunch_dining, size: 20), text: 'Lunch'),
              Tab(icon: Icon(Icons.dinner_dining, size: 20), text: 'Dinner'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _restaurantTabController,
            children: [
              _buildMealTypeTab('breakfast'),
              _buildMealTypeTab('lunch'),
              _buildMealTypeTab('dinner'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeTab(String mealType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('itineraryItem')
          .where('tripID', isEqualTo: widget.tripId)
          .where('category', isEqualTo: mealType)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No ${mealType} options available', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs;
        items.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          return (aData['dayNumber'] ?? 0).compareTo(bData['dayNumber'] ?? 0);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final data = items[index].data() as Map<String, dynamic>;
            final day = data['dayNumber'] ?? 0;
            final restaurants = data['restaurantOptions'] as List? ?? [];
            final travelTimeInfo = data['avgTravelTime'] ?? 'N/A';

            // DYNAMIC PRICE LOGIC
            String averageCostDisplay = data['currencyDisplay'] ?? '';
            if (averageCostDisplay.isEmpty && restaurants.isNotEmpty) {
              averageCostDisplay = _calculateDynamicPriceRange(restaurants);
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                onTap: () => _showRestaurantSelection(context, data),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.orange[50]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.orange[400]!, Colors.orange[600]!]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 8)],
                            ),
                            child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2196F3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('DAY $day', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(child: Text(mealType.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text('${data['startTime']} - ${data['endTime']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.green[300]!),
                                ),
                                child: Text('${restaurants.length} options', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                              if (travelTimeInfo != 'N/A') ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.directions_walk, size: 12, color: Colors.blue[600]),
                                    const SizedBox(width: 4),
                                    Text('Avg $travelTimeInfo', style: TextStyle(fontSize: 11, color: Colors.blue[700])),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.attach_money, size: 18, color: Colors.green[700]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                averageCostDisplay.isEmpty ? 'View options for prices' : averageCostDisplay,
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green[900]),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange[700]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Calculates a flexible price range based on available restaurant options.
  String _calculateDynamicPriceRange(List options) {
    if (options.isEmpty) return '';
    List<double> prices = [];

    for (var opt in options) {
      final optMap = opt as Map<String, dynamic>;
      double? price;

      // 1. Try explicit cost field
      if (optMap['estimated_cost_myr'] != null) {
        price = double.tryParse(optMap['estimated_cost_myr'].toString());
      }
      // 2. Try parsing cost string (e.g., "RM 25.00")
      if (price == null && optMap['cost_display'] != null) {
        final str = optMap['cost_display'].toString();
        final regex = RegExp(r'(\d+([.,]\d+)?)');
        final match = regex.firstMatch(str);
        if (match != null) price = double.tryParse(match.group(1)!.replaceAll(',', ''));
      }
      // 3. Heuristics based on price level
      if (price == null && optMap['price_level'] != null) {
        final level = optMap['price_level'].toString().toLowerCase();
        if (level == 'cheap' || level == '1') price = 15.0;
        else if (level == 'moderate' || level == '2') price = 35.0;
        else if (level == 'expensive' || level == '3') price = 80.0;
      }

      if (price != null && price > 0) prices.add(price);
    }

    if (prices.isEmpty) return "Price based on menu";

    prices.sort();
    final min = prices.first.round();
    final max = prices.last.round();

    // If range is very small, show a single price average
    if ((max - min).abs() < 10) {
      final avg = (prices.reduce((a, b) => a + b) / prices.length).round();
      return "Est. RM $avg";
    }

    return "Est. RM $min - RM $max";
  }

  void _showRestaurantSelection(BuildContext context, Map<String, dynamic> item) {
    final restaurants = item['restaurantOptions'] as List? ?? [];
    if (restaurants.isEmpty) return;
    final mealType = item['category']?.toString().toUpperCase() ?? 'MEAL';
    final dayNumber = item['dayNumber'] ?? 0;

    final sortedRestaurants = List<Map<String, dynamic>>.from(restaurants.map((r) => Map<String, dynamic>.from(r as Map)));
    sortedRestaurants.sort((a, b) => ((a['distance_km'] ?? 99.0) as num).compareTo((b['distance_km'] ?? 99.0) as num));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.orange[400]!, Colors.orange[600]!]), borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text('DAY $dayNumber', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text(mealType, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))
                            ]),
                            Text('${sortedRestaurants.length} options available', style: TextStyle(color: Colors.white.withOpacity(0.9))),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedRestaurants.length,
                    itemBuilder: (context, index) => _buildRestaurantCard(context, sortedRestaurants[index], index + 1),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, Map<String, dynamic> restaurant, int number) {
    final isHalal = restaurant['is_halal'] ?? false;
    final restaurantName = restaurant['name'] ?? 'Restaurant';
    final coordinates = restaurant['coordinates'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(backgroundColor: Colors.orange[100], child: Text('#$number', style: TextStyle(color: Colors.orange[800]))),
            title: Text(restaurantName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(restaurant['cuisine'] ?? 'Local Cuisine'),
              Row(children: [
                Icon(Icons.star, size: 14, color: Colors.amber[700]),
                Text(' ${restaurant['rating'] ?? 4.0}'),
                const SizedBox(width: 10),
                if (isHalal) const Text('HALAL', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
              Text(restaurant['cost_display'] ?? 'Price varies', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500)),
            ]),
            trailing: IconButton(
              icon: const Icon(Icons.map, color: Colors.blue),
              onPressed: () async {
                if (coordinates != null) {
                  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${coordinates['lat']},${coordinates['lng']}');
                  if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}