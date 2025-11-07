import 'dart:io';
import 'dart:typed_data';

import 'package:bb.flutter/bb.dart';
import 'package:mime_type/mime_type.dart';

import 'file.generic.dart';

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class DeviceFile extends GenericFile {
  final FileSystemEntity entity;
  @override
  String get path => entity.path;
  @override
  String get name => entity.path.afterTokenLast(Platform.pathSeparator);
  @override
  bool get isDirectory => entity is Directory;
  @override
  String get mimeType =>
      mimeFromExtension(entity.path.fileExt()) ?? 'application/data';
  @override
  int get size => (entity as File).lengthSync();
  DeviceFile({required this.entity});
  @override
  Future<Iterable<GenericFile>> listFiles() async {
    final List<DeviceFile> files = [];
    if (entity is Directory) {
      final d = entity as Directory;
      await for (final e in d.list()) {
        files.add(DeviceFile(entity: e));
      }
    }
    return files;
  }

  @override
  Future<bool> exists() async {
    return await entity.exists();
  }

  @override
  Future<Stream<Uint8List>> openRead([int? start, int? end]) async {
    return (entity as File)
        .openRead(start, end)
        .map((s) => Uint8List.fromList(s));
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
    return await (entity as File).open();
  }

  @override
  String get uri => 'file:/$path';
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
