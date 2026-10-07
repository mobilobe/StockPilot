// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 4;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      fields[0] as DateTime,
      (fields[1] as List).cast<InventoryOrderItem>(),
      fields[2] as double,
      fields[3] as double,
      fields[4] as double,
      (fields[5] as String?) ?? 'Uncategorized',
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.inventoryList)
      ..writeByte(2)
      ..write(obj.shipping)
      ..writeByte(3)
      ..write(obj.fees)
      ..writeByte(4)
      ..write(obj.totalOrderPrice)
      ..writeByte(5)
      ..write(obj.folder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
