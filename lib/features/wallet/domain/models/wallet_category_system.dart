import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

part 'wallet_category_system.g.dart';

// ==========================================
// 1. THE DYNAMIC DATABASE MODEL
// ==========================================
@HiveType(typeId: 15)
class AetherWalletCategory extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) String name;
  @HiveField(2) String iconEmoji;
  @HiveField(3) String colorHex;
  @HiveField(4) List<String> subcategories;
  @HiveField(5) bool isHidden;
  @HiveField(6) String nature;

  AetherWalletCategory({
    String? id,
    required this.name,
    required this.iconEmoji,
    required this.colorHex,
    required this.subcategories,
    this.isHidden = false,
    required this.nature,
  }) : id = id ?? const Uuid().v4();

  Color get color => Color(int.parse(colorHex, radix: 16));

  static List<AetherWalletCategory> get defaultCategories => [
    // --- EXPENSES ---
    AetherWalletCategory(name: 'Food & Drinks', iconEmoji: '🍔', colorHex: 'FFFB7185', nature: 'Want', subcategories: ['☕ Bar, cafe', '🛒 Groceries', '🍔 Restaurant, fast-food']),
    AetherWalletCategory(name: 'Shopping', iconEmoji: '🛍️', colorHex: 'FFA855F7', nature: 'Want', subcategories: ['👕 Clothes & shoes', '💊 Drug-store, chemist', '📱 Electronics, accessories', '🪁 Free time', '🎁 Gifts, joy', '💄 Health and beauty', '🪴 Home, garden', '💎 Jewels, accessories', '🧸 Kids', '🐕 Pets, animals', '✂️ Stationery, tools']),
    AetherWalletCategory(name: 'Housing', iconEmoji: '🏠', colorHex: 'FF38BDF8', nature: 'Need', subcategories: ['⚡ Energy, utilities', '🔧 Maintenance, repairs', '🏦 Mortgage', '🛡️ Property insurance', '🔑 Rent', '🧹 Services']),
    AetherWalletCategory(name: 'Transportation', iconEmoji: '🚌', colorHex: 'FFFBBF60', nature: 'Need', subcategories: ['🧳 Business trips', '🚆 Long distance', '🚇 Public transport', '🚕 Taxi']),
    AetherWalletCategory(name: 'Vehicle', iconEmoji: '🚗', colorHex: 'FF6366F1', nature: 'Need', subcategories: ['⛽ Fuel', '📄 Leasing', '🅿️ Parking', '🚙 Rentals', '🛡️ Vehicle insurance', '🛠️ Vehicle maintenance']),
    AetherWalletCategory(name: 'Life & Entertainment', iconEmoji: '🎭', colorHex: 'FFEC4899', nature: 'Want', subcategories: ['🏋️ Active sport, fitness', '🚬 Alcohol, tobacco', '📚 Books, audio, subscriptions', '🎗️ Charity, gifts', '🎟️ Culture, sport events', '🎓 Education, development', '⚕️ Health care, doctor', '🎨 Hobbies', '✈️ Holiday, trips, hotels', '🎂 Life events', '🎰 Lottery, gambling', '🍿 TV, Streaming', '💆 Wellness, beauty']),
    AetherWalletCategory(name: 'Communication, PC', iconEmoji: '💻', colorHex: 'FF64748B', nature: 'Need', subcategories: ['🌐 Internet', '📱 Phone, cell phone', '📮 Postal services', '💾 Software, apps, games']),
    AetherWalletCategory(name: 'Financial expenses', iconEmoji: '💸', colorHex: 'FFEF4444', nature: 'Need', subcategories: ['👔 Advisory', '🏦 Charges, Fees', '👶 Child Support', '🛑 Fines', '🛡️ Insurances', '📊 Loan, interests', '📝 Taxes']),
    AetherWalletCategory(name: 'Investments', iconEmoji: '📈', colorHex: 'FF10B981', nature: 'Other', subcategories: ['🖼️ Collections', '📈 Financial investments', '🏢 Realty', '💰 Savings', '🚘 Vehicles, chattels']),
    AetherWalletCategory(name: 'Others', iconEmoji: '📦', colorHex: 'FF9CA3AF', nature: 'Other', subcategories: ['❓ Missing']),
    AetherWalletCategory(name: 'Other Funds (Old)', iconEmoji: '📥', colorHex: 'FF34D399', nature: 'Other', subcategories: ['🎟️ Checks, coupons', '👶 Child Support', '🤝 Dues & grants', '🎁 Gifts', '📈 Interests, dividends', '🤝 Lending, renting', '🎰 Lottery, gambling', '💸 Refunds', '🏠 Rental income', '🏷️ Sale', '💼 Wage, invoices']),

    // --- INCOMES ---
    AetherWalletCategory(name: 'Salary & Employment', iconEmoji: '💼', colorHex: 'FF10B981', nature: 'Income', subcategories: ['📅 Monthly Salary', '📆 Weekly Salary', '💴 Daily Wage', '⏳ Overtime', '🎉 Bonus', '📊 Commission', '➕ Allowance', '💵 Tips', '🚪 Severance/Gratuity', '🔙 Arrears/Back Pay', '⚙️ Salary Adjustment']),
    AetherWalletCategory(name: 'Business', iconEmoji: '🏢', colorHex: 'FF059669', nature: 'Income', subcategories: ['📈 Business Revenue', '🏪 Shop Sales', '🛠️ Service Income', '📦 Product Sales', '🏢 Agency Income', '🗣️ Consulting Income', '📝 Contract Income', '🤝 Business Commission', '💸 Profit Withdrawal', '👥 Partnership Income']),
    AetherWalletCategory(name: 'Freelancing', iconEmoji: '💻', colorHex: 'FF047857', nature: 'Income', subcategories: ['💻 Freelance Project', '⏱️ Hourly Work', '📌 Fixed Project', '🔄 Retainer', '🗣️ Consulting', '⌨️ Development', '🎨 Design', '✍️ Writing', '🎬 Video Editing', '📱 Digital Marketing', '🎧 Virtual Assistant', '🔢 Data Entry', '🌍 Translation', '📚 Tutoring', '➕ Other Freelance']),
    AetherWalletCategory(name: 'Online / E-commerce', iconEmoji: '🛒', colorHex: 'FF34D399', nature: 'Income', subcategories: ['🛒 Online Store Sales', '🏪 Marketplace Sales', '📦 Dropshipping', '🔗 Affiliate Income', '💻 Digital Products', '🖨️ Print-on-Demand', '🔁 Subscription Revenue', '🔄 Reselling']),
    AetherWalletCategory(name: 'Property & Rent', iconEmoji: '🏠', colorHex: 'FF6EE7B7', nature: 'Income', subcategories: ['🏠 House Rent', '🏢 Apartment Rent', '🚪 Room Rent', '🏪 Shop Rent', '🏢 Office Rent', '🏞️ Land Rent', '🅿️ Parking Rent', '📜 Property Lease', '🧳 Short-Term Rental']),
    AetherWalletCategory(name: 'Investments Return', iconEmoji: '📈', colorHex: 'FF38BDF8', nature: 'Income', subcategories: ['💸 Dividends', '📈 Stock Profit', '📊 Mutual Fund Return', '💰 Capital Gain', '📜 Bond Return', '🕌 Sukuk Return', '💵 Investment Interest', '🔄 Profit Distribution']),
    AetherWalletCategory(name: 'Savings & Returns', iconEmoji: '🏦', colorHex: 'FF60A5FA', nature: 'Income', subcategories: ['🏦 Bank Profit', '💰 Savings Return', '🔒 Fixed Deposit Return', '📜 Certificate Return', '💳 Cashback', '🎁 Loyalty Rewards', '🗣️ Referral Bonus']),
    AetherWalletCategory(name: 'Digital / Content', iconEmoji: '📱', colorHex: 'FF818CF8', nature: 'Income', subcategories: ['▶️ YouTube Revenue', '📱 TikTok Revenue', '📘 Facebook Revenue', '📸 Instagram Revenue', '✍️ Blogging', '🎙️ Podcast', '🤝 Sponsorship', '🏷️ Brand Deal', '📺 Ad Revenue', '✨ Creator Fund']),
    AetherWalletCategory(name: 'Education', iconEmoji: '🎓', colorHex: 'FFA78BFA', nature: 'Income', subcategories: ['🎓 Tuition', '👨‍🏫 Teaching', '💻 Online Course Sales', '🎯 Coaching', '🏋️ Training', '🛠️ Workshop', '📚 Tutoring', '🔬 Research Payment', '🏆 Scholarship']),
    AetherWalletCategory(name: 'Professional Services', iconEmoji: '🧑‍💼', colorHex: 'FFC084FC', nature: 'Income', subcategories: ['🗣️ Consulting', '⚖️ Legal Services', '📊 Accounting', '🎨 Design Services', '💻 IT Services', '🔧 Repair Services', '📸 Photography', '🎪 Event Services', '⚕️ Medical Fees']),
    AetherWalletCategory(name: 'Commission & Referral', iconEmoji: '🤝', colorHex: 'FF8B5CF6', nature: 'Income', subcategories: ['💰 Sales Commission', '🗣️ Referral Bonus', '🕵️ Agent Commission', '📈 Brokerage Commission', '🔗 Affiliate Commission', '👥 Recruitment Commission']),
    AetherWalletCategory(name: 'Gifts & Support', iconEmoji: '🎁', colorHex: 'FFF472B6', nature: 'Income', subcategories: ['💵 Cash Gift', '👨‍👩‍👧 Family Support', '🤝 Friend Support', '💍 Wedding Gift', '🎂 Birthday Gift', '🌙 Festival/Eid Gift', '🤲 Financial Assistance']),
    AetherWalletCategory(name: 'Refunds & Reimb.', iconEmoji: '💸', colorHex: 'FFFB7185', nature: 'Income', subcategories: ['🛍️ Purchase Refund', '✈️ Travel Reimbursement', '⚕️ Medical Reimbursement', '💼 Business Reimbursement', '📝 Tax Refund', '🛡️ Insurance Claim', '🔙 Overpayment Refund']),
    AetherWalletCategory(name: 'Govt / Institutional', iconEmoji: '🏛️', colorHex: 'FFFBBF60', nature: 'Income', subcategories: ['🏛️ Government Benefit', '👴 Pension', '📜 Grant', '📉 Subsidy', '💵 Stipend', '🎓 Scholarship', '📝 Tax Refund', '🤲 Relief Payment']),
    AetherWalletCategory(name: 'Family / Personal', iconEmoji: '👨‍👩‍👧', colorHex: 'FFF87171', nature: 'Income', subcategories: ['👨‍👩‍👧 Family Contribution', '❤️ Spouse Contribution', '👴 Parents Support', '👶 Child Support Received', '🏠 Shared Household']),
    AetherWalletCategory(name: 'Transfers & Internal', iconEmoji: '🔄', colorHex: 'FF9CA3AF', nature: 'Income', subcategories: ['📱 Wallet Transfer In', '🏦 Bank Transfer In', '💵 Cash Deposit', '🏦 Transfer From Savings', '🔄 Transfer From Another']),
    AetherWalletCategory(name: 'Asset Sales', iconEmoji: '📦', colorHex: 'FFA3E635', nature: 'Income', subcategories: ['🚗 Car Sale', '🏍️ Bike Sale', '💻 Electronics Sale', '🪑 Furniture Sale', '🏠 Property Sale', '🏞️ Land Sale', '📦 Other Asset Sale']),
    AetherWalletCategory(name: 'Miscellaneous', iconEmoji: '🧾', colorHex: 'FFD1D5DB', nature: 'Income', subcategories: ['🔍 Found Money', '🏆 Prize Money', '🥇 Contest Winning', '🎰 Lottery/Prize', '➕ Other Income']),
  ];
}

