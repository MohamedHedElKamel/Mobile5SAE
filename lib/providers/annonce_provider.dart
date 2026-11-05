import 'package:flutter/foundation.dart';

import '../models/annonce.dart';
import '../services/annonce_service.dart';

class AnnonceProvider extends ChangeNotifier {
  AnnonceProvider({AnnonceService? service}) : _service = service ?? AnnonceService();

  final AnnonceService _service;
  List<Annonce> _annonces = const [];
  bool _chargement = false;
  Object? _erreur;

  List<Annonce> get annonces => List.unmodifiable(_annonces);
  bool get chargement => _chargement;
  bool get isLoading => _chargement;
  Object? get erreur => _erreur;

  Future<void> charger() async {
    _chargement = true;
    _erreur = null;
    notifyListeners();
    try {
      _annonces = await _service.lister();
    } catch (error) {
      _erreur = error;
      rethrow;
    } finally {
      _chargement = false;
      notifyListeners();
    }
  }

  Future<void> ajouter(Annonce annonce) async {
    await _service.ajouter(annonce);
    await charger();
  }

  Future<void> modifier(Annonce annonce) async {
    await _service.modifier(annonce);
    await charger();
  }

  Future<void> supprimer(String id) async {
    await _service.supprimer(id);
    await charger();
  }
}
