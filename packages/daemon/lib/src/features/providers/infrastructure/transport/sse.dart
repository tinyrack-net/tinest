import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// ServerSentEvent defines a public contract.
class ServerSentEvent {
  /// Creates a [ServerSentEvent].
  const new({required this.data, this.event});

  /// The event public API member.
  final String? event;

  /// The data public API member.
  final String data;
}

/// The decodeServerSentEvents public API member.
Stream<ServerSentEvent> decodeServerSentEvents(Stream<Uint8List> bytes) async* {
  String? eventName;
  final data = <String>[];
  await for (final line
      in bytes
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) {
        yield ServerSentEvent(event: eventName, data: data.join('\n'));
      }
      eventName = null;
      data.clear();
      continue;
    }
    if (line.startsWith(':')) continue;
    final separator = line.indexOf(':');
    final field = separator < 0 ? line : line.substring(0, separator);
    var value = separator < 0 ? '' : line.substring(separator + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        eventName = value;
      case 'data':
        data.add(value);
    }
  }
  if (data.isNotEmpty) {
    yield ServerSentEvent(event: eventName, data: data.join('\n'));
  }
}
