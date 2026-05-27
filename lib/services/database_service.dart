import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_models.dart';

class DatabaseService {
  final String uid;
  final FirebaseFirestore _db;

  DatabaseService({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> get _accounts => _userDoc.collection('accounts');
  CollectionReference<Map<String, dynamic>> get _transactions => _userDoc.collection('transactions');
  CollectionReference<Map<String, dynamic>> get _budgets => _userDoc.collection('budgets');
  CollectionReference<Map<String, dynamic>> get _events => _userDoc.collection('scheduledEvents');
  CollectionReference<Map<String, dynamic>> get _subscriptions => _userDoc.collection('subscriptions');
  CollectionReference<Map<String, dynamic>> get _khaataContacts => _userDoc.collection('khaataContacts');
  CollectionReference<Map<String, dynamic>> get _khaataTransactions => _userDoc.collection('khaataTransactions');

  // Shared Ledger Support
  CollectionReference<Map<String, dynamic>> get _sharedKhaatas => _db.collection('sharedKhaatas');
  CollectionReference<Map<String, dynamic>> get _sharedTransactions => _db.collection('sharedTransactions');

  Stream<List<Account>> accountsStream() {
    return _accounts.snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => Account.fromMap({...doc.data(), 'id': doc.id})).toList(),
        );
  }

