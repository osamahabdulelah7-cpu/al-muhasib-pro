import 'package:sqflite/sqflite.dart';
import '../data/accounting_database.dart';

/// Offline inventory foundation. Quantities are stored in thousandths.
class InventoryService {
  InventoryService._();
  static final InventoryService instance = InventoryService._();
  bool _ready = false;

  Future<Database> get _db async {
    final db = await AccountingDatabase.instance.database;
    if (_ready) return db;
    await db.execute("CREATE TABLE IF NOT EXISTS warehouses(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL UNIQUE,location TEXT NOT NULL DEFAULT '',is_active INTEGER NOT NULL DEFAULT 1)");
    await db.execute("CREATE TABLE IF NOT EXISTS products(id INTEGER PRIMARY KEY AUTOINCREMENT,sku TEXT NOT NULL UNIQUE,barcode TEXT NOT NULL DEFAULT '',name TEXT NOT NULL,category TEXT NOT NULL DEFAULT '',unit TEXT NOT NULL DEFAULT 'قطعة',cost_minor INTEGER NOT NULL DEFAULT 0 CHECK(cost_minor>=0),price_minor INTEGER NOT NULL DEFAULT 0 CHECK(price_minor>=0),low_stock_milli INTEGER NOT NULL DEFAULT 0 CHECK(low_stock_milli>=0),is_active INTEGER NOT NULL DEFAULT 1)");
    await db.execute("CREATE TABLE IF NOT EXISTS stock_movements(id INTEGER PRIMARY KEY AUTOINCREMENT,product_id INTEGER NOT NULL REFERENCES products(id),warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),quantity_milli INTEGER NOT NULL CHECK(quantity_milli!=0),unit_cost_minor INTEGER NOT NULL DEFAULT 0 CHECK(unit_cost_minor>=0),reason TEXT NOT NULL,reference TEXT NOT NULL DEFAULT '',created_at TEXT NOT NULL)");
    await db.execute('CREATE INDEX IF NOT EXISTS idx_stock_product_warehouse ON stock_movements(product_id,warehouse_id)');
    await db.execute("CREATE TABLE IF NOT EXISTS parties(id INTEGER PRIMARY KEY AUTOINCREMENT,name TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('customer','supplier','both')),phone TEXT NOT NULL DEFAULT '',address TEXT NOT NULL DEFAULT '',opening_balance_minor INTEGER NOT NULL DEFAULT 0,is_active INTEGER NOT NULL DEFAULT 1)");
    await db.execute("CREATE TABLE IF NOT EXISTS sales_documents(id INTEGER PRIMARY KEY AUTOINCREMENT,number TEXT NOT NULL UNIQUE,kind TEXT NOT NULL CHECK(kind IN ('sale','purchase','sale_return','purchase_return')),party_id INTEGER REFERENCES parties(id),warehouse_id INTEGER NOT NULL REFERENCES warehouses(id),document_date TEXT NOT NULL,status TEXT NOT NULL DEFAULT 'posted' CHECK(status IN ('posted','void')),total_minor INTEGER NOT NULL CHECK(total_minor>=0),note TEXT NOT NULL DEFAULT '')");
    await db.execute('CREATE TABLE IF NOT EXISTS sales_document_lines(id INTEGER PRIMARY KEY AUTOINCREMENT,document_id INTEGER NOT NULL REFERENCES sales_documents(id) ON DELETE CASCADE,product_id INTEGER NOT NULL REFERENCES products(id),quantity_milli INTEGER NOT NULL CHECK(quantity_milli>0),unit_price_minor INTEGER NOT NULL CHECK(unit_price_minor>=0),line_total_minor INTEGER NOT NULL CHECK(line_total_minor>=0))');
    await db.insert('warehouses', {'name':'المخزن الرئيسي'}, conflictAlgorithm: ConflictAlgorithm.ignore);
    _ready = true;
    return db;
  }

  Future<List<Map<String,Object?>>> products() async => (await _db).query('products', where:'is_active=1', orderBy:'name COLLATE NOCASE');

  Future<int> saveProduct({int? id, required String sku, required String name, String barcode='', String category='', String unit='قطعة', int costMinor=0, int priceMinor=0, int lowStockMilli=0}) async {
    if (sku.trim().isEmpty || name.trim().isEmpty) throw ArgumentError('رمز الصنف واسم الصنف مطلوبان');
    if (costMinor<0 || priceMinor<0 || lowStockMilli<0) throw ArgumentError('القيم لا يمكن أن تكون سالبة');
    final values=<String,Object?>{'sku':sku.trim(),'name':name.trim(),'barcode':barcode.trim(),'category':category.trim(),'unit':unit.trim().isEmpty?'قطعة':unit.trim(),'cost_minor':costMinor,'price_minor':priceMinor,'low_stock_milli':lowStockMilli,'is_active':1};
    final db=await _db;
    if(id==null) return db.insert('products',values);
    return db.update('products',values,where:'id=?',whereArgs:[id]);
  }

  Future<List<Map<String,Object?>>> warehouses() async => (await _db).query('warehouses',where:'is_active=1',orderBy:'name');
  Future<int> addWarehouse(String name,{String location=''}) async {
    if(name.trim().isEmpty) throw ArgumentError('اسم المخزن مطلوب');
    return (await _db).insert('warehouses',{'name':name.trim(),'location':location.trim()});
  }

