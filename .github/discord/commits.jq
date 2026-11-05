# Slim Discord card for a push: one embed, no author/pusher.
#   Physics-based runway distances          ← bold subject, links to commit
#   Runway required now uses air density…   ← first sentence of the body, small
#   ─ footer: v5.24.0 · main · 908e8d0
# Bot trailers (Co-Authored-By etc.) are dropped. Max 10 commits shown.
def clean: gsub("^\\s+|\\s+$"; "");
def excerpt:
  split("\n")[1:]
  | map(select(test("^(Co-Authored-By|Claude-Session|Signed-off-by):") | not))
  | join(" ") | gsub("\\s+"; " ") | clean
  | if length > 140 then .[0:137] + "…" else . end;
def line:
  (.message | split("\n")[0] | clean | .[0:120]) as $subject
  | (.message | excerpt) as $body
  | "**[\($subject)](\(.url))**"
    + (if $body == "" then "" else "\n-# \($body)" end);

($commits | length) as $n
| ($commits[-1]) as $last
| {
    username: "Concorde EFB",
    embeds: [{
      color: 15829005,
      description: (
        [$commits[:10][] | line] | join("\n\n")
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
