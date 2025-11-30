// lib/controller/trip_essentials_controller.dart
// Controller for Trip Essentials tab - manages packing list and currency conversion

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utilities/country_data_helper.dart';
import '../utilities/currency_converter.dart';

class TripEssentialsController {
  /// Get country essentials based on destination
  CountryEssentials getCountryEssentials(String country) {
    return CountryDataHelper.getCountryEssentials(country);
  }

  /// Convert currency
  Future<CurrencyResult> convertCurrency({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == 'MYR') {
      return CurrencyConverter.convertFromMYR(amount, toCurrency);
    } else if (toCurrency == 'MYR') {
      return CurrencyConverter.convertToMYR(amount, fromCurrency);
    } else {
      // Convert through MYR
      final toMYR = await CurrencyConverter.convertToMYR(amount, fromCurrency);
      return CurrencyConverter.convertFromMYR(toMYR.convertedAmount, toCurrency);
    }
  }

  /// Get packing list for a trip (saved locally)
  Future<List<PackingItem>> getPackingList(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'packing_list_$tripId';
      final saved = prefs.getString(key);

      if (saved != null) {
        final List<dynamic> items = json.decode(saved);
        return items.map((item) => PackingItem.fromJson(item)).toList();
      }
    } catch (e) {
      // Return default list
    }

    // Return default packing list
    return _getDefaultPackingList();
  }

  /// Save packing list
  Future<void> savePackingList(String tripId, List<PackingItem> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'packing_list_$tripId';
      final data = items.map((item) => item.toJson()).toList();
      await prefs.setString(key, json.encode(data));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Toggle packing item checked status
  Future<List<PackingItem>> togglePackingItem(
      String tripId,
      List<PackingItem> items,
      int index,
      ) async {
    if (index >= 0 && index < items.length) {
      items[index] = items[index].copyWith(isChecked: !items[index].isChecked);
      await savePackingList(tripId, items);
    }
    return items;
  }

  /// Add custom packing item
  Future<List<PackingItem>> addPackingItem(
      String tripId,
      List<PackingItem> items,
      String name,
      String category,
      ) async {
    items.add(PackingItem(
      name: name,
      category: category,
      isChecked: false,
      isCustom: true,
    ));
    await savePackingList(tripId, items);
    return items;
  }

  /// Remove packing item
  Future<List<PackingItem>> removePackingItem(
      String tripId,
      List<PackingItem> items,
      int index,
      ) async {
    if (index >= 0 && index < items.length) {
      items.removeAt(index);
      await savePackingList(tripId, items);
    }
    return items;
  }

  /// Reset packing list to default
  Future<List<PackingItem>> resetPackingList(String tripId) async {
    final items = _getDefaultPackingList();
    await savePackingList(tripId, items);
    return items;
  }

  /// Get packing progress
  double getPackingProgress(List<PackingItem> items) {
    if (items.isEmpty) return 0.0;
    final checked = items.where((item) => item.isChecked).length;
    return checked / items.length;
  }

  /// Default packing list
  List<PackingItem> _getDefaultPackingList() {
    return [
      // Documents
      PackingItem(name: 'Passport', category: 'Documents', isChecked: false),
      PackingItem(name: 'Visa (if required)', category: 'Documents', isChecked: false),
      PackingItem(name: 'Flight tickets', category: 'Documents', isChecked: false),
      PackingItem(name: 'Hotel confirmation', category: 'Documents', isChecked: false),
      PackingItem(name: 'Travel insurance', category: 'Documents', isChecked: false),
      PackingItem(name: 'ID card', category: 'Documents', isChecked: false),
      PackingItem(name: 'Credit/debit cards', category: 'Documents', isChecked: false),
      PackingItem(name: 'Cash (local currency)', category: 'Documents', isChecked: false),

      // Electronics
      PackingItem(name: 'Phone & charger', category: 'Electronics', isChecked: false),
      PackingItem(name: 'Power bank', category: 'Electronics', isChecked: false),
      PackingItem(name: 'Universal adapter', category: 'Electronics', isChecked: false),
      PackingItem(name: 'Camera', category: 'Electronics', isChecked: false),
      PackingItem(name: 'Earphones/headphones', category: 'Electronics', isChecked: false),

      // Toiletries
      PackingItem(name: 'Toothbrush & toothpaste', category: 'Toiletries', isChecked: false),
      PackingItem(name: 'Shampoo & soap', category: 'Toiletries', isChecked: false),
      PackingItem(name: 'Deodorant', category: 'Toiletries', isChecked: false),
      PackingItem(name: 'Sunscreen', category: 'Toiletries', isChecked: false),
      PackingItem(name: 'Medications', category: 'Toiletries', isChecked: false),
      PackingItem(name: 'First aid kit', category: 'Toiletries', isChecked: false),

      // Clothing
      PackingItem(name: 'Underwear', category: 'Clothing', isChecked: false),
      PackingItem(name: 'Socks', category: 'Clothing', isChecked: false),
      PackingItem(name: 'T-shirts', category: 'Clothing', isChecked: false),
      PackingItem(name: 'Pants/shorts', category: 'Clothing', isChecked: false),
      PackingItem(name: 'Sleepwear', category: 'Clothing', isChecked: false),
      PackingItem(name: 'Comfortable shoes', category: 'Clothing', isChecked: false),
      PackingItem(name: 'Rain jacket/umbrella', category: 'Clothing', isChecked: false),

      // Miscellaneous
      PackingItem(name: 'Sunglasses', category: 'Miscellaneous', isChecked: false),
      PackingItem(name: 'Day bag/backpack', category: 'Miscellaneous', isChecked: false),
      PackingItem(name: 'Water bottle', category: 'Miscellaneous', isChecked: false),
      PackingItem(name: 'Snacks', category: 'Miscellaneous', isChecked: false),
    ];
  }
}

// ============================================
// DATA CLASS
// ============================================

class PackingItem {
  final String name;
  final String category;
  final bool isChecked;
  final bool isCustom;

  const PackingItem({
    required this.name,
    required this.category,
    required this.isChecked,
    this.isCustom = false,
  });

  PackingItem copyWith({
    String? name,
    String? category,
    bool? isChecked,
    bool? isCustom,
  }) {
    return PackingItem(
      name: name ?? this.name,
      category: category ?? this.category,
      isChecked: isChecked ?? this.isChecked,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'isChecked': isChecked,
      'isCustom': isCustom,
    };
  }

  factory PackingItem.fromJson(Map<String, dynamic> json) {
    return PackingItem(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Miscellaneous',
      isChecked: json['isChecked'] ?? false,
      isCustom: json['isCustom'] ?? false,
    );
  }
}