// ==========================================
// 2. THE RIVERPOD STATE MANAGER
// ==========================================
final walletCategoryProvider = AsyncNotifierProvider<WalletCategoryNotifier, List<AetherWalletCategory>>(() {
  return WalletCategoryNotifier();
});

class WalletCategoryNotifier extends AsyncNotifier<List<AetherWalletCategory>> {
  static const String boxName = 'aether_wallet_categories';

  @override
  Future<List<AetherWalletCategory>> build() async {
    if (!Hive.isAdapterRegistered(15)) Hive.registerAdapter(AetherWalletCategoryAdapter());
    final box = await Hive.openBox<AetherWalletCategory>(boxName);
    
    if (box.isEmpty) {
      for (var cat in AetherWalletCategory.defaultCategories) {
        await box.put(cat.id, cat);
      }
    }

    // 🌟 SMART SORTING LOGIC (Usage Count + Manual Order)
    final settingsBox = await Hive.openBox('aether_settings');
    List<String> manualOrder = List<String>.from(settingsBox.get('cat_order', defaultValue: []));
    Map<String, int> usageCount = Map<String, int>.from(settingsBox.get('cat_usage', defaultValue: {}));

    final allCats = box.values.toList();

    allCats.sort((a, b) {
      // 1. Manual Order Overrides Everything
      final indexA = manualOrder.indexOf(a.id);
      final indexB = manualOrder.indexOf(b.id);
      
      if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;

      // 2. If no manual order, sort by Most Used
      final countA = usageCount[a.id] ?? 0;
      final countB = usageCount[b.id] ?? 0;
      return countB.compareTo(countA); // Descending (Most used first)
    });

    return allCats;
  }

