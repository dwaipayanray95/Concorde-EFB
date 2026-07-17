/// Centralized external links the app opens or references.
///
/// The GitHub Pages site (siteRoot) is deployed straight from the `gh-pages`
/// branch — see .github/workflows/pages.yml and public/changelog,
/// public/donate for the page sources. Keep this file as the single place
/// that knows those paths so the two stay in sync.
class AppLinks {
  AppLinks._();

  static const String siteRoot = 'https://dwaipayanray95.github.io/Concorde-EFB/';
  static const String changelog = '${siteRoot}changelog/';
  static const String donate = '${siteRoot}donate/';

  static const String githubReleasesLatestApi =
      'https://api.github.com/repos/dwaipayanray95/Concorde-EFB/releases/latest';

  static const String flightsimTo = 'https://flightsim.to/addon/101890/concorde-efb';
  static const String patreon = 'https://www.patreon.com/c/theawesomeray';
}
