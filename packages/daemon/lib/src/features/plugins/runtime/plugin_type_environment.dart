import 'dart:convert';

/// Non-executing analysis of the schema-builder subset used to generate the
/// per-plugin `tinest.types` runtime module and LuaLS definition sidecar.
///
/// Runtime JSON Schema validation remains authoritative. An unsupported or
/// incomplete expression is projected as `any` and reported as an authoring
/// diagnostic; plugin source is never evaluated by this analyzer.
abstract final class PluginTypeEnvironmentGenerator {
  /// Editor-only file emitted into the ABI-scoped authoring cache and excluded
  /// from the plugin's immutable execution bundle.
  static const String sidecarFileName = 'types.d.lua';

  /// Analyzes detached UTF-8 Lua sources in deterministic path order.
  static PluginTypeEnvironment analyze({
    required String pluginId,
    required Map<String, String> sources,
  }) {
    final declarations = <String, _SchemaNode>{};
    final origins = <String, String>{};
    final diagnostics = <PluginTypeAuthoringDiagnostic>[];
    final symbols = <String, _SchemaNode>{};
    for (final entry
        in (sources.entries.toList()
          ..sort((left, right) => left.key.compareTo(right.key)))) {
      final lexer = _LuaLexer(entry.value, entry.key);
      final tokens = lexer.scan(diagnostics);
      _diagnoseDynamicTypeTokenAccess(tokens, entry.key, diagnostics);
      final parser = _LuaSchemaParser(
        tokens: tokens,
        path: entry.key,
        symbols: symbols,
        diagnostics: diagnostics,
      );
      for (final parsed in parser.parse()) {
        _registerTokens(parsed, entry.key, declarations, origins, diagnostics);
      }
    }
    final referenced = referencedTokenNames(sources);
    for (final name in referenced) {
      if (!declarations.containsKey(name)) {
        diagnostics.add(
          PluginTypeAuthoringDiagnostic(
            code: 'plugin_type_unprojected',
            message:
                'Type token $name could not be projected exactly; '
                'runtime validation remains authoritative.',
            path: sources.keys.isEmpty ? 'main.lua' : sources.keys.first,
            line: 1,
            column: 1,
          ),
        );
      }
    }
    return PluginTypeEnvironment._(
      pluginId: pluginId,
      declarations: Map<String, _SchemaNode>.unmodifiable(declarations),
      diagnostics: List<PluginTypeAuthoringDiagnostic>.unmodifiable(
        diagnostics,
      ),
    );
  }

  /// Collects only direct code references returned by
  /// `require("tinest.types")`. This deliberately does not depend on exact
  /// schema projection, so an authoring parser diagnostic cannot block a
  /// valid runtime revision.
  static List<String> referencedTokenNames(Map<String, String> sources) {
    final names = <String>{};
    for (final entry in sources.entries) {
      final tokens = _LuaLexer(
        entry.value,
        entry.key,
      ).scan(<PluginTypeAuthoringDiagnostic>[]);
      final aliases = <String>{};
      for (var index = 0; index < tokens.length - 5; index += 1) {
        if (tokens[index].lexeme != 'local' ||
            tokens[index + 1].kind != _TokenKind.identifier ||
            tokens[index + 2].lexeme != '=') {
          continue;
        }
        final module = _requiredModuleAt(tokens, index + 3);
        if (module == 'tinest.types') aliases.add(tokens[index + 1].lexeme);
      }
      for (var index = 0; index < tokens.length - 2; index += 1) {
        if (tokens[index].kind != _TokenKind.identifier ||
            !aliases.contains(tokens[index].lexeme) ||
            tokens[index + 1].lexeme != '.' ||
            tokens[index + 2].kind != _TokenKind.identifier) {
          continue;
        }
        final name = tokens[index + 2].lexeme;
        if (RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(name)) names.add(name);
      }
    }
    return List<String>.unmodifiable(names.toList(growable: false)..sort());
  }
}