  Future<void> updateCategory(AetherWalletCategory category) async {
    await category.save();
    ref.invalidateSelf();
  }

  // 🌟 NAYA: Increment Usage Count
  Future<void> incrementUsage(String categoryId) async {
    final box = await Hive.openBox('aether_settings');
    Map<String, int> usage = Map<String, int>.from(box.get('cat_usage', defaultValue: {}));
    usage[categoryId] = (usage[categoryId] ?? 0) + 1;
    await box.put('cat_usage', usage);
    ref.invalidateSelf();
  }

  // 🌟 NAYA: Handle Manual Drag & Drop Reordering
  Future<void> reorderCategories(AetherWalletCategory dragged, AetherWalletCategory target) async {
    final box = await Hive.openBox('aether_settings');
    List<String> order = List<String>.from(box.get('cat_order', defaultValue: []));
    
    final stateList = state.value ?? [];
    if (order.isEmpty) {
      order = stateList.map((e) => e.id).toList();
    } else {
       for(var c in stateList) {
         if(!order.contains(c.id)) order.add(c.id);
       }
    }
    
    order.remove(dragged.id);
    final targetIndex = order.indexOf(target.id);
    if (targetIndex != -1) {
      order.insert(targetIndex, dragged.id);
    } else {
      order.add(dragged.id);
    }
    
    await box.put('cat_order', order);
    ref.invalidateSelf();
  }
}

