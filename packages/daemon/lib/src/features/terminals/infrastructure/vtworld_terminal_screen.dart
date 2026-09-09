import 'package:daemon/src/features/terminals/application/terminal_screen.dart';
import 'package:vtworld/vtworld.dart';

/// Screen models backed by the emulator the app renders with.
///
/// The same package parses on both ends, so the grid a client is restored into
/// agrees with the grid the daemon serialized: cell widths, soft wraps, and
/// mode handling cannot drift between two implementations.
final class VtworldTerminalScreenFactory implements TerminalScreenFactory {
  /// Creates the production screen factory.
  const new();

  @override
  TerminalScreen create({
    required int columns,
    required int rows,
    required int scrollbackLines,
  }) => _VtworldTerminalScreen(
    columns: columns,
    rows: rows,
    scrollbackLines: scrollbackLines,
  );
}

final class _VtworldTerminalScreen implements TerminalScreen {
  new({required int columns, required int rows, required int scrollbackLines})
    : _terminal = Terminal(
        options: TerminalOptions(
          cols: columns,
          rows: rows,
          scrollback: scrollbackLines,
        ),
      ) {
    _terminal.loadAddon(_serialize);
    // Deliberately no `onData` subscription. This screen is a mirror, not a
    // terminal: answering a device-attributes or cursor-position query here
    // would give the shell two replies, one from the daemon and one from the
    // attached client's own emulator, and it would read the second as input.
  }

  final Terminal _terminal;
  final SerializeAddon _serialize = SerializeAddon();

  @override
  Future<void> feed(String data) => _terminal.writeAndWait(data);

  @override
  void resize(int columns, int rows) => _terminal.resize(columns, rows);

  @override
  String snapshot({required int scrollbackLines}) => _serialize.serialize(
    options: TerminalSerializeOptions(scrollback: scrollbackLines),
  );

  @override
  void dispose() => _terminal.dispose();
}
