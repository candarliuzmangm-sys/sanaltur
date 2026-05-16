// GENERATED PLACEHOLDER — run: dart run build_runner build
part of 'upload_task_model.dart';

class UploadTaskModelAdapter extends TypeAdapter<UploadTaskModel> {
  @override
  final int typeId = 1;

  @override
  UploadTaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UploadTaskModel(
      id: fields[0] as String,
      propertyId: fields[1] as String,
      roomId: fields[2] as String,
      localPath: fields[3] as String,
      mimeType: fields[4] as String,
      fileName: fields[5] as String,
      status: fields[6] as UploadStatus,
      progress: fields[7] as double,
      remoteKey: fields[8] as String?,
      errorMessage: fields[9] as String?,
      createdAt: fields[10] as DateTime?,
      mediaType: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UploadTaskModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.propertyId)
      ..writeByte(2)
      ..write(obj.roomId)
      ..writeByte(3)
      ..write(obj.localPath)
      ..writeByte(4)
      ..write(obj.mimeType)
      ..writeByte(5)
      ..write(obj.fileName)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.progress)
      ..writeByte(8)
      ..write(obj.remoteKey)
      ..writeByte(9)
      ..write(obj.errorMessage)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.mediaType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadTaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UploadStatusAdapter extends TypeAdapter<UploadStatus> {
  @override
  final int typeId = 0;

  @override
  UploadStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UploadStatus.pending;
      case 1:
        return UploadStatus.uploading;
      case 2:
        return UploadStatus.completed;
      case 3:
        return UploadStatus.failed;
      default:
        return UploadStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, UploadStatus obj) {
    switch (obj) {
      case UploadStatus.pending:
        writer.writeByte(0);
      case UploadStatus.uploading:
        writer.writeByte(1);
      case UploadStatus.completed:
        writer.writeByte(2);
      case UploadStatus.failed:
        writer.writeByte(3);
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
