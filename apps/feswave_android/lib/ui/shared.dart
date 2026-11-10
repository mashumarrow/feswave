import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/models.dart';

const ink = Color(0xff0b0b15),
    panel = Color(0xff171625),
    cyan = Color(0xff52e1eb),
    pink = Color(0xfff485df),
    lilac = Color(0xffbca3ff);
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
    final fallback = ColoredBox(
      color: Color.lerp(panel, color, .18)!,
      child: Center(
        child: Text(
          p.name.isEmpty ? '♪' : p.name.characters.first,
          style: TextStyle(
            color: color,
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
