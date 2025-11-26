import 'dart:io';
import 'dart:typed_data';

import 'package:bb.flutter/bb.dart';
import 'package:mime_type/mime_type.dart';
import 'package:smb_connect/smb_connect.dart';

import 'file.generic.dart';
import 'network.dart';

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class SambaFile extends GenericFile {
  SambaService service;
  SmbFile file;
  SambaFile({required this.service, required this.file});

  @override
  String get name => file.name;
  @override
  String get path => file.path;
  String get uncPath => file.uncPath;
  String get share => file.share;

  int get createTime => file.createTime;
  int get lastModified => file.lastModified;
  int get lastAccess => file.lastAccess;
  @override
  int get size => file.size;
  bool get isExists => file.isExists;

  @override
  bool get isDirectory => file.isDirectory();
  bool get isFile => !isDirectory;
  bool get isArchive => file.isArchive();
  bool get isCompressed => file.isCompressed();
  bool get isHidden => file.isHidden();
  bool get isReadonly => file.isReadonly();
  bool get isSystem => file.isSystem();
  bool get isTemporary => file.isTemporary();
  bool get isVolume => file.isVolume();

  bool get canRead => file.canRead();
  bool get canWrite => file.canWrite();

  @override
  String get mimeType =>
      mimeFromExtension(name.fileExt()) ?? 'application/data';

  Future<void> delete() async {
      await service.smb?.delete(file);
  }

  @override
  Future<bool> exists() async {
      return file.canRead();
  }

  Future<SambaFile> rename(String dstPath, {bool replace = false}) async {
      final nfile = await service.smb!.rename(file, dstPath, replace: replace);
      return SambaFile(service: service, file: nfile);
  }

  @override
  Future<Stream<Uint8List>> openRead([int? start, int? end]) async {
      return await service.smb!.openRead(file, start, end);
  }

  Future<IOSink> openWrite({bool append = false}) async {
      return await service.smb!.openWrite(file, append: append);
  }

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async {
      return await service.smb!.open(file, mode: mode);
  }

  @override
  Future<Iterable<GenericFile>> listFiles() async {
      return (await service.smb!.listFiles(
        file,
      )).map((s) => SambaFile(file: s, service: service));
  }

  @override
  String get uri => 'smb://${service.name}${file.path}';
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
