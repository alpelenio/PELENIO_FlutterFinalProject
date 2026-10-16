import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ======================= THEME / CONSTANTS =======================
const kBlue = Color(0xFF0D47A1);
const kMid = Color(0xFF1976D2);
const kSky = Color(0xFF42A5F5);
const kLight = Color(0xFFE3F2FD);
const kGold = Color(0xFFFFD54F);
const kGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [kBlue, kMid, kSky]);

// >>> ADVISERS: edit names/titles here. Put photos in assets/advisers/ <<<
class Adviser {
  final String name, title, asset;
  const Adviser(this.name, this.title, this.asset);
}

const advisers = [
  Adviser('Ms. Ellaine A. Curib Maelt, LPT', 'Adviser',
      'assets/advisers/ellaine.png'),
  Adviser('Ms. Chiara Genevieve I. Lastimado Maelt, LPT', 'Adviser',
      'assets/advisers/kiara.png'),
];

class EditorialBoardMember {
  final String name, role, asset, description;
  const EditorialBoardMember(this.name, this.role, this.asset,
      {this.description = 'Not provided.'});
}

const editorialBoard = [
  EditorialBoardMember('Dairyl Mae C. Sabdain', 'Editor-in-Chief',
      'assets/editorial_board/editor_in_chief.png'),
  EditorialBoardMember('Anne Francis Marie B. Guillilat', 'News Editor',
      'assets/editorial_board/news_editor.png'),
  EditorialBoardMember('Jacquemae B. Montalbo', 'Feature Editor',
      'assets/editorial_board/feature_editor.png'),
  EditorialBoardMember('Jonalyn M. Reyes', 'Social Media Manager',
      'assets/editorial_board/social_media_manager.png'),
  EditorialBoardMember('John Lloyd B. Lebita', 'Associate Editor (External)',
      'assets/editorial_board/associate_editor_external.png'),
  EditorialBoardMember('Theresa Mae B. Zapico', 'Secretary',
      'assets/editorial_board/secretary.png'),
  EditorialBoardMember('Zamer R. De Erio', 'Literary Editor',
      'assets/editorial_board/literary_editor.png'),
  EditorialBoardMember('Ashley Joy N. Moreno', 'Managing Editor',
      'assets/editorial_board/managing_editor.png'),
  EditorialBoardMember('Collen C. Mendana', 'Assistant Photojournalist',
      'assets/editorial_board/assistant_photojournalist.png'),
  EditorialBoardMember('Jollan Oliver R. De Vera', 'Head Video Editor',
      'assets/editorial_board/head_video_editor.png'),
  EditorialBoardMember('Alnor G. Delenio', 'Head Videographer',
      'assets/editorial_board/head_videographer.png'),
  EditorialBoardMember('Daisymae Mejares', 'Head Photojournalist',
      'assets/editorial_board/head_photojournalist.png'),
  EditorialBoardMember('Justine Niño B. Cubelo', 'Head Layout Artist',
      'assets/editorial_board/head_layout_artist.png'),
  EditorialBoardMember('Kim Althea B. Feliminiano', 'Head Cartoonist',
      'assets/editorial_board/head_cartoonist.png'),
  EditorialBoardMember('Jenifir D. Lopoz', 'Associate Editor (Internal)',
      'assets/editorial_board/associate_editor_internal.png'),
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
String fmt(DateTime d) =>
    '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';
String fmtFull(DateTime d) => '${fmt(d)}, ${d.year}';
DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime nextBirthday(DateTime b) {
  final t = today();
  var n = DateTime(t.year, b.month, b.day);
  if (n.isBefore(t)) n = DateTime(t.year + 1, b.month, b.day);
  return n;
}

int daysUntil(DateTime b) => nextBirthday(b).difference(today()).inDays;

// ======================= MODELS =======================
class Member {
  String id, name, role;
  DateTime? birthday;
  String? photo; // base64 image
  String? photoAsset;
  String description;
  Member(this.id, this.name, this.role, this.birthday,
      [this.photo, this.photoAsset, this.description = 'Not provided.']);
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'birthday': birthday?.toIso8601String(),
        'photo': photo,
        'photoAsset': photoAsset,
        'description': description
      };
  factory Member.fromJson(Map j) => Member(
      j['id'],
      j['name'],
      j['role'],
      j['birthday'] == null ? null : DateTime.parse(j['birthday']),
      j['photo'],
      j['photoAsset'],
      j['description'] ?? 'Not provided.');
}

class Event {
  String id, title, location, notes;
  DateTime date;
  Event(this.id, this.title, this.location, this.notes, this.date);
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'location': location,
        'notes': notes,
        'date': date.toIso8601String()
      };
  factory Event.fromJson(Map j) => Event(j['id'], j['title'], j['location'],
      j['notes'], DateTime.parse(j['date']));
}

// ======================= STORE =======================
class Store extends ChangeNotifier {
  static const adminUsername = 'admin';
  static const adminPassword = 'exemplar123';
  List<Member> members = [];
  List<Event> events = [];
  Map<String, DateTime?> adviserBirthdays = {};
  Map<String, String> users = {adminUsername: adminPassword};
  bool loggedIn = false;
  String? currentUsername;
  int selectedPage = 0;
  bool get isAdmin => currentUsername == adminUsername;
  late SharedPreferences _p;

  Map<String, dynamic> readDraft(String key) =>
      Map<String, dynamic>.from(jsonDecode(_p.getString('draft:$key') ?? '{}'));

