import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_exemplar/main.dart';

void main() {
  test('removes sample members without deleting user-added members', () async {
    SharedPreferences.setMockInitialValues({
      'seeded': true,
      'editorialBoardSeeded': true,
      'members': jsonEncode([
        Member('1', 'Jane Doe', 'Editor-in-Chief', DateTime(2007, 6, 12))
            .toJson(),
        Member('2', 'John Smith', 'Photo Editor', DateTime(2007, 8, 25))
            .toJson(),
        Member('custom', 'Student Member', 'Writer', null).toJson(),
      ]),
      'events': '[]',
    });

    await store.load();

    expect(store.members.map((member) => member.name), ['Student Member']);
    final preferences = await SharedPreferences.getInstance();
    final savedMembers = (jsonDecode(preferences.getString('members')!) as List)
        .cast<Map<String, dynamic>>();
    expect(savedMembers.map((member) => member['name']), ['Student Member']);
  });

  testWidgets('editorial board highlights the editor-in-chief first',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    await store.load();
    expect(
        store.members.where((member) => editorialBoard
            .any((boardMember) => boardMember.name == member.name)),
        hasLength(editorialBoard.length));
    store.login(Store.adminUsername, Store.adminPassword, false);
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExemplarApp());
    await tester.pumpAndSettle();

    expect(find.text('Editorial Board 2026–2027'), findsOneWidget);
    expect(find.text('EDITOR-IN-CHIEF'), findsOneWidget);
    expect(find.textContaining('FEATURED'), findsNothing);
    expect(find.text('Dairyl Mae C. Sabdain'), findsOneWidget);
    expect(editorialBoard.first.role, 'Editor-in-Chief');
    expect(
        store.members.where((member) => editorialBoard
            .any((boardMember) => boardMember.name == member.name)),
        hasLength(editorialBoard.length));
    for (final member in editorialBoard) {
      await rootBundle.load(member.asset);
      expect(
        store.members
            .singleWhere((savedMember) => savedMember.name == member.name)
            .photoAsset,
        member.asset,
      );
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == member.asset),
        findsOneWidget,
        reason: '${member.role} image should be included on Home',
      );
    }
    expect(tester.takeException(), isNull);

    await tester
        .tap(find.byKey(const Key('editorial-photo-Dairyl Mae C. Sabdain')));
    await tester.pumpAndSettle();
    expect(find.text('Birthday: Not provided'), findsOneWidget);
    expect(find.text('Description: Not provided.'), findsOneWidget);
    expect(
      find.byKey(const Key('editorial-photo-preview-Dairyl Mae C. Sabdain')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();

    final portraitFinder =
        find.byKey(const Key('editorial-photo-Dairyl Mae C. Sabdain'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(portraitFinder));
    await mouse.moveTo(tester.getCenter(portraitFinder));
    await tester.pump(const Duration(milliseconds: 200));
    final portraitScale = tester.widget<AnimatedScale>(
      find.descendant(of: portraitFinder, matching: find.byType(AnimatedScale)),
    );
    expect(portraitScale.scale, 1.07);
    await mouse.moveTo(const Offset(0, 0));
    await mouse.removePointer();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dairyl Mae C. Sabdain'));
    await tester.pumpAndSettle();
    expect(find.text('Birthday: Not provided'), findsOneWidget);
    expect(find.text('Description: Not provided.'), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dairyl Mae C. Sabdain'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Dairyl Mae C. Sabdain'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is CircleAvatar &&
          widget.backgroundImage is AssetImage &&
          (widget.backgroundImage as AssetImage).assetName ==
              editorialBoard.first.asset),
      findsOneWidget,
    );
  });

  testWidgets('login and event form drafts survive an app reload',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExemplarApp());
    await tester.enterText(find.byType(TextField).at(0), 'draft-user');
    await tester.enterText(find.byType(TextField).at(1), 'draft-password');
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    // A browser refresh ends the old Dart isolate without dismissing its form.
    // Restore the persisted open-form marker after simulating that teardown.
    store.setPendingEventForm('new');
    await store.load();
    await tester.pumpWidget(const ExemplarApp());
    await tester.pumpAndSettle();
    expect(
        (tester.widget<TextField>(find.byType(TextField).at(0)).controller)
            ?.text,
        'draft-user');
    expect(
        (tester.widget<TextField>(find.byType(TextField).at(1)).controller)
            ?.text,
        'draft-password');

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'exemplar123');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Events').last);
    await tester.pumpAndSettle();
    expect(store.selectedPage, 2);
    await tester.tap(find.text('ADD EVENT'));
    await tester.pumpAndSettle();
    expect(find.text('Add Event'), findsOneWidget);
    expect(store.pendingEventFormId, 'new');
    await tester.enterText(find.byType(TextField).at(0), 'Draft event');
    await tester.enterText(find.byType(TextField).at(1), 'Draft location');
    await tester.enterText(find.byType(TextField).at(2), 'Draft notes');
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await store.load();
    await tester.pumpWidget(const ExemplarApp());
    await tester.pumpAndSettle();
    expect(store.selectedPage, 2);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        2);
    await tester.pumpAndSettle();
    expect(find.text('Add Event'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(0)).controller?.text,
        'Draft event');
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller?.text,
        'Draft location');
    expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller?.text,
        'Draft notes');
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(store.pendingEventFormId, isNull);
  });

  testWidgets('login requires username and password', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExemplarApp());
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Please enter a username and password.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Please enter a password.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '');
    await tester.enterText(find.byType(TextField).at(1), 'exemplar123');
    await tester.tap(find.text('LOG IN'));
    await tester.pump();
    expect(find.text('Please enter a username.'), findsOneWidget);
    expect(store.loggedIn, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('school logo and adviser images are shown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExemplarApp());
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName == 'assets/logo.png'),
      findsOneWidget,
    );

    expect(
        store.login(Store.adminUsername, Store.adminPassword, false), isTrue);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ms. Ellaine A. Curib Maelt, LPT'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Ms. Ellaine A. Curib Maelt, LPT'), findsOneWidget);
    expect(find.text('Ms. Chiara Genevieve I. Lastimado Maelt, LPT'),
        findsOneWidget);
    for (final asset in [
      'assets/advisers/ellaine.png',
      'assets/advisers/kiara.png',
    ]) {
      await rootBundle.load(asset);
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == asset),
        findsOneWidget,
      );
    }
    await tester.tap(
        find.byKey(const Key('adviser-photo-Ms. Ellaine A. Curib Maelt, LPT')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
          const Key('adviser-photo-preview-Ms. Ellaine A. Curib Maelt, LPT')),
      findsOneWidget,
    );
    expect(find.text('Birthday: Not provided'), findsOneWidget);
    expect(find.textContaining('Description:'), findsNothing);
    expect(find.text('Adviser').last, findsOneWidget);
    expect(find.byKey(const Key('edit-adviser-birthday')), findsOneWidget);
    await tester.tap(find.byTooltip('Close photo'));
    await tester.pumpAndSettle();

    final birthday = DateTime(1980, 5, 12);
    store.saveAdviserBirthday(advisers.first.name, birthday);
    await store.load();
    expect(store.adviserBirthday(advisers.first.name), birthday);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event changes update immediately without logging out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ExemplarApp());
    expect(find.text('Admin account: admin / exemplar123'), findsNothing);
    await tester.enterText(find.byType(TextField).at(0), 'admin');
    await tester.enterText(find.byType(TextField).at(1), 'exemplar123');
    await tester.tap(find.text('LOG IN'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Events').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('ADD EVENT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Staff meeting');
    await tester.enterText(find.byType(TextField).at(1), 'Room 1');
    await tester.enterText(
        find.byType(TextField).at(2), 'Bring the complete publication draft.');
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(find.text('Staff meeting'), findsOneWidget);
    expect(find.text('LOG IN'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Staff meeting'));
    await tester.pumpAndSettle();
    expect(find.text('Room 1'), findsNWidgets(2));
    expect(find.text('Bring the complete publication draft.'), findsOneWidget);
    expect(find.text(fmtFull(store.events.single.date)), findsOneWidget);
    await tester.tap(find.text('CLOSE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('admin'), findsNothing);
    expect(find.text('Admin'), findsNothing);

    await tester.tap(find.text('Events').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('No events yet.'), findsOneWidget);
    expect(store.events, isEmpty);
    expect(find.text('LOG IN'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('member accounts can read data but cannot modify it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await store.load();
    expect(store.signUp('reader', 'pass1234'), isTrue);
    expect(store.login('reader', 'pass1234', false), isTrue);
    expect(store.isAdmin, isFalse);

    await tester.pumpWidget(const ExemplarApp());
    await tester.tap(find.text('Members').last);
    await tester.pumpAndSettle();
    expect(find.text('ADD NEW MEMBER'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('Events').last);
    await tester.pumpAndSettle();
    expect(find.text('ADD EVENT'), findsNothing);
    expect(find.byIcon(Icons.edit), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);

    final memberCount = store.members.length;
    final eventCount = store.events.length;
    expect(
        () => store.saveMember(
            Member('blocked', 'Blocked', 'Member', DateTime(2008, 1, 1))),
        throwsStateError);
    expect(() => store.deleteMember(store.members.first.id), throwsStateError);
    expect(
        () => store.saveEvent(
            Event('blocked', 'Blocked', '', '', DateTime(2026, 1, 1))),
        throwsStateError);
    expect(() => store.deleteEvent('blocked'), throwsStateError);
    expect(() => store.resetAll(), throwsStateError);
    expect(store.members, hasLength(memberCount));
    expect(store.events, hasLength(eventCount));

    await tester.tap(find.text('Manage').last);
    await tester.pumpAndSettle();
    expect(find.text('Member • Read-only'), findsOneWidget);
    expect(find.text('Clear all members & events'), findsNothing);
  });
}
