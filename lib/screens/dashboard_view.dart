import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/input_sheets.dart';
import '../widgets/shared_widgets.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService?>();

    if (db == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    _DashboardHeader(db: db),
                    const SizedBox(height: 22),
                    SectionHeader(
                      title: 'Accounts',
                      actionText: 'Add New',
                      onAction: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const AccountSheet(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _WalletCarousel(db: db),
                    const SizedBox(height: 22),
                    _QuickAddRow(db: db),
                    const SizedBox(height: 20),
                    SectionHeader(
                      title: 'Latest transactions',
                    ),
                    const SizedBox(height: 12),
                    _RecentTransactions(db: db),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final DatabaseService db;

  const _DashboardHeader({required this.db});

  void _showSearch(BuildContext context, DatabaseService db) {
    showSearch(
      context: context,
      delegate: _TransactionSearchDelegate(db),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<fb.User?>();

    return Row(
      children: [
        const CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.primary,
          child: Icon(Icons.person_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Welcome back,', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              Text(
                user?.email?.split('@').first ?? 'User',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showSearch(context, db),
          icon: const Icon(Icons.search_rounded),
        ),
        StreamBuilder<List<Subscription>>(
          stream: db.subscriptionsStream(),
          builder: (context, snapshot) {
            final now = DateTime.now();
            final count = (snapshot.data ?? [])
                .where(
                  (s) =>
                      !s.isAuto && // Only manual bills need reminders
                      s.isNotificationOn &&
                      s.dueDate.isAfter(now.subtract(const Duration(days: 1))) &&
                      s.dueDate.isBefore(now.add(const Duration(days: 7))),
                )
                .length;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                if (count > 0)
                  Positioned(
                    right: 8,
                    top: 7,
                    child: Container(
                      height: 17,
                      width: 17,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                      child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            );
          },
        ),
        IconButton(
          onPressed: () => context.read<AuthService>().logout(),
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
    );
  }
}

class _WalletCarousel extends StatelessWidget {
  final DatabaseService db;

  const _WalletCarousel({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: db.accountsStream(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];

        if (accounts.isEmpty) {
          return const EmptyState(
            title: 'No wallets yet',
            subtitle: 'Create accounts using the "Add New" button above.',
          );
        }

        return SizedBox(
          height: 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final account = accounts[index];

              return GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AccountSheet(account: account),
                ),
                child: Container(
                  width: 285,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.blue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.20),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet_rounded),
                          const SizedBox(width: 8),
                          Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                          const Spacer(),
                          const Icon(Icons.edit_rounded, size: 18),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        account.type.name.toUpperCase(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 12),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Rs ${account.balance.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _QuickAddRow extends StatelessWidget {
  final DatabaseService db;

  const _QuickAddRow({required this.db});

  void openSheet(BuildContext context, MoneyTransactionType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTransactionSheet(type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickButton(
          label: '+ Income',
          icon: Icons.add_rounded,
          color: AppColors.green,
          onTap: () => openSheet(context, MoneyTransactionType.income),
        ),
        const SizedBox(width: 10),
        _QuickButton(
          label: '- Expense',
          icon: Icons.remove_rounded,
          color: AppColors.red,
          onTap: () => openSheet(context, MoneyTransactionType.expense),
        ),
        const SizedBox(width: 10),
        _QuickButton(
          label: '<-> Transfer',
          icon: Icons.swap_horiz_rounded,
          color: AppColors.primaryLight,
          onTap: () => openSheet(context, MoneyTransactionType.transfer),
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.16),
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final DatabaseService db;

  const _RecentTransactions({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MoneyTransaction>>(
      stream: db.transactionsStream(limit: 15),
      builder: (context, snapshot) {
        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return const EmptyState(
            title: 'No transactions',
            subtitle: 'Use quick buttons to add income, expense or transfer.',
          );
        }

        return Column(children: items.map((tx) => _TransactionTile(tx: tx)).toList());
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final MoneyTransaction tx;

  const _TransactionTile({required this.tx});

  IconData iconForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('food')) return Icons.restaurant_rounded;
    if (c.contains('rent')) return Icons.home_work_rounded;
    if (c.contains('salary')) return Icons.payments_rounded;
    if (c.contains('netflix')) return Icons.movie_rounded;
    if (c.contains('spotify')) return Icons.music_note_rounded;
    if (c.contains('booking')) return Icons.book_online_rounded;
    if (c.contains('transfer')) return Icons.swap_horiz_rounded;
    return Icons.receipt_long_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.type == MoneyTransactionType.income;
    final isTransfer = tx.type == MoneyTransactionType.transfer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: isIncome
                ? AppColors.green.withValues(alpha: 0.15)
                : isTransfer
                    ? AppColors.primaryLight.withValues(alpha: 0.15)
                    : AppColors.red.withValues(alpha: 0.15),
            child: Icon(
              iconForCategory(tx.category),
              color: isIncome
                  ? AppColors.green
                  : isTransfer
                      ? AppColors.primaryLight
                      : AppColors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.category, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMM d, h:mm a').format(tx.date),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          AmountText(amount: tx.amount, isPositive: isIncome),
        ],
      ),
    );
  }
}

class _AddTransactionSheet extends StatefulWidget {
  final MoneyTransactionType type;

  const _AddTransactionSheet({required this.type});

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final amountController = TextEditingController();
  final categoryController = TextEditingController();
  final notesController = TextEditingController();

  String? accountId;
  String? toAccountId;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    categoryController.text = switch (widget.type) {
      MoneyTransactionType.income => 'Salary',
      MoneyTransactionType.expense => 'Food',
      MoneyTransactionType.transfer => 'Transfer',
    };
  }

  @override
  void dispose() {
    amountController.dispose();
    categoryController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    final amount = double.tryParse(amountController.text.trim());
    
    if (db == null) return;
    if (amount == null || amount <= 0) {
      setState(() => error = 'Please enter a valid amount.');
      return;
    }
    if (accountId == null) {
      setState(() => error = 'Please select an account first.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      if (widget.type == MoneyTransactionType.transfer && toAccountId != null) {
        await db.transferMoney(
          fromAccountId: accountId!,
          toAccountId: toAccountId!,
          amount: amount,
          notes: notesController.text.trim(),
        );
      } else {
        await db.addMoneyTransaction(
          MoneyTransaction(
            id: '',
            accountId: accountId!,
            type: widget.type,
            amount: amount,
            category: categoryController.text.trim(),
            date: DateTime.now(),
            notes: notesController.text.trim(),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService?>();

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: StreamBuilder<List<Account>>(
        stream: db?.accountsStream(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? [];
          if (accounts.isNotEmpty && accountId == null) accountId = accounts.first.id;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.type.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 16),
              if (accounts.isEmpty) ...[
                const EmptyState(
                  title: 'No Accounts',
                  subtitle: 'You need to create a wallet or bank account first.',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const AccountSheet());
                    },
                    child: const Text('Create Account'),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.currency_rupee_rounded)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: accountId,
                  dropdownColor: AppColors.surface,
                  decoration: const InputDecoration(labelText: 'Account'),
                  items: accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                  onChanged: (value) => setState(() => accountId = value),
                ),
                if (widget.type == MoneyTransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: toAccountId,
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(labelText: 'Transfer to'),
                    items: accounts
                        .where((a) => a.id != accountId)
                        .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                        .toList(),
                    onChanged: (value) => setState(() => toAccountId = value),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_rounded)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notes', prefixIcon: Icon(Icons.notes_rounded)),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: saving ? null : save,
                    child: saving ? const CircularProgressIndicator() : const Text('Save'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _TransactionSearchDelegate extends SearchDelegate {
  final DatabaseService db;

  _TransactionSearchDelegate(this.db);

  @override
  ThemeData appBarTheme(BuildContext context) => Theme.of(context);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        if (query.isNotEmpty) IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear_rounded)),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        onPressed: () => close(context, null),
        icon: const Icon(Icons.arrow_back_rounded),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    return StreamBuilder<List<MoneyTransaction>>(
      stream: db.transactionsStream(limit: 100),
      builder: (context, snapshot) {
        final results = (snapshot.data ?? []).where((tx) {
          final q = query.toLowerCase();
          return tx.category.toLowerCase().contains(q) || tx.notes.toLowerCase().contains(q);
        }).toList();

        if (results.isEmpty) {
          return const Center(child: Text('No matching transactions found.', style: TextStyle(color: AppColors.muted)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: results.length,
          itemBuilder: (context, index) => _TransactionTile(tx: results[index]),
        );
      },
    );
  }
}
