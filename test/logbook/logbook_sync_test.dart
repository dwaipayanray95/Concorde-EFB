import 'package:concorde_efb/features/logbook/data/logbook_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const t1 = '2026-05-01T10:00:00.000Z';
  const t2 = '2026-05-02T10:00:00.000Z';

  test('fetches missing and newer, pushes newer local, drops unknown', () {
    final plan = planLogbookSync(
      local: {'same': t1, 'old': t1, 'edited': t2, 'gone': t1},
      remote: {'same': t1, 'old': t2, 'edited': t1, 'new': t1},
    );
    expect(plan.toFetch..sort(), ['new', 'old']);
    expect(plan.toPush, ['edited']);
    expect(plan.toDeleteLocal, ['gone']);
    expect(plan.toDeleteRemote, isEmpty);
  });

  test(
    'pending phone deletes go to the desktop instead of being re-fetched',
    () {
      final plan = planLogbookSync(
        local: {},
        remote: {'x': t1, 'y': t1},
        pendingDeletes: {'x'},
      );
      expect(plan.toFetch, ['y']);
      expect(plan.toDeleteRemote, ['x']);
    },
  );

  test('identical logbooks need nothing', () {
    final plan = planLogbookSync(local: {'a': t1}, remote: {'a': t1});
    expect(plan.toFetch, isEmpty);
    expect(plan.toPush, isEmpty);
    expect(plan.toDeleteLocal, isEmpty);
  });
}