  void saveDraftField(String key, String field, Object value) {
    final draft = readDraft(key);
    draft[field] = value;
    _p.setString('draft:$key', jsonEncode(draft));
  }

  void clearDraft(String key) {
    _p.remove('draft:$key');
  }

  String? get pendingEventFormId => _p.getString('pendingEventFormId');

  void setPendingEventForm(String? eventId) {
    if (eventId == null) {
      _p.remove('pendingEventFormId');
      return;
    }
    _p.setString('pendingEventFormId', eventId);
    selectPage(2);
  }

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final savedAdviserBirthdays =
        jsonDecode(_p.getString('adviserBirthdays') ?? '{}')
            as Map<String, dynamic>;
    adviserBirthdays = {
      for (final adviser in advisers)
        adviser.name: savedAdviserBirthdays[adviser.name] == null
            ? null
            : DateTime.parse(savedAdviserBirthdays[adviser.name] as String),
    };
    members = (jsonDecode(_p.getString('members') ?? '[]') as List)
        .map((e) => Member.fromJson(e))
        .toList();
    events = (jsonDecode(_p.getString('events') ?? '[]') as List)
        .map((e) => Event.fromJson(e))
        .toList();
    final u = _p.getString('users');
    if (u != null) users = Map<String, String>.from(jsonDecode(u));
    users.putIfAbsent(adminUsername, () => adminPassword);
    currentUsername = _p.getString('currentUsername');
    final savedPage = _p.getInt('selectedPage') ?? 0;
    selectedPage = savedPage >= 0 && savedPage < 5 ? savedPage : 0;
    loggedIn = (_p.getBool('remember') ?? false) &&
        currentUsername != null &&
        users.containsKey(currentUsername);
    if (!loggedIn) {
      currentUsername = null;
      await _p.remove('currentUsername');
    }
    const sampleMemberNames = {
      'Jane Doe',
      'John Smith',
      'Maria Garcia',
      'Alex Chen',
    };
    final memberCountBeforeSampleCleanup = members.length;
    members.removeWhere((member) => sampleMemberNames.contains(member.name));
    final removedSampleMembers =
        members.length != memberCountBeforeSampleCleanup;
    await _p.setBool('seeded', true);
    if (_p.getBool('editorialBoardSeeded') != true) {
      for (var i = 0; i < editorialBoard.length; i++) {
        final boardMember = editorialBoard[i];
        final existingIndex = members.indexWhere((member) =>
            member.name.toLowerCase() == boardMember.name.toLowerCase());
        if (existingIndex == -1) {
          members.add(Member(
              'editorial-${i + 1}',
              boardMember.name,
              boardMember.role,
              null,
              null,
              boardMember.asset,
              boardMember.description));
        } else {
          final member = members[existingIndex];
          member.photoAsset ??= boardMember.asset;
          if (member.description == 'Not provided.') {
            member.description = boardMember.description;
          }
        }
      }
      await _p.setBool('editorialBoardSeeded', true);
      _save();
    } else if (removedSampleMembers) {
      _save();
    }
    notifyListeners();
  }

  void _save() {
    _p.setString(
        'members', jsonEncode(members.map((e) => e.toJson()).toList()));
    _p.setString('events', jsonEncode(events.map((e) => e.toJson()).toList()));
    _p.setString('users', jsonEncode(users));
    notifyListeners();
  }

  void _requireAdmin() {
    if (!isAdmin) throw StateError('Only the admin account can modify data.');
  }

  void selectPage(int page) {
    if (page < 0 || page >= 5) {
      throw RangeError.range(page, 0, 4, 'page');
    }
    selectedPage = page;
    _p.setInt('selectedPage', page);
  }

  DateTime? adviserBirthday(String name) => adviserBirthdays[name];

  void saveAdviserBirthday(String name, DateTime? birthday) {
    _requireAdmin();
    adviserBirthdays[name] = birthday;
    _p.setString(
        'adviserBirthdays',
        jsonEncode({
          for (final entry in adviserBirthdays.entries)
            entry.key: entry.value?.toIso8601String(),
        }));
    notifyListeners();
  }

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void saveMember(Member m) {
    _requireAdmin();
    final i = members.indexWhere((e) => e.id == m.id);
    i == -1 ? members.add(m) : members[i] = m;
    _save();
  }

  void deleteMember(String id) {
    _requireAdmin();
    members.removeWhere((e) => e.id == id);
    _save();
  }

  void saveEvent(Event e) {
    _requireAdmin();
    final i = events.indexWhere((x) => x.id == e.id);
    i == -1 ? events.add(e) : events[i] = e;
    events.sort((a, b) => a.date.compareTo(b.date));
    _save();
  }

  void deleteEvent(String id) {
    _requireAdmin();
    events.removeWhere((e) => e.id == id);
    _save();
  }

  bool login(String u, String p, bool remember) {
    if (users[u] != p) return false;
    loggedIn = true;
    currentUsername = u;
    _p.setBool('remember', remember);
    remember
        ? _p.setString('currentUsername', u)
        : _p.remove('currentUsername');
    notifyListeners();
    return true;
  }

  bool signUp(String u, String p) {
    if (u.isEmpty || p.length < 4 || users.containsKey(u)) return false;
    users[u] = p;
    _save();
    return true;
  }

  void logout() {
    loggedIn = false;
    currentUsername = null;
    _p.setBool('remember', false);
    _p.remove('currentUsername');
    notifyListeners();
  }

  void resetAll() {
    _requireAdmin();
    members = [];
    events = [];
    _save();
  }
}

final store = Store();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  runApp(const ExemplarApp());
}

