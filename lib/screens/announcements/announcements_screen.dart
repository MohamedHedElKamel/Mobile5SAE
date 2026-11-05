import 'package:flutter/material.dart';

const _ink = Color(0xFF102A43);
const _blue = Color(0xFF326D98);
const _pale = Color(0xFFF3F8FD);

class _Post {
  _Post(
    this.author,
    this.when,
    this.category,
    this.title,
    this.body,
    this.likes,
    this.comments,
  );
  final String author, when, category, title, body;
  int likes;
  final List<String> comments;
  bool liked = false;
}

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _filters = const ['Tout', 'Résidence', 'Événements', 'Avis'];
  String _filter = 'Tout';
  final List<_Post> _posts = [
    _Post(
      'Administration',
      'Il y a 2 h',
      'Résidence',
      'Coupure d’eau programmée',
      'Une coupure d’eau est prévue demain de 9h à 12h dans le bloc B pour des travaux de maintenance.',
      12,
      [
        'Merci pour l’information, c’est très utile.',
        'Est-ce que l’eau chaude sera aussi coupée ?',
        'Oui, les deux seront coupées pendant les travaux.',
      ],
    ),
    _Post(
      'Vie étudiante',
      'Hier',
      'Événement',
      'Soirée d’accueil des nouveaux',
      'Rejoignez-nous vendredi à 18h dans la salle commune pour rencontrer vos voisins.',
      28,
      ['Super idée !'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final shown = _posts.where((p) {
      if (_filter == 'Tout') return true;
      if (_filter == 'Résidence') return p.category == 'Résidence';
      if (_filter == 'Événements') return p.category == 'Événement';
      return p.category == _filter;
    }).toList();
    return Scaffold(
      backgroundColor: _pale,
      appBar: AppBar(
        backgroundColor: _pale,
        titleSpacing: 18,
        title: const Row(
          children: [
            Icon(Icons.home_outlined, color: _blue),
            SizedBox(width: 12),
            Text(
              'StudentHub',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        onPressed: _create,
        child: const Icon(Icons.add, size: 30),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
        children: [
          const Text(
            'Bonjour, BRAHIM !',
            style: TextStyle(fontSize: 23, color: _ink),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Annonces',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _filter = 'Tout'),
                child: const Text('Voir tout'),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _filters
                  .map(
                    (f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          ...shown.map((post) => _postCard(post)),
        ],
      ),
    );
  }

  Widget _postCard(_Post p) => Card(
    color: Colors.white,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xFFD7E3EF)),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _detail(p),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _avatar(p.author),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.author,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        p.when,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                _tag(p.category),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              p.title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 5),
            Text(
              p.body,
              style: const TextStyle(color: Color(0xFF52677B), height: 1.35),
            ),
            const SizedBox(height: 10),
            _photoPlaceholder(height: 96),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() {
                    p.liked = !p.liked;
                    p.likes += p.liked ? 1 : -1;
                  }),
                  icon: Icon(
                    p.liked ? Icons.favorite : Icons.favorite_border,
                    color: p.liked ? Colors.red : const Color(0xFF52677B),
                  ),
                ),
                Text('${p.likes}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 10),
                const Icon(
                  Icons.mode_comment_outlined,
                  size: 18,
                  color: Color(0xFF52677B),
                ),
                const SizedBox(width: 5),
                Text(
                  '${p.comments.length}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  void _detail(_Post p) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          _AnnouncementDetail(post: p, onChanged: () => setState(() {})),
    ),
  );
  Future<void> _create() async {
    final result = await Navigator.of(context).push<_Post>(
      MaterialPageRoute(builder: (_) => const _CreateAnnouncement()),
    );
    if (result != null && mounted) setState(() => _posts.insert(0, result));
  }
}

class _AnnouncementDetail extends StatefulWidget {
  const _AnnouncementDetail({required this.post, required this.onChanged});
  final _Post post;
  final VoidCallback onChanged;
  @override
  State<_AnnouncementDetail> createState() => _AnnouncementDetailState();
}

class _AnnouncementDetailState extends State<_AnnouncementDetail> {
  final _comment = TextEditingController();
  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Scaffold(
      backgroundColor: _pale,
      appBar: AppBar(
        backgroundColor: _pale,
        title: const Text('Annonce'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              children: [
                Row(
                  children: [
                    _avatar(p.author),
                    const SizedBox(width: 9),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.author,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${p.when} · ${p.category}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  p.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                _photoPlaceholder(height: 125),
                const SizedBox(height: 8),
                Text(p.body, style: const TextStyle(height: 1.4)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEBFC),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      const Text('4,2', style: TextStyle(fontSize: 29)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '★★★★☆',
                              style: TextStyle(
                                color: Color(0xFFE5A400),
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Basé sur 18 avis',
                              style: TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: () => _rate(context),
                        child: const Text('Donner un avis'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Commentaires (${p.comments.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ...p.comments.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _avatar(c.trim().split(' ').first),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFD7E3EF),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(c),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _comment,
                      decoration: InputDecoration(
                        hintText: 'Écrire un commentaire…',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFFD7E3EF),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () {
                      final text = _comment.text.trim();
                      if (text.isEmpty) return;
                      setState(() {
                        p.comments.add(text);
                        _comment.clear();
                      });
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _rate(BuildContext context) {
    var rating = 0;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, update) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Donner un avis',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      onPressed: () => update(() => rating = i + 1),
                      icon: Icon(
                        i < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 34,
                      ),
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Envoyer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateAnnouncement extends StatefulWidget {
  const _CreateAnnouncement();
  @override
  State<_CreateAnnouncement> createState() => _CreateAnnouncementState();
}

class _CreateAnnouncementState extends State<_CreateAnnouncement> {
  final _title = TextEditingController(), _body = TextEditingController();
  String _category = 'Résidence';
  bool _comments = true;
  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pale,
    appBar: AppBar(
      backgroundColor: _pale,
      title: const Text('Nouvelle annonce'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      children: [
        const Text('Titre'),
        const SizedBox(height: 6),
        TextField(
          controller: _title,
          decoration: _input('Ex. : Coupure d’eau demain'),
        ),
        const SizedBox(height: 16),
        const Text('Catégorie'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: ['Résidence', 'Événement', 'Avis', 'Autre']
              .map(
                (c) => ChoiceChip(
                  label: Text(c),
                  selected: _category == c,
                  onSelected: (_) => setState(() => _category = c),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        const Text('Description'),
        const SizedBox(height: 6),
        TextField(
          controller: _body,
          maxLines: 5,
          decoration: _input('Écrivez votre annonce…'),
        ),
        const SizedBox(height: 16),
        const Text('Photos'),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
            const SizedBox(width: 8),
            _photoPlaceholder(width: 78, height: 78),
          ],
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          value: _comments,
          onChanged: (v) => setState(() => _comments = v ?? true),
          title: const Text('Autoriser les commentaires et avis'),
          controlAffinity: ListTileControlAffinity.trailing,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          dense: true,
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ajoutez un titre et une description.'),
                ),
              );
              return;
            }
            Navigator.pop(
              context,
              _Post(
                'Vous',
                'À l’instant',
                _category,
                _title.text.trim(),
                _body.text.trim(),
                0,
                [],
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: _blue,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text(
            'Publier l’annonce',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: Color(0xFFD7E3EF)),
    ),
  );
}

Widget _avatar(String name) => CircleAvatar(
  radius: 19,
  backgroundColor: const Color(0xFF3A729B),
  child: Text(
    name.isEmpty ? '?' : name[0].toUpperCase(),
    style: const TextStyle(color: Colors.white),
  ),
);
Widget _tag(String label) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: const Color(0xFFDCEBFC),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Text(label, style: const TextStyle(fontSize: 11, color: _ink)),
);
Widget _photoPlaceholder({
  double width = double.infinity,
  required double height,
}) => Container(
  width: width,
  height: height,
  decoration: BoxDecoration(
    color: const Color(0xFF9DBFE0),
    borderRadius: BorderRadius.circular(12),
  ),
  child: const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.image_outlined, size: 18, color: _blue),
      SizedBox(width: 7),
      Text('Photo de l’annonce', style: TextStyle(fontSize: 12, color: _ink)),
    ],
  ),
);
