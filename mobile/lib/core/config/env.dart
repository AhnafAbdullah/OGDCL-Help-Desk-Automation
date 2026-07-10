import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Points the app at the OGDCL backend. The API and Blazor dashboard are
/// meant to be run locally per the project README:
///   dotnet run --project src/Ogdcl.Api --urls http://localhost:5080
class Env {
  Env._();

  /// When true, the app runs entirely against an in-memory mock backend
  /// (lib/mock/) instead of the real .NET API — no server needs to be
  /// running. Flip to false once the backend is available; every screen
  /// and repository is written against the same abstract interfaces either
  /// way, so nothing else needs to change.
  static const bool useMockBackend = true;

  /// Set this to your machine's LAN IP (e.g. "192.168.1.20") when running on
  /// a physical device — "localhost"/"10.0.2.2" only resolve to the host
  /// machine from an emulator/simulator, not from real hardware.
  static const String overrideHost = '';

  static const int apiPort = 5080;

  static String get apiBaseUrl => 'http://$_host:$apiPort/api';

  static String get notificationHubUrl => 'http://$_host:$apiPort/hubs/notifications';

  static String get _host {
    if (overrideHost.isNotEmpty) return overrideHost;
    if (kIsWeb) return 'localhost';
    // The Android emulator's loopback to the host machine is 10.0.2.2;
    // every other target (iOS simulator, Windows/macOS/Linux desktop) can
    // reach the host machine via plain localhost.
    if (Platform.isAndroid) return '10.0.2.2';
    return 'localhost';
  }
}
