import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'support/repo_root.dart';

void main() {
  useRepositoryRoot();

  test('production selection controls follow the Select contract', () {
    final violations = <String>[];
    for (final file
        in Directory(
              'packages/app/lib',
            )
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (file) => file.path.endsWith('.dart'),
            )) {
      final result = parseFile(
        path: p.normalize(p.absolute(file.path)),
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      result.unit.accept(_SelectPolicyVisitor(file.path, violations));
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

final class _SelectPolicyVisitor extends RecursiveAstVisitor<void> {
  _SelectPolicyVisitor(this.path, this.violations);

  final String path;
  final List<String> violations;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    super.visitInstanceCreationExpression(node);
    final name = node.constructorName.type.name.lexeme;
    _check(name, node.argumentList, node.offset);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    _check(node.methodName.name, node.argumentList, node.offset);
  }

  void _check(String name, ArgumentList argumentList, int offset) {
    const forbiddenSelectionImplementations = <String>{
      'DropdownButton',
      'DropdownButtonFormField',
      'showModelPicker',
      'showPermissionPicker',
      'ModelPickerSurface',
      'PermissionPickerChoice',
      'ComposerChipSpec',
    };
    final normalizedPath = path.replaceAll(r'\', '/');
    if (forbiddenSelectionImplementations.contains(name)) {
      violations.add(
        '$normalizedPath:$offset: $name bypasses the shared TRSelect contract',
      );
      return;
    }
    if (name != 'TRSelect' && name != 'TRSelectFormField') return;
    final arguments = <String, Expression>{
      for (final argument in argumentList.arguments)
        if (argument is NamedArgument)
          argument.name.lexeme: argument.argumentExpression,
    };
    final searchable = arguments['searchable'];
    final presentation = arguments['presentation'];
    if (searchable is! BooleanLiteral || !searchable.value) {
      violations.add('$normalizedPath:$offset: $name needs searchable: true');
    }
    if (presentation?.toSource() !=
        'TinestSelectPresentation.resolve(context)') {
      violations.add(
        '$normalizedPath:$offset: $name needs '
        'presentation: TinestSelectPresentation.resolve(context)',
      );
    }
  }
}
