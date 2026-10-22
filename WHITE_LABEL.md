# White-label app

This repo is the main GCRM app. Each customer app is a separate folder and a separate GitHub repo, cloned from this one. Product changes are made here and pushed only to this repo. A customer name, package name, and Firebase app ids are edited only in that customer's folder and pushed only to that customer's repo.

`WL_MODE` in this repo stays `platform`. Do not change it.

## Why the parent app was changing

Cloning this repo makes the branch track it. Renaming that remote to `upstream` does not remove the tracking. A plain `git push`, or the IDE Sync button, then sends the customer name and package name to the parent app.

`dart run tool/apply_white_label.dart` now refuses to run in this folder. In the customer folder it removes that tracking before it writes any files. Push from the customer folder only with `git push -u origin HEAD`. Do not run `git push` with no remote.

In this folder:

- Do not edit `white_label/active.json`.
- Do not run `dart run tool/apply_white_label.dart`.
- Do not add the customer repo as a remote.
- Do not push this repo to the customer repo.

`origin` here must stay the main GCRM repo. There is no `upstream`.

## New customer repo

Do this once, in a new folder. Leave this folder alone.

1. Create an empty GitHub repo for the customer. Clone this project beside it, then point the clone at both remotes. `upstream` is this main repo. `origin` is the customer repo:

```bash
git clone <main-repo-url> ironpulse
cd ironpulse
git remote rename origin upstream
git remote add origin <customer-repo-url>
git branch --unset-upstream
git remote -v
```

`git remote -v` must show `upstream` as the main repo and `origin` as the customer repo. `git branch --unset-upstream` stops a later push from updating the parent app. The apply command does this again if the link is still there.

2. In the existing Firebase project, add an Android app and an iOS app. Use the package name and bundle id you will put in the file below. Copy the two Firebase app ids. An app id looks like `1:471565987174:android:…`. It is not the package name or the bundle id.
3. In the new folder, edit `white_label/active.json`:

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
| `WL_IOS_BUNDLE_ID` | iOS bundle id, the same one added in Firebase |
| `WL_FIREBASE_ANDROID_APP_ID` | Android app id from Firebase, like `1:471565987174:android:…` |
| `WL_FIREBASE_IOS_APP_ID` | iOS app id from Firebase, like `1:471565987174:ios:…` |
| `WL_SUPPORT_EMAIL` | Support email |
| `WL_ADMIN_EMAIL` | Admin email |
| `WL_SUPPORT_PHONE` | Support phone |

`WL_APP_NAME_PREFIX` and `WL_APP_NAME_SUFFIX` are optional wordmark pieces. Leave them, or set them to match the new name.

4. From that same folder, run:

```bash
dart run tool/apply_white_label.dart
```

That writes the name and ids into Android, iOS, web, and the Firebase config files in the customer folder only. It does not change this parent app. If `origin` is still the main repo, the command stops and writes nothing. Then replace the logo and icons if this customer has their own:

- `assets/images/logo.png`
- `android/app/src/main/res/mipmap-*/ic_launcher.png`
- `android/app/src/main/res/mipmap-*/ic_launcher_foreground.png`
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `web/favicon.png` and `web/icons/`

5. Commit in that folder and push only to the customer repo. This sets the branch to track the customer repo, not the parent:

```bash
git push -u origin HEAD
```

Same Firebase project and same rules. The clone can open only the two gyms named in that file: one test gym and one real gym. Create those gyms in the main GCRM app first, then paste their document ids. This clone will not create gyms, will not open any other gym, and will not show the super-admin signup link. If either gym id is missing, or both ids are the same, the clone stops on launch.

## Update the white-label app only

Make the product change in this main folder, commit it, and push it only to the main repo:

```bash
git push origin HEAD
```

Then open the customer folder, not this one, and pull that update in:

```bash
cd ironpulse
git remote -v
bash tool/update_from_main.sh
git push origin HEAD
```

`bash tool/update_from_main.sh` fetches `upstream/main` into the customer folder. It keeps that repo's `white_label/active.json`, logo, and launcher icons, then writes the customer name and ids back onto Android, iOS, web, and the Firebase files. It does not push, and it does not change the parent app. You do not edit `active.json` again for a normal code update, and you do not run the apply command by hand unless the script tells you to.

`git push origin HEAD` from the customer folder updates only the customer repo.

If the script stops because a code file conflicts, fix the listed files in the customer folder, then run:

```bash
git add <fixed-files>
git merge --continue
dart run tool/apply_white_label.dart
git push origin HEAD
```

If the script says files still need a commit, those are the customer name and ids applied on top of the new code. Commit them in the customer folder and push with `git push origin HEAD`.
