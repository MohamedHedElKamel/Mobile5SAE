# Vérification de compte StudentHub

Le serveur Node envoie les courriels par Gmail SMTP. Le mot de passe
d'application est lu uniquement depuis `backend/.env`. Ne le mettez jamais dans
 Flutter, dans Git ou dans un message.

## Configurer Gmail SMTP

1. Sur le compte Google d'envoi, activez la validation en deux étapes puis créez
   un mot de passe d'application. Comme le mot de passe déjà partagé dans le
   chat est exposé, révoquez-le et créez-en un nouveau.
2. Dans `backend/.env`, configurez :

   ```env
   PORT=6500
   GMAIL_SMTP_USER=votre-adresse@gmail.com
   GMAIL_SMTP_APP_PASSWORD=mot_de_passe_application
   GMAIL_SMTP_SENDER_NAME=StudentHub
   ```

   Gmail retire les espaces du mot de passe d'application. Gardez `backend/.env`
   privé : il est ignoré par Git.
3. Installez la dépendance et lancez le serveur depuis `backend` :

   ```powershell
   npm install
   npm start
   ```

4. Vérifiez `http://localhost:6500/health`. Pour l'émulateur Android en
   développement, lancez Flutter depuis la racine du projet :

   ```powershell
   flutter run -d emulator-5554 --dart-define=ACCOUNT_API_URL=http://10.0.2.2:6500 --dart-define=ALLOW_INSECURE_MAIL_API=true
   ```

   Pour un téléphone sur le même Wi-Fi, utilisez l'adresse IP locale du PC.
   Pour une version distribuée, hébergez le serveur derrière HTTPS.
Le parcours utilise `/verification-email` pour envoyer un code à 6 chiffres et
`/verify-email` pour le confirmer. Le code expire après 10 minutes. Il est
gardé en mémoire par le serveur : un redémarrage invalide les codes en cours.
Sans URL ou sans service mail, l'inscription est interrompue et aucun compte
n'est créé. L'émulateur Android ne peut pas joindre le `localhost` de Windows ;
utilisez une URL publique HTTPS pour le serveur.

Le serveur limite les envois a dix par heure et par adresse IP. Pour une mise
en production publique, ajoutez une protection anti-abus adaptée à votre
hébergeur. La base des comptes reste SQLite sur chaque appareil : les actions
administrateur ne sont donc visibles que sur l'appareil qui contient cette base.
Pour un déploiement multi-utilisateur, il faudra transférer comptes et rôles
vers une base serveur partagée et protéger l'administration par une connexion
administrateur côté serveur.

## Activer l'écran d'administration pour une démonstration locale

L'inscription publique ne propose jamais le rôle administrateur. Pour une
démonstration sur émulateur, créez d'abord un compte normal, récupérez
`studenthub.db` depuis Android Studio > Device Explorer >
`data/data/com.example.studenthub/databases/`, puis ouvrez-le avec DB Browser
for SQLite. Dans l'onglet d'exécution SQL, attribuez le rôle au compte choisi :

```sql
UPDATE users SET rolePrincipal = 'administrateur', emailVerified = 1,
  accountStatus = 'approved' WHERE email = 'votre-adresse@example.com';
```

Replacez la base dans l'émulateur et reconnectez ce compte. L'option « Gestion
des comptes » apparaît sur son profil. Ceci convient à une maquette locale,
pas à une application publiée.

## Mode hors ligne et synchronisation des reclamations

L'application lit d'abord les reclamations depuis SQLite. Les brouillons restent locaux et sont visibles seulement par leur auteur sur cet appareil. Les demandes envoyees sont placees dans une file locale lorsqu'aucune connexion n'est disponible; l'application retente la synchronisation au retour au premier plan et toutes les 30 secondes tant que la liste des reclamations est ouverte.

Avec `ACCOUNT_API_URL` configure en HTTPS, `GET /complaints` recupere les demandes partagees et `POST /complaints` synchronise les nouvelles demandes et leurs changements de statut. Les donnees partagees sont conservees dans `backend/data/complaints.json`; configurez un stockage persistant sur l'hebergeur et ne versionnez pas ce fichier. Les photos restent locales et ne sont pas partagees.

Tous les utilisateurs connectes a la meme API voient les reclamations synchronisees. Les comptes et les brouillons restent dans le SQLite local. L'API de partage de demonstration n'est pas authentifiee; elle ne convient pas a un deploiement contenant des renseignements prives sans ajout d'une authentification serveur et de regles d'acces.

## Assistant IA

L'onglet **Assistant IA** est disponible pour tous les comptes connectés. Pour activer
les réponses, créez une clé API sur la plateforme OpenAI puis ajoutez-la au fichier
`backend/.env` (gardez cette clé privée et ne la mettez jamais dans Flutter) :

```env
OPENAI_API_KEY=votre_cle_api
OPENAI_MODEL=gpt-5.4-mini
```

Lancez le serveur depuis le dossier `backend` avec `npm start`, puis relancez Flutter
avec l'URL du serveur déjà utilisée pour l'e-mail :

```powershell
flutter run -d emulator-5554 --dart-define=ACCOUNT_API_URL=http://10.0.2.2:6500 --dart-define=ALLOW_INSECURE_MAIL_API=true
```

L'appel IA passe par l'API Responses et la clé reste côté serveur. L'utilisation de
l'API peut entraîner des frais selon votre compte OpenAI.
