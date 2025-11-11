import 'dart:io';
import 'dart:typed_data';

import 'package:bb.flutter/bb.dart';
import 'package:collection/collection.dart';

import '../bb_samba.dart';

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
abstract class GenericFile {
  String get path;
  String get name;
  bool get isDirectory;
  int get size;
  Future<Iterable<GenericFile>> listFiles();
  String get mimeType;
  Future<RandomAccessFile> open({FileMode mode = FileMode.read});
  Future<Stream<Uint8List>> openRead([int? start, int? end]);
  String get uri;
  String get folder => path.beforeTokenLast('/').afterTokenLast('/');
  String get fullName => '$folder/$name';
  Future<bool> exists();
  @override
  bool operator ==(Object other) => other is GenericFile && other.uri == uri;
  @override
  int get hashCode => uri.hashCode;
  static Future<GenericFile> from({required String uri}) async {
    final u = Uri.parse(uri);
    switch (u.scheme) {
      case 'smb':
        final path =
            '/${uri.substring('smb://'.length).afterToken('/').decodedUri}';
        final service = Network.services.firstWhereOrNull(
          (s) => s.name == u.host,
        );
        if (service == null) {
          throw StateError('No samba service named ${u.host}');
        }
        return await service.file(path);
      case 'file':
        final path = uri.substring('file:/'.length).decodedUri;
        return DeviceFile(entity: File(path));
    }
    throw UnimplementedError('Unknown uri scheme ${u.scheme}://');
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
