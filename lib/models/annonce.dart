enum StatutAnnonce { enAttente, publiee, archivee }

class Annonce {
  const Annonce({
    required this.id,
    required this.titre,
    required this.description,
    required this.typeLocation,
    required this.loyer,
    required this.surface,
    required this.chambres,
    this.etage,
    required this.ville,
    required this.quartier,
    required this.adresse,
    required this.photos,
    this.statut = StatutAnnonce.enAttente,
    required this.proprietaireId,
  });

  final String id;
  final String titre;
  final String description;
  final String typeLocation;
  final double loyer;
  final double surface;
  final int chambres;
  final int? etage;
  final String ville;
  final String quartier;
  final String adresse;
  final List<String> photos;
  final StatutAnnonce statut;
  final String proprietaireId;

  Annonce copyWith({
    String? id,
    String? titre,
    String? description,
    String? typeLocation,
    double? loyer,
    double? surface,
    int? chambres,
    Object? etage = _unchanged,
    String? ville,
    String? quartier,
    String? adresse,
    List<String>? photos,
    StatutAnnonce? statut,
    String? proprietaireId,
  }) => Annonce(
    id: id ?? this.id,
    titre: titre ?? this.titre,
    description: description ?? this.description,
    typeLocation: typeLocation ?? this.typeLocation,
    loyer: loyer ?? this.loyer,
    surface: surface ?? this.surface,
    chambres: chambres ?? this.chambres,
    etage: identical(etage, _unchanged) ? this.etage : etage as int?,
    ville: ville ?? this.ville,
    quartier: quartier ?? this.quartier,
    adresse: adresse ?? this.adresse,
    photos: photos ?? this.photos,
    statut: statut ?? this.statut,
    proprietaireId: proprietaireId ?? this.proprietaireId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'titre': titre,
    'description': description,
    'typeLocation': typeLocation,
    'loyer': loyer,
    'surface': surface,
    'chambres': chambres,
    'etage': etage,
    'ville': ville,
    'quartier': quartier,
    'adresse': adresse,
    'photos': photos,
    'statut': statut.name,
    'proprietaireId': proprietaireId,
  };

  factory Annonce.fromJson(Map<String, dynamic> json) => Annonce(
    id: json['id'] as String,
    titre: json['titre'] as String,
    description: json['description'] as String,
    typeLocation: json['typeLocation'] as String,
    loyer: (json['loyer'] as num).toDouble(),
    surface: (json['surface'] as num).toDouble(),
    chambres: (json['chambres'] as num).toInt(),
    etage: json['etage'] == null ? null : (json['etage'] as num).toInt(),
    ville: json['ville'] as String,
    quartier: json['quartier'] as String,
    adresse: json['adresse'] as String,
    photos: (json['photos'] as List? ?? const []).map((photo) => photo as String).toList(),
    statut: StatutAnnonce.values.firstWhere(
      (value) => value.name == json['statut'],
      orElse: () => StatutAnnonce.enAttente,
    ),
    proprietaireId: json['proprietaireId'] as String,
  );
}

const Object _unchanged = Object();
