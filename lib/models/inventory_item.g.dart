// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryItemAdapter extends TypeAdapter<InventoryItem> {
  @override
  final int typeId = 0;

  @override
  InventoryItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryItem(
      fields[0] as String,
      fields[1] as double,
      fields[2] as int,
      fields[3] as int,
      fields[4] as String,
      fields[5] as String,
      (fields[6] as List).cast<Order>(),
      (fields[7] as List).cast<Sale>(),
      (fields[8] ?? 'Uncategorized').toString(),
      hasVariants: fields[9] as bool? ?? false,
      variantValues: (fields[11] as List?)?.cast<String>() ?? <String>[],
      variantStock:
          (fields[12] as Map?)?.map(
            (key, value) => MapEntry(
              key.toString(),
              value is num ? value.toInt() : int.tryParse('$value') ?? 0,
            ),
          ) ??
          <String, int>{},
    );
  }

  @override
  void write(BinaryWriter writer, InventoryItem obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.inventoryCount)
      ..writeByte(3)
      ..write(obj.soldCount)
      ..writeByte(4)
      ..write(obj.sku)
      ..writeByte(5)
      ..write(obj.id)
      ..writeByte(6)
      ..write(obj.orderList)
      ..writeByte(7)
      ..write(obj.salesList)
      ..writeByte(8)
      ..write(obj.folder)
      ..writeByte(9)
      ..write(obj.hasVariants)
      ..writeByte(11)
      ..write(obj.variantValues)
      ..writeByte(12)
      ..write(obj.variantStock);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
