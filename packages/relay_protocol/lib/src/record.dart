import 'dart:convert';
import 'dart:typed_data';

/// Maximum complete plaintext record, including its nine-byte header.
const int maxRelayPlaintextRecordBytes = 64 * 1024;

/// Maximum application payload carried by one encrypted record.
const int maxRelayRecordPayloadBytes = maxRelayPlaintextRecordBytes - 9;

/// Logical payload kinds multiplexed inside an encrypted relay session.
enum RelayRecordType {
  /// Long-lived JSON-RPC traffic.
  rpc,

  /// Opens a typed attachment stream.
  attachmentOpen,

  /// Carries an attachment chunk.
  attachmentData,

  /// Grants attachment sender credit.
  attachmentCredit,

  /// Closes a logical stream, or the authenticated session at stream zero.
  close,
}

/// Splits one JSON-RPC message into bounded, ordered plaintext records.
List<RelayRecord> fragmentRelayRpcMessage(String message) {
  final bytes = utf8.encode(message);
  const chunkBytes = maxRelayRecordPayloadBytes - 1;
  final records = <RelayRecord>[];
  if (bytes.isEmpty) {
    return <RelayRecord>[
      RelayRecord(
        type: RelayRecordType.rpc,
        streamId: 0,
        payload: const <int>[1],
      ),
    ];
  }
  for (var offset = 0; offset < bytes.length; offset += chunkBytes) {
    final end = (offset + chunkBytes).clamp(0, bytes.length);
    records.add(
      RelayRecord(
        type: RelayRecordType.rpc,
        streamId: 0,
        payload: <int>[
          if (end == bytes.length) 1 else 0,
          ...bytes.sublist(offset, end),
        ],
      ),
    );
  }
  return records;
}

/// Reassembles an ordered series of JSON-RPC fragments.
final class RelayRpcMessageAssembler {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  /// Adds one RPC record and returns a complete message after its final chunk.
  String? add(RelayRecord record) {
    if (record.type != RelayRecordType.rpc ||
        record.streamId != 0 ||
        record.payload.isEmpty ||
        record.payload.first > 1) {
      throw const FormatException('Invalid relay RPC fragment.');
    }
    _bytes.add(record.payload.sublist(1));
    if (record.payload.first == 0) {
      return null;
    }
    final value = utf8.decode(_bytes.takeBytes());
    return value;
  }
}

/// One bounded plaintext record before authenticated encryption.
final class RelayRecord {
  /// Creates a validated multiplexed record.
  new({required this.type, required this.streamId, required List<int> payload})
    : payload = Uint8List.fromList(payload) {
    if (streamId < 0) {
      throw RangeError.value(streamId, 'streamId');
    }
    if (payload.length > maxRelayRecordPayloadBytes) {
      throw RangeError.range(
        payload.length,
        0,
        maxRelayRecordPayloadBytes,
        'payload.length',
      );
    }
  }

  /// Parses a strict binary record.
  factory decode(List<int> bytes) {
    if (bytes.length < 9) {
      throw const FormatException('Relay record is truncated.');
    }
    final header = ByteData.sublistView(Uint8List.fromList(bytes), 0, 9);
    final typeIndex = header.getUint8(0);
    final length = header.getUint32(5);
    if (typeIndex >= RelayRecordType.values.length ||
        length != bytes.length - 9) {
      throw const FormatException('Relay record header is invalid.');
    }
    return RelayRecord(
      type: RelayRecordType.values[typeIndex],
      streamId: header.getUint32(1),
      payload: bytes.sublist(9),
    );
  }

  /// Semantic type of this record.
  final RelayRecordType type;

  /// Multiplexed stream identifier; zero is reserved for JSON-RPC.
  final int streamId;

  /// Bounded plaintext payload.
  final Uint8List payload;

  /// Encodes the record for authenticated encryption.
  Uint8List encode() {
    final header = ByteData(9)
      ..setUint8(0, type.index)
      ..setUint32(1, streamId)
      ..setUint32(5, payload.length);
    return Uint8List.fromList(<int>[
      ...header.buffer.asUint8List(),
      ...payload,
    ]);
  }
}
