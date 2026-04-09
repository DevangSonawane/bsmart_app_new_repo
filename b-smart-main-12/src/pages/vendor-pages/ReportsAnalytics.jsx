import { useCallback, useEffect, useMemo, useState } from "react";
import { useSelector } from "react-redux";
import { jsPDF } from "jspdf";
import autoTable from "jspdf-autotable";
import api from "../../lib/api";
import {
  AlertCircle,
  ArrowDownLeft,
  ArrowUpRight,
  BarChart2,
  Calendar,
  CheckCircle2,
  Clock,
  Download,
  Eye,
  FileDown,
  Filter,
  Globe,
  Heart,
  Loader2,
  MousePointerClick,
  Search,
  Send,
  Target,
  TrendingUp,
  Users,
  DollarSign,
  Zap,
} from "lucide-react";

const REPORTS = [
  { id: "performance", label: "Performance Summary", endpoint: "/reports/performance-summary", desc: "Overall campaign performance metrics", icon: TrendingUp, color: "text-orange-500", bg: "bg-orange-50 dark:bg-orange-900/20" },
  { id: "click", label: "Click Report", endpoint: "/reports/clicks", desc: "Detailed click-through analysis", icon: MousePointerClick, color: "text-blue-500", bg: "bg-blue-50 dark:bg-blue-900/20" },
  { id: "engagement", label: "Engagement Report", endpoint: "/reports/engagement", desc: "Likes, shares, comments & interactions", icon: Heart, color: "text-pink-500", bg: "bg-pink-50 dark:bg-pink-900/20" },
  { id: "conversion", label: "Conversion Report", endpoint: "/reports/conversions", desc: "Conversion tracking & ROI insights", icon: Zap, color: "text-purple-500", bg: "bg-purple-50 dark:bg-purple-900/20" },
  { id: "geographic", label: "Geographic Report", endpoint: "/reports/geographic", desc: "Audience breakdown by location", icon: Globe, color: "text-green-500", bg: "bg-green-50 dark:bg-green-900/20" },
  { id: "financial", label: "Financial Report", endpoint: "/wallet/vendor/:userId/history", desc: "Spend, budget & billing summary", icon: DollarSign, color: "text-amber-500", bg: "bg-amber-50 dark:bg-amber-900/20" },
];

const PRESETS = [
  { value: "today", label: "Today" },
  { value: "7d", label: "Last 7 days" },
  { value: "30d", label: "Last 30 days" },
  { value: "this_month", label: "This month" },
  { value: "last_month", label: "Last month" },
  { value: "custom", label: "Custom" },
];

const SUMMARY_CARDS = [
  { key: "total_impressions", label: "Total Impressions", icon: Eye, tone: "bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400" },
  { key: "total_clicks", label: "Total Clicks", icon: MousePointerClick, tone: "bg-pink-100 dark:bg-pink-900/30 text-pink-600 dark:text-pink-400" },
  { key: "engagement_rate", label: "Engagement Rate", icon: Heart, tone: "bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400", kind: "percent" },
  { key: "total_spend", label: "Total Spend", icon: DollarSign, tone: "bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400" },
  { key: "conversions", label: "Conversions", icon: Zap, tone: "bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400" },
  { key: "reach", label: "Reach", icon: Users, tone: "bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400" },
];

const COLUMNS = {
  performance: [
    ["date", "Date"], ["impressions", "Impressions"], ["clicks", "Clicks"], ["ctr", "CTR", "percent"], ["reach", "Reach"], ["frequency", "Frequency", "decimal"],
  ],
  click: [
    ["ad_name", "Ad Name"], ["impressions", "Impressions"], ["total_clicks", "Total Clicks"], ["unique_clicks", "Unique Clicks"], ["invalid_clicks", "Invalid Clicks"], ["click_rate", "Click Rate", "percent"], ["cpc", "CPC", "decimal"], ["coins_spent", "Coins Spent"],
  ],
  engagement: [
    ["ad_name", "Ad Name"], ["impressions", "Impressions"], ["likes", "Likes"], ["dislikes", "Dislikes"], ["comments", "Comments"], ["saves", "Saves"], ["engagement_rate", "Engagement Rate", "percent"],
  ],
  conversion: [
    ["ad_name", "Ad Name"], ["conversions", "Conversions"], ["conversion_rate", "Conversion Rate", "percent"], ["cost_per_conversion", "Cost/Conversion", "decimal"], ["roas", "ROAS", "decimal"], ["revenue", "Revenue"], ["total_spend", "Spend"],
  ],
  geographic: [
    ["country", "Country"], ["impressions", "Impressions"], ["clicks", "Clicks"], ["ctr", "CTR", "percent"], ["reach", "Reach"],
  ],
  financial: [
    ["period", "Period"], ["total_spend", "Total Spend"], ["coins_used", "Coins Used"], ["budget_used", "Budget Used", "percent"], ["cpm", "CPM", "decimal"], ["cost_per_lead", "Cost Per Lead", "decimal"],
  ],
};

