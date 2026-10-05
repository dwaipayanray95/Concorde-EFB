# Google Play listing: everything you need

Copy and paste from here into Play Console. Graphics are in `store/google-play/`.

> Play Console changes its wording from time to time. If a label differs slightly, pick the closest
> option. Where a rule can change (like testing requirements), Play Console shows the current one.

## 0. Before you start
- A Google Play developer account (one-time $25 fee) with identity verification completed.
- Package name for the app: `com.theawesomeray.concorde_efb`. It can never be changed once created.
- A signed `.aab`: run the **Build** workflow, mode **release**, Android only (see `ANDROID_SIGNING.md`).
  Download it from the draft release. Each upload needs a higher build number than the last, and the
  version rule in `AGENTS.md` already does that.

## 1. Create the app
Play Console → **Create app**
- App name: `Concorde EFB`
- Default language: English (United Kingdom or United States)
- App or game: **App**
- Free or paid: **Free**
- Tick the declarations (developer program policies, US export laws).

## 2. Store listing (Grow → Store presence → Main store listing)
| Field | Value |
|---|---|
| App name (max 30) | `Concorde EFB` |
| Short description (max 80) | `Concorde flight planner: fuel, V-speeds, METAR, checklists, live monitor.` |
| App icon | `store/google-play/icon-512.png` |
| Feature graphic | `store/google-play/feature-graphic-1024x500.png` |
| Phone screenshots | at least 2 (see below) |
| Category | **Tools** (or Simulation if offered for apps) |
| Contact email | your public support email (shown on the store page) |
| Website | https://dwaipayanray95.github.io/Concorde-EFB/ |
| Privacy policy | https://dwaipayanray95.github.io/Concorde-EFB/privacy/ |

**Full description** (max 4000):

```
Concorde EFB is a free Electronic Flight Bag for the DC Designs Concorde in Microsoft Flight Simulator 2020 and 2024. Plan the flight, check the numbers, run the checklists and watch the flight live, all from your phone or tablet.

FLIGHT PLANNING
- Import your latest SimBrief flight plan or enter the route by hand
- Trip, taxi, contingency, final reserve and alternate fuel, with endurance checks
- Cruise level handling for Concorde, including non-RVSM levels

PERFORMANCE
- Takeoff and landing V-speeds scaled to your weights
- Runway length checks with live METAR wind, temperature and pressure
- Crosswind and tailwind limits, wet and contaminated runways, reheat on or off
- A single dispatch GO / NO-GO summary

CHECKLISTS
- Interactive checklists from cold and dark through to shutdown, with your live speeds filled in

FLIGHT MONITOR
- Live flight data from the simulator: engines, fuel and centre of gravity, attitude, gear and nose
- Warnings and chimes for overspeed, gear and centre of gravity
- Connects over your home Wi-Fi to the free Concorde EFB desktop app on your simulator PC (Windows)

Concorde EFB is for flight simulation only and is not affiliated with DC Designs, Microsoft, British Airways or Air France. Numbers are indicative and not for real-world use.

The Android app shows a banner ad. It has no accounts and does not sell your data.
```

**Screenshots:** ready-made sets rendered from the real app (JetBrains Mono, loaded EGLL-KJFK
flight, dark + light), all within Play's limits:
- Phone (1920x1080): `store/google-play/screenshots-phone/` -- upload these under Phone screenshots.
- Tablet (2560x1600): `store/google-play/screenshots-tablet/` -- use for both 7-inch and 10-inch tablets.
Files are numbered in the suggested upload order (planner, fuel release, performance, fuel schematic,
cockpit panels, checklists, then light-mode extras).

## 3. App content (Policy → App content)
| Question | Answer |
|---|---|
| Privacy policy | the URL above |
| Ads | **Yes, my app contains ads** |
| App access | All functionality available without login |
| Content rating | Fill the questionnaire: category *Utility, productivity, communication or other*. No violence, sexual content, language, gambling, drugs, user-generated content, location sharing or purchases. Expect a rating for everyone. |
| Target audience | **18 and over** (keeps you outside the Families policy) |
| News app | No |
| Government app | No |
| Financial features | None |
| Health features | None |
| COVID-19 apps | Not a COVID app |
| Data safety | see section 4 |

## 4. Data safety form
The honest summary: the app has no accounts and sends nothing to you. The only data leaving the
device is what Google's AdMob ad SDK collects, plus ordinary internet requests for weather and
airport data.

- Does your app collect or share user data? **Yes** (because of AdMob).
- Is all data encrypted in transit? **Yes** (HTTPS).
- Can users request data deletion? There is no account, and nothing is stored by you. Answer **No** to
  "provides a way to request deletion" if the form requires a yes/no; users can reset their advertising ID
  in Android settings.

Declare these types, **collected and shared**, purpose **Advertising or marketing** (and **Analytics**
where offered), **not optional**, shared with Google (AdMob):
- Device or other IDs (advertising ID)
- App activity: app interactions (ad impressions and clicks)
- App info and performance: diagnostics / crash logs
- Approximate location (derived from IP address)

Google publishes the exact list its ad SDK collects ("Provide information for Google Play's Data safety
section" in the AdMob help). If that page differs from the list above, follow Google's page.

Not declared: the SimBrief username you type is sent to SimBrief only when you press import and is stored
only on your device; weather and airport requests send airport codes only. These are requests you start yourself
and none of it reaches the developer.

If the data safety form ever disagrees with `public/privacy/index.html`, fix the policy page too.

## 5. Release
Release → Testing/Production → Create new release
1. Let Play manage app signing (**Play App Signing**, the default).
2. Upload `ConcordeEFB_v<version>_release_android.aab`.
3. Release name: the version, e.g. `5.12.1`.
4. Release notes: copy the user-friendly text from the GitHub release.
5. Review and roll out.

**New personal developer accounts** have to run a **closed test** first: a minimum number of testers
(12 when this was written) who stay opted in for 14 days, before **production** access is unlocked.
Play Console shows the current rule and a progress counter under *Dashboard*. Plan for this: start the
closed test as soon as the listing is filled in, and invite friends from the Concorde and flight-sim community
(Discord is a good source).

## 6. After the app is live
- AdMob → App settings → **Link to Google Play** so ads and payments are matched to the store listing.
- Add `app-ads.txt` to your website (we still need to decide where it can be hosted).
- Answer reviews and keep the changelog and Play release notes in step.
