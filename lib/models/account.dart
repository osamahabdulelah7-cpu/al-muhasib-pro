enum AccountType { asset, liability, equity, income, expense }

class Account {
  const Account({
    this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentId,
    this.isActive = true,
  });

  final int? id;
  final String code;
  final String name;
  final AccountType type;
  final int? parentId;
  final bool isActive;

  Map<String, Object?> toMap() => {
    'id': id,
    'code': code,
    'name': name,
    'type': type.name,
    'parent_id': parentId,
    'is_active': isActive ? 1 : 0,
  };

  factory Account.fromMap(Map<String, Object?> map) => Account(
    id: map['id'] as int?,
    code: map['code'] as String,
    name: map['name'] as String,
    type: AccountType.values.firstWhere(
      (type) => type.name == map['type'],
      orElse: () => AccountType.asset,
    ),
    parentId: map['parent_id'] as int?,
    isActive: (map['is_active'] as int? ?? 1) == 1,
  );
}
