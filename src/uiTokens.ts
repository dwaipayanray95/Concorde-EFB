export const UI_TOKENS = {
  spacing: {
    pageStack: "space-y-8",
    sectionStack: "space-y-6",
    blockGap: "gap-6",
  },
  card: "efb-surface p-6 transition-colors duration-500 hover:bg-white/10",
  cardHeader: {
    wrap: "flex items-center justify-between mb-5",
    title: "text-lg font-semibold text-white/90",
  },
  label: "efb-label block mb-2 ml-1",
  metric: {
    box: "efb-metric flex flex-col justify-center",
    label: "text-[10px] uppercase tracking-[0.24em] text-white/40",
    value: "text-lg font-semibold text-white/90 tabular-nums",
  },
  divider: "h-px bg-white/5 my-6",
  statusPill: {
    base:
      "inline-flex items-center gap-2 rounded-full border px-3 py-1 text-[11px] font-semibold uppercase tracking-[0.18em]",
    ok: "border-emerald-400/40 bg-emerald-500/10 text-emerald-300",
    warning: "border-amber-400/40 bg-amber-500/10 text-amber-400",
    error: "border-rose-400/40 bg-rose-500/10 text-rose-300",
    lifr: "border-fuchsia-400/40 bg-fuchsia-500/15 text-fuchsia-300",
    neutral: "border-white/10 bg-white/5 text-white/70",
  },
  surface: {
    soft: "rounded-3xl border border-white/10 bg-black/25",
    panel: "rounded-3xl border border-white/10 bg-black/30",
  },
} as const;
