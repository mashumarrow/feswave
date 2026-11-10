import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/models.dart';

const ink = Color(0xff090911),
    panel = Color(0xff14111e),
    cyan = Color(0xff37d5f7),
    pink = Color(0xfff14be5),
    lilac = Color(0xffaa75ff);
Color tint(String color) => switch (color) {
  'blue' => cyan,
  'orange' => const Color(0xffffba76),
  'purple' => lilac,
  _ => pink,
};

class Avatar extends StatelessWidget {
  const Avatar(this.p, {super.key, this.size = 48});
  final Profile p;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = tint(p.color);
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-.48, -.63),
          radius: 1.25,
          colors: [
            Color.lerp(color, Colors.white, .65)!,
            color,
            Color.lerp(color, const Color(0xff180f42), .74)!,
          ],
          stops: const [0, .34, 1],
        ),
      ),
      child: Center(
        child: Text(
          p.name.isEmpty ? '♪' : p.name.characters.first,
          style: TextStyle(
            color: Colors.white,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black87)],
            fontSize: size * .41,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
    final artwork = Uri.tryParse(p.favorite?.artworkUrl ?? '');
    final url =
        artwork != null &&
            artwork.scheme == 'https' &&
            artwork.host.endsWith('.mzstatic.com')
        ? artwork.toString()
        : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: .75), width: 1.5),
      ),
      padding: const EdgeInsets.all(2),
      child: ClipOval(
        child: url == null
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

Future<void> showPerson(
  BuildContext context,
  Profile person, {
  bool demo = false,
}) => showDialog<void>(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: panel,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xff60406c)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  demo ? 'DEMO PARTICIPANT' : 'ON THE SAME WAVE',
                  style: captionStyle,
                ),
              ),
              IconButton(
                tooltip: '閉じる',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
        Flexible(child: ProfileCard(person)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    ),
  ),
);

class ProfileCard extends StatelessWidget {
  const ProfileCard(this.p, {super.key});
  final Profile p;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    padding: const EdgeInsets.all(20),
    children: [
      Center(child: Avatar(p, size: 76)),
      const SizedBox(height: 10),
      Center(
        child: Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
      ),
      if (p.artist.isNotEmpty || p.song.isNotEmpty)
        Center(
          child: Text(
            [p.artist, p.song].where((v) => v.isNotEmpty).join(' / '),
          ),
        ),
      for (final t in p.tracks)
        ListTile(
          title: Text(t.trackName),
          subtitle: Text(t.artistName),
          leading: Icon(
            t.trackId == p.favoriteTrackId
                ? Icons.stars_rounded
                : Icons.music_note,
          ),
          trailing: t.trackUrl == null
              ? null
              : const Icon(Icons.open_in_new, size: 18),
          onTap: () async {
            final uri = Uri.tryParse(t.trackUrl ?? '');
            if (uri != null &&
                uri.scheme == 'https' &&
                (uri.host == 'music.apple.com' ||
                    uri.host == 'itunes.apple.com')) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
    ],
  );
}

void notice(BuildContext c, Object message) {
  if (c.mounted) {
    ScaffoldMessenger.of(c)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message.toString())));
  }
}

const captionStyle = TextStyle(
  fontSize: 10,
  letterSpacing: 1.4,
  color: Color(0xffc3a4d4),
);
const noteStyle = TextStyle(
  fontSize: 12,
  height: 1.6,
  color: Color(0xffb6a9c2),
);

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.kicker,
    this.title,
    this.icon,
    this.description, {
    super.key,
  });
  final String kicker, title, description;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kicker, style: captionStyle),
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 9),
            Icon(icon, color: title == 'Live' ? cyan : pink, size: 26),
          ],
        ),
        if (description.isNotEmpty) Text(description, style: noteStyle),
      ],
    ),
  );
}

class WavePanel extends StatelessWidget {
  const WavePanel({super.key, required this.children, this.center = false});
  final List<Widget> children;
  final bool center;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: panel,
      border: Border.all(color: const Color(0xff35283e)),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class WaveFooter extends StatelessWidget {
  const WaveFooter({super.key});
  @override
  Widget build(BuildContext context) =>
      const Text('FESWAVE  © 2026', style: captionStyle);
}
