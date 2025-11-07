import 'package:bb.flutter/bb.dart';
import 'package:bonsoir/bonsoir.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:smb_connect/src/exceptions.dart';

import 'file.samba.dart';

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class Network {
  static final type = '_smb._tcp';
  static final onUpdate = Event<ServiceEvent>();
  static BonsoirDiscovery discovery = BonsoirDiscovery(type: type);
  static Set<SambaService> services = {};
  static Future<void> initialize() async {
    await discovery.initialize();
    discovery.eventStream!.listen((event) async {
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          event.service.resolve(discovery.serviceResolver);
          break;
        case BonsoirDiscoveryServiceResolvedEvent():
          final smb = SambaService.fromBonsoir(event.service);
          services.add(smb);
          onUpdate.fire(
            ServiceEvent(service: smb, event: ServiceEventType.discovered),
          );
          smb.onConnect.on((_) {
            onUpdate.fire(
              ServiceEvent(service: smb, event: ServiceEventType.connected),
            );
          });
          smb.onDisconnected.on((_) async {
            onUpdate.fire(
              ServiceEvent(service: smb, event: ServiceEventType.disconnected),
            );
            await BB.sleep(Duration(milliseconds: 100));
            while (true) {
              try {
                if (services.contains(smb)) {
                  await smb.reconnect();
                }
                break;
              } catch (error) {
                Debug.warning(error);
              }
              await BB.sleep(Duration(seconds: 5));
            }
          });
          try {
            final json = await Store.read('cred.${smb.name}');
            final credentials = Credentials.fromJson(json);
            await smb.connect(credentials: credentials);
          } catch (error) {
            Debug.info('no saved credentials for ${smb.name}');
          }
          break;
        case BonsoirDiscoveryServiceUpdatedEvent():
          break;
        case BonsoirDiscoveryServiceLostEvent():
          final smb = services.firstWhereOrNull(
            (s) => s.name == event.service.name,
          );
          if (smb == null) return;
          services.remove(smb);
          onUpdate.fire(
            ServiceEvent(service: smb, event: ServiceEventType.lost),
          );
          break;
        case BonsoirDiscoveryStartedEvent():
          Debug.info('Bonsoir discovery started');
          break;
        default:
          Debug.info('Unknown bonsoir event occurred : $event.');
          break;
      }
    });
    await discovery.start();
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class SambaService {
  final onDisconnected = Event();
  final onConnect = Event();
  String get key => '$name.$host.$port';
  String name;
  String host;
  int port;
  SmbConnect? smb;
  Credentials? credentials;
  bool get isConnected => smb != null;
  List<SambaFile> shares = [];
  SambaService({required this.name, required this.host, required this.port});
  static SambaService fromBonsoir(BonsoirService service) => SambaService(
    name: service.name,
    host: service.host ?? '',
    port: service.port,
  );
  Future<void> disconnect() async {
    await Store.remove('cred.$name');
    credentials = null;
    await smb?.close();
    smb = null;
    Debug.info('smb://$name disconnected by user');
    onDisconnected.fire(());
  }

  Future<void> reconnect() async {
    if (credentials != null) {
      Debug.info('smb://$name trying to reconnect');
      await connect(credentials: credentials!);
    }
  }

  Future<void> connect({required Credentials credentials}) async {
    try {
      smb = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: credentials.login,
        password: credentials.password,
        onDisconnect: (_) {
          smb = null;
          shares = [];
          Debug.info('smb://$name disconnected accidentally');
          onDisconnected.fire(());
        },
      );
      this.credentials = credentials;
      shares.clear();
      try {
        final sh = await smb!.listShares();
        for (final s in sh) {
          final f = await file(s.path);
          shares.add(f);
        }
      } catch (error) {
        Debug.warning('problem loading smb.shares');
      }
      shares.shuffle();
      shares.sort((a, b) {
        bool isMusic(String name) {
          final n = name.toLowerCase();
          return n.contains('music') || n.contains('audio');
        }

        final ma = isMusic(a.name);
        final mb = isMusic(b.name);
        if (ma == mb) return 0;
        return ma ? -1 : 1;
      });
      Store.write('cred.$name', credentials.toJson());
      Debug.info('smb://$name connected');
      onConnect.fire(());
    } catch (error) {
      if (error is SmbException) {
        throw NetworkException(error.message);
      }
      rethrow;
    }
  }

  Future<SambaFile> file(String path) async {
    final file = await smb?.file(path);
    if (file == null) {
      throw Exception('smb:$name, can`t find file $path');
    }
    return SambaFile(service: this, file: file);
  }

  @override
  String toString() {
    return 'SambaService(name: $name)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SambaService && other.key == key;
  }

  @override
  int get hashCode => key.hashCode;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class Credentials {
  final String login;
  final String password;
  Credentials({required this.login, required this.password});

  Map<String, dynamic> toJson() {
    return {'login': login, 'password': password};
  }

  factory Credentials.fromJson(Map<String, dynamic> map) {
    return Credentials(
      login: map['login'] ?? '',
      password: map['password'] ?? '',
    );
  }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
enum ServiceEventType { discovered, disconnected, connected, lost }

//////////////////////////////////////////////////////////////////////////////////////////////////////////
class ServiceEvent {
  final SambaService service;
  final ServiceEventType event;
  const ServiceEvent({required this.service, required this.event});

  @override
  String toString() => 'ServiceEvent(service: $service, event: $event)';
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
class NetworkException extends Error {
  final String message;
  NetworkException(this.message);
  @override
  String toString() => 'NetworkException: $message';
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