class ExemplarApp extends StatelessWidget {
  const ExemplarApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'The Exemplar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: kBlue, primary: kBlue, surface: Colors.white),
          textTheme: GoogleFonts.poppinsTextTheme(),
          scaffoldBackgroundColor: Colors.white,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(color: kBlue.withOpacity(.15))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: BorderSide(color: kBlue.withOpacity(.15))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: kMid, width: 2)),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: kBlue,
                shape: const StadiumBorder(),
                minimumSize: const Size(0, 50)),
          ),
        ),
        home: ListenableBuilder(
            listenable: store,
            builder: (_, __) =>
                store.loggedIn ? const Shell() : const LoginPage()),
      );
}

// ======================= UI KIT =======================
TextStyle serif(double s,
        {Color c = Colors.white, FontWeight w = FontWeight.w700}) =>
    GoogleFonts.playfairDisplay(fontSize: s, color: c, fontWeight: w);

class _Wave extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, s.height - 28)
    ..quadraticBezierTo(s.width * .25, s.height, s.width * .5, s.height - 18)
    ..quadraticBezierTo(s.width * .78, s.height - 40, s.width, s.height - 8)
    ..lineTo(s.width, 0)
    ..close();
  @override
  bool shouldReclip(_) => false;
}

class _Deco extends CustomPainter {
  void spark(Canvas c, Offset o, double r, Paint p) => c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
        ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
        ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r),
      p);
  @override
  void paint(Canvas c, Size s) {
    final w = Paint()..color = Colors.white.withOpacity(.09);
    c.drawCircle(Offset(s.width * .92, 10), 80, w);
    c.drawCircle(Offset(s.width * .05, s.height * .85), 55, w);
    c.drawCircle(Offset(s.width * .6, s.height * .05), 28, w);
    final g = Paint()..color = kGold;
    spark(c, Offset(s.width * .80, s.height * .30), 11, g);
    spark(c, Offset(s.width * .90, s.height * .58), 7, g);
    spark(c, Offset(s.width * .70, s.height * .72), 6, g);
  }

  @override
  bool shouldRepaint(_) => false;
}

class Header extends StatelessWidget {
  final double height;
  final Widget child;
  const Header({super.key, required this.height, required this.child});
  @override
  Widget build(BuildContext context) => ClipPath(
        clipper: _Wave(),
        child: Container(
          height: height + MediaQuery.of(context).padding.top,
          decoration: const BoxDecoration(gradient: kGrad),
          child: Stack(children: [
            Positioned.fill(child: CustomPaint(painter: _Deco())),
            SafeArea(
                bottom: false,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    child: child)),
          ]),
        ),
      );
}

Widget logoBadge(double size) => Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .14),
      decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black26, blurRadius: 12, offset: Offset(0, 4))
          ]),
      child: Image.asset('assets/logo.png',
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.auto_stories, color: kBlue)),
    );

Widget avatar(String? photo, String name, double r, {String? asset}) {
  ImageProvider? img;
  if (photo != null) {
    try {
      img = MemoryImage(base64Decode(photo));
    } catch (_) {}
  } else if (asset != null) {
    img = AssetImage(asset);
  }
  return Container(
    padding: const EdgeInsets.all(3),
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: kGrad),
    child: CircleAvatar(
      radius: r,
      backgroundColor: kLight,
      backgroundImage: img,
      child: img == null
          ? Text(name.isEmpty ? '?' : name[0].toUpperCase(),
              style: serif(r * .9, c: kBlue))
          : null,
    ),
  );
}

Color roleColor(String role) {
  const p = [kBlue, Color(0xFF0288D1), Color(0xFF3949AB), Color(0xFF00838F)];
  return p[role.codeUnits.fold(0, (a, b) => a + b) % p.length];
}

Widget chip(String t, Color c, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4)
        ],
        Flexible(
            child: Text(t,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                    fontSize: 12, color: c, fontWeight: FontWeight.w600))),
      ]),
    );

void _showEditorialMemberDetails(
    BuildContext context, EditorialBoardMember boardMember) {
  final member = store.members
      .firstWhere((candidate) => candidate.name == boardMember.name);
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(member.name, style: serif(20, c: kBlue)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(member.photoAsset ?? boardMember.asset,
                height: 145,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 72, color: kMid)),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(member.role,
                  style: const TextStyle(
                      color: kMid, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'Birthday: ${member.birthday == null ? 'Not provided' : fmtFull(member.birthday!)}'),
              const SizedBox(height: 8),
              Text('Description: ${member.description}'),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('CLOSE'))
      ],
    ),
  );
}

