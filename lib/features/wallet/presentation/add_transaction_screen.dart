import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart'; 
import 'package:intl/intl.dart';

import '../../../core/themes/aether_colors.dart';
import '../../../core/themes/widgets/aether_ambient_background.dart';
import '../../../core/themes/widgets/aether_glass_card.dart';
import '../data/wallet_providers.dart';
import '../domain/models/aether_account.dart';
import '../domain/models/aether_transaction.dart';
import '../domain/utils/aether_category.dart';
import '../domain/utils/aether_currency.dart';
import '../../diary/data/diary_provider.dart';
import '../domain/models/wallet_category_system.dart';
import 'widgets/aether_liquid_date_picker.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final AetherTransaction? editTransaction;
  const AddTransactionScreen({super.key, this.editTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();
  
  final FocusNode _titleFocusNode = FocusNode();
  bool _showNumpad = false; 

  String _type = 'expense'; 
  
  AetherWalletCategory? _selectedMainCategory;
  String? _selectedSubcategory;
  String? _selectedAccountId;
  String? _selectedDestinationAccountId; 
  
  DateTime _selectedDate = DateTime.now();

  bool _isAdvancedExpanded = false;
  List<String> _attachmentPaths = []; 

  bool get _isEditing => widget.editTransaction != null;

  bool _showTutorial = false;
  int _tutorialStep = 1;
  final GlobalKey _amountKey = GlobalKey();
  final GlobalKey _categoryKey = GlobalKey();
  final GlobalKey _saveKey = GlobalKey();

  static const Color _bgTop = Color(0xFF060B14);
  static const Color _bgBottom = Color(0xFF0A0714);
  static const Color _expense = Color(0xFFFB7185); 
  static const Color _expenseDeep = Color(0xFF7F1D2E);
  static const Color _income = Color(0xFF34F5C5); 
  static const Color _incomeDeep = Color(0xFF0F5B4C);
  static const Color _transfer = Color(0xFF38BDF8); 
  static const Color _transferDeep = Color(0xFF1E3A5F);

  @override
  void initState() {
    super.initState();
    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) setState(() => _showNumpad = false);
    });

    if (_isEditing) {
      final t = widget.editTransaction!;
      _type = t.type;
      _amountController.text = t.amount.toString().replaceAll(RegExp(r'\.0$'), ''); 
      _titleController.text = t.title;
      _selectedAccountId = t.accountId;
      _selectedDestinationAccountId = t.destinationAccountId;
      _attachmentPaths = t.attachmentPaths != null ? List.from(t.attachmentPaths!) : [];
      if (_attachmentPaths.isNotEmpty) _isAdvancedExpanded = true;
      _selectedSubcategory = t.subcategory;
      _selectedDate = t.date;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    if (_isEditing) {
      setState(() => _showNumpad = true);
      return;
    }
    
    final box = await Hive.openBox('aether_settings');
    bool tutorialShown = box.get('add_txn_tutorial_shown', defaultValue: false);
    
    if (!tutorialShown) {
      setState(() => _showTutorial = true);
    } else {
      setState(() => _showNumpad = true); 
    }
  }

  Future<void> _endTutorial() async {
    final box = await Hive.openBox('aether_settings');
    await box.put('add_txn_tutorial_shown', true);
    setState(() {
      _showTutorial = false;
      _showNumpad = true;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboards() {
    if (_titleFocusNode.hasFocus) _titleFocusNode.unfocus();
    if (_showNumpad) setState(() => _showNumpad = false);
  }

  void _onNumpadTap(String val) {
    HapticFeedback.selectionClick();
    String current = _amountController.text;

    if (val == '<') {
      if (current.isNotEmpty) _amountController.text = current.substring(0, current.length - 1);
    } else if (val == '.') {
      if (!current.contains('.')) _amountController.text = current.isEmpty ? '0.' : '$current.';
    } else {
      if (current == '0' && val == '0') return;
      if (current == '0' && val != '.') current = '';
      if (current.contains('.')) {
        final parts = current.split('.');
        if (parts[1].length >= 2) return;
      }
      _amountController.text = current + val;
    }
    setState(() {}); 
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickCustomDate(Color accent) async {
    HapticFeedback.selectionClick();
    _dismissKeyboards();
    final picked = await showAetherLiquidDateTimePicker(
      context: context,
      initialDateTime: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      accentColor: accent,
      title: "Transaction Date & Time",
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _attachReceipt() async {
    try {
      final imageService = ref.read(imageStorageProvider);
      final pickedFile = await imageService.pickImageFromGallery();
      if (pickedFile != null) {
        final savedPath = await imageService.saveImageToAppStorage(pickedFile);
        if (!mounted) return; 
        setState(() { _attachmentPaths.add(savedPath); _isAdvancedExpanded = true; });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Attachment failed: $e')));
    }
  }

  Future<void> _saveTransaction() async {
    if (_type == 'transfer') {
      if (_selectedAccountId == _selectedDestinationAccountId) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot transfer to same account.'), backgroundColor: Colors.redAccent));
        return;
      }
      if (_selectedDestinationAccountId == null) {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select destination.'), backgroundColor: Colors.redAccent));
        return;
      }
    }

    final parsedAmount = double.tryParse(_amountController.text.trim().replaceAll(',', '')) ?? 0.0;
    if (parsedAmount <= 0) {
      HapticFeedback.vibrate(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid amount.')));
      return;
    }

    if (_selectedAccountId == null) {
      HapticFeedback.vibrate(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please create an Account first!'), backgroundColor: Colors.redAccent));
      return;
    }

    if (_type != 'transfer' && _selectedMainCategory == null && !_isEditing) {
      HapticFeedback.vibrate(); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a category.'), backgroundColor: Colors.redAccent));
      return;
    }

    HapticFeedback.heavyImpact();
    
    String finalTitle = _titleController.text.trim();
    if (finalTitle.isEmpty) {
      finalTitle = _type == 'transfer' ? 'Transfer' : (_selectedSubcategory ?? _selectedMainCategory?.name ?? 'Expense');
    }

    try {
      final accountsList = ref.read(accountNotifierProvider).valueOrNull ?? [];
      final sourceAccount = accountsList.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accountsList.first);

      final transaction = AetherTransaction(
        id: _isEditing ? widget.editTransaction!.id : null,
        title: finalTitle,
        amount: parsedAmount,
        currency: sourceAccount.currency,
        exchangeRate: sourceAccount.baseConversionRate, 
        type: _type,
        category: _type == 'transfer' ? 'Transfer' : (_selectedMainCategory?.name ?? widget.editTransaction?.category ?? 'Expense'),
        subcategory: _selectedSubcategory,
        accountId: _selectedAccountId!,
        destinationAccountId: _type == 'transfer' ? _selectedDestinationAccountId : null, 
        attachmentPaths: _attachmentPaths.isNotEmpty ? _attachmentPaths.toList() : null, 
        date: _selectedDate,
        createdAt: _isEditing ? widget.editTransaction!.createdAt : null,
      );

      await ref.read(transactionNotifierProvider.notifier).addTransaction(transaction); 
      if (!mounted) return; 
      context.pop();
    } catch (e) {
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
    }
  }

  String _getMultiCurrencyPreview(List<AetherAccount> accounts) {
    if (_type != 'transfer' || _selectedAccountId == null || _selectedDestinationAccountId == null || _amountController.text.isEmpty) return "";
    final srcAcc = accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => accounts.first);
    final dstAcc = accounts.firstWhere((a) => a.id == _selectedDestinationAccountId, orElse: () => accounts.first);
    if (srcAcc.currency == dstAcc.currency) return ""; 

    double inputAmt = double.tryParse(_amountController.text) ?? 0.0;
    double baseAmount = inputAmt * srcAcc.baseConversionRate;
    double destAmount = baseAmount / (dstAcc.baseConversionRate > 0 ? dstAcc.baseConversionRate : 1.0);

    return "≈ ${AetherCurrency.format(destAmount, currencyCode: dstAcc.currency)}";
  }

  String _getLocalCurrencySymbol(String code) {
    return AetherCurrency.fromCode(code).symbol.trim();
  }

  Rect? _getTargetRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final pos = box.localToGlobal(Offset.zero);
    return pos & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountNotifierProvider).valueOrNull ?? [];
    
    if (_selectedAccountId == null && accounts.isNotEmpty && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _selectedAccountId = accounts.first.id); });
    }
    if (_type == 'transfer' && _selectedDestinationAccountId == null && accounts.length > 1 && !_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _selectedDestinationAccountId = accounts.firstWhere((a) => a.id != _selectedAccountId).id); });
    }

    final Color accent = _type == 'expense' ? _expense : _type == 'income' ? _income : _transfer;
    final Color accentDeep = _type == 'expense' ? _expenseDeep : _type == 'income' ? _incomeDeep : _transferDeep;
    
    final currentAccount = accounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => AetherAccount(title: 'None', accountType: 'cash', colorHex: 'FFFFFF', iconName: ''));
    final String currencySymbol = _getLocalCurrencySymbol(currentAccount.currency);

    final bool isKeyboardVisible = _showNumpad || _titleFocusNode.hasFocus;
    final String previewText = _getMultiCurrencyPreview(accounts);

    return PopScope(
      canPop: !isKeyboardVisible && !_showTutorial,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showTutorial) { _endTutorial(); return; }
        if (isKeyboardVisible) _dismissKeyboards();
      },
      child: GestureDetector(
        onTap: _dismissKeyboards, 
        behavior: HitTestBehavior.translucent, 
        child: Scaffold(
          backgroundColor: _bgTop,
          resizeToAvoidBottomInset: false, 
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, 
                      end: Alignment.bottomCenter, 
                      colors: [_bgTop, Color(0xFF0B0F1C), _bgBottom], 
                      stops: [0.0, 0.5, 1.0]
                    )
                  ),
                ),
              ),
              Positioned(
                top: -100, right: -80, 
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400), 
                    width: 300, height: 300, 
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [accent.withValues(alpha: 0.24), Colors.transparent]))
                  )
                )
              ),
              Positioned(
                bottom: 40, left: -120, 
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400), 
                    width: 260, height: 260, 
                    decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [accentDeep.withValues(alpha: 0.28), Colors.transparent]))
                  )
                )
              ),

              AetherAmbientBackground(
                color1: Colors.transparent, color2: Colors.transparent,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _circleIconButton(Icons.close_rounded, Colors.white70, () { HapticFeedback.lightImpact(); context.pop(); }),
                            Text(
                              _isEditing ? "Edit Log" : "Fast Log", 
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.4)
                            ),
                            Container(
                              key: _saveKey,
                              child: _circleIconButton(Icons.check_rounded, Colors.black87, _saveTransaction, filled: accent)
                            ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.045), 
                                      borderRadius: BorderRadius.circular(20), 
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.07))
                                    ),
                                    child: Row(
                                      children: [
                                        _buildTypeTab('Expense', 'expense', _expense),
                                        _buildTypeTab('Income', 'income', _income),
                                        _buildTypeTab('Transfer', 'transfer', _transfer),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),

                              Container(
                                key: _amountKey,
                                child: GestureDetector(
                                  onTap: () { FocusScope.of(context).unfocus(); setState(() => _showNumpad = true); },
                                  behavior: HitTestBehavior.opaque,
                                  child: Center(
                                    child: Column(
                                      children: [
                                        AbsorbPointer(
                                          child: IntrinsicWidth(
                                            child: TextField(
                                              controller: _amountController, 
                                              readOnly: true, 
                                              showCursor: true, 
                                              textAlign: TextAlign.center, 
                                              style: TextStyle(
                                                color: Colors.white, 
                                                fontSize: 58, 
                                                fontWeight: FontWeight.w300, 
                                                letterSpacing: -1, 
                                                fontFeatures: const [FontFeature.tabularFigures()]
                                              ),
                                              decoration: InputDecoration(
                                                prefixText: "$currencySymbol ", 
                                                prefixStyle: TextStyle(
                                                  color: accent.withValues(alpha: 0.7), 
                                                  fontSize: 30, 
                                                  fontWeight: FontWeight.w600
                                                ), 
                                                hintText: "0", 
                                                hintStyle: const TextStyle(color: Colors.white24), 
                                                border: InputBorder.none, 
                                                contentPadding: EdgeInsets.zero
                                              ),
                                            ),
                                          ),
                                        ).animate().scaleXY(begin: 0.9, duration: 400.ms, curve: Curves.easeOutBack),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: 46, 
                                          height: 3, 
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.1)]), 
                                            borderRadius: BorderRadius.circular(4)
                                          )
                                        ),
                                        if (previewText.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 10.0),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _income.withValues(alpha: 0.12), 
                                                borderRadius: BorderRadius.circular(10)
                                              ),
                                              child: Text(
                                                previewText, 
                                                style: const TextStyle(color: _income, fontSize: 13, fontWeight: FontWeight.w700)
                                              ),
                                            ).animate().fadeIn(),
                                          )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 40),

                              // 🌟 DATE SELECTOR SECTION 🌟
                              const _SectionLabel("DATE"),
                              const SizedBox(height: 12),
                              _buildDateSelector(accent),
                              const SizedBox(height: 28),

                              if (_type != 'transfer') ...[
                                const _SectionLabel("CATEGORY"),
                                const SizedBox(height: 12),
                                Container(
                                  key: _categoryKey,
                                  child: GestureDetector(
                                    onTap: () {
                                      _dismissKeyboards();
                                      showCategoryPickerBottomSheet(context, ref, _type, (cat, sub) {
                                        setState(() { _selectedMainCategory = cat; _selectedSubcategory = sub; });
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.035), 
                                        borderRadius: BorderRadius.circular(20), 
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.07))
                                      ),
                                      child: Row(
                                        children: [
                                          if (_selectedMainCategory != null) ...[
                                            Container(
                                              padding: const EdgeInsets.all(10), 
                                              decoration: BoxDecoration(
                                                color: _selectedMainCategory!.color.withValues(alpha: 0.15), 
                                                shape: BoxShape.circle
                                              ), 
                                              child: Text(_selectedMainCategory!.iconEmoji, style: const TextStyle(fontSize: 18))
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, 
                                                children: [
                                                  Text(
                                                    _selectedSubcategory ?? _selectedMainCategory!.name, 
                                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                                                  ), 
                                                  const SizedBox(height: 4), 
                                                  Text(
                                                    _selectedMainCategory!.name, 
                                                    style: const TextStyle(color: Colors.white38, fontSize: 12)
                                                  )
                                                ]
                                              )
                                            ),
                                          ] else if (_isEditing && widget.editTransaction!.category != 'Transfer') ...[
                                            Container(
                                              padding: const EdgeInsets.all(10), 
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.05), 
                                                shape: BoxShape.circle
                                              ), 
                                              child: const Icon(Icons.category, color: Colors.white54)
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start, 
                                                children: [
                                                  Text(
                                                    _selectedSubcategory ?? widget.editTransaction!.category, 
                                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                                                  ), 
                                                  const SizedBox(height: 4), 
                                                  Text(
                                                    widget.editTransaction!.category, 
                                                    style: const TextStyle(color: Colors.white38, fontSize: 12)
                                                  )
                                                ]
                                              )
                                            ),
                                          ] else ...[
                                            Container(
                                              padding: const EdgeInsets.all(10), 
                                              decoration: BoxDecoration(
                                                color: accent.withValues(alpha: 0.1), 
                                                shape: BoxShape.circle
                                              ), 
                                              child: Icon(Icons.grid_view_rounded, color: accent)
                                            ),
                                            const SizedBox(width: 16),
                                            const Expanded(
                                              child: Text(
                                                "Select Category", 
                                                style: TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.w600)
                                              )
                                            ),
                                          ],
                                          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                              ],

                              _SectionLabel(_type == 'transfer' ? "FROM ACCOUNT" : "ACCOUNT"),
                              const SizedBox(height: 12),
                              if (accounts.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16), 
                                  decoration: BoxDecoration(
                                    color: _expense.withValues(alpha: 0.08), 
                                    borderRadius: BorderRadius.circular(18), 
                                    border: Border.all(color: _expense.withValues(alpha: 0.25))
                                  ), 
                                  child: const Text("No accounts found.", style: TextStyle(color: _expense, fontSize: 12))
                                )
                              else
                                _buildAccountSelector(accounts, _selectedAccountId, (id) => setState(() => _selectedAccountId = id), accent),

                              if (_type == 'transfer' && accounts.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                const _SectionLabel("TO ACCOUNT").animate().fadeIn(),
                                const SizedBox(height: 12),
                                _buildAccountSelector(accounts, _selectedDestinationAccountId, (id) => setState(() => _selectedDestinationAccountId = id), _transfer).animate().slideX(),
                              ],

                              const SizedBox(height: 28),

                              GestureDetector(
                                onTap: () { HapticFeedback.selectionClick(); setState(() => _isAdvancedExpanded = !_isAdvancedExpanded); },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.tune_rounded, color: accent, size: 15),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Advanced Options & Receipts", 
                                        style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _isAdvancedExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
                                        color: accent, 
                                        size: 18
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              AnimatedSize(
                                duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic,
                                child: _isAdvancedExpanded ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 22),
                                    
                                    if (_type != 'transfer' && _selectedMainCategory != null && _selectedMainCategory!.subcategories.isNotEmpty) ...[
                                      Wrap(
                                        spacing: 8, runSpacing: 10,
                                        children: _selectedMainCategory!.subcategories.map((sub) {
                                          final isSelected = _selectedSubcategory == sub;
                                          return GestureDetector(
                                            onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedSubcategory = sub); },
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 200), 
                                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isSelected ? _selectedMainCategory!.color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.03), 
                                                borderRadius: BorderRadius.circular(20), 
                                                border: Border.all(color: isSelected ? _selectedMainCategory!.color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08))
                                              ),
                                              child: Text(
                                                sub, 
                                                style: TextStyle(color: isSelected ? _selectedMainCategory!.color : Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 22),
                                    ],

                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.035), 
                                        borderRadius: BorderRadius.circular(18), 
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.06))
                                      ),
                                      child: TextField(
                                        focusNode: _titleFocusNode, 
                                        controller: _titleController,
                                        style: const TextStyle(color: Colors.white70, fontSize: 15),
                                        decoration: const InputDecoration(
                                          hintText: "Add custom note (Optional)", 
                                          hintStyle: TextStyle(color: Colors.white24), 
                                          border: InputBorder.none
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: _attachReceipt,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: accent.withValues(alpha: 0.10), 
                                              borderRadius: BorderRadius.circular(16), 
                                              border: Border.all(color: accent.withValues(alpha: 0.25))
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.receipt_long_rounded, color: accent, size: 17),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Attach File", 
                                                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 13)
                                                ),
                                              ]
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        if (_attachmentPaths.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: _income.withValues(alpha: 0.12), 
                                              borderRadius: BorderRadius.circular(10)
                                            ),
                                            child: Text(
                                              "${_attachmentPaths.length} Attached", 
                                              style: const TextStyle(color: _income, fontWeight: FontWeight.w700, fontSize: 12)
                                            ),
                                          ),
                                      ],
                                    )
                                  ],
                                ) : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 350), 
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_showTutorial)
                Positioned.fill(
                  child: Builder(
                    builder: (context) {
                      final key = _tutorialStep == 1 ? _amountKey : (_tutorialStep == 2 ? _categoryKey : _saveKey);
                      final rect = _getTargetRect(key) ?? Rect.zero;
                      final isTopHalf = rect.center.dy < MediaQuery.of(context).size.height / 2;

                      return Material(
                        color: Colors.transparent,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size.infinite,
                              painter: _SpotlightPainter(rect),
                            ),
                            Positioned(
                              top: isTopHalf ? rect.bottom + 20 : null,
                              bottom: isTopHalf ? null : (MediaQuery.of(context).size.height - rect.top) + 20,
                              left: 20, right: 20,
                              child: Column(
                                children: [
                                  Icon(
                                    isTopHalf ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, 
                                    color: Colors.white, 
                                    size: 40
                                  ).animate(onPlay: (c) => c.repeat(reverse: true)).slideY(begin: -0.2, end: 0.2),
                                  const SizedBox(height: 16),
                                  Text(
                                    _tutorialStep == 1 ? "1. Enter your amount here." :
                                    _tutorialStep == 2 ? "2. Select a category for your transaction." :
                                    "3. Tap here to save!",
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  ).animate().fadeIn(),
                                ],
                              ),
                            ),
                            Positioned(
                              bottom: 40, left: 20, right: 20,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: _endTutorial, 
                                    child: const Text(
                                      "Skip", 
                                      style: TextStyle(color: Colors.white54, fontSize: 16)
                                    )
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accent, 
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      if (_tutorialStep < 3) setState(() => _tutorialStep++);
                                      else _endTutorial();
                                    },
                                    child: Text(
                                      _tutorialStep < 3 ? "Next" : "Got it!", 
                                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          
          bottomSheet: _showNumpad && !_showTutorial ? ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.035), 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), 
                  border: Border.all(color: Colors.white.withValues(alpha: 0.07))
                ),
                padding: const EdgeInsets.only(bottom: 24, top: 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, 
                      height: 4, 
                      margin: const EdgeInsets.only(bottom: 10), 
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4))
                    ),
                    Row(
                      children: [
                        _buildNumpadBtn('1'), 
                        _buildNumpadBtn('2'), 
                        _buildNumpadBtn('3')
                      ]
                    ),
                    Row(
                      children: [
                        _buildNumpadBtn('4'), 
                        _buildNumpadBtn('5'), 
                        _buildNumpadBtn('6')
                      ]
                    ),
                    Row(
                      children: [
                        _buildNumpadBtn('7'), 
                        _buildNumpadBtn('8'), 
                        _buildNumpadBtn('9')
                      ]
                    ),
                    Row(
                      children: [
                        _buildNumpadBtn('.'), 
                        _buildNumpadBtn('0'), 
                        _buildNumpadBtn('<', accent: accent)
                      ]
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _showNumpad = false);
                        },
                        child: Container(
                          height: 54, 
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: accent, 
                            borderRadius: BorderRadius.circular(16)
                          ),
                          child: const Icon(
                            Icons.check_rounded, 
                            color: Colors.black87, 
                            size: 28
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ).animate().slideY(begin: 1.0, duration: 250.ms, curve: Curves.easeOutCubic) : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // 🌟 NAYA: BUILD DATE SELECTOR WITH TODAY, YESTERDAY & CUSTOM PICKER
  Widget _buildDateSelector(Color accent) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final isToday = _isSameDay(_selectedDate, now);
    final isYesterday = _isSameDay(_selectedDate, yesterday);
    final isCustom = !isToday && !isYesterday;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          // TODAY CHIP
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDate = DateTime(now.year, now.month, now.day, _selectedDate.hour, _selectedDate.minute);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isToday ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isToday ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
                  width: isToday ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.today_rounded, color: isToday ? accent : Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Today",
                    style: TextStyle(
                      color: isToday ? accent : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // YESTERDAY CHIP
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedDate = DateTime(yesterday.year, yesterday.month, yesterday.day, _selectedDate.hour, _selectedDate.minute);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isYesterday ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isYesterday ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
                  width: isYesterday ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, color: isYesterday ? accent : Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    "Yesterday",
                    style: TextStyle(
                      color: isYesterday ? accent : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // CUSTOM DATE CHIP
          GestureDetector(
            onTap: () => _pickCustomDate(accent),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isCustom ? accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCustom ? accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.07),
                  width: isCustom ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: isCustom ? accent : Colors.white38, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    isCustom ? DateFormat('MMM d, yyyy').format(_selectedDate) : "Pick Date",
                    style: TextStyle(
                      color: isCustom ? accent : Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, Color iconColor, VoidCallback onTap, {Color? filled}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, 
        height: 40, 
        decoration: BoxDecoration(
          color: filled ?? Colors.white.withValues(alpha: 0.06), 
          shape: BoxShape.circle, 
          border: filled == null ? Border.all(color: Colors.white.withValues(alpha: 0.08)) : null, 
          boxShadow: filled != null ? [
            BoxShadow(color: filled.withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6))
          ] : null
        ), 
        child: Icon(icon, color: iconColor, size: 19)
      ),
    );
  }

  Widget _buildNumpadBtn(String text, {Color accent = Colors.white70}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onNumpadTap(text),
        child: Container(
          height: 52, 
          color: Colors.transparent,
          child: Center(
            child: text == '<' 
              ? Icon(Icons.backspace_outlined, color: accent, size: 22) 
              : Text(
                  text, 
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w300)
                )
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSelector(List<AetherAccount> accounts, String? selectedId, Function(String) onSelect, Color activeColor) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal, 
        itemCount: accounts.length,
        itemBuilder: (context, index) {
          final acc = accounts[index];
          final isSelected = selectedId == acc.id;
          return Padding(
            padding: const EdgeInsets.only(right: 10.0), 
            child: GestureDetector(
              onTap: () { 
                HapticFeedback.selectionClick(); 
                onSelect(acc.id); 
              }, 
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200), 
                padding: const EdgeInsets.symmetric(horizontal: 18), 
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withValues(alpha: 0.14) : Colors.white.withValues(alpha: 0.035), 
                  borderRadius: BorderRadius.circular(16), 
                  border: Border.all(
                    color: isSelected ? activeColor.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.07), 
                    width: isSelected ? 1.4 : 1
                  )
                ), 
                child: Center(
                  child: Row(
                    children: [
                      Icon(
                        acc.accountType == 'crypto' ? Icons.currency_bitcoin_rounded : Icons.account_balance_rounded, 
                        color: isSelected ? activeColor : Colors.white38, 
                        size: 15
                      ), 
                      const SizedBox(width: 8), 
                      Text(
                        acc.title, 
                        style: TextStyle(
                          color: isSelected ? activeColor : Colors.white54, 
                          fontWeight: FontWeight.w700, 
                          fontSize: 13
                        )
                      )
                    ]
                  )
                )
              )
            )
          );
        },
      ),
    );
  }

  Widget _buildTypeTab(String label, String type, Color activeColor) {
    return Expanded(
      child: GestureDetector(
        onTap: () { 
          if (_type != type) {
            setState(() { 
              _type = type; 
              _selectedMainCategory = null; 
              _selectedSubcategory = null; 
            }); 
          }
          HapticFeedback.selectionClick(); 
        }, 
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220), 
          curve: Curves.easeOutCubic, 
          padding: const EdgeInsets.symmetric(vertical: 12), 
          decoration: BoxDecoration(
            gradient: _type == type ? LinearGradient(colors: [activeColor.withValues(alpha: 0.32), activeColor.withValues(alpha: 0.12)]) : null, 
            color: _type == type ? null : Colors.transparent, 
            borderRadius: BorderRadius.circular(16), 
            border: _type == type ? Border.all(color: activeColor.withValues(alpha: 0.5)) : null, 
            boxShadow: _type == type ? [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.18), 
                blurRadius: 14, 
                offset: const Offset(0, 4)
              )
            ] : []
          ), 
          child: Center(
            child: Text(
              label, 
              style: TextStyle(
                color: _type == type ? Colors.white : Colors.white38, 
                fontWeight: FontWeight.w700, 
                fontSize: 13
              )
            )
          )
        )
      )
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text; 
  const _SectionLabel(this.text);
  @override 
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3, 
          height: 13, 
          decoration: BoxDecoration(
            color: Colors.white24, 
            borderRadius: BorderRadius.circular(2)
          )
        ), 
        const SizedBox(width: 8), 
        Text(
          text, 
          style: const TextStyle(
            color: Colors.white54, 
            fontSize: 12, 
            letterSpacing: 1.4, 
            fontWeight: FontWeight.w700
          )
        )
      ]
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  _SpotlightPainter(this.targetRect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.85);
    if (targetRect == Rect.zero) {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      return;
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(targetRect.inflate(8), const Radius.circular(16))),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) => oldDelegate.targetRect != targetRect;
}