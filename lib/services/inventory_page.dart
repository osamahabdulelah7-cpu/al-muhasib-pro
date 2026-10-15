import 'package:flutter/material.dart';
import 'inventory_service.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _service = InventoryService.instance;
  int _section = 0;
  bool _busy = false;
  String? _error;
  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; });
    try { await action(); }
    catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _busy = false);
  }
  Future<void> _addProduct() async {
    final sku=TextEditingController(), name=TextEditingController(), category=TextEditingController(), price=TextEditingController(), cost=TextEditingController();
    final form=GlobalKey<FormState>();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('إضافة صنف'),
      content:Form(key:form,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:sku,decoration:const InputDecoration(labelText:'رمز الصنف *'),validator:(v)=>v==null||v.trim().isEmpty?'مطلوب':null),
        TextFormField(controller:name,decoration:const InputDecoration(labelText:'اسم الصنف *'),validator:(v)=>v==null||v.trim().isEmpty?'مطلوب':null),
        TextFormField(controller:category,decoration:const InputDecoration(labelText:'التصنيف')),
        TextFormField(controller:cost,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'تكلفة الوحدة بالريال'),validator:(v)=>v!=null&&(int.tryParse(v)??-1)>=0?null:'أدخل رقمًا صحيحًا'),
        TextFormField(controller:price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'سعر البيع بالريال'),validator:(v)=>v!=null&&(int.tryParse(v)??-1)>=0?null:'أدخل رقمًا صحيحًا'),
      ]))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>form.currentState!.validate()?Navigator.pop(ctx,true):null,child:const Text('حفظ')],
    ));
    if(ok==true) await _run(() async { await _service.saveProduct(sku:sku.text,name:name.text,category:category.text,costMinor:(int.parse(cost.text)*100),priceMinor:(int.parse(price.text)*100)); });
    sku.dispose(); name.dispose(); category.dispose(); price.dispose(); cost.dispose();
  }
  Future<void> _addWarehouse() async {
    final name=TextEditingController(), location=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('إضافة مخزن'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'اسم المخزن')),
      TextField(controller:location,decoration:const InputDecoration(labelText:'الموقع')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
    if(ok==true) await _run(() async { await _service.addWarehouse(name.text,location:location.text); });
    name.dispose(); location.dispose();
  }
  Future<void> _addParty() async {
    final name=TextEditingController(), phone=TextEditingController();
    String kind='customer';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setD)=>AlertDialog(title:const Text('إضافة عميل أو مورد'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:const InputDecoration(labelText:'الاسم')),
      TextField(controller:phone,decoration:const InputDecoration(labelText:'الهاتف')),
      DropdownButtonFormField<String>(value:kind,items:const [DropdownMenuItem(value:'customer',child:Text('عميل')),DropdownMenuItem(value:'supplier',child:Text('مورد')),DropdownMenuItem(value:'both',child:Text('عميل ومورد'))],onChanged:(v)=>setD(()=>kind=v??'customer')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))])));
    if(ok==true) await _run(() async { await _service.saveParty(name:name.text,kind:kind,phone:phone.text); });
    name.dispose(); phone.dispose();
  }
  @override
  Widget build(BuildContext context) => Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
      ChoiceChip(label:const Text('الأصناف والمخزون'),selected:_section==0,onSelected:(_)=>setState(()=>_section=0)),
      const SizedBox(width:6),ChoiceChip(label:const Text('المخازن'),selected:_section==1,onSelected:(_)=>setState(()=>_section=1)),
      const SizedBox(width:6),ChoiceChip(label:const Text('العملاء والموردون'),selected:_section==2,onSelected:(_)=>setState(()=>_section=2)),
      const SizedBox(width:6),ChoiceChip(label:const Text('فواتير البيع والشراء'),selected:_section==3,onSelected:(_)=>setState(()=>_section=3)),
    ]))),
    if(_busy) const LinearProgressIndicator(),
    if(_error!=null) Padding(padding:const EdgeInsets.all(8),child:Text('تعذر التنفيذ: $_error',style:const TextStyle(color:Colors.red))),
    Expanded(child:FutureBuilder<List<Map<String,Object?>>>(
      key:ValueKey(_section),
      future:_section==0?_service.stock():_section==1?_service.warehouses():_section==2?_service.parties():_service.documents(),
      builder:(context,snapshot){
        if(snapshot.connectionState==ConnectionState.waiting)return const Center(child:CircularProgressIndicator());
        if(snapshot.hasError)return Center(child:Text('تعذر تحميل البيانات: ${snapshot.error}'));
        final rows=snapshot.data??[];
        if(rows.isEmpty)return Center(child:Text(_section==0?'أضف أصنافًا لتبدأ إدارة المخزون':_section==1?'لا توجد مخازن':'لا توجد سجلات بعد'));
        return ListView.builder(itemCount:rows.length,itemBuilder:(context,i){
          final r=rows[i];
          if(_section==0){
            final qty=(r['quantity_milli'] as int)/1000;
            final low=qty<=(r['low_stock_milli'] as int)/1000;
            return ListTile(leading:Icon(Icons.inventory_2_outlined,color:low?Colors.deepOrange:Colors.teal),title:Text('${r['name']}'),subtitle:Text('رمز: ${r['sku']} • ${r['warehouse_name']}\nالكمية: ${qty.toStringAsFixed(3)} ${r['unit']} • التصنيف: ${r['category']}'),isThreeLine:true,trailing:IconButton(tooltip:'تعديل المخزون',icon:const Icon(Icons.tune),onPressed:()=>_adjust(r)));
          }
          if(_section==1)return ListTile(leading:const Icon(Icons.warehouse_outlined),title:Text('${r['name']}'),subtitle:Text('${r['location']??''}'));
          if(_section==2)return ListTile(leading:const Icon(Icons.people_outline),title:Text('${r['name']}'),subtitle:Text('${r['kind']} • ${r['phone']}'));
          return ListTile(leading:const Icon(Icons.receipt_long),title:Text('${r['number']}'),subtitle:Text('${r['kind']} • ${r['document_date']}'),trailing:Text('${((r['total_minor'] as int)/100).toStringAsFixed(2)}'));
        });
      },
    )),
    if(_section<3) Padding(padding:const EdgeInsets.all(12),child:Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:_section==0?_addProduct:_section==1?_addWarehouse:_addParty,icon:const Icon(Icons.add),label:Text(_section==0?'إضافة صنف':_section==1?'إضافة مخزن':'إضافة عميل/مورد')))),
  ]);

  Future<void> _adjust(Map<String,Object?> row) async {
    final qty=TextEditingController();
    final reason=TextEditingController(text:'تسوية مخزون');
    final warehouses=await _service.warehouses();
    if(!mounted||warehouses.isEmpty)return;
    int warehouseId=row['warehouse_id'] as int;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('تسوية مخزون: ${row['name']}'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<int>(value:warehouseId,items:warehouses.map((w)=>DropdownMenuItem(value:w['id'] as int,child:Text('${w['name']}'))).toList(),onChanged:(v)=>warehouseId=v??warehouseId,decoration:const InputDecoration(labelText:'المخزن')),
      TextField(controller:qty,keyboardType:const TextInputType.numberWithOptions(decimal:true,signed:true),decoration:const InputDecoration(labelText:'الكمية (+ إضافة، - صرف)')),
      TextField(controller:reason,decoration:const InputDecoration(labelText:'السبب')),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
    if(ok==true){
      final parsed=double.tryParse(qty.text.trim());
      if(parsed==null){setState(()=>_error='أدخل كمية صحيحة');}
      else await _run(() async {await _service.adjustStock(productId:row['product_id'] as int,warehouseId:warehouseId,quantityMilli:(parsed*1000).round(),reason:reason.text);});
    }
    qty.dispose();reason.dispose();
    if(mounted)setState((){});
  }
}