void _showEditorialMemberPhoto(
    BuildContext context, EditorialBoardMember boardMember) {
  final member = store.members
      .firstWhere((candidate) => candidate.name == boardMember.name);
  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 600),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(member.name, style: serif(20, c: kBlue)),
                  ),
                  IconButton(
                    tooltip: 'Close photo',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ]),
                Text(member.role,
                    style: const TextStyle(
                        color: kMid, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 2.2,
                    child: Image.asset(
                      member.photoAsset ?? boardMember.asset,
                      key: Key('editorial-photo-preview-${boardMember.name}'),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 96, color: kMid),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Birthday: ${member.birthday == null ? 'Not provided' : fmtFull(member.birthday!)}'),
                      const SizedBox(height: 8),
                      Text('Description: ${member.description}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showAdviserPhoto(BuildContext context, Adviser adviser) {
  var birthday = store.adviserBirthday(adviser.name);
  showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
              insetPadding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 600),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(adviser.name,
                                  style: serif(20, c: kBlue))),
                          IconButton(
                            tooltip: 'Close photo',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close),
                          ),
                        ]),
                        Text(adviser.title,
                            style: const TextStyle(
                                color: kMid, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 2.2,
                            child: Image.asset(
                              adviser.asset,
                              key: Key('adviser-photo-preview-${adviser.name}'),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.person,
                                  size: 96,
                                  color: kMid),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Birthday: ${birthday == null ? 'Not provided' : fmtFull(birthday!)}'),
                              if (store.isAdmin) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  key: const Key('edit-adviser-birthday'),
                                  onPressed: () async {
                                    final selected = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          birthday ?? DateTime(1980, 1, 1),
                                      firstDate: DateTime(1900),
                                      lastDate: today(),
                                    );
                                    if (selected == null) return;
                                    store.saveAdviserBirthday(
                                        adviser.name, selected);
                                    setDialogState(() => birthday = selected);
                                  },
                                  icon: const Icon(Icons.cake),
                                  label: Text(birthday == null
                                      ? 'ADD BIRTHDAY'
                                      : 'EDIT BIRTHDAY'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )),
  );
}

class FancyCard extends StatelessWidget {
  final Widget child;
  final Color accent;
  final VoidCallback? onTap;
  const FancyCard(
      {super.key, required this.child, this.accent = kMid, this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: kBlue.withOpacity(.12),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(width: 7, color: accent),
                      Expanded(
                          child: Padding(
                              padding: const EdgeInsets.all(12), child: child)),
                    ]),
              ),
            ),
          ),
        ),
      );
}

Widget sectionTitle(String t) => Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Row(children: [
        Container(
            width: 5,
            height: 22,
            decoration: BoxDecoration(
                gradient: kGrad, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 8),
        Expanded(
            child: Text(t,
                overflow: TextOverflow.ellipsis, style: serif(19, c: kBlue))),
        const SizedBox(width: 6),
        const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFFFB300)),
      ]),
    );

Widget emptyState(IconData i, String t) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 64, color: kSky.withOpacity(.6)),
        const SizedBox(height: 8),
        Text(t, style: GoogleFonts.poppins(color: Colors.black54)),
      ]),
    );

Widget dateBadge(DateTime d, {double size = 54}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: d.isBefore(today())
            ? const LinearGradient(colors: [Colors.grey, Colors.blueGrey])
            : kGrad,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_months[d.month - 1].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white70, fontSize: 11, height: 1.1)),
            Text('${d.day}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    height: 1.1)),
          ]),
    );

Future<bool> confirmDelete(BuildContext c, String what) async =>
    await showDialog<bool>(
      context: c,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete $what?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ??
    false;

Future<DateTime?> pickDate(BuildContext c, DateTime init,
        {bool birthday = false}) =>
    showDatePicker(
      context: c,
      initialDate: init,
      firstDate: DateTime(birthday ? 1990 : 2020),
      lastDate: DateTime(birthday ? 2015 : 2100),
    );

// ======================= LOGIN =======================
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController u, p;
  bool hide = true, remember = true;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    final draft = store.readDraft('login');
    u = TextEditingController(text: draft['username'] as String? ?? '');
    p = TextEditingController(text: draft['password'] as String? ?? '');
    remember = draft['remember'] as bool? ?? true;
  }

  void _msg(String s) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));

  void _signUp() {
    final draft = store.readDraft('signup');
    final nu = TextEditingController(text: draft['username'] as String? ?? ''),
        np = TextEditingController(text: draft['password'] as String? ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sign Up', style: serif(22, c: kBlue)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: nu,
              onChanged: (value) =>
                  store.saveDraftField('signup', 'username', value),
              decoration:
                  const InputDecoration(hintText: 'Username or School ID')),
          const SizedBox(height: 8),
          TextField(
              controller: np,
              onChanged: (value) =>
                  store.saveDraftField('signup', 'password', value),
              obscureText: true,
              decoration:
                  const InputDecoration(hintText: 'Password (4+ chars)')),
          const SizedBox(height: 8),
          const Text('New accounts are members with read-only access.',
              style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final ok = store.signUp(nu.text.trim(), np.text);
              if (ok) store.clearDraft('signup');
              Navigator.pop(context);
              _msg(ok
                  ? 'Account created! You can log in now.'
                  : 'Invalid or already-used username.');
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Header(
            height: 270,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                logoBadge(110),
                const SizedBox(height: 10),
                Text('THE EXEMPLAR', style: serif(30)),
                Text('SCHOOL PUBLICATION',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 12, letterSpacing: 3)),
              ]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(children: [
                Text('Welcome back!', style: serif(22, c: kBlue)),
                const Text('Please log in to continue'),
                const SizedBox(height: 18),
                TextField(
                    controller: u,
                    onChanged: (value) {
                      store.saveDraftField('login', 'username', value);
                      if (_loginError != null) {
                        setState(() => _loginError = null);
                      }
                    },
                    decoration: const InputDecoration(
                        hintText: 'Username or School ID',
                        prefixIcon: Icon(Icons.person, color: kMid))),
                const SizedBox(height: 12),
                TextField(
                  controller: p,
                  onChanged: (value) {
                    store.saveDraftField('login', 'password', value);
                    if (_loginError != null) {
                      setState(() => _loginError = null);
                    }
                  },
                  obscureText: hide,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: kMid),
                    suffixIcon: IconButton(
                        icon: Icon(
                            hide ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => hide = !hide)),
                  ),
                ),
                if (_loginError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _loginError!,
                        key: const Key('login-validation-message'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Checkbox(
                            value: remember,
                            onChanged: (v) {
                              setState(() => remember = v!);
                              store.saveDraftField(
                                  'login', 'remember', remember);
                            }),
                        const Text('Remember me'),
                      ]),
                      TextButton(
                          onPressed: () =>
                              _msg('Ask your adviser to reset your password.'),
                          child: const Text('Forgot Password?')),
                    ]),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      gradient: kGrad,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: kBlue.withOpacity(.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6))
                      ]),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent),
                    onPressed: () {
                      final username = u.text.trim();
                      if (username.isEmpty && p.text.isEmpty) {
                        setState(() => _loginError =
                            'Please enter a username and password.');
                      } else if (username.isEmpty) {
                        setState(
                            () => _loginError = 'Please enter a username.');
                      } else if (p.text.isEmpty) {
                        setState(
                            () => _loginError = 'Please enter a password.');
                      } else if (!store.login(username, p.text, remember)) {
                        setState(() => _loginError = null);
                        _msg('Wrong ID or password.');
                      } else {
                        setState(() => _loginError = null);
                        store.clearDraft('login');
                      }
                    },
                    child: const Text('LOG IN',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  ),
                ),
                Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                          onPressed: _signUp, child: const Text('Sign Up')),
                    ]),
              ]),
            ),
          ),
        ]),
      );
}