void _diagnoseDynamicTypeTokenAccess(
  List<_Token> tokens,
  String path,
  List<PluginTypeAuthoringDiagnostic> diagnostics,
) {
  final aliases = <String>{};
  for (var index = 0; index < tokens.length - 5; index += 1) {
    if (tokens[index].lexeme != 'local' ||
        tokens[index + 1].kind != _TokenKind.identifier ||
        tokens[index + 2].lexeme != '=') {
      continue;
    }
    if (_requiredModuleAt(tokens, index + 3) == 'tinest.types') {
      aliases.add(tokens[index + 1].lexeme);
    }
  }
  for (var index = 0; index < tokens.length - 1; index += 1) {
    if (tokens[index].kind == _TokenKind.identifier &&
        aliases.contains(tokens[index].lexeme) &&
        tokens[index + 1].lexeme == '[') {
      diagnostics.add(
        PluginTypeAuthoringDiagnostic(
          code: 'plugin_type_dynamic_reference',
          message:
              'Type tokens must use a static PascalCase code reference '
              'such as T.Input; bracket access is unsupported.',
          path: path,
          line: tokens[index].line,
          column: tokens[index].column,
        ),
      );
    }
  }
}

String? _requiredModuleAt(List<_Token> tokens, int index) {
  if (tokens[index].lexeme != 'require') return null;
  if (tokens[index + 1].kind == _TokenKind.string) {
    return tokens[index + 1].value;
  }
  if (tokens[index + 1].lexeme == '(' &&
      tokens[index + 2].kind == _TokenKind.string &&
      tokens[index + 3].lexeme == ')') {
    return tokens[index + 2].value;
  }
  return null;
}

/// One source-positioned, editor-only schema projection problem.
final class PluginTypeAuthoringDiagnostic {
  /// Creates an immutable diagnostic from the non-executing source analyzer.
  const new({
    required this.code,
    required this.message,
    required this.path,
    required this.line,
    required this.column,
  });

  /// Stable diagnostic identifier.
  final String code;

  /// Human-readable explanation.
  final String message;

  /// Bundle-relative source path.
  final String path;

  /// One-based line number.
  final int line;

  /// One-based column number.
  final int column;
}

/// Generated runtime token inventory and matching LuaCATS sidecar.
final class PluginTypeEnvironment {
  new _({
    required this.pluginId,
    required this._declarations,
    required this.diagnostics,
  });

  /// Plugin namespace whose source was projected.
  final String pluginId;
  final Map<String, _SchemaNode> _declarations;

  /// Non-blocking authoring diagnostics from static projection.
  final List<PluginTypeAuthoringDiagnostic> diagnostics;

  /// Static token names installed into the revision-local `tinest.types`.
  List<String> get tokenNames => List<String>.unmodifiable(
    _declarations.keys.toList(growable: false)..sort(),
  );

  /// Non-executable LuaLS definition for `require("tinest.types")`.
  String get authoringDefinition {
    final namespace =
        'tinest_plugin_${pluginId.replaceAll(RegExp('[^A-Za-z0-9_]'), '_')}';
    final output = StringBuffer('---@meta tinest.types\n\n');
    final rendered = <String>{};
    for (final name in tokenNames) {
      _renderDeclaration(
        output,
        namespace,
        name,
        _declarations[name]!,
        rendered,
      );
    }
    output.writeln('---@class (exact) $namespace.Types');
    for (final name in tokenNames) {
      final node = _declarations[name]!;
      final valueType = '$namespace.$name';
      final tokenType = node is _EnumSchema
          ? 'tinest.EnumTypeToken<$valueType, $valueType.Values>'
          : 'tinest.TypeToken<$valueType>';
      output.writeln('---@field $name $tokenType');
    }
    output
      ..writeln()
      ..writeln('---@type $namespace.Types')
      ..writeln('local types')
      ..writeln('return types');
    return output.toString();
  }
}

