// R4 robustness: deep links and router parsing (lib/app/router.dart). A link comes from anywhere (a QR, a web
// page, another app), so:
//
// TC-R4-L-01  random links never throw, every redirect chain ends within go_router's 5 hops, and app links
//             only ever lead to an in-app path (never another scheme or host)
// TC-R4-L-02  signed out, no link reaches a signed-in page; a kept join is only ever /join or /friends/code
// TC-R4-L-03  links with broken percent-escapes, huge codes, dot segments or unknown pages open a screen
//             (the page or "not found"), never a crash
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitify/app/not_found_screen.dart';
import 'package:splitify/app/router.dart';
import 'package:splitify/features/auth/application/pending_join.dart';
import 'package:splitify/features/friends/presentation/friend_routes.dart';

import '../support/group_harness.dart';

const _pieces = [
  'splitify://',
  'https://',
  'http://evil.example/',
  'intent://',
  'join',
  'friend',
  'group',
  'groups',
  'dev', //
  'account',
  'delete',
  'friends',
  'code',
  'debug',
  'login',
  'sign-in',
  'welcome',
  '/',
  '//',
  '?',
  '&',
  '#', //
  '=',
  'code=',
  'user=',
  '..',
  '.',
  '%',
  '%2F',
  '%25',
  '%ZZ',
  '%E0%A4',
  '%00',
  ':',
  '@',
  'ABCD-EFGH',
  'abcdefgh', //
  ' ',
  '+',
  'é',
  '🎉',
  'ש',
  'u:x',
  'm:y',
  'g1',
  'e2e-a',
  'capture',
  'notifications',
  'settings',
  'edit',
];

String _randomLink(Random r) =>
    [for (var i = 0; i < 1 + r.nextInt(10); i++) _pieces[r.nextInt(_pieces.length)]].join();

bool _public(String path) =>
    path == Routes.welcome || path.startsWith(Routes.signIn) || path.startsWith('/debug/');

/// Follows the router's redirects like go_router does; the final location, or null after 5 hops.
String? _follow(String link, {required bool signedIn, PendingJoin? pending, bool debug = false}) {
  var location = link;
  for (var hop = 0; hop <= 5; hop++) {
    final next = authRedirect(
      Uri.parse(location),
      signedIn: signedIn,
      debug: debug,
      pendingJoin: pending,
    );
    if (next == null) return location;
    location = next;
  }
  return null;
}

void main() {
  // TC-R4-L-01
  group('random links', () {
    test('never throw, end within 5 redirects, and app links stay inside the app', () {
      final r = Random(4401);
      var parsed = 0;
      for (var k = 0; k < 20000; k++) {
        final uri = Uri.tryParse(_randomLink(r));
        if (uri == null) continue;
        parsed++;
        final String? link;
        try {
          link = linkRedirect(uri);
        } on Object catch (e) {
          fail('linkRedirect($uri) threw $e');
        }
        if (link != null) {
          final to = Uri.parse(link);
          expect(to.hasScheme, isFalse, reason: '$uri → $link');
          expect(to.hasAuthority, isFalse, reason: '$uri → $link');
          expect(link.startsWith('/'), isTrue, reason: '$uri → $link');
        }
        for (final signedIn in [false, true]) {
          final end = _follow(uri.toString(), signedIn: signedIn, pending: PendingJoin());
          expect(end, isNotNull, reason: '$uri loops (signed in: $signedIn)');
        }
      }
      expect(parsed, greaterThan(10000));
    });
  });

  // TC-R4-L-02
  group('signed out', () {
    test('no link reaches a signed-in page; a kept join is /join or /friends/code only', () {
      final r = Random(4402);
      for (var k = 0; k < 20000; k++) {
        final uri = Uri.tryParse(_randomLink(r));
        if (uri == null) continue;
        final pending = PendingJoin();
        final end = _follow(uri.toString(), signedIn: false, pending: pending);
        final path = Uri.parse(end!).path;
        expect(_public(path), isTrue, reason: '$uri ends at $end while signed out');
        final kept = pending.take();
        if (kept != null) {
          final p = Uri.parse(kept).path;
          expect(
            p == Routes.join ||
                p == FriendRoutes.addByCode ||
                p.startsWith('${FriendRoutes.addByCode}/'),
            isTrue,
            reason: '$uri kept $kept',
          );
        }
      }
    });

    test('the debug sign-in link does nothing in a release build', () {
      for (final link in ['splitify://dev/login?user=e2e-a', '/login', '/dev/login?user=x']) {
        final end = _follow(link, signedIn: false);
        expect(end, isNot(contains(Routes.devLogin)), reason: link);
        final signedInEnd = _follow(link, signedIn: true);
        expect(signedInEnd, isNot(contains(Routes.devLogin)), reason: link);
      }
    });

    test('dot segments cannot climb out of a kept invite', () {
      final pending = PendingJoin();
      final end = _follow('/friends/code/../../account/delete', signedIn: false, pending: pending);
      expect(end, Routes.welcome);
      expect(pending.take(), isNull);
      final joinPending = PendingJoin();
      _follow(
        'splitify://join/../account/delete?code=ABCDEFGH',
        signedIn: false,
        pending: joinPending,
      );
      final kept = joinPending.take();
      expect(kept == null || Uri.parse(kept).path == Routes.join, isTrue, reason: '$kept');
    });
  });

  // TC-R4-L-03
  group('odd links open a screen, never a crash', () {
    final links = <String>[
      '/friends/%25ZZ',
      '/friends/%25E0%25A4',
      '/friends/code/%25ZZ',
      '/friends/${'x' * 5000}',
      '/groups/${'a' * 5000}',
      '/groups/%25ZZ/settings',
      '/join/%25E0%25A4',
      '/join?code=${'A' * 20000}',
      '/join?code=%25ZZ',
      '/no/such/page',
      linkRedirect(Uri.parse('splitify://friend?code=%2525ZZ'))!,
      linkRedirect(Uri.parse('splitify://groups/%2525ZZ'))!,
    ];
    for (final link in links) {
      testWidgets('opens ${link.length > 60 ? '${link.substring(0, 60)}…' : link}', (tester) async {
        await pumpGroups(tester, link, overrides: fixedGroupData());
        await settle(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(Scaffold), findsWidgets);
        // Either the page or "not found"; both lead back home.
        expect(
          find.byType(NotFoundScreen).evaluate().isNotEmpty ||
              find.byType(Scaffold).evaluate().isNotEmpty,
          isTrue,
        );
      });
    }
  });
}
