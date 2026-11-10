import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/models.dart';

const ink = Color(0xff090911),
    panel = Color(0xff11111c),
    cyan = Color(0xff37d5f7),
    pink = Color(0xfff14be5),
    lilac = Color(0xffaa75ff);
Color tint(String color) => switch (color) {
  'blue' => cyan,
  'orange' => const Color(0xffffba76),
  'purple' => lilac,
  _ => pink,
};

class FeswaveLogo extends StatelessWidget {
  const FeswaveLogo({super.key});
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/feswave.svg',
    width: 116,
    height: 26,
    semanticsLabel: 'FESWAVE',
  );
}

class WaveIcon extends StatelessWidget {
  const WaveIcon(this.name, {super.key, this.size = 21, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/icons/$name.svg',
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(
      color ?? IconTheme.of(context).color ?? Colors.white,
      BlendMode.srcIn,
    ),
    excludeFromSemantics: true,
  );
}

class Avatar extends StatelessWidget {
  const Avatar(this.p, {super.key, this.size = 48, this.glow});
  final Color? glow;
  final Profile p;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = glow ?? tint(p.color);
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
          semanticsLabel: '',
          textScaler: TextScaler.noScaling,
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
      padding: EdgeInsets.zero,
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
                  person.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
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
        if (demo) const Text('デモ参加者', style: noteStyle),
        Flexible(child: ProfileCard(person)),
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

const noteStyle = TextStyle(
  fontSize: 14,
  height: 1.5,
  color: Color(0xffc5b9cc),
);

const captionStyle = TextStyle(
  fontSize: 10,
  letterSpacing: 1.4,
  color: Color(0xffc3a4d4),
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
  final String icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker,
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 1.4,
            color: Color(0xffae91c9),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 30,
                height: 1.2,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 9),
            WaveIcon(
              icon,
              color: title == 'Live' ? cyan : pink,
              size: title == 'Live' ? 33 : 25,
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (description.isNotEmpty)
          Text(
            description,
            style: const TextStyle(
              fontSize: 10,
              height: 1.7,
              color: Color(0xff938c9f),
            ),
          ),
      ],
    ),
  );
}

class WavePanel extends StatelessWidget {
  const WavePanel({
    super.key,
    required this.children,
    this.center = false,
    this.padding = const EdgeInsets.all(16),
  });
  final List<Widget> children;
  final bool center;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: padding,
    decoration: BoxDecoration(
      color: panel,
      border: Border.all(color: const Color(0xff242331)),
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