void _registerTokens(
  _SchemaNode node,
  String path,
  Map<String, _SchemaNode> declarations,
  Map<String, String> origins,
  List<PluginTypeAuthoringDiagnostic> diagnostics,
) {
  final name = node.tokenName;
  if (name != null) {
    final origin = '$path:${node.offset}';
    final prior = origins[name];
    if (prior == null) {
      origins[name] = origin;
      declarations[name] = node;
    } else if (prior != origin) {
      diagnostics.add(
        PluginTypeAuthoringDiagnostic(
          code: 'plugin_type_duplicate',
          message: 'Type token $name is declared more than once.',
          path: path,
          line: node.line,
          column: node.column,
        ),
      );
    }
  }
  switch (node) {
    case _ObjectSchema(:final fields):
      for (final child in fields.values) {
        _registerTokens(child, path, declarations, origins, diagnostics);
      }
    case _ContainerSchema(:final item):
      _registerTokens(item, path, declarations, origins, diagnostics);
    case _PrimitiveSchema() ||
        _ReferenceSchema() ||
        _EnumSchema() ||
        _UnknownSchema():
      break;
  }
}

void _renderDeclaration(
  StringBuffer output,
  String namespace,
  String name,
  _SchemaNode node,
  Set<String> rendered,
) {
  final qualified = '$namespace.$name';
  if (!rendered.add(qualified)) return;
  switch (node) {
    case _ObjectSchema(:final fields):
      for (final entry in fields.entries) {
        _renderNested(
          output,
          namespace,
          '$name${_pascal(entry.key)}',
          entry.value,
          rendered,
        );
      }
      output.writeln('---@class (exact) $qualified');
      for (final entry
          in (fields.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key)))) {
        final optional =
            entry.value is _ContainerSchema &&
            (entry.value as _ContainerSchema).container == _Container.optional;
        final type = _catsType(
          entry.value,
          namespace,
          '$name${_pascal(entry.key)}',
          stripOptional: optional,
        );
        output.writeln(
          '---@field ${_fieldName(entry.key)}${optional ? '?' : ''} $type',
        );
      }
      output.writeln();
    case _EnumSchema(:final values):
      final literals = values.values.map(jsonEncode).join('|');
      output
        ..writeln(
          '---@alias $qualified ${literals.isEmpty ? 'string' : literals}',
        )
        ..writeln('---@class (exact) $qualified.Values');
      for (final entry
          in (values.entries.toList()
            ..sort((left, right) => left.key.compareTo(right.key)))) {
        output.writeln('---@field ${entry.key} ${jsonEncode(entry.value)}');
      }
      output.writeln();
    case _PrimitiveSchema() ||
        _ContainerSchema() ||
        _ReferenceSchema() ||
        _UnknownSchema():
      output
        ..writeln('---@alias $qualified ${_catsType(node, namespace, name)}')
        ..writeln();
  }
}

void _renderNested(
  StringBuffer output,
  String namespace,
  String fallbackName,
  _SchemaNode node,
  Set<String> rendered,
) {
  switch (node) {
    case _ObjectSchema():
      _renderDeclaration(
        output,
        namespace,
        node.tokenName ?? fallbackName,
        node,
        rendered,
      );
    case _ContainerSchema(:final item):
      _renderNested(output, namespace, '${fallbackName}Item', item, rendered);
    case _PrimitiveSchema() ||
        _ReferenceSchema() ||
        _EnumSchema() ||
        _UnknownSchema():
      break;
  }
}

