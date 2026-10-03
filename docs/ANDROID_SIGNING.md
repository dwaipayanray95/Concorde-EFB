# Android signing (one-time setup)

Google Play only accepts apps signed with a key you own. This is that key (Google calls it
the **upload key**). You make it once, store it as GitHub secrets, and every **release** build of the
Build workflow then signs the app automatically.

Debug and profile builds are never signed with this key.

> Keep the key file and its passwords safe. Never put them in the repository or send them in chat.

## 1. Create the key (on your own computer)

You need `keytool`, which comes with Android Studio. Open a terminal and run **one** of these.

**Windows (PowerShell):**
```
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Mac (Terminal):**
```
"/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/keytool" -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

It asks for:
- a **keystore password** (choose a strong one and write it down),
- your name and a few details (anything sensible; it is not shown to users),
- a **key password** (press Enter to use the same as the keystore password).

This creates the file `upload-keystore.jks` in the folder you ran it from.

## 2. Back it up

Copy `upload-keystore.jks` and the passwords into your password manager (or an encrypted drive).
If you lose them, Google can reset the upload key, but it takes support requests and time.

## 3. Turn the file into text for GitHub

**Windows (PowerShell):**
```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```

**Mac (Terminal):**
```
base64 -i upload-keystore.jks | pbcopy
```

The long text is now on your clipboard.

## 4. Add four secrets on GitHub

Repository → **Settings → Secrets and variables → Actions → New repository secret**. Add:

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | paste the long text from step 3 |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password |
| `ANDROID_KEY_ALIAS` | `upload` |
| `ANDROID_KEY_PASSWORD` | the key password (same as the keystore password if you pressed Enter) |

## 5. Build

Run the **Build** workflow with mode **release**. If a secret is missing the build stops and says which one.
On success, the run summary shows the signing certificate fingerprint, and the `.aab` file is attached
to the release.

## 6. First upload to Google Play

In Play Console, create the app (package name `com.theawesomeray.concorde_efb`), then upload the
`.aab`. When asked, keep **Play App Signing** switched on (the default). Google then holds the final
signing key and your upload key only proves the upload is from you.

## Building on your own computer (optional)

Create `android/key.properties` (git-ignored) with:
```
storeFile=C:/path/to/upload-keystore.jks
storePassword=YOUR_PASSWORD
keyAlias=upload
keyPassword=YOUR_PASSWORD
```
Then `flutter build appbundle --release` signs with it. Without that file, a local release build
falls back to the debug key, which Play rejects.