  Stream<List<MoneyTransaction>> transactionsStream({int limit = 30}) {
    return _transactions.orderBy('date', descending: true).limit(limit).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => MoneyTransaction.fromMap({...doc.data(), 'id': doc.id})).toList(),
        );
  }

  Stream<List<ScheduledEvent>> eventsStream() {
    return _events.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => ScheduledEvent.fromMap({...doc.data(), 'id': doc.id})).toList();
      items.sort((a, b) => a.date.compareTo(b.date));
      return items;
    });
  }

  Stream<List<Subscription>> subscriptionsStream() {
    return _subscriptions.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) => Subscription.fromMap({...doc.data(), 'id': doc.id})).toList();
      items.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return items;
    });
  }

  Stream<List<KhaataContact>> khaataContactsStream() {
    final controller = StreamController<List<KhaataContact>>();
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void update() async {
      final personal = await _khaataContacts.get(const GetOptions(source: Source.cache)).then(
          (s) => s.docs.map((doc) => KhaataContact.fromMap({...doc.data(), 'id': doc.id})).toList(),
          onError: (_) => <KhaataContact>[]);
      
      final shared = await _sharedKhaatas.where('participants', arrayContains: uid).get().then(
          (s) => s.docs.map((doc) => KhaataContact.fromMap({...doc.data(), 'id': doc.id})).toList(),
          onError: (_) => <KhaataContact>[]);

      if (!controller.isClosed) controller.add([...personal, ...shared]);
    }

    sub1 = _khaataContacts.snapshots().listen((_) => update());
    sub2 = _sharedKhaatas.where('participants', arrayContains: uid).snapshots().listen((_) => update());

    controller.onCancel = () {
      sub1?.cancel();
      sub2?.cancel();
    };

    return controller.stream;
  }

  Stream<List<KhaataTransaction>> khaataTransactionsStream(String contactId) {
    return _khaataTransactions.where('contactId', isEqualTo: contactId).snapshots().map((snap) {
      final items = snap.docs.map((doc) => KhaataTransaction.fromMap({...doc.data(), 'id': doc.id})).toList();
      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    });
  }

  Future<void> addAccount(Account account) async {
    final docRef = account.id.isEmpty ? _accounts.doc() : _accounts.doc(account.id);
    await docRef.set(account.copyWith(id: docRef.id).toMap());
    _syncTotalBalance();
  }

  Future<void> updateAccount(Account account) async {
    await _accounts.doc(account.id).set(account.toMap(), SetOptions(merge: true));
    _syncTotalBalance();
  }

  Future<void> deleteAccount(String accountId) async {
    await _accounts.doc(accountId).delete();
    _syncTotalBalance();
  }

  Future<void> addScheduledEvent(ScheduledEvent event) async {
    final docRef = event.id.isEmpty ? _events.doc() : _events.doc(event.id);
    await docRef.set({...event.toMap(), 'id': docRef.id});
  }

  Future<void> deleteScheduledEvent(String id) async {
    await _events.doc(id).delete();
  }

  Future<void> addSubscription(Subscription subscription) async {
    final docRef = subscription.id.isEmpty ? _subscriptions.doc() : _subscriptions.doc(subscription.id);
    await docRef.set(subscription.copyWith(id: docRef.id).toMap());
  }

  Future<void> deleteSubscription(String id) async {
    await _subscriptions.doc(id).delete();
  }

  Future<void> toggleSubscriptionNotification({required String subscriptionId, required bool enabled}) {
    return _subscriptions.doc(subscriptionId).update({'isNotificationOn': enabled});
  }

  Future<UserProfile?> findUserByEmail(String email) async {
    final snap = await _db.collection('users').where('email', isEqualTo: email.trim().toLowerCase()).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return UserProfile.fromMap({...snap.docs.first.data(), 'uid': snap.docs.first.id});
  }

  Future<void> createSharedKhaata(UserProfile otherUser) async {
    final docRef = _sharedKhaatas.doc();
    final contact = KhaataContact(
      id: docRef.id,
      name: otherUser.email.split('@').first,
      phoneNumber: '',
      totalToGive: 0,
      totalToTake: 0,
      participants: [uid, otherUser.uid],
      isShared: true,
    );
    await docRef.set(contact.toMap());
  }

  Future<void> addMoneyTransaction(MoneyTransaction transaction) async {
    final txRef = _transactions.doc();
    final accountRef = _accounts.doc(transaction.accountId);
    
    final delta = switch (transaction.type) {
      MoneyTransactionType.income => transaction.amount,
      _ => -transaction.amount,
    };

    final batch = _db.batch();
    batch.set(txRef, transaction.copyWith(id: txRef.id).toMap());
    batch.update(accountRef, {'balance': FieldValue.increment(delta)});
    
    await batch.commit();
    _syncTotalBalance();
  }

  Future<void> transferMoney({
    required String fromAccountId,
    required String toAccountId,
    required double amount,
    String notes = '',
  }) async {
    final outRef = _transactions.doc();
    final inRef = _transactions.doc();
    final fromRef = _accounts.doc(fromAccountId);
    final toRef = _accounts.doc(toAccountId);
    final now = DateTime.now();

    final batch = _db.batch();
    batch.set(outRef, MoneyTransaction(id: outRef.id, accountId: fromAccountId, type: MoneyTransactionType.transfer, amount: amount, category: 'Transfer Out', date: now, notes: notes).toMap());
    batch.set(inRef, MoneyTransaction(id: inRef.id, accountId: toAccountId, type: MoneyTransactionType.income, amount: amount, category: 'Transfer In', date: now, notes: notes).toMap());
    batch.update(fromRef, {'balance': FieldValue.increment(-amount)});
    batch.update(toRef, {'balance': FieldValue.increment(amount)});
    
    await batch.commit();
    _syncTotalBalance();
  }

  Future<void> addKhaataContact(KhaataContact contact) async {
    final docRef = contact.id.isEmpty ? _khaataContacts.doc() : _khaataContacts.doc(contact.id);
    await docRef.set(contact.copyWith(id: docRef.id).toMap());
  }

  Future<void> deleteKhaataContact(String contactId) async {
    // We try to delete from both collections just in case
    final batch = _db.batch();
    batch.delete(_khaataContacts.doc(contactId));
    batch.delete(_sharedKhaatas.doc(contactId));
    
    // Cleanup transactions
    final txs = await _khaataTransactions.where('contactId', isEqualTo: contactId).get();
    for (var doc in txs.docs) batch.delete(doc.reference);
    
    final stxs = await _sharedTransactions.where('contactId', isEqualTo: contactId).get();
    for (var doc in stxs.docs) batch.delete(doc.reference);

    await batch.commit();
  }

  Future<void> addKhaataTransaction(KhaataTransaction transaction) async {
    final isShared = (await _sharedKhaatas.doc(transaction.contactId).get()).exists;
    final txRef = isShared ? _sharedTransactions.doc() : _khaataTransactions.doc();
    final contactRef = isShared ? _sharedKhaatas.doc(transaction.contactId) : _khaataContacts.doc(transaction.contactId);

    final giveDelta = transaction.type == KhaataTransactionType.take ? transaction.amount : 0.0;
    final takeDelta = transaction.type == KhaataTransactionType.give ? transaction.amount : 0.0;

    final batch = _db.batch();
    batch.set(txRef, transaction.copyWith(id: txRef.id).toMap());
    batch.update(contactRef, {
      'totalToGive': FieldValue.increment(giveDelta),
      'totalToTake': FieldValue.increment(takeDelta),
    });
    
    await batch.commit();
  }

  Future<void> settleContact(String contactId) async {
    final isShared = (await _sharedKhaatas.doc(contactId).get()).exists;
    final contactRef = isShared ? _sharedKhaatas.doc(contactId) : _khaataContacts.doc(contactId);
    
    await contactRef.update({'totalToGive': 0, 'totalToTake': 0});
  }

  Future<void> updateSavingsTarget(double target) async {
    await _userDoc.set({'savingsTarget': target}, SetOptions(merge: true));
  }

  Stream<UserProfile> userProfileStream() {
    return _userDoc.snapshots().map((snap) => UserProfile.fromMap({...snap.data() ?? {}, 'uid': uid}));
  }

  Future<void> _syncTotalBalance() async {
    try {
      final snapshot = await _accounts.get();
      final total = snapshot.docs.fold<double>(0, (totalSum, doc) {
        final value = doc.data()['balance'];
        return value is num ? totalSum + value.toDouble() : totalSum;
      });
      await _userDoc.set({'totalBalance': total}, SetOptions(merge: true));
    } catch (_) {}
  }
}