// ======================= SHELL =======================
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late int i;
  static const titles = [
    'Welcome back!',
    'Our Members',
    'Events & Schedule',
    'Birthday Calendar',
    'Manage'
  ];

  @override
  void initState() {
    super.initState();
    i = store.selectedPage;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, kLight])),
          child: Column(children: [
            Header(
              height: 130,
              child: Row(children: [
                logoBadge(54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('THE EXEMPLAR', style: serif(24)),
                        Text(titles[i],
                            style: GoogleFonts.poppins(
                                color: Colors.white70, fontSize: 13)),
                      ]),
                ),
              ]),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: store,
                builder: (_, __) => switch (i) {
                  0 => HomePage(),
                  1 => MembersPage(),
                  2 => EventsPage(),
                  3 => BirthdaysPage(),
                  _ => ManagePage(),
                },
              ),
            ),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                    color: kBlue.withOpacity(.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: NavigationBar(
                height: 66,
                elevation: 0,
                backgroundColor: Colors.transparent,
                indicatorColor: kLight,
                selectedIndex: i,
                onDestinationSelected: (v) => setState(() {
                  i = v;
                  store.selectPage(v);
                }),
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home, color: kBlue),
                      label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.groups_outlined),
                      selectedIcon: Icon(Icons.groups, color: kBlue),
                      label: 'Members'),
                  NavigationDestination(
                      icon: Icon(Icons.event_outlined),
                      selectedIcon: Icon(Icons.event, color: kBlue),
                      label: 'Events'),
                  NavigationDestination(
                      icon: Icon(Icons.cake_outlined),
                      selectedIcon: Icon(Icons.cake, color: kBlue),
                      label: 'Birthdays'),
                  NavigationDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings, color: kBlue),
                      label: 'Manage'),
                ],
              ),
            ),
          ),
        ),
      );
}

// ======================= HOME =======================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget stat(IconData ic, String n, String l) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                  color: kBlue.withOpacity(.12),
                  blurRadius: 14,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(children: [
            CircleAvatar(
                radius: 20,
                backgroundColor: kLight,
                child: Icon(ic, color: kBlue)),
            const SizedBox(height: 6),
            Text(n, style: serif(26, c: kBlue)),
            Text(l,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final upcoming =
        store.events.where((e) => !e.date.isBefore(today())).take(3).toList();
    final bdays = store.members
        .where((member) => member.birthday != null)
        .toList()
      ..sort(
          (a, b) => daysUntil(a.birthday!).compareTo(daysUntil(b.birthday!)));
    return ListView(padding: const EdgeInsets.only(bottom: 16), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(children: [
          stat(Icons.groups, '${store.members.length}', 'Members'),
          stat(Icons.event, '${store.events.length}', 'Events')
        ]),
      ),
      sectionTitle('Editorial Board 2026–2027'),
      _featuredEditorInChief(context, editorialBoard.first),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: editorialBoard.length - 1,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, index) =>
              _boardMemberCard(context, editorialBoard[index + 1]),
        ),
      ),
      sectionTitle('Meet Our Advisers'),
      SizedBox(
        height: 212,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          itemCount: advisers.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final a = advisers[i];
            return Container(
              width: 190,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: kBlue.withOpacity(.14),
                      blurRadius: 14,
                      offset: const Offset(0, 5))
                ],
              ),
              child: Column(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(22)),
                    child: _AdviserPortrait(adviser: a),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(children: [
                    Text(a.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kMid)),
                  ]),
                ),
              ]),
            );
          },
        ),
      ),
      sectionTitle('Upcoming Events'),
      if (upcoming.isEmpty)
        Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Text('No upcoming events.',
                    style: GoogleFonts.poppins(color: Colors.black54)))),
      for (final e in upcoming)
        FancyCard(
          child: Row(children: [
            dateBadge(e.date, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (e.location.isNotEmpty)
                      Text(e.location,
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 12)),
                  ]),
            ),
          ]),
        ),
      sectionTitle('Next Birthdays'),
      if (bdays.isEmpty)
        Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
                child: Text(
                    store.members.isEmpty
                        ? 'No members yet.'
                        : 'No birthdays provided yet.',
                    style: GoogleFonts.poppins(color: Colors.black54)))),
      for (final m in bdays.take(3))
        FancyCard(
          accent: kGold,
          child: Row(children: [
            avatar(m.photo, m.name, 22, asset: m.photoAsset),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${m.role} • ${fmt(m.birthday!)}',
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 12)),
                  ]),
            ),
            chip(
                daysUntil(m.birthday!) == 0
                    ? 'Today!'
                    : '${daysUntil(m.birthday!)}d',
                kBlue,
                icon: Icons.cake),
          ]),
        ),
    ]);
  }
}

