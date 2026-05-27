import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class AccountSheet extends StatefulWidget {
  final Account? account;
  const AccountSheet({super.key, this.account});

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  late final nameController = TextEditingController(text: widget.account?.name);
  late final balanceController = TextEditingController(text: widget.account?.balance.toStringAsFixed(0));
  late AccountType type = widget.account?.type ?? AccountType.wallet;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    balanceController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    final balance = double.tryParse(balanceController.text.trim());
    
    if (db == null) return;
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'Please enter an account name.');
      return;
    }
    if (balance == null || balance < 0) {
      setState(() => error = 'Please enter a valid balance.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      if (widget.account == null) {
        await db.addAccount(Account(
          id: '',
          name: nameController.text.trim(),
          type: type,
          balance: balance,
        ));
      } else {
        await db.updateAccount(widget.account!.copyWith(
          name: nameController.text.trim(),
          type: type,
          balance: balance,
        ));
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> delete() async {
    final db = context.read<DatabaseService?>();
    if (db == null || widget.account == null) return;

    setState(() => saving = true);
    try {
      await db.deleteAccount(widget.account!.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: widget.account == null ? 'New Account' : 'Edit Account',
      saving: saving,
      onSave: save,
      extraAction: widget.account != null
          ? TextButton.icon(
              onPressed: saving ? null : delete,
              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              label: const Text('Delete', style: TextStyle(color: AppColors.red)),
            )
          : null,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Account Name', prefixIcon: Icon(Icons.account_box_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: balanceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Balance', prefixIcon: Icon(Icons.currency_rupee_rounded)),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AccountType>(
          initialValue: type,
          dropdownColor: AppColors.surface,
          decoration: const InputDecoration(labelText: 'Type'),
          items: AccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
          onChanged: (v) => setState(() => type = v!),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ],
      ],
    );
  }
}

class AddKhaataContactSheet extends StatefulWidget {
  const AddKhaataContactSheet({super.key});

  @override
  State<AddKhaataContactSheet> createState() => _AddKhaataContactSheetState();
}

class _AddKhaataContactSheetState extends State<AddKhaataContactSheet> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool saving = false;
  String? error;

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    if (db == null || nameController.text.isEmpty) return;

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await db.addKhaataContact(KhaataContact(
        id: '',
        name: nameController.text.trim(),
        phoneNumber: phoneController.text.trim(),
        totalToGive: 0,
        totalToTake: 0,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'New Contact',
      saving: saving,
      onSave: save,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Contact Name', prefixIcon: Icon(Icons.person_add_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone_rounded)),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ],
      ],
    );
  }
}

class AddKhaataTransactionSheet extends StatefulWidget {
  final String contactId;
  const AddKhaataTransactionSheet({super.key, required this.contactId});

  @override
  State<AddKhaataTransactionSheet> createState() => _AddKhaataTransactionSheetState();
}

class _AddKhaataTransactionSheetState extends State<AddKhaataTransactionSheet> {
  final amountController = TextEditingController();
  final notesController = TextEditingController();
  KhaataTransactionType type = KhaataTransactionType.give;
  bool saving = false;
  String? error;

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    final amount = double.tryParse(amountController.text.trim());

    if (db == null) return;
    if (amount == null || amount <= 0) {
      setState(() => error = 'Please enter a valid amount.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await db.addKhaataTransaction(KhaataTransaction(
        id: '',
        contactId: widget.contactId,
        type: type,
        amount: amount,
        date: DateTime.now(),
        notes: notesController.text.trim(),
        isSettled: false,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'eKhaata Record',
      saving: saving,
      onSave: save,
      children: [
        DropdownButtonFormField<KhaataTransactionType>(
          initialValue: type,
          dropdownColor: AppColors.surface,
          decoration: const InputDecoration(labelText: 'Transaction Type'),
          items: [
            const DropdownMenuItem(value: KhaataTransactionType.give, child: Text('I GAVE (Increases Take)')),
            const DropdownMenuItem(value: KhaataTransactionType.take, child: Text('I TOOK (Increases Give)')),
          ],
          onChanged: (v) => setState(() => type = v!),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.currency_rupee_rounded)),
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
      ],
    );
  }
}

class AddSubscriptionSheet extends StatefulWidget {
  const AddSubscriptionSheet({super.key});

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final nameController = TextEditingController();
  final costController = TextEditingController();
  DateTime dueDate = DateTime.now().add(const Duration(days: 30));
  bool isAuto = false;
  bool saving = false;
  String? error;

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    final cost = double.tryParse(costController.text.trim());
    