String _catsType(
  _SchemaNode node,
  String namespace,
  String fallbackName, {
  bool stripOptional = false,
}) => switch (node) {
  _PrimitiveSchema(:final cats) => cats,
  _ObjectSchema(:final tokenName) => '$namespace.${tokenName ?? fallbackName}',
  _EnumSchema(:final tokenName) =>
    tokenName == null ? 'string' : '$namespace.$tokenName',
  _ReferenceSchema(:final target) => switch (target) {
    _ObjectSchema(:final tokenName) when tokenName != null =>
      '$namespace.$tokenName',
    _EnumSchema(:final tokenName) when tokenName != null =>
      '$namespace.$tokenName',
    _ => 'any',
  },
  _ContainerSchema(:final container, :final item) => switch (container) {
    _Container.optional =>
      stripOptional
          ? _catsType(item, namespace, fallbackName)
          : '${_catsType(item, namespace, fallbackName)}?',
    _Container.array =>
      '${_parenthesize(_catsType(item, namespace, '${fallbackName}Item'))}[]',
    _Container.map =>
      'table<string, ${_catsType(item, namespace, '${fallbackName}Value')}>',
  },
  _UnknownSchema() => 'any',
};

String _parenthesize(String value) =>
    value.contains('|') || value.endsWith('?') ? '($value)' : value;

String _pascal(String value) => value
    .split(RegExp('[^A-Za-z0-9]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join();

String _fieldName(String value) =>
    RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)
    ? value
    : '[${jsonEncode(value)}]';

enum _Container { optional, array, map }

sealed class _SchemaNode {
  const new({
    required this.offset,
    required this.line,
    required this.column,
    this.tokenName,
  });

  final int offset;
  final int line;
  final int column;
  final String? tokenName;
}

final class _PrimitiveSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    required this.cats,
  });

  final String cats;
}

final class _ContainerSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    required this.container,
    required this.item,
  });

  final _Container container;
  final _SchemaNode item;
}

final class _ObjectSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    required super.tokenName,
    required this.fields,
  });

  final Map<String, _SchemaNode> fields;
}

final class _EnumSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    required super.tokenName,
    required this.values,
  });

  final Map<String, String> values;
}

final class _ReferenceSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    required this.target,
  });

  final _SchemaNode? target;
}

final class _UnknownSchema extends _SchemaNode {
  const new({
    required super.offset,
    required super.line,
    required super.column,
    super.tokenName,
  });
}

enum _TokenKind { identifier, string, number, symbol, eof }

final class _Token {
  const new({
    required this.kind,
    required this.lexeme,
    required this.offset,
    required this.line,
    required this.column,
    this.value,
  });

  final _TokenKind kind;
  final String lexeme;
  final String? value;
  final int offset;
  final int line;
  final int column;
}

final class _LuaLexer {
  new(this.source, this.path);

  final String source;
  final String path;
  var _index = 0;
  var _line = 1;
  var _column = 1;

  List<_Token> scan(List<PluginTypeAuthoringDiagnostic> diagnostics) {
    final tokens = <_Token>[];
    while (_index < source.length) {
      final char = source[_index];
      if (_isWhitespace(char)) {
        _advance();
      } else if (char == '-' && _peek(1) == '-') {
        _comment(diagnostics);
      } else if (char == '"' || char == "'") {
        tokens.add(_quoted(char, diagnostics));
      } else if (char == '[' && _longBracketLevel(_index) != null) {
        tokens.add(_longString(diagnostics));
      } else if (_isIdentifierStart(char)) {
        tokens.add(_identifier());
      } else if (_isDigit(char)) {
        tokens.add(_number());
      } else {
        tokens.add(_symbol());
      }
    }
    tokens.add(
      _Token(
        kind: _TokenKind.eof,
        lexeme: '',
        offset: _index,
        line: _line,
        column: _column,
      ),
    );
    return tokens;
  }

  void _comment(List<PluginTypeAuthoringDiagnostic> diagnostics) {
    _advance();
    _advance();
    final level = _longBracketLevel(_index);
    if (level == null) {
      while (_index < source.length && source[_index] != '\n') {
        _advance();
      }
      return;
    }
    _consumeLongBracket(level, diagnostics, emit: false);
  }

