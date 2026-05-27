import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_models.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/input_sheets.dart';
import '../widgets/shared_widgets.dart';

class KhaataView extends StatelessWidget {
  const KhaataView({super.key});

  @override
  Widget build(BuildContext context) {
    final db = context.watch<DatabaseService?>();

    if (db == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<KhaataContact>>(
          stream: db.khaataContactsStream(),
          builder: (context, snapshot) {
            final contacts = snapshot.data ?? [];

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('eKhaata', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                        Text('Manage your ledger', style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const ShareKhaataSheet(),
                          ),
                          icon: const Icon(Icons.share_rounded),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const AddKhaataContactSheet(),
                          ),
                          icon: const Icon(Icons.person_add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                if (contacts.isEmpty)
                  const EmptyState(
                    title: 'No eKhaata records',
                    subtitle: 'Add a private contact or link with a user to start tracking Rs.',
                  )
                else
                  ...contacts.map((contact) => _KhaataContactCard(contact: contact, db: db)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _KhaataContactCard extends StatelessWidget {
  final KhaataContact contact;
  final DatabaseService db;

  const _KhaataContactCard({required this.contact, required this.db});

  Future<void> sendReminder(BuildContext context) async {
    final net = contact.totalToTake - contact.totalToGive;
    if (net == 0) return;

    final amountText = net > 0
        ? 'You have to return Rs ${net.abs().toStringAsFixed(0)}.'
        : 'I have to return Rs ${net.abs().toStringAsFixed(0)}.';

    final message = Uri.encodeComponent('Hi ${contact.name}, eKhaata reminder. $amountText');
    final cleanPhone = contact.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final whatsapp = Uri.parse('https://wa.me/$cleanPhone?text=$message');
    final sms = Uri.parse('sms:$cleanPhone?body=$message');

    if (await canLaunchUrl(whatsapp)) {
      await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
      return;
    }

    if (await canLaunchUrl(sms)) {
      await launchUrl(sms, mode: LaunchMode.externalApplication);
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No messaging app found.')));
    }
  }

  void showTimeline(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _TimelineSheet(contact: contact, db: db),
    );
  }

  Future<void> confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete eKhaata?'),
        content: Text('This will permanently remove ${contact.name} and all transaction history.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await db.deleteKhaataContact(contact.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final net = contact.totalToTake - contact.totalToGive;
    final statusText = net == 0 
      ? 'Settled' 
      : net > 0 
        ? 'They owe: Rs ${net.abs().toStringAsFixed(0)}' 
        : 'You owe: Rs ${net.abs().toStringAsFixed(0)}';
    
    final statusColor = net == 0 ? AppColors.muted : net > 0 ? AppColors.green : AppColors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card, 
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.1)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        collapsedIconColor: AppColors.muted,
        iconColor: AppColors.primaryLight,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.17),
          child: Text(
            contact.name.isEmpty ? '?' : contact.name[0].toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        title: Row(
          children: [
            Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w900)),
            if (contact.isShared) ...[
              const SizedBox(width: 8),
              const Icon(Icons.people_rounded, size: 14, color: AppColors.muted),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.w800),
          ),
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Record',
                  icon: Icons.add_circle_outline_rounded,
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => AddKhaataTransactionSheet(contactId: contact.id),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Timeline',
                  icon: Icons.timeline_rounded,
                  onTap: () => showTimeline(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  label: 'Settle',
                  icon: Icons.done_all_rounded,
                  onTap: () => db.settleContact(contact.id),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => confirmDelete(context),
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
          if (contact.phoneNumber.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label: 'Send Reminder',
                icon: Icons.message_rounded,
                onTap: () => sendReminder(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, overflow: TextOverflow.ellipsis),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class _TimelineSheet extends StatelessWidget {
  final KhaataContact contact;
  final DatabaseService db;

  const _TimelineSheet({required this.contact, required this.db});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: StreamBuilder<List<KhaataTransaction>>(
        stream: db.khaataTransactionsStream(contact.id),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${contact.name} Timeline', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 18),
              if (items.isEmpty)
                const EmptyState(title: 'No records', subtitle: 'No transactions found.')
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final tx = items[index];
                      final isTake = tx.type == KhaataTransactionType.take;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface, 
                          borderRadius: BorderRadius.circular(18),
                          border: tx.isSettled ? null : Border.all(color: (isTake ? AppColors.green : AppColors.red).withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: tx.isSettled 
                                ? AppColors.muted.withValues(alpha: 0.1)
                                : isTake
                                  ? AppColors.green.withValues(alpha: 0.15)
                                  : AppColors.red.withValues(alpha: 0.15),
                              child: Icon(
                                isTake ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: tx.isSettled ? AppColors.muted : (isTake ? AppColors.green : AppColors.red),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isTake ? 'I Took (Loan)' : 'I Gave (Credit)', 
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      decoration: tx.isSettled ? TextDecoration.lineThrough : null,
                                      color: tx.isSettled ? AppColors.muted : null,
                                    )
                                  ),
                                  Text(
                                    DateFormat('MMM d, yyyy').format(tx.date),
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                                  ),
                                  if (tx.notes.isNotEmpty)
                                    Text(tx.notes, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                ],
                              ),
                            ),
                            Text(
                              'Rs ${tx.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: tx.isSettled ? AppColors.muted : (isTake ? AppColors.green : AppColors.red),
                                fontWeight: FontWeight.w900,
                                decoration: tx.isSettled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
