# Slim Discord card for a push: one embed, no author/pusher, sent @silent.
#   Physics-based runway distances          <- bold subject, links to commit
#   ‖ full commit body + files ‖            <- spoiler: click to expand
#   footer: v5.24.0 · main · 908e8d0
# Bot trailers (Co-Authored-By etc.) are dropped. Max 10 commits shown.
def clean: gsub("^\\s+|\\s+$"; "");
def cut($n): if length > $n then .[0:$n - 1] + "…" else . end;
def body:
  split("\n")[1:]
  | map(select(test("^(Co-Authored-By|Claude-Session|Signed-off-by):") | not))
  | join("\n") | clean | gsub("\\|\\|"; "|") | cut(500);
def files:
  [ (if (.added | length) > 0 then "+\(.added | length)" else empty end),
    (if (.modified | length) > 0 then "~\(.modified | length)" else empty end),
    (if (.removed | length) > 0 then "−\(.removed | length)" else empty end) ]
  | if length == 0 then "" else join(" ") + " files" end;
def line:
  (.message | split("\n")[0] | clean | cut(120)) as $subject
  | (.message | body) as $body
  | files as $files
  | ([$body, (if $files == "" then empty else "`\($files)`" end)]
     | map(select(. != "")) | join("\n")) as $details
  | "**[\($subject)](\(.url))**"
    + (if $details == "" then "" else "\n||\($details)||" end);

($commits | length) as $n
| ($commits[-1]) as $last
| {
    username: "Concorde EFB",
    flags: 4096,
    embeds: [{
      color: 15829005,
      description: (
        [$commits[:10][] | line] | join("\n\n") | cut(3900)
        + (if $n > 10 then "\n\n-# [+\($n - 10) more](\($compare))" else "" end)
      ),
      footer: {
        text: ([
          (if $version != "" then "v\($version)" else empty end),
          $branch,
          (if $n == 1 then $last.id[0:7] else "\($n) commits" end)
        ] | join("  ·  "))
      },
      timestamp: $last.timestamp
    }]
  }