class _EditorialBoardPortrait extends StatefulWidget {
  final EditorialBoardMember member;
  final double size;
  final double borderRadius;

  const _EditorialBoardPortrait({
    required this.member,
    required this.size,
    this.borderRadius = 10,
  });

  @override
  State<_EditorialBoardPortrait> createState() =>
      _EditorialBoardPortraitState();
}

class _EditorialBoardPortraitState extends State<_EditorialBoardPortrait> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Material(
              color: kLight,
              child: InkWell(
                key: Key('editorial-photo-${widget.member.name}'),
                onTap: () => _showEditorialMemberPhoto(context, widget.member),
                child: AnimatedScale(
                  scale: _hovering ? 1.07 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Image.asset(
                    widget.member.asset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 54, color: kMid),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AdviserPortrait extends StatefulWidget {
  final Adviser adviser;

  const _AdviserPortrait({required this.adviser});

  @override
  State<_AdviserPortrait> createState() => _AdviserPortraitState();
}

class _AdviserPortraitState extends State<_AdviserPortrait> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: Material(
          color: kLight,
          child: InkWell(
            key: Key('adviser-photo-${widget.adviser.name}'),
            onTap: () => _showAdviserPhoto(context, widget.adviser),
            child: AnimatedScale(
              scale: _hovering ? 1.07 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: Image.asset(
                widget.adviser.asset,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.person, size: 54, color: kMid),
                ),
              ),
            ),
          ),
        ),
      );
}

Widget _featuredEditorInChief(
        BuildContext context, EditorialBoardMember member) =>
    Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          hoverColor: Colors.white.withOpacity(.10),
          hoverDuration: const Duration(milliseconds: 160),
          mouseCursor: SystemMouseCursors.click,
          onTap: () => _showEditorialMemberDetails(context, member),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: kGrad,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: kBlue.withOpacity(.22),
                    blurRadius: 16,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.star, color: kGold, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('EDITOR-IN-CHIEF',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: .5)),
                ),
                const SizedBox(width: 24),
              ]),
              const SizedBox(height: 6),
              _EditorialBoardPortrait(
                  member: member, size: 120, borderRadius: 18),
              const SizedBox(height: 6),
              Text(member.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text(member.role,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );

Widget _boardMemberCard(BuildContext context, EditorialBoardMember member) =>
    Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        hoverColor: kBlue.withOpacity(.08),
        hoverDuration: const Duration(milliseconds: 160),
        mouseCursor: SystemMouseCursors.click,
        onTap: () => _showEditorialMemberDetails(context, member),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: kBlue.withOpacity(.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imageSize = constraints.maxWidth.clamp(0.0, 128.0);
                  return Container(
                    width: imageSize,
                    height: imageSize,
                    decoration: BoxDecoration(
                      color: kLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: _EditorialBoardPortrait(
                        member: member,
                        size: imageSize,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Column(children: [
                Text(member.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
                Text(member.role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: kMid)),
              ]),
            ),
          ]),
        ),
      ),
    );

// ======================= MEMBERS (CRUD) =======================
class MembersPage extends StatefulWidget {
  const MembersPage({super.key});
  @override
  State<MembersPage> createState() => _MembersPageState();
}

