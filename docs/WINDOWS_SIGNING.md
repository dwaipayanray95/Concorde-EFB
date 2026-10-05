# Windows code signing (SignPath Foundation)

Unsigned Windows programs trigger "Windows protected your PC" (SmartScreen) and are a favourite target
for antivirus false alarms. That is especially bad here because the Flight Monitor depends on a helper
program, `msfs_bridge.exe`, and an antivirus that quarantines it makes the monitor look broken.
Signing fixes the warnings over time and proves the files really come from this project.

**SignPath Foundation** gives qualifying open-source projects a code-signing certificate for free.
(Android signing, macOS notarization and Windows signing are three separate things. See
`ANDROID_SIGNING.md` for Android.)

> SignPath's rules and screens change now and then. Their website is the final word; this is the plan.

## What gets signed
Only release builds. Debug and profile test builds stay unsigned.
1. `concorde_efb.exe` (the app) and `msfs_bridge.exe` (the helper), **before** they go into the installer.
2. The finished installer (`..._windows_setup.exe`).

Third-party files (Flutter's DLLs, the Python runtime) are left as they are.

## 1. Requirements (SignPath Foundation)
- The code must be **public open source under an OSI-approved licence** (MIT, Apache-2.0, GPL...).
  The repo has a `LICENSE` file at its root (Apache-2.0).
- The project must be real and maintained, with a public home page, a download and a way to contact you.
- You must publish a short **code signing policy** on your website (text below) and credit SignPath.
- Only programs built from this repository, by the GitHub build, are signed.

## 2. Apply
Go to the SignPath Foundation page (search "SignPath Foundation open source", then **Apply**) and give them:
- Project name: Concorde EFB
- Repository: https://github.com/dwaipayanray95/Concorde-EFB
- Homepage: https://dwaipayanray95.github.io/Concorde-EFB/
- Licence: Apache-2.0 (the `LICENSE` file is in the repo root)
- Where the code signing policy is published (section 5)
- How releases are built: the GitHub **Build** workflow, on GitHub-hosted runners

Approval can take days or weeks.

## 3. After approval, in the SignPath website
(SignPath's onboarding or support will help with the first setup.)
1. Create the project with the short name (slug) `concorde-efb`.
2. Connect the trusted build system **GitHub.com** and link this repository.
3. Add the signing policy `release-signing`. SignPath usually requires a person to approve each release
   signing request. That's you; approve it in their web app or by email when the Build workflow waits.
4. Add two **artifact configurations**.

   Slug `binaries`:
   ```xml
   <artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
     <zip-file>
       <pe-file path="concorde_efb.exe"><authenticode-sign/></pe-file>
       <pe-file path="msfs_bridge.exe"><authenticode-sign/></pe-file>
     </zip-file>
   </artifact-configuration>
   ```
   Slug `installer`:
   ```xml
   <artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
     <zip-file>
       <pe-file-set>
         <include path="*_windows_setup.exe" />
         <authenticode-sign/>
       </pe-file-set>
     </zip-file>
   </artifact-configuration>
   ```
5. Create a **CI user** and copy its **API token**. Also copy your **Organization ID**.

## 4. On GitHub (Settings → Secrets and variables → Actions)
| Kind | Name | Value |
|---|---|---|
| Secret | `SIGNPATH_API_TOKEN` | the CI user's API token |
| Variable | `SIGNPATH_ORGANIZATION_ID` | your organization ID |
| Variable (only if you used other names) | `SIGNPATH_PROJECT_SLUG` | default `concorde-efb` |
| Variable (only if you used other names) | `SIGNPATH_SIGNING_POLICY_SLUG` | default `release-signing` |

Until both the secret and `SIGNPATH_ORGANIZATION_ID` exist, signing is skipped, and release builds show
a warning that the Windows installer is unsigned.

## 5. Publish the code signing policy (needed for the application)
Put this on your website and in the README once SignPath has agreed to the project. Do not claim signing
before it is true.

> **Code signing policy**
> Free code signing for Windows releases is provided by [SignPath.io](https://about.signpath.io/),
> certificate by [SignPath Foundation](https://signpath.org/).
>
> Only programs built from this repository's public source by the project's GitHub build pipeline are signed.
> Roles: committers and reviewers: the project owner (@dwaipayanray95). Approver: the project owner.
>
> **Privacy:** this program will not transfer any information to other networked systems unless specifically
> requested by the user or the person installing or operating it. See the
> [privacy policy](https://dwaipayanray95.github.io/Concorde-EFB/privacy/).

(If the app's behaviour changes, keep that last privacy sentence true. The privacy page lists what
the app contacts.)

## 6. Check it worked
Run **Build** (Windows, mode release). When SignPath asks for approval, approve it. Then download the
installer, right-click it → **Properties → Digital Signatures**: it should list SignPath Foundation.
The run summary also shows the signature status. The workflow fails if the signature is not valid.

A signed installer still can show a SmartScreen warning at first. That reputation builds up as people
download it. A signature is what lets reputation attach to you.