  _Token _quoted(
    String quote,
    List<PluginTypeAuthoringDiagnostic> diagnostics,
  ) {
    final start = _mark();
    _advance();
    final value = StringBuffer();
    var closed = false;
    while (_index < source.length) {
      final char = source[_index];
      if (char == quote) {
        _advance();
        closed = true;
        break;
      }
      if (char.codeUnitAt(0) == 92 && _index + 1 < source.length) {
        _advance();
        final escaped = source[_index];
        value.write(switch (escaped) {
          'n' => '\n',
          'r' => '\r',
          't' => '\t',
          _ => escaped,
        });
        _advance();
      } else {
        value.write(char);
        _advance();
      }
    }
    if (!closed) _diagnoseUnterminated(start, diagnostics, 'string');
    return _tokenFrom(start, _TokenKind.string, value: value.toString());
  }

  _Token _longString(List<PluginTypeAuthoringDiagnostic> diagnostics) {
    final start = _mark();
    final level = _longBracketLevel(_index)!;
    final value = _consumeLongBracket(level, diagnostics, emit: true);
    return _tokenFrom(start, _TokenKind.string, value: value);
  }

  String _consumeLongBracket(
    int level,
    List<PluginTypeAuthoringDiagnostic> diagnostics, {
    required bool emit,
  }) {
    final start = _mark();
    for (var count = 0; count < level + 2; count += 1) {
      _advance();
    }
    final value = StringBuffer();
    while (_index < source.length) {
      if (source[_index] == ']' && _closingLongBracket(_index, level)) {
        for (var count = 0; count < level + 2; count += 1) {
          _advance();
        }
        return value.toString();
      }
      if (emit) value.write(source[_index]);
      _advance();
    }
    _diagnoseUnterminated(start, diagnostics, 'long string or comment');
    return value.toString();
  }

  _Token _identifier() {
    final start = _mark();
    while (_index < source.length && _isIdentifierPart(source[_index])) {
      _advance();
    }
    return _tokenFrom(start, _TokenKind.identifier);
  }

  _Token _number() {
    final start = _mark();
    while (_index < source.length &&
        (_isDigit(source[_index]) || source[_index] == '.')) {
      _advance();
    }
    return _tokenFrom(start, _TokenKind.number);
  }

  _Token _symbol() {
    final start = _mark();
    _advance();
    return _tokenFrom(start, _TokenKind.symbol);
  }

  ({int offset, int line, int column}) _mark() =>
      (offset: _index, line: _line, column: _column);

  _Token _tokenFrom(
    ({int offset, int line, int column}) start,
    _TokenKind kind, {
    String? value,
  }) => _Token(
    kind: kind,
    lexeme: source.substring(start.offset, _index),
    value: value,
    offset: start.offset,
    line: start.line,
    column: start.column,
  );

  void _diagnoseUnterminated(
    ({int offset, int line, int column}) start,
    List<PluginTypeAuthoringDiagnostic> diagnostics,
    String label,
  ) {
    diagnostics.add(
      PluginTypeAuthoringDiagnostic(
        code: 'plugin_types_parse',
        message: 'Unterminated Lua $label.',
        path: path,
        line: start.line,
        column: start.column,
      ),
    );
  }

  int? _longBracketLevel(int index) {
    if (index >= source.length || source[index] != '[') return null;
    var cursor = index + 1;
    while (cursor < source.length && source[cursor] == '=') {
      cursor += 1;
    }
    return cursor < source.length && source[cursor] == '['
        ? cursor - index - 1
        : null;
  }

  bool _closingLongBracket(int index, int level) {
    if (source[index] != ']') return false;
    var cursor = index + 1;
    for (var count = 0; count < level; count += 1) {
      if (cursor >= source.length || source[cursor] != '=') return false;
      cursor += 1;
    }
    return cursor < source.length && source[cursor] == ']';
  }

  String? _peek(int distance) =>
      _index + distance < source.length ? source[_index + distance] : null;

