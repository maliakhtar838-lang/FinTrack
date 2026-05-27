import 'package:cloud_firestore/cloud_firestore.dart';

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _toDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

enum AccountType { cash, bank, wallet }

enum MoneyTransactionType { income, expense, transfer }

enum KhaataTransactionType { give, take }

AccountType accountTypeFromString(String? value) {
  return AccountType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AccountType.wallet,
  );
}

MoneyTransactionType moneyTransactionTypeFromString(String? value) {
  return MoneyTransactionType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MoneyTransactionType.expense,
  );
}

KhaataTransactionType khaataTransactionTypeFromString(String? value) {
  return KhaataTransactionType.values.firstWhere(
    (e) => e.name == value,
    orElse: () => KhaataTransactionType.give,
  );
}

class UserProfile {
  final String uid;
  final String email;
  final double totalBalance;
  final double savingsTarget;

  const UserProfile({
    required this.uid,
    required this.email,
    required this.totalBalance,
    this.savingsTarget = 0,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'totalBalance': totalBalance,
        'savingsTarget': savingsTarget,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      totalBalance: _toDouble(map['totalBalance']),
      savingsTarget: _toDouble(map['savingsTarget']),
    );
  }
}

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'balance': balance,
      };

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: accountTypeFromString(map['type']),
      balance: _toDouble(map['balance']),
    );
  }
}

class MoneyTransaction {
  final String id;
  final String accountId;
  final MoneyTransactionType type;
  final double amount;
  final String category;
  final DateTime date;
  final String notes;

  const MoneyTransaction({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    required this.notes,
  });

  MoneyTransaction copyWith({
    String? id,
    String? accountId,
    MoneyTransactionType? type,
    double? amount,
    String? category,
    DateTime? date,
    String? notes,
  }) {
    return MoneyTransaction(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'accountId': accountId,
        'type': type.name,
        'amount': amount,
        'category': category,
        'date': Timestamp.fromDate(date),
        'notes': notes,
      };

  factory MoneyTransaction.fromMap(Map<String, dynamic> map) {
    return MoneyTransaction(
      id: map['id'] ?? '',
      accountId: map['accountId'] ?? '',
      type: moneyTransactionTypeFromString(map['type']),
      amount: _toDouble(map['amount']),
      category: map['category'] ?? '',
      date: _toDate(map['date']),
      notes: map['notes'] ?? '',
    );
  }
}

class Budget {
  final String id;
  final String category;
  final double limitAmount;
  final double currentSpent;

  const Budget({
    required this.id,
    required this.category,
    required this.limitAmount,
    required this.currentSpent,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category': category,
        'limitAmount': limitAmount,
        'currentSpent': currentSpent,
      };

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'] ?? '',
      category: map['category'] ?? '',
      limitAmount: _toDouble(map['limitAmount']),
      currentSpent: _toDouble(map['currentSpent']),
    );
  }
}

class ScheduledEvent {
  final String id;
  final String title;
  final double expectedCost;
  final DateTime date;
  final bool isCompleted;

  const ScheduledEvent({
    required this.id,
    required this.title,
    required this.expectedCost,
    required this.date,
    required this.isCompleted,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'expectedCost': expectedCost,
        'date': Timestamp.fromDate(date),
        'isCompleted': isCompleted,
      };

  factory ScheduledEvent.fromMap(Map<String, dynamic> map) {
    return ScheduledEvent(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      expectedCost: _toDouble(map['expectedCost']),
      date: _toDate(map['date']),
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}

class Subscription {
  final String id;
  final String name;
  final double cost;
  final DateTime dueDate;
  final bool isNotificationOn;
  final bool isAuto;

  const Subscription({
    required this.id,
    required this.name,
    required this.cost,
    required this.dueDate,
    required this.isNotificationOn,
    this.isAuto = false,
  });

  Subscription copyWith({
    String? id,
    String? name,
    double? cost,
    DateTime? dueDate,
    bool? isNotificationOn,
    bool? isAuto,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      dueDate: dueDate ?? this.dueDate,
      isNotificationOn: isNotificationOn ?? this.isNotificationOn,
      isAuto: isAuto ?? this.isAuto,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'cost': cost,
        'dueDate': Timestamp.fromDate(dueDate),
        'isNotificationOn': isNotificationOn,
        'isAuto': isAuto,
      };

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      cost: _toDouble(map['cost']),
      dueDate: _toDate(map['date'] ?? map['dueDate']),
      isNotificationOn: map['isNotificationOn'] ?? true,
      isAuto: map['isAuto'] ?? false,
    );
  }
}

class KhaataContact {
  final String id;
  final String name;
  final String phoneNumber;
  final double totalToGive;
  final double totalToTake;
  final List<String> participants;
  final bool isShared;

  const KhaataContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.totalToGive,
    required this.totalToTake,
    this.participants = const [],
    this.isShared = false,
  });

  KhaataContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    double? totalToGive,
    double? totalToTake,
    List<String>? participants,
    bool? isShared,
  }) {
    return KhaataContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      totalToGive: totalToGive ?? this.totalToGive,
      totalToTake: totalToTake ?? this.totalToTake,
      participants: participants ?? this.participants,
      isShared: isShared ?? this.isShared,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phoneNumber': phoneNumber,
        'totalToGive': totalToGive,
        'totalToTake': totalToTake,
        'participants': participants,
        'isShared': isShared,
      };

  factory KhaataContact.fromMap(Map<String, dynamic> map) {
    return KhaataContact(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      totalToGive: _toDouble(map['totalToGive']),
      totalToTake: _toDouble(map['totalToTake']),
      participants: List<String>.from(map['participants'] ?? []),
      isShared: map['isShared'] ?? false,
    );
  }
}

class KhaataTransaction {
  final String id;
  final String contactId;
  final KhaataTransactionType type;
  final double amount;
  final DateTime date;
  final String notes;
  final bool isSettled;

  const KhaataTransaction({
    required this.id,
    required this.contactId,
    required this.type,
    required this.amount,
    required this.date,
    required this.notes,
    required this.isSettled,
  });

  KhaataTransaction copyWith({
    String? id,
    String? contactId,
    KhaataTransactionType? type,
    double? amount,
    DateTime? date,
    String? notes,
    bool? isSettled,
  }) {
    return KhaataTransaction(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      isSettled: isSettled ?? this.isSettled,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'contactId': contactId,
        'type': type.name,
        'amount': amount,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'isSettled': isSettled,
      };

  factory KhaataTransaction.fromMap(Map<String, dynamic> map) {
    return KhaataTransaction(
      id: map['id'] ?? '',
      contactId: map['contactId'] ?? '',
      type: khaataTransactionTypeFromString(map['type']),
      amount: _toDouble(map['amount']),
      date: _toDate(map['date']),
      notes: map['notes'] ?? '',
      isSettled: map['isSettled'] ?? false,
    );
  }
}