// B SMART – minimal, clean, light theme
const PDF_THEME = {
  pageBg: [255, 255, 255],          // pure white page
  headerBg: [255, 255, 255],        // white header area (no dark panel)
  text: [30, 20, 40],               // near-black text
  textMuted: [150, 130, 165],       // soft muted purple-grey
  textLight: [190, 175, 205],       // lighter muted
  white: [255, 255, 255],
  border: [238, 228, 248],          // soft lavender border
  divider: [240, 232, 252],         // very soft lavender divider
  accentPink: [214, 41, 118],       // insta-pink   #d62976
  accentOrange: [250, 126, 30],     // insta-orange #fa7e1e
  accentPurple: [150, 47, 191],     // insta-purple #962fbf
  accentYellow: [254, 218, 117],    // insta-yellow #feda75
  metricBg: [252, 250, 255],        // near-white card bg
  tableBg: [248, 244, 255],         // very light lavender alternating rows
  tableHeader: [250, 245, 255],     // near-white table header
  reports: {
    performance: { accent: [250, 126, 30],  soft: [255, 245, 235] },   // orange
    click:       { accent: [214, 41, 118],  soft: [255, 235, 245] },   // pink
    engagement:  { accent: [150, 47, 191],  soft: [248, 235, 255] },   // purple
    conversion:  { accent: [214, 41, 118],  soft: [255, 235, 245] },   // pink
    geographic:  { accent: [150, 47, 191],  soft: [248, 235, 255] },   // purple
    financial:   { accent: [250, 126, 30],  soft: [255, 245, 235] },   // orange
  },
};

const asNum = (v) => Number(v || 0);
const fmt = (v, kind) => {
  if (v == null || v === "") return "-";
  if (kind === "percent") return `${asNum(v).toFixed(2)}%`;
  if (kind === "decimal") return asNum(v).toFixed(2);
  if (typeof v === "number") return v.toLocaleString("en-IN");
  return String(v);
};

const dateStr = (d) => {
  const y = d.getFullYear();
  const m = `${d.getMonth() + 1}`.padStart(2, "0");
  const day = `${d.getDate()}`.padStart(2, "0");
  return `${y}-${m}-${day}`;
};

const getRange = (preset, customStart, customEnd) => {
  const now = new Date();
  const start = new Date(now);
  const end = new Date(now);
  if (preset === "custom") return { startDate: customStart || "", endDate: customEnd || "" };
  if (preset === "today") return { startDate: dateStr(now), endDate: dateStr(now) };
  if (preset === "7d") start.setDate(start.getDate() - 6);
  if (preset === "30d") start.setDate(start.getDate() - 29);
  if (preset === "this_month") start.setDate(1);
  if (preset === "last_month") {
    const s = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const e = new Date(now.getFullYear(), now.getMonth(), 0);
    return { startDate: dateStr(s), endDate: dateStr(e) };
  }
  return { startDate: dateStr(start), endDate: dateStr(end) };
};

const normalizeSummary = (data) => ({
  total_impressions: data?.overview?.total_impressions ?? 0,
  total_clicks: data?.overview?.total_clicks ?? 0,
  engagement_rate: data?.overview?.engagement_rate ?? 0,
  total_spend: data?.overview?.total_spend ?? 0,
  conversions: data?.overview?.conversions ?? 0,
  reach: data?.overview?.reach ?? 0,
});

const getWeekStart = (value) => {
  const date = new Date(value);
  const normalized = new Date(date.getFullYear(), date.getMonth(), date.getDate());
  const day = normalized.getDay();
  const diff = normalized.getDate() - day + (day === 0 ? -6 : 1);
  normalized.setDate(diff);
  return normalized;
};

const normalizeRows = (reportId, data) => {
  const rows = Array.isArray(data?.data) ? data.data : Array.isArray(data?.rows) ? data.rows : Array.isArray(data) ? data : [];
  if (reportId === "performance") {
    const dataRows = Array.isArray(data?.data) ? data.data : [];
    return dataRows.map((r) => ({
      date: r.date ?? "-",
      impressions: r.impressions ?? 0,
      clicks: r.clicks ?? 0,
      ctr: r.ctr ?? 0,
      reach: r.reach ?? 0,
      frequency: r.frequency ?? 0,
    }));
  }
  if (reportId === "click") return rows.map((r) => ({ ad_name: r.ad_name || r.caption || "Untitled Ad", impressions: r.impressions ?? 0, total_clicks: r.total_clicks ?? 0, unique_clicks: r.unique_clicks ?? 0, invalid_clicks: r.invalid_clicks ?? 0, click_rate: r.click_rate ?? 0, cpc: r.cpc ?? 0, coins_spent: r.coins_spent ?? 0 }));
  if (reportId === "engagement") return rows.map((r) => ({ ad_name: r.ad_name || r.caption || "Untitled Ad", impressions: r.impressions ?? 0, likes: r.likes ?? 0, dislikes: r.dislikes ?? 0, comments: r.comments ?? 0, saves: r.saves ?? 0, engagement_rate: r.engagement_rate ?? 0 }));
  if (reportId === "conversion") return rows.map((r) => ({ ad_name: r.ad_name || r.caption || "Untitled Ad", conversions: r.conversions ?? r.unique_clicks ?? 0, conversion_rate: r.conversion_rate ?? 0, cost_per_conversion: r.cost_per_conversion ?? r.cost_per_lead ?? 0, roas: r.roas ?? 0, revenue: r.revenue ?? 0, total_spend: r.total_spend ?? r.spend ?? 0 }));
  if (reportId === "geographic") return rows.map((r) => ({ country: r.country || r._id || "Unknown", impressions: r.impressions ?? 0, clicks: r.clicks ?? r.total_clicks ?? 0, ctr: r.ctr ?? r.click_rate ?? 0, reach: r.reach ?? 0 }));
  if (reportId === "financial") return Array.isArray(data?.financialRows) ? data.financialRows : [];
  return rows;
};

