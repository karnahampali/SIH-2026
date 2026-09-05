// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanRecordAdapter extends TypeAdapter<ScanRecord> {
  @override
  final int typeId = 1;

  @override
  ScanRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanRecord()
      ..id = fields[0] as String
      ..documentId = fields[1] as String
      ..scannedAt = fields[2] as DateTime
      ..officerNote = fields[3] as String
      ..docIntegrityScore = fields[4] as double
      ..photoMatchScore = fields[5] as double
      ..faceMatchScore = fields[6] as double
      ..livenessScore = fields[7] as double
      ..dbStatusScore = fields[8] as double
      ..riskScore = fields[9] as double
      ..riskLevel = fields[10] as String
      ..action = fields[11] as String
      ..docIntegrityReason = fields[12] as String
      ..photoMatchReason = fields[13] as String
      ..faceMatchReason = fields[14] as String
      ..livenessReason = fields[15] as String
      ..dbStatusReason = fields[16] as String
      ..liveFacePhotoPath = fields[17] as String
      ..faceEmbedding = fields[18] as String
      ..documentName = fields[19] as String
      ..documentType = fields[20] as String;
  }

  @override
  void write(BinaryWriter writer, ScanRecord obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.documentId)
      ..writeByte(2)
      ..write(obj.scannedAt)
      ..writeByte(3)
      ..write(obj.officerNote)
      ..writeByte(4)
      ..write(obj.docIntegrityScore)
      ..writeByte(5)
      ..write(obj.photoMatchScore)
      ..writeByte(6)
      ..write(obj.faceMatchScore)
      ..writeByte(7)
      ..write(obj.livenessScore)
      ..writeByte(8)
      ..write(obj.dbStatusScore)
      ..writeByte(9)
      ..write(obj.riskScore)
      ..writeByte(10)
      ..write(obj.riskLevel)
      ..writeByte(11)
      ..write(obj.action)
      ..writeByte(12)
      ..write(obj.docIntegrityReason)
      ..writeByte(13)
      ..write(obj.photoMatchReason)
      ..writeByte(14)
      ..write(obj.faceMatchReason)
      ..writeByte(15)
      ..write(obj.livenessReason)
      ..writeByte(16)
      ..write(obj.dbStatusReason)
      ..writeByte(17)
      ..write(obj.liveFacePhotoPath)
      ..writeByte(18)
      ..write(obj.faceEmbedding)
      ..writeByte(19)
      ..write(obj.documentName)
      ..writeByte(20)
      ..write(obj.documentType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
