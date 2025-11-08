import 'dart:io';
import 'dart:typed_data';

import 'package:bb.flutter/bb.dart';

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
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