const Select = ({ value, onChange, options, icon: Icon }) => (
  <div className="relative">
    <div className="pointer-events-none absolute inset-y-0 left-3 flex items-center">{Icon ? <Icon size={14} className="text-gray-400" /> : null}</div>
    <select value={value} onChange={(e) => onChange(e.target.value)} className="w-full appearance-none rounded-xl border border-gray-200 bg-white py-2.5 pl-9 pr-8 text-sm text-gray-700 outline-none focus:border-pink-500 focus:ring-2 focus:ring-pink-500/20 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200">
      {options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
    </select>
    <div className="pointer-events-none absolute inset-y-0 right-3 flex items-center"><Search size={12} className="rotate-90 text-gray-300" /></div>
  </div>
);

export default function ReportsAnalytics() {
  const { userObject } = useSelector((state) => state.auth);
  const [datePreset, setDatePreset] = useState("30d");
  const [startDate, setStartDate] = useState("");
  const [endDate, setEndDate] = useState("");
  const [selectedAd, setSelectedAd] = useState("all");
  const [country, setCountry] = useState("all");
  const [language, setLanguage] = useState("all");
  const [gender, setGender] = useState("all");
  const [showFilters, setShowFilters] = useState(false);
  const [selectedReport, setSelectedReport] = useState("performance");
  const [ads, setAds] = useState([]);
  const [summary, setSummary] = useState(normalizeSummary({}));
  const [rows, setRows] = useState([]);
  const [financialMeta, setFinancialMeta] = useState(null);
  const [summaryLoading, setSummaryLoading] = useState(true);
  const [reportLoading, setReportLoading] = useState(true);
  const [reportUnavailable, setReportUnavailable] = useState(false);
  const [summaryError, setSummaryError] = useState("");
  const [reportError, setReportError] = useState("");
  const [exportMsg, setExportMsg] = useState("");

  const [tablePage, setTablePage] = useState(1);
  const TABLE_PAGE_SIZE = 7;

  const currentReport = REPORTS.find((r) => r.id === selectedReport);
  const params = useMemo(() => {
    const range = getRange(datePreset, startDate, endDate);
    const next = {};
    if (range.startDate) next.startDate = range.startDate;
    if (range.endDate) next.endDate = range.endDate;
    if (selectedAd !== "all") next.ad_id = selectedAd;
    if (country !== "all") next.country = country;
    if (language !== "all") next.language = language;
    if (gender !== "all") next.gender = gender;
    return next;
  }, [datePreset, startDate, endDate, selectedAd, country, language, gender]);

  const adOptions = useMemo(() => [{ value: "all", label: "All Ads" }, ...ads.map((ad) => ({ value: ad._id, label: ad.caption || ad.title || "Untitled Ad" }))], [ads]);

  // Reset table page whenever report type or data changes
  React.useEffect(() => { setTablePage(1); }, [selectedReport, rows.length]);

  const fetchAds = useCallback(async () => {
    if (!userObject?._id) return;
    try {
      const res = await api.get(`/ads/user/${userObject._id}`);
      const list = Array.isArray(res.data) ? res.data : Array.isArray(res.data?.ads) ? res.data.ads : Array.isArray(res.data?.data) ? res.data.data : [];
      setAds(list);
    } catch {
      setAds([]);
    }
  }, [userObject?._id]);

  const fetchSummary = useCallback(async () => {
    setSummaryLoading(true);
    setSummaryError("");
    try {
      const res = await api.get("/reports/summary", { params });
      setSummary(normalizeSummary(res.data));
    } catch (err) {
      setSummary(normalizeSummary({}));
      setSummaryError(err?.response?.data?.message || "Failed to load overview.");
    } finally {
      setSummaryLoading(false);
    }
  }, [params]);

  const fetchReport = useCallback(async () => {
    if (!currentReport) return;
    setReportLoading(true);
    setReportError("");
    setReportUnavailable(false);
    setFinancialMeta(null);
    try {
      let res;
      if (currentReport.id === "financial") {
        const walletRes = await api.get(`/wallet/vendor/${userObject?._id}/history`, {
          params: { startDate: params.startDate, endDate: params.endDate, limit: 500, page: 1 },
        });
        const transactions = Array.isArray(walletRes.data?.transactions) ? walletRes.data.transactions : [];
        const debitTransactions = transactions
          .filter((tx) => tx.direction === "debit")
          .sort((a, b) => new Date(a.created_at || a.createdAt) - new Date(b.created_at || b.createdAt));

        const grouped = new Map();
        debitTransactions.forEach((tx) => {
          const createdAt = tx.created_at || tx.createdAt;
          if (!createdAt) return;
          const weekStart = getWeekStart(createdAt);
          const key = dateStr(weekStart);
          if (!grouped.has(key)) {
            const weekEnd = new Date(weekStart);
            weekEnd.setDate(weekEnd.getDate() + 6);
            grouped.set(key, {
              startDate: dateStr(weekStart),
              endDate: dateStr(weekEnd),
              total_spend: 0,
            });
          }
          grouped.get(key).total_spend += Number(tx.amount || 0);
        });

        const periods = Array.from(grouped.values()).sort((a, b) => a.startDate.localeCompare(b.startDate));
        const budgetBase = Number(walletRes.data?.summary?.total_credited || 0) || (Number(walletRes.data?.summary?.total_debited || 0) + Number(walletRes.data?.wallet?.balance || 0));

        const financialRows = await Promise.all(periods.map(async (period, index) => {
          let periodSummary = null;
          try {
            const summaryRes = await api.get("/reports/summary", {
              params: {
                ...params,
                startDate: period.startDate,
                endDate: period.endDate,
              },
            });
            periodSummary = summaryRes.data?.overview || {};
          } catch {
            periodSummary = {};
          }
          const impressions = Number(periodSummary?.total_impressions || 0);
          const conversions = Number(periodSummary?.conversions || 0);
          const spend = Number(period.total_spend || 0);
          return {
            period: `Week ${index + 1}`,
            total_spend: spend,
            coins_used: spend,
            budget_used: budgetBase > 0 ? +((spend / budgetBase) * 100).toFixed(2) : 0,
            cpm: impressions > 0 ? +((spend / impressions) * 1000).toFixed(2) : 0,
            cost_per_lead: conversions > 0 ? +(spend / conversions).toFixed(2) : 0,
          };
        }));

        res = {
          data: {
            ...walletRes.data,
            financialRows,
          },
        };
      } else {
        res = await api.get(currentReport.endpoint, { params });
      }
      if (currentReport.id === "financial") {
        setFinancialMeta({
          wallet: res.data?.wallet || null,
          summary: res.data?.summary || null,
          user: res.data?.user || null,
        });
      }
      setRows(normalizeRows(currentReport.id, res.data));
    } catch (err) {
      setRows([]);
      if (err?.response?.status === 404) setReportUnavailable(true);
      else setReportError(err?.response?.data?.message || "Failed to load report.");
    } finally {
      setReportLoading(false);
    }
  }, [currentReport, params, userObject?._id]);

  useEffect(() => { fetchAds(); }, [fetchAds]);
  useEffect(() => { fetchSummary(); }, [fetchSummary]);
  useEffect(() => { fetchReport(); }, [fetchReport]);

  const exportCsv = () => {
    if (!rows.length) return;
    const cols = COLUMNS[selectedReport] || [];
    const csv = [
      cols.map((c) => c[1]).join(","),
      ...rows.map((row) => cols.map((c) => `"${fmt(row[c[0]], c[2])}"`).join(",")),
    ].join("\n");
    const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `${selectedReport}_report.csv`;
    a.click();
    URL.revokeObjectURL(url);
    setExportMsg("CSV exported successfully.");
    setTimeout(() => setExportMsg(""), 2500);
  };

  const exportPdf = () => {
    if (!rows.length) return;
    const cols = COLUMNS[selectedReport] || [];
    const reportTheme = PDF_THEME.reports[selectedReport] || PDF_THEME.reports.performance;
    const doc = new jsPDF({
      orientation: cols.length > 6 ? "landscape" : "portrait",
      unit: "pt",
      format: "a4",
    });

    const range = getRange(datePreset, startDate, endDate);
    const filterParts = [];
    if (range.startDate || range.endDate) {
      filterParts.push(`${range.startDate || "All"} – ${range.endDate || "All"}`);
    }
    if (selectedAd !== "all") {
      const selectedAdLabel = adOptions.find((o) => o.value === selectedAd)?.label || selectedAd;
      filterParts.push(`Ad: ${selectedAdLabel}`);
    }
    if (country !== "all")  filterParts.push(`Country: ${country}`);
    if (language !== "all") filterParts.push(`Language: ${language}`);
    if (gender !== "all")   filterParts.push(`Gender: ${gender}`);

    const pageW  = doc.internal.pageSize.getWidth();
    const pageH  = doc.internal.pageSize.getHeight();
    const summaryItems = SUMMARY_CARDS.map((card) => ({
      label: card.label,
      value: fmt(summary[card.key], card.kind),
    }));
    const margin = 36;
    const contentW = pageW - margin * 2;

    // ── PAGE BACKGROUND (white) ───────────────────────────────────────
    doc.setFillColor(...PDF_THEME.pageBg);
    doc.rect(0, 0, pageW, pageH, "F");

    // ── HEADER ───────────────────────────────────────────────────────
    // Logo badge – small, coloured square
    const badgeSize = 38;
    const badgeX = margin;
    const badgeY = 28;
    doc.setFillColor(...reportTheme.accent);
    doc.roundedRect(badgeX, badgeY, badgeSize, badgeSize, 10, 10, "F");
    doc.setTextColor(...PDF_THEME.white);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(18);
    doc.text("B", badgeX + badgeSize / 2, badgeY + 26, { align: "center" });

    // Brand + report name
    const textX = badgeX + badgeSize + 12;
    doc.setTextColor(...PDF_THEME.text);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(20);
    doc.text("B SMART", textX, badgeY + 16);

    doc.setFont("helvetica", "bold");
    doc.setFontSize(11);
    doc.setTextColor(...reportTheme.accent);
    doc.text(currentReport?.label || "Report", textX, badgeY + 31);

    doc.setFont("helvetica", "normal");
    doc.setFontSize(8.5);
    doc.setTextColor(...PDF_THEME.textMuted);
    doc.text(currentReport?.desc || "", textX, badgeY + 44);

    // Report type pill (top-right, minimal outline style)
    const pillW = 130, pillH = 22;
    const pillX = pageW - margin - pillW;
    const pillY = badgeY + 2;
    doc.setDrawColor(...reportTheme.accent);
    doc.setLineWidth(1.2);
    doc.roundedRect(pillX, pillY, pillW, pillH, 11, 11, "D");
    doc.setTextColor(...reportTheme.accent);
    doc.setFont("helvetica", "bold");
    doc.setFontSize(8);
    doc.text("VENDOR ANALYTICS", pillX + pillW / 2, pillY + 14.5, { align: "center" });

    // Generated date
    const now = new Date();
    doc.setFont("helvetica", "normal");
    doc.setFontSize(7.5);
    doc.setTextColor(...PDF_THEME.textMuted);
    doc.text(
      `Generated: ${now.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })}`,
      pageW - margin,
      badgeY + 36,
      { align: "right" }
    );

    // Full-width thin divider under header
    const headerBottom = badgeY + badgeSize + 14;
    doc.setDrawColor(...PDF_THEME.divider);
    doc.setLineWidth(1);
    doc.line(margin, headerBottom, pageW - margin, headerBottom);

    // ── FILTER CHIPS ─────────────────────────────────────────────────
    let curY = headerBottom + 16;
    if (filterParts.length) {
      doc.setFont("helvetica", "bold");
      doc.setFontSize(7);
      doc.setTextColor(...PDF_THEME.textMuted);
      doc.text("FILTERS", margin, curY + 9);
      let chipX = margin + doc.getTextWidth("FILTERS") + 10;
      filterParts.forEach((part) => {
        doc.setFontSize(7.5);
        const chipW = doc.getTextWidth(part) + 18;
        if (chipX + chipW > pageW - margin) { chipX = margin; curY += 18; }
        doc.setFillColor(...reportTheme.soft);
        doc.roundedRect(chipX, curY, chipW, 16, 8, 8, "F");
        doc.setTextColor(...reportTheme.accent);
        doc.setFont("helvetica", "bold");
        doc.text(part, chipX + 9, curY + 11);
        chipX += chipW + 6;
      });
      curY += 26;
    }

    // ── KEY METRICS LABEL ─────────────────────────────────────────────
    curY += 4;
    doc.setFont("helvetica", "bold");
    doc.setFontSize(7.5);
    doc.setTextColor(...PDF_THEME.textMuted);
    doc.text("KEY METRICS", margin, curY);
    doc.setDrawColor(...reportTheme.accent);
    doc.setLineWidth(1.5);
    doc.line(margin + doc.getTextWidth("KEY METRICS") + 6, curY - 2, margin + doc.getTextWidth("KEY METRICS") + 32, curY - 2);
    curY += 10;

    // ── METRIC CARDS ─────────────────────────────────────────────────
    const cardGap = 10;
    const cardW   = (contentW - cardGap * 2) / 3;
    const cardH   = 58;
    const metricAccents = [
      PDF_THEME.accentOrange,
      PDF_THEME.accentPink,
      PDF_THEME.accentPurple,
      PDF_THEME.accentPink,
      PDF_THEME.accentPurple,
      PDF_THEME.accentOrange,
    ];

    summaryItems.forEach((item, i) => {
      const col = i % 3;
      const row = Math.floor(i / 3);
      const x   = margin + col * (cardW + cardGap);
      const y   = curY + row * (cardH + cardGap);
      const acc = metricAccents[i];

      // Card: fill + soft border stroke — plain rect, no rounded corners
      doc.setFillColor(...PDF_THEME.metricBg);
      doc.setDrawColor(...PDF_THEME.border);
      doc.setLineWidth(0.5);
      doc.rect(x, y, cardW, cardH, "FD");

      // Accent: clean thick line on the left edge, full card height
      doc.setDrawColor(...acc);
      doc.setLineWidth(3);
      doc.line(x + 1.5, y, x + 1.5, y + cardH);

      // Label
      doc.setFont("helvetica", "bold");
      doc.setFontSize(7);
      doc.setTextColor(...PDF_THEME.textMuted);
      doc.text(item.label.toUpperCase(), x + 14, y + 20);

      // Value
      doc.setFont("helvetica", "bold");
      doc.setFontSize(18);
      doc.setTextColor(...PDF_THEME.text);
      doc.text(String(item.value), x + 14, y + 46);
    });

    curY += 2 * cardH + cardGap + 18;

    // ── DETAILED DATA LABEL ───────────────────────────────────────────
    doc.setFont("helvetica", "bold");
    doc.setFontSize(7.5);
    doc.setTextColor(...PDF_THEME.textMuted);
    doc.text("DETAILED DATA", margin, curY);
    doc.setDrawColor(...reportTheme.accent);
    doc.setLineWidth(1.5);
    doc.line(margin + doc.getTextWidth("DETAILED DATA") + 6, curY - 2, margin + doc.getTextWidth("DETAILED DATA") + 32, curY - 2);
    curY += 10;

    // ── TABLE ─────────────────────────────────────────────────────────
    autoTable(doc, {
      startY: curY,
      head: [cols.map((c) => c[1])],
      body: rows.map((row) => cols.map((c) => fmt(row[c[0]], c[2]))),
      theme: "plain",
      styles: {
        fontSize: 8.5,
        cellPadding: { top: 7, right: 10, bottom: 7, left: 10 },
        overflow: "linebreak",
        textColor: PDF_THEME.text,
        font: "helvetica",
        lineColor: PDF_THEME.divider,
        lineWidth: 0.5,
      },
      headStyles: {
        fillColor: PDF_THEME.tableHeader,
        textColor: PDF_THEME.textMuted,
        fontStyle: "bold",
        halign: "left",
        fontSize: 7.5,
        cellPadding: { top: 9, right: 10, bottom: 9, left: 10 },
        lineColor: PDF_THEME.border,
        lineWidth: 0.6,
      },
      bodyStyles: {
        fillColor: PDF_THEME.white,
      },
      alternateRowStyles: {
        fillColor: PDF_THEME.tableBg,
      },
      columnStyles: Object.fromEntries(cols.map((_c, i) => [i, { cellWidth: "auto" }])),
      margin: { left: margin, right: margin, top: 40, bottom: 52 },
      // ── FOOTER ────────────────────────────────────────────────────
      didDrawPage: (data) => {
        // Thin 2-tone footer rule
        doc.setDrawColor(...PDF_THEME.accentOrange);
        doc.setLineWidth(1.2);
        doc.line(margin, pageH - 36, pageW / 2, pageH - 36);
        doc.setDrawColor(...PDF_THEME.accentPink);
        doc.line(pageW / 2, pageH - 36, pageW - margin, pageH - 36);

        doc.setFont("helvetica", "normal");
        doc.setFontSize(7.5);
        doc.setTextColor(...PDF_THEME.textLight);
        doc.text("B SMART · Vendor Analytics", margin, pageH - 22);
        doc.text(`${rows.length} rows`, pageW / 2, pageH - 22, { align: "center" });
        doc.setFont("helvetica", "bold");
        doc.setTextColor(...reportTheme.accent);
        doc.text(`Page ${data.pageNumber}`, pageW - margin, pageH - 22, { align: "right" });
      },
    });

    const safeName = (currentReport?.label || "report").toLowerCase().replace(/\s+/g, "_");
    doc.save(`bsmart_${safeName}.pdf`);
    setExportMsg("PDF downloaded successfully.");
    setTimeout(() => setExportMsg(""), 2500);
  };

  const clearFilters = () => {
    setDatePreset("30d");
    setStartDate("");
    setEndDate("");
    setSelectedAd("all");
    setCountry("all");
    setLanguage("all");
    setGender("all");
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black">
      <div className="mx-auto max-w-7xl space-y-6 p-4 md:p-8">
        <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-center">
          <div>
            <h1 className="text-2xl font-extrabold tracking-tight md:text-3xl"><span className="bg-gradient-to-r from-orange-500 via-red-500 to-pink-600 bg-clip-text text-transparent">Reports & Analytics</span></h1>
            <p className="mt-1 text-sm text-gray-500 dark:text-gray-400">Vendor analytics is now wired to live report APIs.</p>
          </div>
          <div className="flex flex-wrap gap-2">
            <button onClick={exportPdf} className="flex items-center gap-1.5 rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-xs font-bold text-gray-700 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200"><Download size={13} /> Download PDF</button>
            <button onClick={exportCsv} className="flex items-center gap-1.5 rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-xs font-bold text-gray-700 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200"><FileDown size={13} /> Export CSV</button>
            <button className="flex items-center gap-1.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 px-3.5 py-2 text-xs font-bold text-white"><Send size={13} /> Schedule Email</button>
          </div>
        </div>

        {exportMsg ? <div className="flex items-center gap-2 rounded-xl border border-green-200 bg-green-50 px-4 py-3 text-sm font-semibold text-green-700 dark:border-green-800 dark:bg-green-900/20 dark:text-green-400"><CheckCircle2 size={15} /> {exportMsg}</div> : null}
        {summaryError ? <div className="flex items-center gap-2 rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm font-semibold text-red-700 dark:border-red-800 dark:bg-red-900/20 dark:text-red-400"><AlertCircle size={15} /> {summaryError}</div> : null}

        <div className="rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900">
          <div className="flex items-center justify-between border-b border-gray-50 px-4 py-3.5 dark:border-gray-800">
            <div className="flex items-center gap-2"><Filter size={14} className="text-gray-500" /><span className="text-sm font-bold text-gray-900 dark:text-white">Filters</span></div>
            <div className="flex items-center gap-3">
              <button onClick={clearFilters} className="text-[11px] font-semibold text-pink-500">Clear all</button>
              <button onClick={() => setShowFilters((v) => !v)} className="rounded-xl border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs font-semibold text-gray-500 dark:border-gray-700 dark:bg-gray-800 md:hidden">Toggle</button>
            </div>
          </div>
          <div className={`${showFilters ? "block" : "hidden"} p-4 md:block md:p-5`}>
            <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-6">
              <div className="col-span-2 md:col-span-1 lg:col-span-2"><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">Date Range</label><Select value={datePreset} onChange={setDatePreset} options={PRESETS} icon={Calendar} /></div>
              {datePreset === "custom" ? (
                <div className="col-span-2 grid grid-cols-2 gap-2">
                  <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">From</label><input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className="w-full rounded-xl border border-gray-200 bg-white px-3 py-2.5 text-sm dark:border-gray-700 dark:bg-gray-900" /></div>
                  <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">To</label><input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className="w-full rounded-xl border border-gray-200 bg-white px-3 py-2.5 text-sm dark:border-gray-700 dark:bg-gray-900" /></div>
                </div>
              ) : null}
              <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">Ad</label><Select value={selectedAd} onChange={setSelectedAd} options={adOptions} icon={Target} /></div>
              <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">Country</label><Select value={country} onChange={setCountry} options={[{ value: "all", label: "All Countries" }, { value: "India", label: "India" }, { value: "United States", label: "United States" }, { value: "United Kingdom", label: "United Kingdom" }, { value: "UAE", label: "UAE" }, { value: "Singapore", label: "Singapore" }]} icon={Globe} /></div>
              <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">Language</label><Select value={language} onChange={setLanguage} options={[{ value: "all", label: "All Languages" }, { value: "English", label: "English" }, { value: "Hindi", label: "Hindi" }, { value: "Tamil", label: "Tamil" }, { value: "Telugu", label: "Telugu" }]} icon={Search} /></div>
              <div><label className="mb-1.5 block text-[9px] font-black uppercase tracking-widest text-gray-400">Gender</label><Select value={gender} onChange={setGender} options={[{ value: "all", label: "All Genders" }, { value: "male", label: "Male" }, { value: "female", label: "Female" }, { value: "other", label: "Other" }]} icon={Users} /></div>
            </div>
          </div>
        </div>

        <div>
          <p className="mb-3 text-[10px] font-black uppercase tracking-widest text-gray-400">Overview</p>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
            {SUMMARY_CARDS.map((card) => {
              const Icon = card.icon;
              return (
                <div key={card.key} className="rounded-2xl border border-gray-100 bg-white p-4 dark:border-gray-800 dark:bg-gray-900">
                  <div className={`mb-3 flex h-9 w-9 items-center justify-center rounded-xl ${card.tone}`}><Icon size={16} /></div>
                  {summaryLoading ? <div className="h-7 w-20 animate-pulse rounded-lg bg-gray-100 dark:bg-gray-800" /> : <div className="text-xl font-black text-gray-900 dark:text-white">{fmt(summary[card.key], card.kind)}</div>}
                  <div className="mt-0.5 text-xs text-gray-500 dark:text-gray-400">{card.label}</div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="grid grid-cols-1 gap-5 lg:grid-cols-4">
          <div className="space-y-2 lg:col-span-1">
            {REPORTS.map((report) => {
              const Icon = report.icon;
              const active = selectedReport === report.id;
              return (
                <button key={report.id} onClick={() => setSelectedReport(report.id)} className={`w-full rounded-2xl border-2 p-4 text-left transition-all ${active ? "border-pink-500 bg-gradient-to-r from-orange-500 to-pink-600 text-white" : "border-gray-100 bg-white dark:border-gray-800 dark:bg-gray-900"}`}>
                  <div className="flex items-center gap-3">
                    <div className={`flex h-9 w-9 items-center justify-center rounded-xl ${active ? "bg-white/20" : report.bg}`}><Icon size={16} className={active ? "text-white" : report.color} /></div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-sm font-bold">{report.label}</div>
                      <div className={`truncate text-[11px] ${active ? "text-white/75" : "text-gray-400"}`}>{report.desc}</div>
                    </div>
                  </div>
                </button>
              );
            })}
          </div>

          <div className="overflow-hidden rounded-2xl border border-gray-100 bg-white shadow-sm dark:border-gray-800 dark:bg-gray-900 lg:col-span-3">
            <div className="flex items-center justify-between border-b border-gray-100 px-5 py-4 dark:border-gray-800">
                <div className="flex items-center gap-3">
                  <div className={`flex h-9 w-9 items-center justify-center rounded-xl ${currentReport?.bg ?? ""}`}>
                    {currentReport ? <currentReport.icon size={16} className={currentReport.color} /> : null}
                  </div>
                  <div>
                    <h2 className="text-sm font-bold text-gray-900 dark:text-white">{currentReport?.label}</h2>
                    <p className="mt-0.5 text-[11px] text-gray-400">{currentReport?.desc}</p>
                  </div>
                </div>
                {/* Column chips */}
                <div className="hidden items-center gap-1.5 sm:flex">
                  {(COLUMNS[selectedReport] || []).slice(0, 3).map((col) => (
                    <span key={col[0]} className="rounded-lg border border-gray-200 bg-gray-50 px-2.5 py-1 text-[10px] font-bold uppercase tracking-wide text-gray-500 dark:border-gray-700 dark:bg-gray-800 dark:text-gray-400">
                      {col[1]}
                    </span>
                  ))}
                  {(COLUMNS[selectedReport] || []).length > 3 && (
                    <span className="rounded-lg border border-gray-200 bg-gray-50 px-2.5 py-1 text-[10px] font-bold text-gray-400 dark:border-gray-700 dark:bg-gray-800">
                      +{(COLUMNS[selectedReport] || []).length - 3} more
                    </span>
                  )}
                </div>
            </div>

            {selectedReport === "financial" && financialMeta?.summary ? (
              <div className="grid grid-cols-2 gap-3 border-b border-gray-100 bg-gray-50/50 px-5 py-4 dark:border-gray-800 dark:bg-gray-800/30 md:grid-cols-4">
                <div>
                  <div className="text-[10px] font-black uppercase tracking-wider text-gray-400">Wallet Balance</div>
                  <div className="mt-1 text-sm font-bold text-gray-900 dark:text-white">{fmt(financialMeta.wallet?.balance)}</div>
                </div>
                <div>
                  <div className="text-[10px] font-black uppercase tracking-wider text-gray-400">Total Credited</div>
                  <div className="mt-1 text-sm font-bold text-gray-900 dark:text-white">{fmt(financialMeta.summary.total_credited)}</div>
                </div>
                <div>
                  <div className="text-[10px] font-black uppercase tracking-wider text-gray-400">Total Debited</div>
                  <div className="mt-1 text-sm font-bold text-gray-900 dark:text-white">{fmt(financialMeta.summary.total_debited)}</div>
                </div>
                <div>
                  <div className="text-[10px] font-black uppercase tracking-wider text-gray-400">Transactions</div>
                  <div className="mt-1 text-sm font-bold text-gray-900 dark:text-white">{fmt(financialMeta.summary.total_transactions)}</div>
                </div>
              </div>
            ) : null}

            {reportLoading ? (
              <div className="flex flex-col items-center gap-3 py-12"><Loader2 className="h-8 w-8 animate-spin text-pink-500" /><span className="text-sm text-gray-400">Loading report data...</span></div>
            ) : reportUnavailable ? (
              <div className="flex flex-col items-center gap-3 py-12 text-center"><AlertCircle className="h-8 w-8 text-gray-300" /><p className="text-sm font-semibold text-gray-500 dark:text-gray-300">This report API is not available yet on the backend.</p></div>
            ) : reportError ? (
              <div className="flex flex-col items-center gap-3 py-12 text-center"><AlertCircle className="h-8 w-8 text-red-300" /><p className="text-sm font-semibold text-red-600 dark:text-red-400">{reportError}</p></div>
            ) : rows.length === 0 ? (
              <div className="flex flex-col items-center gap-3 py-12 text-center"><BarChart2 className="h-8 w-8 text-gray-300" /><p className="text-sm font-semibold text-gray-500 dark:text-gray-300">No data for the selected filters.</p></div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-left">
                  <thead>
                    <tr className="border-b border-gray-100 bg-gray-50 dark:border-gray-800 dark:bg-gray-800/50">
                      {(COLUMNS[selectedReport] || []).map((col) => <th key={col[0]} className="px-4 py-3 text-[10px] font-black uppercase tracking-wider text-gray-400">{col[1]}</th>)}
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                    {rows.slice((tablePage - 1) * TABLE_PAGE_SIZE, tablePage * TABLE_PAGE_SIZE).map((row, idx) => (
                      <tr key={`${selectedReport}-${idx}`} className="hover:bg-gray-50 dark:hover:bg-gray-800/40">
                        {(COLUMNS[selectedReport] || []).map((col) => <td key={col[0]} className="px-4 py-3 text-sm text-gray-700 dark:text-gray-300">{fmt(row[col[0]], col[2])}</td>)}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}

            {!reportLoading && rows.length > 0 ? (() => {
              const totalPages = Math.ceil(rows.length / TABLE_PAGE_SIZE);
              const showPagination = rows.length > TABLE_PAGE_SIZE;
              return (
                <>
                  {showPagination && (
                    <div className="flex items-center justify-between border-t border-gray-100 bg-gray-50/50 px-5 py-3 dark:border-gray-800 dark:bg-gray-800/30">
                      <div className="flex items-center gap-1">
                        {/* First */}
                        <button
                          onClick={() => setTablePage(1)}
                          disabled={tablePage === 1}
                          className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 bg-white text-xs font-bold text-gray-500 transition-all hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-30 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
                        >«</button>
                        {/* Prev */}
                        <button
                          onClick={() => setTablePage(p => Math.max(1, p - 1))}
                          disabled={tablePage === 1}
                          className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 bg-white text-xs font-bold text-gray-500 transition-all hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-30 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
                        >‹</button>

                        {/* Page numbers with ellipsis */}
                        {Array.from({ length: totalPages }, (_, i) => i + 1)
                          .filter(p => p === 1 || p === totalPages || Math.abs(p - tablePage) <= 1)
                          .reduce((acc, p, i, arr) => {
                            if (i > 0 && p - arr[i - 1] > 1) acc.push('…');
                            acc.push(p);
                            return acc;
                          }, [])
                          .map((item, i) =>
                            typeof item === 'string' ? (
                              <span key={`e${i}`} className="flex h-8 w-6 items-center justify-center text-xs text-gray-400">…</span>
                            ) : (
                              <button
                                key={item}
                                onClick={() => setTablePage(item)}
                                className={`flex h-8 w-8 items-center justify-center rounded-lg text-xs font-bold transition-all ${
                                  tablePage === item
                                    ? 'bg-gradient-to-r from-orange-500 to-pink-600 text-white shadow-sm'
                                    : 'border border-gray-200 bg-white text-gray-600 hover:bg-gray-100 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800'
                                }`}
                              >{item}</button>
                            )
                          )
                        }

                        {/* Next */}
                        <button
                          onClick={() => setTablePage(p => Math.min(totalPages, p + 1))}
                          disabled={tablePage === totalPages}
                          className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 bg-white text-xs font-bold text-gray-500 transition-all hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-30 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
                        >›</button>
                        {/* Last */}
                        <button
                          onClick={() => setTablePage(totalPages)}
                          disabled={tablePage === totalPages}
                          className="flex h-8 w-8 items-center justify-center rounded-lg border border-gray-200 bg-white text-xs font-bold text-gray-500 transition-all hover:bg-gray-100 disabled:cursor-not-allowed disabled:opacity-30 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-400 dark:hover:bg-gray-800"
                        >»</button>
                      </div>
                      <span className="text-xs text-gray-400 tabular-nums">
                        Page {tablePage} / {totalPages} · {rows.length} total rows
                      </span>
                    </div>
                  )}

                  {/* Footer row */}
                  <div className="flex items-center justify-between border-t border-gray-50 bg-gray-50/50 px-5 py-3.5 dark:border-gray-800 dark:bg-gray-800/30">
                    <p className="text-xs text-gray-400">
                      {showPagination
                        ? `Showing ${(tablePage - 1) * TABLE_PAGE_SIZE + 1}–${Math.min(tablePage * TABLE_PAGE_SIZE, rows.length)} of ${rows.length} rows · ${PRESETS.find((p) => p.value === datePreset)?.label ?? "Custom range"}`
                        : `${rows.length} rows · ${PRESETS.find((p) => p.value === datePreset)?.label ?? "Custom range"}`
                      }
                    </p>
                    <div className="flex items-center gap-2">
                      <button onClick={exportCsv} className="flex items-center gap-1.5 rounded-xl border border-gray-200 bg-white px-3.5 py-2 text-xs font-bold text-gray-700 dark:border-gray-700 dark:bg-gray-900 dark:text-gray-200"><FileDown size={12} /> Export CSV</button>
                      <button onClick={exportPdf} className="flex items-center gap-1.5 rounded-xl bg-gradient-to-r from-orange-500 to-pink-600 px-3.5 py-2 text-xs font-bold text-white"><Download size={12} /> Download PDF</button>
                    </div>
                  </div>
                </>
              );
            })() : null}
          </div>
        </div>
      </div>
    </div>
  );
}