    if (db == null) return;
    if (nameController.text.trim().isEmpty) {
      setState(() => error = 'Please enter a service name.');
      return;
    }
    if (cost == null || cost <= 0) {
      setState(() => error = 'Please enter a valid cost.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await db.addSubscription(Subscription(
        id: '',
        name: nameController.text.trim(),
        cost: cost,
        dueDate: dueDate,
        isNotificationOn: !isAuto, // Auto bills don't need notifications
        isAuto: isAuto,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'New Subscription',
      saving: saving,
      onSave: save,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Service Name', prefixIcon: Icon(Icons.repeat_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: costController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Monthly Cost', prefixIcon: Icon(Icons.currency_rupee_rounded)),
        ),
        const SizedBox(height: 12),
        SwitchListTile.adaptive(
          title: const Text('Automatic Payment'),
          subtitle: const Text('No notification reminder needed'),
          value: isAuto,
          onChanged: (val) => setState(() => isAuto = val),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 4),
        ListTile(
          title: const Text('Next Due Date'),
          subtitle: Text(DateFormat('MMM d, yyyy').format(dueDate)),
          trailing: const Icon(Icons.calendar_today_rounded),
          contentPadding: EdgeInsets.zero,
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: dueDate,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => dueDate = picked);
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ],
      ],
    );
  }
}

class AddEventSheet extends StatefulWidget {
  const AddEventSheet({super.key});

  @override
  State<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<AddEventSheet> {
  final titleController = TextEditingController();
  final costController = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;
  String? error;

  Future<void> save() async {
    final db = context.read<DatabaseService?>();
    final cost = double.tryParse(costController.text.trim());
    
    if (db == null) return;
    if (titleController.text.trim().isEmpty) {
      setState(() => error = 'Please enter an event title.');
      return;
    }
    if (cost == null || cost < 0) {
      setState(() => error = 'Please enter a valid cost.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      await db.addScheduledEvent(ScheduledEvent(
        id: '',
        title: titleController.text.trim(),
        expectedCost: cost,
        date: date,
        isCompleted: false,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'New Event',
      saving: saving,
      onSave: save,
      children: [
        TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Event Title', prefixIcon: Icon(Icons.event_note_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: costController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Expected Cost', prefixIcon: Icon(Icons.currency_rupee_rounded)),
        ),
        const SizedBox(height: 12),
        ListTile(
          title: const Text('Event Date'),
          subtitle: Text(DateFormat('MMM d, yyyy').format(date)),
          trailing: const Icon(Icons.calendar_today_rounded),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 30)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null) setState(() => date = picked);
          },
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ],
      ],
    );
  }
}

class ShareKhaataSheet extends StatefulWidget {
  const ShareKhaataSheet({super.key});

  @override
  State<ShareKhaataSheet> createState() => _ShareKhaataSheetState();
}

class _ShareKhaataSheetState extends State<ShareKhaataSheet> {
  final emailController = TextEditingController();
  bool searching = false;
  String? error;
  UserProfile? foundUser;

  Future<void> search() async {
    final db = context.read<DatabaseService?>();
    if (db == null || emailController.text.isEmpty) return;

    setState(() {
      searching = true;
      error = null;
      foundUser = null;
    });

    try {
      final user = await db.findUserByEmail(emailController.text);
      if (user == null) {
        setState(() => error = 'User not found.');
      } else if (user.uid == db.uid) {
        setState(() => error = "You can't share with yourself.");
      } else {
        setState(() => foundUser = user);
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> create() async {
    final db = context.read<DatabaseService?>();
    if (db == null || foundUser == null) return;
    try {
      await db.createSharedKhaata(foundUser!);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _BaseSheet(
      title: 'Shared eKhaata',
      saving: false,
      onSave: foundUser != null ? create : search,
      children: [
        const Text(
          'Connect with another app user to maintain a shared ledger together.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'User Email',
            prefixIcon: const Icon(Icons.alternate_email_rounded),
            suffixIcon: IconButton(onPressed: search, icon: const Icon(Icons.search_rounded)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: AppColors.red, fontSize: 12)),
        ],
        if (foundUser != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                const SizedBox(width: 12),
                Expanded(child: Text(foundUser!.email, style: const TextStyle(fontWeight: FontWeight.w700))),
                const Icon(Icons.check_circle_rounded, color: AppColors.green),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BaseSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool saving;
  final VoidCallback onSave;
  final Widget? extraAction;

  const _BaseSheet({
    required this.title,
    required this.children,
    required this.saving,
    required this.onSave,
    this.extraAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: AppColors.cardSoft, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              if (extraAction != null) extraAction!,
            ],
          ),
          const SizedBox(height: 22),
          ...children,
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: saving ? const CircularProgressIndicator() : const Text('Save Entry'),
            ),
          ),
        ],
      ),
    );
  }
}