  void _advance() {
    if (source[_index] == '\n') {
      _line += 1;
      _column = 1;
    } else {
      _column += 1;
    }
    _index += 1;
  }
}

final class _LuaSchemaParser {
  new({
    required this.tokens,
    required this.path,
    required this.symbols,
    required this.diagnostics,
  });

  final List<_Token> tokens;
  final String path;
  final Map<String, _SchemaNode> symbols;
  final List<PluginTypeAuthoringDiagnostic> diagnostics;
  final Set<String> _tinestAliases = <String>{};
  final Set<String> _schemaAliases = <String>{};
  final Set<String> _typeAliases = <String>{};
  final Set<int> _parsedOffsets = <int>{};

  List<_SchemaNode> parse() {
    _discoverAliases();
    final result = <_SchemaNode>[];
    for (var index = 0; index < tokens.length - 1; index += 1) {
      if (_is(index, 'local') && _identifier(index + 1)) {
        final names = <String>[];
        var cursor = index + 1;
        while (_identifier(cursor)) {
          names.add(tokens[cursor].lexeme);
          cursor += 1;
          if (!_is(cursor, ',')) break;
          cursor += 1;
        }
        if (_is(cursor, '=')) {
          final parsed = _trySchema(cursor + 1);
          if (parsed != null) {
            symbols[names.first] = parsed.node;
            result.add(parsed.node);
            _parsedOffsets.add(tokens[cursor + 1].offset);
          }
        }
      }
      if (_builder(index) != null && _parsedOffsets.add(tokens[index].offset)) {
        final parsed = _trySchema(index);
        if (parsed != null) result.add(parsed.node);
      }
    }
    return result;
  }

  void _discoverAliases() {
    for (var index = 0; index < tokens.length - 5; index += 1) {
      if (!_is(index, 'local') ||
          !_identifier(index + 1) ||
          !_is(index + 2, '=')) {
        continue;
      }
      final alias = tokens[index + 1].lexeme;
      final module = _requiredModule(index + 3);
      if (module == 'tinest') _tinestAliases.add(alias);
      if (module == 'tinest.types') _typeAliases.add(alias);
      if (_identifier(index + 3) &&
          _tinestAliases.contains(tokens[index + 3].lexeme) &&
          _is(index + 4, '.') &&
          _is(index + 5, 'schema')) {
        _schemaAliases.add(alias);
      }
    }
  }

  String? _requiredModule(int index) {
    if (!_is(index, 'require')) return null;
    if (tokens[index + 1].kind == _TokenKind.string) {
      return tokens[index + 1].value;
    }
    if (_is(index + 1, '(') &&
        tokens[index + 2].kind == _TokenKind.string &&
        _is(index + 3, ')')) {
      return tokens[index + 2].value;
    }
    return null;
  }

  _ParseResult? _trySchema(int index) {
    try {
      return _schema(index);
    } on _SchemaParseFailure catch (failure) {
      diagnostics.add(
        PluginTypeAuthoringDiagnostic(
          code: 'plugin_types_parse',
          message: failure.message,
          path: path,
          line: failure.token.line,
          column: failure.token.column,
        ),
      );
      return _ParseResult(
        _UnknownSchema(
          offset: failure.token.offset,
          line: failure.token.line,
          column: failure.token.column,
        ),
        failure.index + 1,
      );
    }
  }

