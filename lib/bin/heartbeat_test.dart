import 'dart:io';
import 'package:dart_mavlink/mavlink.dart';
import 'package:dart_mavlink/dialects/common.dart';

void main() async {
  final dialect = MavlinkDialectCommon();
  final parser = MavlinkParser(dialect);

  // The parser doesn't hand you messages directly — it announces them
  // through a Stream. We set up a listener once, here, and it will keep
  // firing every time a new message gets successfully parsed.
  parser.stream.listen((frame) {
    final message = frame.message;
    if (message is Heartbeat) {
      final armed = (message.baseMode & 128) != 0;
      print('Heartbeat received — armed: $armed, mode: ${message.customMode}');
    }
  });

  // Open a UDP "mailbox" on port 14550 — this is the same port MAVProxy
  // is already forwarding data to.
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 14550);
  print('Listening on UDP 14550 for MAVLink data...');

  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final datagram = socket.receive();
      if (datagram != null) {
        // Hand the raw bytes to the parser. It doesn't return anything
        // here — instead, it'll emit a frame on parser.stream above,
        // once it recognizes a complete, valid message.
        parser.parse(datagram.data);
      }
    }
  });
}
