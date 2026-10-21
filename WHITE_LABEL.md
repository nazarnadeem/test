# White-label app

Each customer app is its own GitHub repo. Clone this project, change `white_label/active.json`, then run one command. Leave this repo as the main GCRM app (`WL_MODE` stays `platform`).

Same Firebase project and same rules. The clone can open only the two gyms named in that file: one test gym and one real gym.

## New customer repo

1. Clone this project. Create an empty GitHub repo for the customer, then point the clone at both remotes before you commit. `upstream` stays the main GCRM repo. `origin` is the customer repo:

```bash
git clone <main-repo-url> ironpulse
cd ironpulse
git remote rename origin upstream
git remote add origin <this-white-label-repo-url>
```

2. In the existing Firebase project, add an Android app and an iOS app. Use the package name and bundle id you will put in the file below. Copy the two Firebase app ids.
3. Edit `white_label/active.json` in the new repo:

| Field | Change it to |
| --- | --- |
| `WL_MODE` | `white_label` |
| `WL_TEST_TENANT_ID` | Firestore `tenants` id of the test gym |
| `WL_LIVE_TENANT_ID` | Firestore `tenants` id of the real gym |
| `WL_APP_NAME` | Name shown inside the app |
| `WL_TAGLINE` | Line under the name |
| `WL_APP_DESCRIPTION` | Short description |
| `WL_DISPLAY_NAME` | Name under the phone icon |
| `WL_BUNDLE_NAME` | Short iOS name, no spaces |
| `WL_ANDROID_APPLICATION_ID` | Android package name, such as `com.ironpulse.gym` |
| `WL_IOS_BUNDLE_ID` | iOS bundle id, same one you added in Firebase |
| `WL_FIREBASE_ANDROID_APP_ID` | Android app id from Firebase |
| `WL_FIREBASE_IOS_APP_ID` | iOS app id from Firebase |
| `WL_SUPPORT_EMAIL` | Support email |
| `WL_ADMIN_EMAIL` | Admin email |
| `WL_SUPPORT_PHONE` | Support phone |

`WL_APP_NAME_PREFIX` and `WL_APP_NAME_SUFFIX` are optional wordmark pieces. Leave them, or set them to match the new name.

4. From the new repo root, run:

```bash
dart run tool/apply_white_label.dart
```

That writes the name and ids into Android, iOS, web, and the Firebase config files. Then replace the logo and icons if this customer has their own:

- `assets/images/logo.png`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `web/favicon.png` and `web/icons/`

5. Commit and push to the customer repo:

```bash
git push -u origin HEAD
```

## When the main app changes

Do not clone again. From the customer repo:

```bash
bash tool/update_from_main.sh
git push
```

That fetches bug fixes and new features from `upstream`. Your gym ids, app name, package name, Firebase app ids, logo, and launcher icons stay. After the pull, the script writes the name and ids back onto the updated Android, iOS, and web files.

If the script stops because a code file conflicts, fix the listed files, then run:

```bash
git add <fixed-files>
git merge --continue
dart run tool/apply_white_label.dart
git push
```

If the script says files still need a commit, those are your app name and ids applied on top of the new code. Commit them and push.

The two gyms must already exist. Create them in the main GCRM app, then paste their document ids here. This clone will not create gyms, will not open any other gym, and will not show the super-admin signup link.

If either gym id is missing, or both ids are the same, the clone stops on launch instead of opening every gym.
