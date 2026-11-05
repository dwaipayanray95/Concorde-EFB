# Big release / beta card. Inputs: $rel (github.event.release), $entries
# (public/changelog/entries.json), $site (Pages base URL).
#  - Full release: amber, changelog bullets for that version, platform
#    download links, app icon + cockpit screenshot banner. Notifies.
#  - Beta: blue, build notes excerpt, download links. Sent silently.
def clean: gsub("^\\s+|\\s+$"; "");
def cut($n): if length > $n then .[0:$n - 1] + "…" else . end;
($rel.prerelease) as $beta
| ($rel.tag_name | ltrimstr("v")) as $ver
| ([$entries[] | select(.title | startswith("v" + $ver + " "))][0]) as $entry
| ([$rel.assets[]? | {name, url: .browser_download_url}]) as $assets
| def platform($re; $label):
    ($assets | map(select(.name | test($re; "i"))) | first) as $a
    | if $a then "[\($label)](\($a.url))" else empty end;
  ([platform("windows|\\.exe$"; "Windows"),
    platform("android|\\.apk$"; "Android"),
    platform("mac|\\.dmg$"; "macOS")]) as $downloads
| (if $entry and ($beta | not)
   then ($entry.title | sub("^v[^ ]+ — "; "")) as $headline
        | "### \($headline)\n" + ($entry.items | map("• " + .) | join("\n"))
   else ($rel.body // "" | clean
         | gsub("\r"; "") | cut(if $beta then 900 else 1800 end))
   end) as $notes
| {
    username: "Concorde EFB",
    avatar_url: "\($site)/landing/app-icon-256.png",
    flags: (if $beta then 4096 else 0 end),
    embeds: [({
      color: (if $beta then 5793266 else 15829005 end),
      author: { name: (if $beta then "BETA BUILD" else "NEW RELEASE" end),
                icon_url: "\($site)/landing/app-icon-256.png" },
      title: (if $beta then ($rel.name // $rel.tag_name)
              else "Concorde EFB \($rel.tag_name)" end),
      url: $rel.html_url,
      description: (if $notes == "" then "A new build is available." else $notes | cut(3800) end),
      thumbnail: { url: "\($site)/landing/app-icon-256.png" },
      fields: [
        { name: "Download",
          value: (if ($downloads | length) > 0 then $downloads | join("  ·  ")
                  else "[Downloads page](\($site)/downloads/)" end),
          inline: true },
        { name: "Details",
          value: "[Release notes](\($rel.html_url))  ·  [Changelog](\($site)/changelog/)",
          inline: true }
      ],
      footer: { text: (if $beta then "Pre-release · for testing" else "Concorde EFB · DC Designs Concorde for MSFS" end) },
      timestamp: ($rel.published_at // $rel.created_at)
    } + (if $beta then {} else { image: { url: "\($site)/landing/screenshots/monitor-cockpit.png" } } end))]
  }