class _MembersPageState extends State<MembersPage> {
  String q = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    q = store.readDraft('members-search')['query'] as String? ?? '';
    _searchController = TextEditingController(text: q);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void form([Member? m]) {
    if (!store.isAdmin) return;
    final draftKey = 'member-${m?.id ?? 'new'}';
    final draft = store.readDraft(draftKey);
    final name = TextEditingController(
            text: draft['name'] as String? ?? m?.name ?? ''),
        role = TextEditingController(
            text: draft['role'] as String? ?? m?.role ?? '');
    final birthdayDraft = draft['birthday'] as String?;
    DateTime? bd = birthdayDraft == null
        ? m?.birthday ?? (m == null ? DateTime(2008, 1, 1) : null)
        : DateTime.tryParse(birthdayDraft);
    String? photo = m?.photo;
    String? photoAsset = m?.photoAsset;
    final description = TextEditingController(
        text: draft['description'] as String? ??
            (m?.description == 'Not provided.' ? '' : m?.description ?? ''));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(m == null ? 'Add New Member' : 'Edit Member',
                style: serif(22, c: kBlue)),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () async {
                final x = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 400,
                    imageQuality: 75);
                if (x == null) return;
                final b = await x.readAsBytes();
                set(() {
                  photo = base64Encode(b);
                  photoAsset = null;
                });
              },
              child: Stack(alignment: Alignment.bottomRight, children: [
                avatar(photo, name.text.isEmpty ? '+' : name.text, 46,
                    asset: photoAsset),
                const CircleAvatar(
                    radius: 15,
                    backgroundColor: kBlue,
                    child:
                        Icon(Icons.camera_alt, size: 15, color: Colors.white)),
              ]),
            ),
            if (photo != null || photoAsset != null)
              TextButton(
                  onPressed: () => set(() {
                        photo = null;
                        photoAsset = null;
                      }),
                  child: const Text('Remove photo')),
            const SizedBox(height: 10),
            TextField(
                controller: name,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'name', value),
                decoration: const InputDecoration(
                    hintText: 'Full name',
                    prefixIcon: Icon(Icons.person, color: kMid))),
            const SizedBox(height: 10),
            TextField(
                controller: role,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'role', value),
                decoration: const InputDecoration(
                    hintText: 'Role (e.g. Staff Writer)',
                    prefixIcon: Icon(Icons.badge, color: kMid))),
            const SizedBox(height: 10),
            TextField(
                controller: description,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'description', value),
                maxLines: 3,
                decoration: const InputDecoration(
                    hintText: 'Description',
                    prefixIcon: Icon(Icons.notes, color: kMid))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.cake),
              label: Text(
                  'Birthday: ${bd == null ? 'Not provided' : fmtFull(bd!)}'),
              style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 48)),
              onPressed: () async {
                final d = await pickDate(ctx, bd ?? DateTime(2008, 1, 1),
                    birthday: true);
                if (d != null) {
                  set(() => bd = d);
                  store.saveDraftField(
                      draftKey, 'birthday', d.toIso8601String());
                }
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  if (name.text.trim().isEmpty || role.text.trim().isEmpty)
                    return;
                  store.saveMember(Member(
                      m?.id ?? store.newId(),
                      name.text.trim(),
                      role.text.trim(),
                      bd,
                      photo,
                      photoAsset,
                      description.text.trim().isEmpty
                          ? 'Not provided.'
                          : description.text.trim()));
                  store.clearDraft(draftKey);
                  Navigator.pop(ctx);
                },
                child: const Text('SAVE'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = store.members
        .where((m) =>
            '${m.name} ${m.role}'.toLowerCase().contains(q.toLowerCase()))
        .toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: store.isAdmin
          ? FloatingActionButton(
              backgroundColor: kBlue,
              foregroundColor: Colors.white,
              onPressed: () => form(),
              child: const Icon(Icons.person_add))
          : null,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
          child: TextField(
              controller: _searchController,
              onChanged: (v) {
                setState(() => q = v);
                store.saveDraftField('members-search', 'query', v);
              },
              decoration: const InputDecoration(
                  hintText: 'Search name or role...',
                  prefixIcon: Icon(Icons.search, color: kMid))),
        ),
        Expanded(
          child: list.isEmpty
              ? emptyState(Icons.groups_outlined, 'No members found.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return FancyCard(
                      accent: roleColor(m.role),
                      child: Row(children: [
                        avatar(m.photo, m.name, 30, asset: m.photoAsset),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(m.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  chip(m.role, roleColor(m.role),
                                      icon: Icons.workspace_premium),
                                  chip(
                                      m.birthday == null
                                          ? 'Birthday not provided'
                                          : fmt(m.birthday!),
                                      kMid,
                                      icon: Icons.cake),
                                ]),
                              ]),
                        ),
                        if (store.isAdmin)
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.edit, color: kMid),
                                onPressed: () => form(m)),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                if (await confirmDelete(context, m.name))
                                  store.deleteMember(m.id);
                              },
                            ),
                          ]),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ======================= EVENTS (CRUD) =======================