// ==========================================
// 3. THE PREMIUM BOTTOM SHEET PICKER
// ==========================================
void showCategoryPickerBottomSheet(BuildContext context, WidgetRef ref, String transactionType, Function(AetherWalletCategory, String?) onSelect) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context, 
    backgroundColor: Colors.transparent, 
    isScrollControlled: true,
    builder: (ctx) => _CategoryPickerSheet(txType: transactionType, onSelect: onSelect),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final String txType;
  final Function(AetherWalletCategory, String?) onSelect;
  const _CategoryPickerSheet({required this.txType, required this.onSelect});
  
  @override 
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  AetherWalletCategory? _selectedMainCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🌟 HELPER: Build Grid Card Design
  Widget _buildGridCard(AetherWalletCategory cat, {bool isHovered = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isHovered ? 0.08 : 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: isHovered ? 0.15 : 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [cat.color.withValues(alpha: 0.3), cat.color.withValues(alpha: 0.05)])),
            child: Center(child: Text(cat.iconEmoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(height: 10),
          Text(cat.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(walletCategoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65, minChildSize: 0.5, maxChildSize: 0.9,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0714).withValues(alpha: 0.85),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Colors.white54)),
              error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
              data: (allCategories) {
                
                final visibleCategories = allCategories.where((c) {
                  if (c.isHidden) return false;
                  if (widget.txType == 'income' && c.nature != 'Income') return false;
                  if (widget.txType != 'income' && c.nature == 'Income') return false;

                  if (_searchQuery.isEmpty) return true;
                  final query = _searchQuery.toLowerCase();
                  if (c.name.toLowerCase().contains(query)) return true;
                  if (c.subcategories.any((sub) => sub.toLowerCase().contains(query))) return true;
                  return false;
                }).toList();

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_selectedMainCategory != null)
                            GestureDetector(
                              onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedMainCategory = null); },
                              child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20)),
                            )
                          else
                            const SizedBox(width: 36),
                          
                          Text(_selectedMainCategory != null ? _selectedMainCategory!.name : "Select Category", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          
                          GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryMasterListScreen()));
                            },
                            child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20)),
                          ),
                        ],
                      ),
                    ),

                    if (_selectedMainCategory == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: const InputDecoration(icon: Icon(Icons.search_rounded, color: Colors.white38, size: 20), hintText: "Search categories...", hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                        ),
                      ),

                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _selectedMainCategory == null
                            ? GridView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 0.85, crossAxisSpacing: 12, mainAxisSpacing: 12),
                                itemCount: visibleCategories.length,
                                itemBuilder: (ctx, i) {
                                  final cat = visibleCategories[i];
                                  
                                  // 🌟 NAYA: LONG PRESS DRAG & DROP FOR GRID 🌟
                                  return DragTarget<AetherWalletCategory>(
                                    onWillAcceptWithDetails: (data) => data.data.id != cat.id,
                                    onAcceptWithDetails: (details) {
                                      HapticFeedback.heavyImpact();
                                      ref.read(walletCategoryProvider.notifier).reorderCategories(details.data, cat);
                                    },
                                    builder: (context, candidateData, rejectedData) {
                                      final isHovered = candidateData.isNotEmpty;

                                      return LongPressDraggable<AetherWalletCategory>(
                                        data: cat,
                                        delay: const Duration(milliseconds: 250),
                                        onDragStarted: () => HapticFeedback.selectionClick(),
                                        feedback: Material(
                                          color: Colors.transparent,
                                          child: SizedBox(
                                            width: MediaQuery.of(context).size.width / 3.5, 
                                            height: MediaQuery.of(context).size.width / 3,
                                            child: Transform.scale(scale: 1.05, child: _buildGridCard(cat, isHovered: true))
                                          )
                                        ),
                                        childWhenDragging: Opacity(opacity: 0.3, child: _buildGridCard(cat)),
                                        child: GestureDetector(
                                          onTap: () { 
                                            HapticFeedback.selectionClick(); 
                                            if (cat.subcategories.isEmpty) {
                                              ref.read(walletCategoryProvider.notifier).incrementUsage(cat.id);
                                              widget.onSelect(cat, null);
                                              Navigator.pop(context);
                                            } else {
                                              setState(() => _selectedMainCategory = cat); 
                                            }
                                          },
                                          child: _buildGridCard(cat, isHovered: isHovered),
                                        ),
                                      );
                                    }
                                  );
                                },
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: _selectedMainCategory!.subcategories.length + 1, 
                                itemBuilder: (ctx, i) {
                                  if (i == 0) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: ListTile(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          ref.read(walletCategoryProvider.notifier).incrementUsage(_selectedMainCategory!.id);
                                          widget.onSelect(_selectedMainCategory!, null); 
                                          Navigator.pop(context);
                                        },
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        tileColor: Colors.white.withValues(alpha: 0.06), 
                                        leading: Container(
                                          padding: const EdgeInsets.all(8), 
                                          decoration: BoxDecoration(color: _selectedMainCategory!.color.withValues(alpha: 0.2), shape: BoxShape.circle), 
                                          child: Text(_selectedMainCategory!.iconEmoji, style: const TextStyle(fontSize: 18))
                                        ),
                                        title: const Text("General", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                        subtitle: const Text("Main category only", style: TextStyle(color: Colors.white38, fontSize: 11)),
                                        trailing: const Icon(Icons.check_circle_outline, color: Colors.white24, size: 20),
                                      ),
                                    ).animate().fadeIn(delay: 0.ms).slideX(begin: 0.05);
                                  }

                                  final String rawSub = _selectedMainCategory!.subcategories[i - 1];
                                  
                                  // 🌟 NAYA: EMOJI EXTRACTION LOGIC 🌟
                                  String subEmoji = '✨';
                                  String subText = rawSub;
                                  final int firstSpace = rawSub.indexOf(' ');
                                  
                                  if (firstSpace != -1) {
                                    final possibleEmoji = rawSub.substring(0, firstSpace);
                                    if (!RegExp(r'[a-zA-Z0-9]').hasMatch(possibleEmoji)) {
                                      subEmoji = possibleEmoji;
                                      subText = rawSub.substring(firstSpace + 1).trim();
                                    }
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ListTile(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        ref.read(walletCategoryProvider.notifier).incrementUsage(_selectedMainCategory!.id);
                                        widget.onSelect(_selectedMainCategory!, subText);
                                        Navigator.pop(context);
                                      },
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      tileColor: Colors.white.withValues(alpha: 0.03),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8), 
                                        decoration: BoxDecoration(color: _selectedMainCategory!.color.withValues(alpha: 0.1), shape: BoxShape.circle), 
                                        child: Text(subEmoji, style: const TextStyle(fontSize: 16)) // 🌟 REPLACED ARROW WITH EMOJI
                                      ),
                                      title: Text(subText, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      trailing: const Icon(Icons.check_circle_outline, color: Colors.white24, size: 20),
                                    ),
                                  ).animate().fadeIn(delay: Duration(milliseconds: 20 * i)).slideX(begin: 0.05);
                                },
                              ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. CATEGORY MASTER LIST SCREEN
