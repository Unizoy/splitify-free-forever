// D-033: the import controller's one-setup-screen flow (Account entry: a new group named after the file).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/features/import_splitwise/application/import_controller.dart';
import 'package:splitify/features/import_splitwise/domain/import_mapping.dart';

Uint8List _fixture(String name) =>
    Uint8List.fromList(File('test/fixtures/splitwise/$name').readAsBytesSync());

void main() {
  late ProviderContainer container;

  ImportController controller() => container.read(importControllerProvider(null).notifier);
  ImportState state() => container.read(importControllerProvider(null));

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    // Keep the autoDispose provider alive for the whole test.
    container.listen(importControllerProvider(null), (_, _) {});
  });

  group('D-033 groupNameFromFile', () {
    // D-033
    test('D-033 the file name becomes a group name', () {
      expect(groupNameFromFile('group_inr_usd.csv'), 'Group inr usd');
      expect(groupNameFromFile('goa-trip_2026-11-21_export.csv'), 'Goa trip');
      expect(groupNameFromFile('.csv'), '');
    });
  });

  group('D-033 loadFile from Account', () {
    // D-033
    test('D-033 sets step people, creatingGroup and a name from the file', () async {
      await controller().loadFile(
        'group_inr_usd.csv',
        _fixture('group_inr_usd.csv'),
        myName: 'Asha',
      );
      final s = state();
      expect(s.step, ImportStep.people);
      expect(s.creatingGroup, isTrue);
      expect(s.newGroupName, 'Group inr usd');
      expect(s.groupId, isNull);
      expect(s.fileName, 'group_inr_usd.csv');
      expect(s.members.single, (id: newGroupMeId, name: 'Asha', isMe: true));
      expect(s.mapping.keys, ['Aarav', 'Priya', 'Rohan', 'Meera']);
      expect(s.parsed!.file.rows, hasLength(8));
      expect(s.canPreview, isTrue);
    });

    // D-033
    test('D-033 a bad file stays on the file step with the problem', () async {
      await controller().loadFile('bad_header.csv', _fixture('bad_header.csv'));
      expect(state().step, ImportStep.file);
      expect(state().problem?.code, isNotNull);
      expect(state().parsed, isNull);
      expect(state().canPreview, isFalse);
    });

    // D-033
    test('D-033 a file with no rows is refused', () async {
      await controller().loadFile(
        'empty.csv',
        Uint8List.fromList(utf8.encode('Date,Description,Category,Cost,Currency,Aarav,Priya\n')),
      );
      expect(state().step, ImportStep.file);
      expect(state().problem, isNotNull);
    });
  });

  group('D-033 new group name and canPreview', () {
    Future<void> load() =>
        controller().loadFile('group_inr_usd.csv', _fixture('group_inr_usd.csv'), myName: 'Asha');

    // D-033
    test('D-033 renameNewGroup changes the name', () async {
      await load();
      controller().renameNewGroup('Goa 2026');
      expect(state().newGroupName, 'Goa 2026');
      expect(state().step, ImportStep.people);
    });

    // D-033
    test(
      'D-033 an empty or 61-letter name blocks the preview; 60 and a normal name allow it',
      () async {
        await load();
        controller().renameNewGroup('');
        expect(state().canPreview, isFalse);
        controller().renameNewGroup('   ');
        expect(state().canPreview, isFalse);
        controller().renameNewGroup('a' * 61);
        expect(state().canPreview, isFalse);
        controller().renameNewGroup('a' * 60);
        expect(state().canPreview, isTrue);
        controller().renameNewGroup('Goa');
        expect(state().canPreview, isTrue);
      },
    );

    // D-033
    test('D-033 a mapping problem blocks the preview', () async {
      await load();
      controller().setChoice('Aarav', const UseMember(newGroupMeId));
      controller().setChoice('Priya', const UseMember(newGroupMeId));
      expect(state().mappingProblem, MappingProblem.sameMemberTwice);
      expect(state().canPreview, isFalse);

      controller().setChoice('Priya', const SkipPerson());
      expect(state().mappingProblem, isNull);
      expect(state().canPreview, isTrue);

      for (final n in ['Aarav', 'Rohan', 'Meera']) {
        controller().setChoice(n, const SkipPerson());
      }
      expect(state().mappingProblem, MappingProblem.nobodyLeft);
      expect(state().canPreview, isFalse);
    });

    // D-033
    test(
      'D-033 goTo(preview) is refused when the setup is not complete, allowed when it is',
      () async {
        await load();
        controller().renameNewGroup('');
        controller().goTo(ImportStep.preview);
        expect(state().step, ImportStep.people);

        controller().renameNewGroup('Goa');
        controller().goTo(ImportStep.preview);
        expect(state().step, ImportStep.preview);

        controller().goTo(ImportStep.people);
        expect(state().step, ImportStep.people);
      },
    );

    // D-033
    test('D-033 goTo(preview) is refused before any file is read', () {
      controller().goTo(ImportStep.preview);
      expect(state().step, ImportStep.file);
    });
  });
}
