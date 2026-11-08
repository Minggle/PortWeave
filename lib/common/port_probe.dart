import 'dart:async';
import 'dart:io';

import 'port_routing.dart';

Future<Map<int, int>> desktopPortOwners() async {
  final ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('netstat.exe', [
      '-ano',
      '-p',
      'tcp',
    ]).timeout(const Duration(seconds: 5));
  } else if (Platform.isMacOS) {
    result = await Process.run('/usr/sbin/lsof', [
      '-nP',
      '-i4TCP',
      '-sTCP:LISTEN',
      '-Fpn',
    ]).timeout(const Duration(seconds: 5));
    if (result.exitCode == 1 &&
        result.stdout.toString().trim().isEmpty &&
        result.stderr.toString().trim().isEmpty) {
      return const {};
    }
  } else {
    throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
  }
  if (result.exitCode != 0) {
    throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
  }
  return Platform.isMacOS
      ? parseMacOSPortOwners(result.stdout.toString())
      : parseWindowsPortOwners(result.stdout.toString());
}

Map<int, int> parseMacOSPortOwners(String output) {
  final owners = <int, int>{};
  final ambiguous = <int>{};
  final localAddress = RegExp(r'^(?:127\.0\.0\.1|0\.0\.0\.0|\*):([0-9]+)$');
  int? owner;
  for (final line in output.split('\n')) {
    final field = line.trim();
    if (field.startsWith('p')) {
      owner = int.tryParse(field.substring(1));
    } else if (owner != null && owner > 0 && field.startsWith('n')) {
      final match = localAddress.firstMatch(field.substring(1));
      final port = match == null ? null : int.tryParse(match[1]!);
      if (port == null || port < 1 || port > 65535) continue;
      if (owners.containsKey(port) && owners[port] != owner) {
        ambiguous.add(port);
      }
      owners[port] = owner;
    }
  }
  for (final port in ambiguous) {
    owners.remove(port);
  }
  return owners;
}

Map<int, int> parseWindowsPortOwners(String output) {
  final owners = <int, int>{};
  for (final line in output.split('\n')) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length != 5 ||
        fields.first != 'TCP' ||
        fields[2] != '0.0.0.0:0') {
      continue;
    }
    final local = fields[1];
    if (!local.startsWith('127.0.0.1:') && !local.startsWith('0.0.0.0:')) {
      continue;
    }
    final port = int.tryParse(local.substring(local.lastIndexOf(':') + 1));
    final owner = int.tryParse(fields.last);
    if (port != null && owner != null) owners[port] = owner;
  }
  return owners;
}

Future<void> checkPortAvailable(int port, {int? existingOwner}) async {
  if (existingOwner != null && (Platform.isWindows || Platform.isMacOS)) {
    if ((await desktopPortOwners())[port] == existingOwner) return;
  }
  try {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
    await socket.close();
  } on SocketException {
    throw const PortRoutingException(PortRoutingIssue.portOccupied);
  }
}

Future<void> checkSocksHandshake(int port) async {
  final socket = await Socket.connect(
    InternetAddress.loopbackIPv4,
    port,
    timeout: const Duration(seconds: 2),
  );
  final iterator = StreamIterator(socket);
  try {
    socket.add([5, 1, 0]);
    await socket.flush();
    final response = <int>[];
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (response.length < 2) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative ||
          !await iterator.moveNext().timeout(remaining)) {
        throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
      }
      response.addAll(iterator.current);
    }
    if (response[0] != 5 || response[1] != 0) {
      throw const PortRoutingException(PortRoutingIssue.coreUnavailable);
    }
  } finally {
    socket.destroy();
    await iterator.cancel();
  }
}
