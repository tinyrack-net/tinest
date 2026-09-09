@Tags(<String>['feature_test__plugin_authoring__unit'])
library;

import 'package:daemon/src/features/plugins/runtime/plugin_type_environment.dart';
import 'package:test/test.dart';

void main() {
  test('generates exact nested LuaCATS types from reference builders', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.reader',
      sources: <String, String>{
        'main.lua': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")

local Status, status = S.literal_enum(T.Status, {
  active = "active",
  completed = "completed",
})
local Input = S.object(T.Input, {
  path = S.string(),
  line = S.optional(S.integer()),
  tags = S.array(S.string()),
  scores = S.map(S.number()),
  profile = S.object({name = S.string()}),
  status = Status,
})
local Output = S.object(T.Output, {text = S.string()})
''',
      },
    );

    expect(
      environment.diagnostics.map(
        (diagnostic) =>
            '${diagnostic.code}|${diagnostic.path}|${diagnostic.message}',
      ),
      isEmpty,
    );
    expect(environment.tokenNames, <String>['Input', 'Output', 'Status']);
    expect(
      environment.authoringDefinition,
      allOf(<Matcher>[
        contains('---@class (exact) tinest_plugin_acme_reader.Input'),
        contains('---@field line? integer'),
        contains('---@field tags string[]'),
        contains('---@field scores table<string, number>'),
        contains('---@field profile tinest_plugin_acme_reader.InputProfile'),
        contains('---@field completed "completed"'),
        contains(
          <String>[
            '---@field Status tinest.EnumTypeToken<',
            'tinest_plugin_acme_reader.Status, ',
            'tinest_plugin_acme_reader.Status.Values>',
          ].join(),
        ),
        contains('---@meta tinest.types'),
      ]),
    );
  });

  test('reports unsupported tokenized shapes without evaluating source', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.reader',
      sources: <String, String>{
        'main.lua': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, fields_from_untrusted_code())
''',
      },
    );

    expect(
      environment.diagnostics.map((diagnostic) => diagnostic.code),
      contains('plugin_types_parse'),
    );
    expect(environment.tokenNames, isEmpty);
    expect(
      PluginTypeEnvironmentGenerator.referencedTokenNames(<String, String>{
        'main.lua': '''
local T = require("tinest.types")
local Input = S.object(T.Input, fields_from_untrusted_code())
''',
      }),
      <String>['Input'],
    );
  });

  test('runtime token inventory is independent of comments and strings', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.reader',
      sources: <String, String>{
        'main.lua': '''
-- S.object(T.Forged, {})
local text = "S.object(T.AlsoForged, {})"
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
return S.object(T.Real, {})
''',
      },
    );

    expect(environment.tokenNames, <String>['Real']);
  });

  test('requires explicit modules and supports Lua call sugar', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.reader',
      sources: <String, String>{
        'main.lua': '''
local tinest = require "tinest"
local S = tinest.schema
local Types = require "tinest.types"
local Input = S.object(Types.Input, {path = S.string()})

-- These names are ordinary locals, not magic SDK globals.
local forged = T.Forged
local also_forged = T.AlsoForged
''',
      },
    );

    expect(
      environment.diagnostics.map(
        (diagnostic) =>
            '${diagnostic.code}|${diagnostic.path}|${diagnostic.message}',
      ),
      isEmpty,
    );
    expect(environment.tokenNames, <String>['Input']);
    expect(
      PluginTypeEnvironmentGenerator.referencedTokenNames(<String, String>{
        'main.lua': 'return T.Forged',
      }),
      isEmpty,
    );
  });

  test('diagnoses unsupported dynamic type-token access', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.reader',
      sources: <String, String>{
        'main.lua': '''
local T = require("tinest.types")
local name = "Input"
local token = T[name]
''',
      },
    );

    expect(
      environment.diagnostics,
      contains(
        isA<PluginTypeAuthoringDiagnostic>()
            .having(
              (diagnostic) => diagnostic.code,
              'code',
              'plugin_type_dynamic_reference',
            )
            .having((diagnostic) => diagnostic.line, 'line', 3),
      ),
    );
    expect(
      PluginTypeEnvironmentGenerator.referencedTokenNames(<String, String>{
        'main.lua': 'local T = require("tinest.types")\nreturn T[name]',
      }),
      isEmpty,
    );
  });

  test('projects primitive, enum, raw, and static-key schema forms', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.forms',
      sources: <String, String>{
        'main.lua': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Mode, mode = S.enum(T.Mode, {"fast", "safe"})
local Raw = tinest.schema.raw(T.Raw, {type = "object"})
local Input = S.object(T.Input, {
  plain = S.string(),
  ["dash-key"] = S.optional(Mode),
  quoted = S.map(S.boolean()),
  raw = Raw,
})
''',
      },
    );

    expect(
      environment.diagnostics.map(
        (diagnostic) =>
            '${diagnostic.code}|${diagnostic.path}|${diagnostic.message}',
      ),
      isEmpty,
    );
    expect(environment.tokenNames, <String>['Input', 'Mode', 'Raw']);
    expect(
      environment.authoringDefinition,
      allOf(<Matcher>[
        contains('---@field plain string'),
        contains('---@field ["dash-key"]? tinest_plugin_acme_forms.Mode'),
        contains('---@field quoted table<string, boolean>'),
        contains('---@alias tinest_plugin_acme_forms.Raw any'),
        contains('---@field fast "fast"'),
      ]),
    );
  });

  test('diagnoses duplicate token ownership across Lua modules', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.duplicates',
      sources: <String, String>{
        'main.lua': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {})
''',
        'lua/other.lua': '''
local tinest = require("tinest")
local T = require("tinest.types")
local Input = tinest.schema.object(T.Input, {})
''',
      },
    );

    expect(
      environment.diagnostics.map(
        (diagnostic) =>
            '${diagnostic.code}|${diagnostic.path}|${diagnostic.message}',
      ),
      contains(startsWith('plugin_type_duplicate|main.lua|')),
    );
  });

  test('lexer reports unterminated quoted and long Lua tokens', () {
    final quoted = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.quoted',
      sources: const <String, String>{'main.lua': 'local text = "unterminated'},
    );
    final longString = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.long',
      sources: const <String, String>{
        'main.lua': 'local text = [==[unterminated',
      },
    );
    final longComment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.comment',
      sources: const <String, String>{'main.lua': '--[=[unterminated'},
    );

    expect(
      quoted.diagnostics.single.message,
      contains('Unterminated Lua string'),
    );
    expect(
      longString.diagnostics.single.message,
      contains('Unterminated Lua long string or comment'),
    );
    expect(
      longComment.diagnostics.single.message,
      contains('Unterminated Lua long string or comment'),
    );
  });

  test('valid long strings and comments cannot forge type tokens', () {
    final environment = PluginTypeEnvironmentGenerator.analyze(
      pluginId: 'acme.long-safe',
      sources: <String, String>{
        'main.lua': '''
local text = [==[S.object(T.ForgedByString, {})]==]
--[=[S.object(T.ForgedByComment, {})]=]
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Real = S.object(T.Real, {})
''',
      },
    );

    expect(environment.diagnostics, isEmpty);
    expect(environment.tokenNames, <String>['Real']);
  });

  test('schema parser reports every rejected static authoring form', () {
    final cases = <String, String>{
      'missing container schema': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.array(T.Input)
''',
      'dynamic object field': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {[field()] = S.string()})
''',
      'dynamic object schema': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {value = make_schema()})
''',
      'dynamic enum key': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Mode = S.literal_enum(T.Mode, {[mode()] = "fast"})
''',
      'non-string enum literal': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Mode = S.literal_enum(T.Mode, {fast = 1})
''',
      'non-string enum value': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Mode = S.enum(T.Mode, {1})
''',
      'lowercase type token': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.input, {})
''',
      'unterminated builder call': '''
local tinest = require("tinest")
local S = tinest.schema
local T = require("tinest.types")
local Input = S.object(T.Input, {value = S.string()
''',
    };

    for (final entry in cases.entries) {
      final environment = PluginTypeEnvironmentGenerator.analyze(
        pluginId: 'acme.invalid',
        sources: <String, String>{'main.lua': entry.value},
      );
      expect(
        environment.diagnostics.map((diagnostic) => diagnostic.code),
        contains('plugin_types_parse'),
        reason: entry.key,
      );
    }
  });
}