// ==========================================
class CategoryMasterListScreen extends ConsumerWidget {
  const CategoryMasterListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(walletCategoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text("Manage Categories", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        centerTitle: true,
      ),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white54)),
        error: (e, _) => Center(child: Text("Error: $e", style: const TextStyle(color: Colors.red))),
        data: (cats) {
          return ListView.builder(
            padding: const EdgeInsets.all(20), physics: const BouncingScrollPhysics(), itemCount: cats.length,
            itemBuilder: (ctx, i) {
              final cat = cats[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditCategoryScreen(category: cat))),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  tileColor: Colors.white.withValues(alpha: 0.03),
                  leading: Container(width: 44, height: 44, decoration: BoxDecoration(shape: BoxShape.circle, color: cat.color.withValues(alpha: 0.2)), child: Center(child: Text(cat.iconEmoji, style: const TextStyle(fontSize: 20)))),
                  title: Text(cat.name, style: TextStyle(color: cat.isHidden ? Colors.white38 : Colors.white, fontWeight: FontWeight.bold, decoration: cat.isHidden ? TextDecoration.lineThrough : null)),
                  subtitle: Text("${cat.subcategories.length} subcategories • ${cat.nature}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  trailing: Icon(Icons.edit_rounded, color: Colors.white.withValues(alpha: 0.2), size: 18),
                ),
              );
            },
          );
        }
      ),
    );
  }
}

