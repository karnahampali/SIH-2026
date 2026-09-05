// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'issued_document.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IssuedDocumentAdapter extends TypeAdapter<IssuedDocument> {
  @override
  final int typeId = 0;

  @override
  IssuedDocument read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IssuedDocument()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..dob = fields[2] as String
      ..idNumber = fields[3] as String
      ..nationality = fields[4] as String
      ..expiry = fields[5] as String
      ..docType = fields[6] as String
      ..photoPath = fields[7] as String
      ..photoHash = fields[8] as String
      ..combinedHash = fields[9] as String
      ..signature = fields[10] as String
      ..publicKeyBase64 = fields[11] as String
      ..issuedAt = fields[12] as DateTime
      ..issuingAuthority = fields[13] as String;
  }

  @override
  void write(BinaryWriter writer, IssuedDocument obj) {
    writer
      ..writeByte(14)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dob)
      ..writeByte(3)
      ..write(obj.idNumber)
      ..writeByte(4)
      ..write(obj.nationality)
      ..writeByte(5)
      ..write(obj.expiry)
      ..writeByte(6)
      ..write(obj.docType)
      ..writeByte(7)
      ..write(obj.photoPath)
      ..writeByte(8)
      ..write(obj.photoHash)
      ..writeByte(9)
      ..write(obj.combinedHash)
      ..writeByte(10)
      ..write(obj.signature)
      ..writeByte(11)
      ..write(obj.publicKeyBase64)
      ..writeByte(12)
      ..write(obj.issuedAt)
      ..writeByte(13)
      ..write(obj.issuingAuthority);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IssuedDocumentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
