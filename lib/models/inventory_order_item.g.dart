// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_order_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryOrderItemAdapter extends TypeAdapter<InventoryOrderItem> {
  @override
  final int typeId = 1;

  @override
  InventoryOrderItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryOrderItem(
      fields[0] as InventoryItem,
      fields[1] as int,
      fields[2] as double,
      fields[3] as double,
      fields[4] as int,
      selectedVariant: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryOrderItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.inventoryItem)
      ..writeByte(1)
      ..write(obj.quantity)
      ..writeByte(2)
      ..write(obj.price)
      ..writeByte(3)
      ..write(obj.shippedPrice)
      ..writeByte(4)
      ..write(obj.currentQuantity)
      ..writeByte(5)
      ..write(obj.selectedVariant);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryOrderItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