// ==========================================
// 5. EDIT CATEGORY SCREEN
// ==========================================
class EditCategoryScreen extends ConsumerStatefulWidget {
  final AetherWalletCategory category;
  const EditCategoryScreen({super.key, required this.category});
  @override ConsumerState<EditCategoryScreen> createState() => _EditCategoryScreenState();
}

class _EditCategoryScreenState extends ConsumerState<EditCategoryScreen> {
  late TextEditingController _nameController;
  late String _currentNature;
  late bool _isHidden;
  late String _currentIcon;
  late String _currentColorHex;

  final List<String> _emojiPalette = ['🍔','🛍️','🏠','🚌','🚗','🎭','💻','💸','📈','💰','📦','🏥','✈️','🎁','🛒','🎓','🏢','🤝','🏛️','🧾'];
  final List<String> _colorPalette = ['FFFB7185','FFA855F7','FF38BDF8','FFFBBF60','FF6366F1','FFEC4899','FF10B981','FF34D399','FF9CA3AF','FFEAB308','FF059669','FF818CF8','FFF472B6'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category.name);
    _currentNature = widget.category.nature;
    _isHidden = widget.category.isHidden;
    _currentIcon = widget.category.iconEmoji;
    _currentColorHex = widget.category.colorHex;
  }

  @override
  void dispose() { _nameController.dispose(); super.dispose(); }

  void _openCustomizationModal() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF1E1E1E), shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Visual Customization", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              const Text("Select Icon", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: _emojiPalette.map((e) => GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setModalState(() => _currentIcon = e); setState(() {}); },
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: _currentIcon == e ? Colors.white24 : Colors.white.withValues(alpha: 0.05), shape: BoxShape.circle), child: Center(child: Text(e, style: const TextStyle(fontSize: 20)))),
                )).toList(),
              ),
              const SizedBox(height: 32),
              const Text("Select Color Theme", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: _colorPalette.map((c) => GestureDetector(
                  onTap: () { HapticFeedback.selectionClick(); setModalState(() => _currentColorHex = c); setState(() {}); },
                  child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(int.parse(c, radix: 16)), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: _currentColorHex == c ? 3 : 0))),
                )).toList(),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _saveChanges() {
    HapticFeedback.heavyImpact();
    widget.category.name = _nameController.text.trim();
    widget.category.nature = _currentNature;
    widget.category.isHidden = _isHidden;
    widget.category.iconEmoji = _currentIcon;
    widget.category.colorHex = _currentColorHex;
    ref.read(walletCategoryProvider.notifier).updateCategory(widget.category);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = Color(int.parse(_currentColorHex, radix: 16));

    return Scaffold(
      backgroundColor: const Color(0xFF060B14),
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.check_rounded, color: Colors.greenAccent), onPressed: _saveChanges)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _openCustomizationModal,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [currentColor.withValues(alpha: 0.4), currentColor.withValues(alpha: 0.1)]), border: Border.all(color: currentColor.withValues(alpha: 0.6), width: 2)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(_currentIcon, style: const TextStyle(fontSize: 44)),
                    Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle), child: const Icon(Icons.edit, color: Colors.white, size: 14))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextField(
              controller: _nameController, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(labelText: "Category Name", labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white.withValues(alpha: 0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Global Visibility", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Switch(value: !_isHidden, activeColor: currentColor, onChanged: (v) => setState(() => _isHidden = !v)),
              ],
            ),
            const SizedBox(height: 24),
            const Align(alignment: Alignment.centerLeft, child: Text("Nature / Classification", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Row(
              children: ['Need', 'Want', 'Income', 'Other'].map((n) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(n, style: const TextStyle(fontSize: 11)), selected: _currentNature == n,
                    selectedColor: currentColor.withValues(alpha: 0.3), backgroundColor: Colors.white.withValues(alpha: 0.05),
                    onSelected: (_) => setState(() => _currentNature = n),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 40),
            const Align(alignment: Alignment.centerLeft, child: Text("Subcategories (Fixed)", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8, alignment: WrapAlignment.start,
              children: widget.category.subcategories.map((s) {
                // Remove emoji visually here in edit screen too for cleanliness
                final int firstSpace = s.indexOf(' ');
                final textOnly = firstSpace != -1 ? s.substring(firstSpace + 1).trim() : s;
                return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)), child: Text(textOnly, style: const TextStyle(color: Colors.white70, fontSize: 12)));
              }).toList(),
            )
          ],
        ),
      ),
    );
  }
}