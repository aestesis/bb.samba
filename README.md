# bb_samba

![Version](https://img.shields.io/badge/version-0.0.1-blue.svg)
![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=flat&logo=Flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=flat&logo=dart&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

A Flutter/Dart package that provides a seamless interface for discovering, connecting to, and interacting with Samba (SMB) network shares. 

This package simplifies local network file sharing by combining mDNS discovery (Bonjour/Zeroconf) with an abstracted file system API, allowing you to treat local device files and remote SMB files uniformly.

## Features

- 🔍 **mDNS Discovery**: Automatically discover local SMB servers using the `bonsoir` package (`_smb._tcp`).
- 🔐 **Credential Management**: Securely connect to shares with automatic saving and restoring of credentials.
- 🔄 **Auto-Reconnect**: Handles network drops and reconnects automatically when the connection is lost.
- 📁 **Unified File API**: Use `GenericFile` to seamlessly interact with both local files (`file://`) and remote Samba files (`smb://`).
- 📂 **Share Management**: Easily list and interact with shares exposed by the SMB servers.

## Installation

Add `bb_samba` to your `pubspec.yaml` dependencies. Since this package relies on specific git repositories, you should include it directly from git:

```yaml
dependencies:
  bb_samba:
    git:
      url: https://github.com/renanyoy/bb.samba.git
```

Make sure you also have the necessary platform requirements for the underlying dependencies like `bonsoir` and `smb_connect`.

## Usage

### Initialization

Before using the network discovery features, initialize the `Network` class.

```dart
import 'package:bb_samba/bb_samba.dart';

void main() async {
  // Initialize mDNS discovery for SMB services
  await Network.initialize();
}
```

### Discovering Services

You can listen to network updates to discover when SMB services are found, connected, disconnected, or lost.

```dart
Network.onUpdate.on((ServiceEvent event) {
  switch (event.event) {
    case ServiceEventType.discovered:
      print('Found SMB Service: ${event.service.name}');
      break;
    case ServiceEventType.connected:
      print('Connected to: ${event.service.name}');
      break;
    case ServiceEventType.disconnected:
      print('Disconnected from: ${event.service.name}');
      break;
    case ServiceEventType.lost:
      print('Lost SMB Service: ${event.service.name}');
      break;
  }
});
```

### Connecting to a Samba Service

Once a service is discovered, you can connect to it using credentials.

```dart
// Assuming 'service' is a SambaService instance obtained from Network.services
final credentials = Credentials(login: 'username', password: 'password');

try {
  await service.connect(credentials: credentials);
  print('Connected successfully. Available shares: ${service.shares.length}');
} catch (e) {
  print('Connection failed: $e');
}
```

### Working with Files

`bb_samba` provides a `GenericFile` abstraction that unifies standard `dart:io` files and remote Samba files.

#### Resolving a File from a URI

```dart
// You can use a local path or a remote samba path
final remoteFile = await GenericFile.from(uri: 'smb://ServerName/Share/folder/file.txt');
final localFile = await GenericFile.from(uri: 'file:///path/to/local/file.txt');
```

#### Reading File Content

```dart
// Check if it exists
if (await remoteFile.exists()) {
  // Read entirely into memory
  final content = await remoteFile.content;
  
  // Or stream the content
  final stream = await remoteFile.openRead();
  stream.listen((chunk) {
    print('Received ${chunk.length} bytes');
  });
}
```

#### Directory Listing

```dart
if (remoteFile.isDirectory) {
  final files = await remoteFile.listFiles();
  for (final file in files) {
    print(file.name);
  }
}
```

## Core Components

- **`Network`**: Handles the `bonsoir` discovery for `_smb._tcp` and maintains a set of available `SambaService`s.
- **`SambaService`**: Represents an individual SMB server. Manages the connection state, credentials (via `Store`), and available shares.
- **`GenericFile`**: An abstract interface for file operations (`open`, `openRead`, `listFiles`, `size`, etc.).
- **`SambaFile` & `DeviceFile`**: Implementations of `GenericFile` for SMB shares and local device storage respectively.

## Dependencies

This project relies on a few specialized packages:
- [`smb_connect`](https://github.com/renanyoy/smb_connect.git): Low-level SMB protocol binding.
- [`bb.dart`](https://github.com/aestesis/bb.dart.git) / [`bb.flutter`](https://github.com/aestesis/bb.flutter.git): Core utilities, state management, and debugging.
- [`bonsoir`](https://pub.dev/packages/bonsoir): Used for Apple's Bonjour / ZeroConf (mDNS) network discovery.