  _ParseResult? _schema(int index) {
    if (!_identifier(index)) return null;
    final builder = _builder(index);
    if (builder == null) {
      final token = tokens[index];
      return _ParseResult(
        _ReferenceSchema(
          offset: token.offset,
          line: token.line,
          column: token.column,
          target: symbols[token.lexeme],
        ),
        index + 1,
      );
    }
    final start = tokens[index];
    var cursor = builder.argumentsIndex;
    final token = _typeToken(cursor);
    String? tokenName;
    if (token != null) {
      tokenName = token.name;
      cursor = token.next;
      _expect(cursor, ',', 'Expected a comma after type token.');
      cursor += 1;
    }
    return switch (builder.name) {
      'string' => _simple(start, cursor, 'string'),
      'integer' => _simple(start, cursor, 'integer'),
      'number' => _simple(start, cursor, 'number'),
      'boolean' => _simple(start, cursor, 'boolean'),
      'any' => _simple(start, cursor, 'any'),
      'optional' || 'array' || 'map' => _container(start, builder.name, cursor),
      'object' => _object(start, tokenName, cursor),
      'enum' => _enum(start, tokenName, cursor, literal: false),
      'literal_enum' => _enum(start, tokenName, cursor, literal: true),
      'raw' => _raw(start, tokenName, cursor),
      _ => null,
    };
  }

  _ParseResult _simple(_Token start, int cursor, String cats) {
    final end = _closing(cursor, '(', ')');
    return _ParseResult(
      _PrimitiveSchema(
        offset: start.offset,
        line: start.line,
        column: start.column,
        cats: cats,
      ),
      end + 1,
    );
  }

  _ParseResult _container(_Token start, String name, int cursor) {
    final item = _schema(cursor);
    if (item == null) {
      throw _failure(cursor, 'Expected a schema builder argument.');
    }
    final end = _closing(item.next, '(', ')');
    return _ParseResult(
      _ContainerSchema(
        offset: start.offset,
        line: start.line,
        column: start.column,
        container: switch (name) {
          'optional' => _Container.optional,
          'array' => _Container.array,
          _ => _Container.map,
        },
        item: item.node,
      ),
      end + 1,
    );
  }

  _ParseResult _object(_Token start, String? tokenName, int cursor) {
    var index = cursor;
    _expect(index, '{', 'Object fields must be a literal table.');
    final fields = <String, _SchemaNode>{};
    index += 1;
    while (!_is(index, '}')) {
      final key = _fieldKey(index);
      if (key == null) {
        throw _failure(index, 'Expected a static object field.');
      }
      index = key.next;
      _expect(index, '=', 'Expected = after object field ${key.name}.');
      final value = _schema(index + 1);
      if (value == null) {
        throw _failure(index + 1, 'Object fields must use schema builders.');
      }
      fields[key.name] = value.node;
      index = value.next;
      if (_is(index, ',') || _is(index, ';')) {
        index += 1;
      }
    }
    index += 1;
    final end = _closing(index, '(', ')');
    return _ParseResult(
      _ObjectSchema(
        offset: start.offset,
        line: start.line,
        column: start.column,
        tokenName: tokenName,
        fields: Map<String, _SchemaNode>.unmodifiable(fields),
      ),
      end + 1,
    );
  }

  _ParseResult _enum(
    _Token start,
    String? tokenName,
    int cursor, {
    required bool literal,
  }) {
    var index = cursor;
    _expect(index, '{', 'Enum values must be a literal table.');
    final values = <String, String>{};
    index += 1;
    while (!_is(index, '}')) {
      if (literal) {
        final key = _fieldKey(index);
        if (key == null) throw _failure(index, 'Expected a static enum key.');
        index = key.next;
        _expect(index, '=', 'Expected = after enum key ${key.name}.');
        index += 1;
        if (tokens[index].kind != _TokenKind.string) {
          throw _failure(index, 'Enum values must be string literals.');
        }
        values[key.name] = tokens[index].value!;
        index += 1;
      } else {
        if (tokens[index].kind != _TokenKind.string) {
          throw _failure(index, 'Enum values must be string literals.');
        }
        final value = tokens[index].value!;
        values[value] = value;
        index += 1;
      }
      if (_is(index, ',') || _is(index, ';')) {
        index += 1;
      }
    }
    final end = _closing(index + 1, '(', ')');
    return _ParseResult(
      _EnumSchema(
        offset: start.offset,
        line: start.line,
        column: start.column,
        tokenName: tokenName,
        values: Map<String, String>.unmodifiable(values),
      ),
      end + 1,
    );
  }