class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !store.isAdmin || store.selectedPage != 2) return;
      final pendingId = store.pendingEventFormId;
      if (pendingId == null) return;
      final matches =
          store.events.where((item) => item.id == pendingId).toList();
      final event =
          pendingId == 'new' || matches.isEmpty ? null : matches.first;
      if (pendingId != 'new' && event == null) {
        store.setPendingEventForm(null);
        return;
      }
      form(context, event);
    });
  }

  void showDetails(BuildContext context, Event event) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(event.title, style: serif(22, c: kBlue)),
        content: SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                chip(fmtFull(event.date), kMid, icon: Icons.event),
                if (event.location.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.place, size: 18, color: kMid),
                    const SizedBox(width: 6),
                    Expanded(child: Text(event.location))
                  ])
                ],
                if (event.notes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(event.notes)
                ],
              ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'))
        ],
      ),
    );
  }

  void form(BuildContext context, [Event? e]) {
    if (!store.isAdmin) return;
    final pendingId = e?.id ?? 'new';
    store.setPendingEventForm(pendingId);
    final draftKey = 'event-${e?.id ?? 'new'}';
    final draft = store.readDraft(draftKey);
    final title = TextEditingController(
            text: draft['title'] as String? ?? e?.title ?? ''),
        loc = TextEditingController(
            text: draft['location'] as String? ?? e?.location ?? ''),
        notes = TextEditingController(
            text: draft['notes'] as String? ?? e?.notes ?? '');
    DateTime d =
        DateTime.tryParse(draft['date'] as String? ?? '') ?? e?.date ?? today();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e == null ? 'Add Event' : 'Edit Event',
                style: serif(22, c: kBlue)),
            const SizedBox(height: 14),
            TextField(
                controller: title,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'title', value),
                decoration: const InputDecoration(
                    hintText: 'Event title',
                    prefixIcon: Icon(Icons.title, color: kMid))),
            const SizedBox(height: 10),
            TextField(
                controller: loc,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'location', value),
                decoration: const InputDecoration(
                    hintText: 'Location',
                    prefixIcon: Icon(Icons.place, color: kMid))),
            const SizedBox(height: 10),
            TextField(
                controller: notes,
                onChanged: (value) =>
                    store.saveDraftField(draftKey, 'notes', value),
                decoration: const InputDecoration(
                    hintText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes, color: kMid))),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Date: ${fmtFull(d)}'),
              style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  minimumSize: const Size(double.infinity, 48)),
              onPressed: () async {
                final x = await pickDate(ctx, d);
                if (x != null) {
                  set(() => d = x);
                  store.saveDraftField(draftKey, 'date', x.toIso8601String());
                }
              },
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    store.setPendingEventForm(null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('CANCEL'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (title.text.trim().isEmpty) return;
                    store.saveEvent(Event(
                        e?.id ?? store.newId(),
                        title.text.trim(),
                        loc.text.trim(),
                        notes.text.trim(),
                        d));
                    store.clearDraft(draftKey);
                    store.setPendingEventForm(null);
                    Navigator.pop(ctx);
                  },
                  child: const Text('SAVE'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: store.isAdmin
            ? FloatingActionButton.extended(
                backgroundColor: kBlue,
                foregroundColor: Colors.white,
                onPressed: () => form(context),
                icon: const Icon(Icons.add),
                label: const Text('ADD EVENT'))
            : null,
        body: store.events.isEmpty
            ? emptyState(Icons.event_busy, 'No events yet.')
            : ListView(
                padding: const EdgeInsets.only(top: 4, bottom: 90),
                children: [
                    for (final e in store.events)
                      FancyCard(
                        accent:
                            e.date.isBefore(today()) ? Colors.blueGrey : kMid,
                        onTap: () => showDetails(context, e),
                        child: Row(children: [
                          dateBadge(e.date),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Wrap(spacing: 6, runSpacing: 4, children: [
                                    chip(
                                        e.date == today()
                                            ? 'Today'
                                            : (e.date.isBefore(today())
                                                ? 'Past'
                                                : 'Upcoming'),
                                        e.date.isBefore(today())
                                            ? Colors.blueGrey
                                            : kBlue),
                                    if (e.location.isNotEmpty)
                                      chip(e.location, kMid, icon: Icons.place),
                                  ]),
                                ]),
                          ),
                          if (store.isAdmin)
                            Column(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit, color: kMid),
                                  onPressed: () => form(context, e)),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon:
                                    const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  if (await confirmDelete(context, e.title))
                                    store.deleteEvent(e.id);
                                },
                              ),
                            ]),
                        ]),
                      ),
                  ]),
      );
}

// ======================= BIRTHDAYS =======================
class BirthdaysPage extends StatelessWidget {
  const BirthdaysPage({super.key});
  @override
  Widget build(BuildContext context) {
    final list = store.members
        .where((member) => member.birthday != null)
        .toList()
      ..sort(
          (a, b) => daysUntil(a.birthday!).compareTo(daysUntil(b.birthday!)));
    if (list.isEmpty) {
      return emptyState(
          Icons.cake_outlined,
          store.members.isEmpty
              ? 'Add members to see birthdays.'
              : 'No birthdays provided yet.');
    }
    final first = list.first;
    final d = daysUntil(first.birthday!);
    return ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 16),
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: kGrad,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                    color: kBlue.withOpacity(.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Row(children: [
              avatar(first.photo, first.name, 34, asset: first.photoAsset),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NEXT BIRTHDAY',
                          style: GoogleFonts.poppins(
                              color: kGold,
                              fontSize: 11,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w600)),
                      Text(first.name, style: serif(21)),
                      Text(
                          d == 0
                              ? 'Today! Happy birthday!'
                              : 'in $d days • ${fmt(first.birthday!)}',
                          style: const TextStyle(color: Colors.white70)),
                    ]),
              ),
              const Icon(Icons.cake, color: kGold, size: 38),
            ]),
          ),
          sectionTitle('Coming Up'),
          for (final m in list.skip(1))
            FancyCard(
              accent: kGold,
              child: Row(children: [
                avatar(m.photo, m.name, 24, asset: m.photoAsset),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${m.role} • ${fmt(m.birthday!)}',
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      ]),
                ),
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      color: kLight, shape: BoxShape.circle),
                  child: daysUntil(m.birthday!) == 0
                      ? const Text('🎉', style: TextStyle(fontSize: 22))
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${daysUntil(m.birthday!)}',
                              style: serif(18, c: kBlue)),
                          const Text('days',
                              style: TextStyle(fontSize: 10, color: kMid)),
                        ]),
                ),
              ]),
            ),
        ]);
  }
}

// ======================= MANAGE =======================
class ManagePage extends StatelessWidget {
  const ManagePage({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.only(top: 4, bottom: 16), children: [
        if (!store.isAdmin)
          FancyCard(
            child: Row(children: [
              avatar(null, store.currentUsername ?? '?', 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.currentUsername ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      chip('Member • Read-only', kBlue, icon: Icons.visibility),
                    ]),
              ),
            ]),
          ),
        FancyCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.groups, color: kBlue),
                title: const Text('Total members'),
                trailing: Text('${store.members.length}',
                    style: serif(20, c: kBlue)))),
        FancyCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event, color: kBlue),
                title: const Text('Total events'),
                trailing: Text('${store.events.length}',
                    style: serif(20, c: kBlue)))),
        if (store.isAdmin)
          FancyCard(
            accent: Colors.red,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Clear all members & events'),
              onTap: () async {
                if (await confirmDelete(context, 'ALL data')) store.resetAll();
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
              onPressed: store.logout,
              icon: const Icon(Icons.logout),
              label: const Text('LOG OUT')),
        ),
      ]);
}
