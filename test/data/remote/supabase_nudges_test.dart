import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/data/remote/supabase_nudges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// S-259: a refused Realtime join (a group made offline is not on the server yet) is retried, so the group
/// still gets live updates without restarting the app.
void main() {
  late List<String> joins;
  late Map<String, ({void Function() changed, void Function() failed})> live;
  late List<String> left;

  SupabaseNudges nudges() => SupabaseNudges(
    SupabaseClient('http://localhost', 'test-key'),
    userId: () => 'u1',
    join: (topic, {required onChanged, required onFailed}) {
      joins.add(topic);
      live[topic] = (changed: onChanged, failed: onFailed);
      return () async => left.add(topic);
    },
  );

  setUp(() {
    joins = [];
    live = {};
    left = [];
  });

  test('joins every group topic and the user topic once', () {
    fakeAsync((async) {
      final n = nudges();
      n.watchGroups({'g1', 'g2'});
      n.watchGroups({'g1', 'g2'});
      async.flushMicrotasks();
      expect(joins, unorderedEquals(['group:g1', 'group:g2', 'user:u1']));
      n.watchGroups({'g1'});
      async.flushMicrotasks();
      expect(left, ['group:g2']);
      n.dispose();
      async.flushMicrotasks();
    });
  });

  test('a refused join is tried again after a pause and nudges once it works', () {
    fakeAsync((async) {
      final n = nudges();
      var nudged = 0;
      n.nudges.listen((_) => nudged++);
      n.watchGroups({'new-group'});
      async.flushMicrotasks();
      live['group:new-group']!.failed();
      async.flushMicrotasks();
      expect(left, contains('group:new-group'));
      expect(joins.where((t) => t == 'group:new-group'), hasLength(1));
      async.elapse(const Duration(seconds: 11));
      expect(joins.where((t) => t == 'group:new-group'), hasLength(2));
      live['group:new-group']!.changed();
      async.flushMicrotasks();
      expect(nudged, 1);
      n.dispose();
      async.flushMicrotasks();
    });
  });

  test('a refused join is also tried again on the next group list', () {
    fakeAsync((async) {
      final n = nudges();
      n.watchGroups({'g1'});
      live['group:g1']!.failed();
      async.flushMicrotasks();
      n.watchGroups({'g1'});
      async.flushMicrotasks();
      expect(joins.where((t) => t == 'group:g1'), hasLength(2));
      // The pending timer does not join a third time while the topic is joined.
      async.elapse(const Duration(minutes: 3));
      expect(joins.where((t) => t == 'group:g1'), hasLength(2));
      n.dispose();
      async.flushMicrotasks();
    });
  });

  test('no retry for a topic that is no longer wanted', () {
    fakeAsync((async) {
      final n = nudges();
      n.watchGroups({'gone'});
      live['group:gone']!.failed();
      n.watchGroups(const {});
      async.elapse(const Duration(minutes: 3));
      expect(joins.where((t) => t == 'group:gone'), hasLength(1));
      n.dispose();
      async.flushMicrotasks();
    });
  });
}