  _ParseResult _raw(_Token start, String? tokenName, int cursor) {
    final end = _closing(cursor, '(', ')');
    return _ParseResult(
      _UnknownSchema(
        offset: start.offset,
        line: start.line,
        column: start.column,
        tokenName: tokenName,
      ),
      end + 1,
    );
  }

  _Builder? _builder(int index) {
    if (!_identifier(index)) return null;
    if (_schemaAliases.contains(tokens[index].lexeme) &&
        _is(index + 1, '.') &&
        _identifier(index + 2) &&
        _is(index + 3, '(')) {
      return _Builder(tokens[index + 2].lexeme, index + 4);
    }
    if (_tinestAliases.contains(tokens[index].lexeme) &&
        _is(index + 1, '.') &&
        _is(index + 2, 'schema') &&
        _is(index + 3, '.') &&
        _identifier(index + 4) &&
        _is(index + 5, '(')) {
      return _Builder(tokens[index + 4].lexeme, index + 6);
    }
    return null;
  }

  ({String name, int next})? _typeToken(int index) {
    if (_identifier(index) &&
        _typeAliases.contains(tokens[index].lexeme) &&
        _is(index + 1, '.') &&
        _identifier(index + 2)) {
      final name = tokens[index + 2].lexeme;
      if (!RegExp(r'^[A-Z][A-Za-z0-9_]*$').hasMatch(name)) {
        throw _failure(index + 2, 'Type token names must be PascalCase.');
      }
      return (name: name, next: index + 3);
    }
    return null;
  }

  ({String name, int next})? _fieldKey(int index) {
    if (_identifier(index)) {
      return (name: tokens[index].lexeme, next: index + 1);
    }
    if (tokens[index].kind == _TokenKind.string) {
      return (name: tokens[index].value!, next: index + 1);
    }
    if (_is(index, '[') &&
        tokens[index + 1].kind == _TokenKind.string &&
        _is(index + 2, ']')) {
      return (name: tokens[index + 1].value!, next: index + 3);
    }
    return null;
  }

  int _closing(int cursor, String open, String close) {
    var index = cursor;
    var depth = 0;
    while (index < tokens.length) {
      if (_is(index, open)) depth += 1;
      if (_is(index, close)) {
        if (depth == 0) return index;
        depth -= 1;
      }
      index += 1;
    }
    throw _failure(tokens.length - 1, 'Unterminated schema builder call.');
  }

  void _expect(int index, String lexeme, String message) {
    if (!_is(index, lexeme)) throw _failure(index, message);
  }

  _SchemaParseFailure _failure(int index, String message) =>
      _SchemaParseFailure(tokens[index], index, message);

  bool _identifier(int index) =>
      index < tokens.length && tokens[index].kind == _TokenKind.identifier;

  bool _is(int index, String lexeme) =>
      index < tokens.length && tokens[index].lexeme == lexeme;
}

final class _Builder {
  const new(this.name, this.argumentsIndex);
  final String name;
  final int argumentsIndex;
}

final class _ParseResult {
  const new(this.node, this.next);
  final _SchemaNode node;
  final int next;
}

final class _SchemaParseFailure implements Exception {
  const new(this.token, this.index, this.message);
  final _Token token;
  final int index;
  final String message;
}

bool _isWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
bool _isDigit(String value) =>
    value.codeUnitAt(0) >= 48 && value.codeUnitAt(0) <= 57;
bool _isIdentifierStart(String value) {
  final code = value.codeUnitAt(0);
  return value == '_' ||
      (code >= 65 && code <= 90) ||
      (code >= 97 && code <= 122);
}

bool _isIdentifierPart(String value) =>
    _isIdentifierStart(value) || _isDigit(value);
