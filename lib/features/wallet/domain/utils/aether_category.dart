import 'package:flutter/material.dart';
import '../../../../core/themes/aether_colors.dart';

class AetherCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final List<String> subcategories;

  const AetherCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.subcategories,
  });

  // The Relational Category Dictionary
  static const List<AetherCategory> defaultCategories = [
    AetherCategory(id: 'c1', name: 'Food', icon: Icons.fastfood_rounded, color: Colors.orangeAccent, subcategories: ['Zingers & Fast Food', 'Biryani', 'Chai & Snacks', 'Delivery', 'Groceries']),
    AetherCategory(id: 'c2', name: 'Transport', icon: Icons.local_gas_station_rounded, color: Colors.blueAccent, subcategories: ['Fuel', 'Uber/InDrive', 'Bus/Train', 'Maintenance', 'Parking']),
    AetherCategory(id: 'c3', name: 'Business & Tech', icon: Icons.memory_rounded, color: Colors.cyanAccent, subcategories: ['Meta Ads', 'Aura-X Inventory', 'Server/Hosting', 'Software Subs', 'Hardware']),
    AetherCategory(id: 'c4', name: 'Bills', icon: Icons.receipt_long_rounded, color: Colors.redAccent, subcategories: ['Electricity', 'Internet/PTCL', 'Mobile Recharge', 'Water', 'Gas']),
    AetherCategory(id: 'c5', name: 'Income', icon: Icons.account_balance_wallet_rounded, color: AetherColors.walletNeonMint, subcategories: ['Freelance Projects', 'Aura-X Sales', 'Salary', 'Investments']),
    AetherCategory(id: 'c6', name: 'Education', icon: Icons.school_rounded, color: Colors.purpleAccent, subcategories: ['VU Tuition', 'Courses', 'Books/Supplies', 'Hostel']),
    AetherCategory(id: 'c7', name: 'Entertainment', icon: Icons.sports_esports_rounded, color: Colors.pinkAccent, subcategories: ['PUBG UC', 'Match Tickets', 'Netflix/Spotify', 'Outings']),
  ];

  static AetherCategory fromName(String name) {
    return defaultCategories.firstWhere(
      (c) => c.name == name,
      orElse: () => defaultCategories.first, // Fallback to Food
    );
  }
}