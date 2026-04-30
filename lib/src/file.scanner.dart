import 'dart:async';
import 'dart:io';

import 'package:bb.flutter/bb.dart';
import 'package:bb_dart/bb_dart.dart';
import 'package:bb_samba/bb_samba.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class FileScanner {
  final scanning = EventValue<bool>(false);
  final Set<StorageLocation> storages;
  final Future<void> Function(GenericFile file) onFile;
  final Set<String> extensions;
  final List<GenericFile> files = [];
  String? debugUri;
  bool disposed = false;
  bool running = true;
  FileScanner({
    required Iterable<String> extensions,
    required this.onFile,
    this.storages = StorageLocation.all,
    this.debugUri,
  }) : extensions = {...extensions} {
    launch();
    if (storages.contains(StorageLocation.network)) {
      Network.onUpdate.on(_onNetworkUpdate);
    }
  }
  void dispose() {
    Network.onUpdate.off(_onNetworkUpdate);
    disposed = true;
  }

  void run() => running = true;
  void pause() => running = false;

  Future<void> _onNetworkUpdate(ServiceEvent se) async {
    final smb = se.service;
    Debug.info('🔍 service update $se');
    switch (se.event) {
      case ServiceEventType.discovered:
        Debug.info('🔍 $smb discovered');
        break;
      case ServiceEventType.connected:
        if (debugUri != null) {
          try {
            final file = await GenericFile.from(uri: debugUri!);
            files.add(file);
            debugUri = null;
          } catch (_) {}
        } else {
          files.addAll(smb.shares);
        }
        Debug.info('🔍 $smb connected, added ${smb.shares.length} shares');
        break;
      case ServiceEventType.disconnected:
        files.removeWhere((f) => f is SambaFile && f.service == smb);
        Debug.info('🔍 $smb disconnect');
        break;
      case ServiceEventType.lost:
        Debug.info('🔍 $smb lost');
        break;
    }
  }

  Future<void> launch() async {
    if (debugUri != null) {
      try {
        final file = await GenericFile.from(uri: debugUri!);
        files.add(file);
        debugUri = null;
      } catch (_) {}
    } else if (storages.contains(StorageLocation.device)) {
      await addLocalFiles();
    }
    while (!disposed) {
      if (running) {
        if (files.isNotEmpty) {
          final f = files.first;
          files.removeAt(0);
          scanning.set(true);
          try {
            if (f.isDirectory) {
              try {
                final fl = await f.listFiles();
                files.insertAll(0, fl.shuffled());
                await BB.sleep(Duration(milliseconds: 100));
              } catch (error) {
                Debug.info('🔍📁 ${f.path} 🔥 $error');
              }
            } else if (extensions.contains(f.path.fileExt())) {
              await onFile(f);
            }
          } catch (error, stackTrace) {
            Debug.info('🔍 $error');
            Debug.info(stackTrace);
          }
        } else {
          await BB.sleep(Duration(seconds: 1));
        }
      } else {
        scanning.set(false);
        await BB.sleep(Duration(seconds: 5));
      }
    }
  }

  Future<void> addLocalFiles() async {
    if (Platform.isAndroid) {
      try {
        if (!(await Permission.storage.isGranted)) {
          await Permission.storage.request();
        }
        if (!(await Permission.manageExternalStorage.isGranted)) {
          await Permission.manageExternalStorage.request();
        }
      } catch (error) {
        Debug.warning(error);
      }
      final directory = Directory('/storage/emulated/0');
      files.add(DeviceFile(entity: directory));
      // TODO: add sdcard
      // https://android.stackexchange.com/questions/55481/how-can-i-determine-the-sd-cards-path
    }
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
enum StorageLocation {
  generic,
  device,
  network;

  IconData get icon {
    switch (this) {
      case StorageLocation.device:
        return Icons.phone_android;
      case StorageLocation.network:
        return Icons.device_hub;
      default:
        return Icons.question_answer;
    }
  }

  static StorageLocation from({GenericFile? file, String? uri}) {
    if (file is DeviceFile) {
      return device;
    } else if (file is SambaFile) {
      return network;
    }
    if (uri?.startsWith('file://') ?? false) {
      return .device;
    }
    if (uri?.startsWith('smb://') ?? false) {
      return .network;
    }
    return generic;
  }

  static const Set<StorageLocation> all = {...StorageLocation.values};
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
extension StorageLocationSet on Set<StorageLocation> {
  IconData? get icon {
    if (length == 1) {
      return first.icon;
    }
    return Icons.all_inclusive;
  }

  static List<Set<StorageLocation>> get all => [
    {StorageLocation.device, StorageLocation.network},
    {StorageLocation.device},
    {StorageLocation.network},
  ];
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