  Future<List<Map<String,Object?>>> stock({int? warehouseId}) async {
    final filter=warehouseId==null?'':' AND w.id=?';
    final args=warehouseId==null?<Object?>[]:<Object?>[warehouseId];
    return (await _db).rawQuery('''SELECT p.id AS product_id,p.sku,p.name,p.category,p.unit,p.cost_minor,p.price_minor,p.low_stock_milli,w.id AS warehouse_id,w.name AS warehouse_name,COALESCE(SUM(sm.quantity_milli),0) AS quantity_milli FROM products p CROSS JOIN warehouses w LEFT JOIN stock_movements sm ON sm.product_id=p.id AND sm.warehouse_id=w.id WHERE p.is_active=1 AND w.is_active=1 $filter GROUP BY p.id,w.id ORDER BY p.name,w.name''',args);
  }

  Future<void> adjustStock({required int productId,required int warehouseId,required int quantityMilli,required String reason,int unitCostMinor=0,String reference=''}) async {
    if(quantityMilli==0 || reason.trim().isEmpty || unitCostMinor<0) throw ArgumentError('تحقق من الكمية والسبب والتكلفة');
    final db=await _db;
    await db.transaction((txn) async {
      final p=await txn.query('products',where:'id=? AND is_active=1',whereArgs:[productId],limit:1);
      final w=await txn.query('warehouses',where:'id=? AND is_active=1',whereArgs:[warehouseId],limit:1);
      if(p.isEmpty || w.isEmpty) throw StateError('الصنف أو المخزن غير موجود');
      final q=await txn.rawQuery('SELECT COALESCE(SUM(quantity_milli),0) AS qty FROM stock_movements WHERE product_id=? AND warehouse_id=?',[productId,warehouseId]);
      if((q.first['qty'] as int)+quantityMilli<0) throw StateError('الكمية غير كافية في المخزن');
      await txn.insert('stock_movements',{'product_id':productId,'warehouse_id':warehouseId,'quantity_milli':quantityMilli,'unit_cost_minor':unitCostMinor,'reason':reason.trim(),'reference':reference.trim(),'created_at':DateTime.now().toIso8601String()});
    });
  }

  Future<List<Map<String,Object?>>> parties({String? kind}) async => (await _db).query('parties',where:kind==null?'is_active=1':'is_active=1 AND (kind=? OR kind=?)',whereArgs:kind==null?null:[kind,'both'],orderBy:'name COLLATE NOCASE');
  Future<int> saveParty({required String name,required String kind,String phone='',String address='',int openingBalanceMinor=0}) async {
    if(name.trim().isEmpty || !{'customer','supplier','both'}.contains(kind)) throw ArgumentError('تحقق من اسم الطرف ونوعه');
    return (await _db).insert('parties',{'name':name.trim(),'kind':kind,'phone':phone.trim(),'address':address.trim(),'opening_balance_minor':openingBalanceMinor});
  }

  Future<int> createDocument({required String number,required String kind,required int warehouseId,required List<({int productId,int quantityMilli,int unitPriceMinor})> lines,int? partyId,String note='',DateTime? date}) async {
    if(!{'sale','purchase','sale_return','purchase_return'}.contains(kind)||number.trim().isEmpty||lines.isEmpty) throw ArgumentError('نوع ورقم المستند والسطور مطلوبة');
    if(lines.any((l)=>l.quantityMilli<=0||l.unitPriceMinor<0)) throw ArgumentError('تحقق من الكميات والأسعار');
    final total=lines.fold<int>(0,(sum,l)=>sum+(l.quantityMilli*l.unitPriceMinor~/1000);
    final db=await _db;
    return db.transaction((txn) async {
      final id=await txn.insert('sales_documents',{'number':number.trim(),'kind':kind,'party_id':partyId,'warehouse_id':warehouseId,'document_date':(date??DateTime.now()).toIso8601String(),'status':'posted','total_minor':total,'note':note.trim()});
      final sign=(kind=='purchase'||kind=='sale_return')?1:-1;
      for(final l in lines) {
        final p=await txn.query('products',where:'id=? AND is_active=1',whereArgs:[l.productId],limit:1);
        if(p.isEmpty) throw StateError('أحد الأصناف غير موجود');
        final lineTotal=l.quantityMilli*l.unitPriceMinor~/1000;
        await txn.insert('sales_document_lines',{'document_id':id,'product_id':l.productId,'quantity_milli':l.quantityMilli,'unit_price_minor':l.unitPriceMinor,'line_total_minor':lineTotal});
        final q=await txn.rawQuery('SELECT COALESCE(SUM(quantity_milli),0) AS qty FROM stock_movements WHERE product_id=? AND warehouse_id=?',[l.productId,warehouseId]);
        final delta=l.quantityMilli*sign;
        if((q.first['qty'] as int)+delta<0) throw StateError('المخزون غير كافٍ للصنف');
        await txn.insert('stock_movements',{'product_id':l.productId,'warehouse_id':warehouseId,'quantity_milli':delta,'unit_cost_minor':l.unitPriceMinor,'reason':kind,'reference':number.trim(),'created_at':DateTime.now().toIso8601String()});
      }
      return id;
    });
  }

  Future<List<Map<String,Object?>>> documents() async => (await _db).query('sales_documents',orderBy:'document_date DESC,id DESC');
  Future<List<Map<String,Object?>>> lowStock() async {
    final rows=await stock();
    return rows.where((r)=>(r['quantity_milli'] as int)<=(r['low_stock_milli'] as int)).toList();
  }
}