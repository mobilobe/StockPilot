// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_line_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SaleLineItemAdapter extends TypeAdapter<SaleLineItem> {
  @override
  final int typeId = 2;

  @override
  SaleLineItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleLineItem(
      quantity: fields[0] as int,
      unitPrice: fields[1] as double,
      source: fields[2] as String,
      orderItem: fields[3] as InventoryOrderItem?,
    );
  }

  @override
  void write(BinaryWriter writer, SaleLineItem obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.quantity)
      ..writeByte(1)
      ..write(obj.unitPrice)
      ..writeByte(2)
      ..write(obj.source)
      ..writeByte(3)
      ..write(obj.orderItem);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleLineItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
