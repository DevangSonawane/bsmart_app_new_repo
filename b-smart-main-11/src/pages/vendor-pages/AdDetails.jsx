import { useParams, useNavigate } from "react-router-dom";
import { useState, useEffect, useCallback, useRef } from "react";
import api from "../../lib/api";
import {
  ArrowLeft, CheckCircle, BarChart2, Users, MessageCircle,
  ThumbsDown, Clock, Eye, MapPin, Globe, Tag,
  Film, Hash, Building2, Coins, Heart, AlertCircle,
  ChevronDown, ChevronUp, RefreshCw, ArrowDownLeft, ArrowUpRight,
  ChevronLeft, ChevronRight, Wallet, TrendingUp, TrendingDown,
  Activity, UserCheck, BarChart, PieChart as PieIcon, MapPinned,
  Venus, Mars, Transgender,
  MousePointerClick, Target, Smartphone, Monitor, Calendar,
  Megaphone, ShieldCheck, TestTube2, CalendarClock, Zap,
  Link2, Phone, Mail, MessageSquare, Layers
} from "lucide-react";
import {
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from "recharts";

// ─── Age Breakdown Pie Charts (Chart.js) ──────────────────────────────────────

const AGE_LABELS_SHORT = ["Child", "Teen", "Adult", "Middle age", "Senior", "Unknown"];
const AGE_KEYS = [
  "Child (0–12 years)",
  "Teen (13–19 years)",
  "Adult (20–39 years)",
  "Middle Age (40–59 years)",
  "Senior (60+ years)",
  "Unknown",
];
const AGE_COLORS = ["#378ADD", "#1D9E75", "#7F77DD", "#D4537E", "#EF9F27", "#888780"];

const AgeBreakdownCharts = ({ stats }) => {
  const viewsAge    = stats?.views?.by_age    || {};
  const likesAge    = stats?.likes?.by_age    || {};
  const dislikesAge = stats?.dislikes?.by_age || {};

  const toData = (obj) => AGE_KEYS.map(k => obj[k] ?? 0);

  const charts = [
    { id: "agePieViews",    label: "Views by age",    data: toData(viewsAge)    },
    { id: "agePieLikes",    label: "Likes by age",    data: toData(likesAge)    },
    { id: "agePieDislikes", label: "Dislikes by age", data: toData(dislikesAge) },
  ];

  // Inject Chart.js once
  useEffect(() => {
    if (window.__chartJsLoaded) {
      renderCharts(charts);
      return;
    }
    const script = document.createElement("script");
    script.src = "https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js";
    script.onload = () => {
      window.__chartJsLoaded = true;
      renderCharts(charts);
    };
    document.head.appendChild(script);
    return () => {
      charts.forEach(c => {
        const inst = window.__ageCharts?.[c.id];
        if (inst) { inst.destroy(); delete window.__ageCharts[c.id]; }
      });
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [JSON.stringify({ viewsAge, likesAge, dislikesAge })]);

  const renderCharts = (chartList) => {
    if (!window.Chart) return;
    window.__ageCharts = window.__ageCharts || {};
    chartList.forEach(({ id, data }) => {
      const canvas = document.getElementById(id);
      if (!canvas) return;
      if (window.__ageCharts[id]) { window.__ageCharts[id].destroy(); }
      const total = data.reduce((a, b) => a + b, 0);
      window.__ageCharts[id] = new window.Chart(canvas, {
        type: "pie",
        data: {
          labels: AGE_LABELS_SHORT.map((l, i) => `${l} (${data[i]})`),
          datasets: [{
            data,
            backgroundColor: AGE_COLORS,
            borderColor: "transparent",
            borderWidth: 0,
            hoverOffset: 6,
          }],
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false },
            tooltip: {
              callbacks: {
                label: (ctx) => {
                  const val = ctx.parsed;
                  const pct = total > 0 ? Math.round((val / total) * 100) : 0;
                  return ` ${val} (${pct}%)`;
                },
              },
            },
          },
        },
      });
    });
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm p-6">
      <h3 className="text-base font-bold text-gray-900 dark:text-white mb-1 flex items-center gap-2">
        <BarChart className="w-4 h-4 text-purple-500" />
        Age Breakdown
      </h3>
      <p className="text-xs text-gray-400 mb-6">Views, likes and dislikes split across age groups</p>

      {/* Color legend */}
      <div className="flex flex-wrap gap-x-4 gap-y-2 mb-6">
        {AGE_LABELS_SHORT.map((lbl, i) => (
          <span key={lbl} className="flex items-center gap-1.5 text-xs text-gray-500 dark:text-gray-400">
            <span className="w-2.5 h-2.5 rounded-sm flex-shrink-0" style={{ backgroundColor: AGE_COLORS[i] }} />
            {lbl}
          </span>
        ))}
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
        {charts.map(({ id, label, data }) => {
          const total = data.reduce((a, b) => a + b, 0);
          const dominant = data.indexOf(Math.max(...data));
          return (
            <div key={id} className="flex flex-col items-center">
              <p className="text-xs font-bold uppercase tracking-wider text-gray-400 mb-3">{label}</p>
              {/* Dominant badge */}
              {total > 0 && (
                <div className="mb-3 px-3 py-1 rounded-full text-[11px] font-bold" style={{ backgroundColor: AGE_COLORS[dominant] + "22", color: AGE_COLORS[dominant] }}>
                  Top: {AGE_LABELS_SHORT[dominant]} · {Math.round((data[dominant] / total) * 100)}%
                </div>
              )}
              <div style={{ position: "relative", width: "100%", height: "200px" }}>
                <canvas id={id} />
              </div>
              {/* Per-slice mini legend */}
              <div className="mt-4 w-full space-y-1.5">
                {data.map((val, i) => {
                  if (val === 0) return null;
                  const pct = total > 0 ? Math.round((val / total) * 100) : 0;
                  return (
                    <div key={i} className="flex items-center gap-2">
                      <span className="w-2 h-2 rounded-sm flex-shrink-0" style={{ backgroundColor: AGE_COLORS[i] }} />
                      <span className="text-[11px] text-gray-500 dark:text-gray-400 flex-1 truncate">{AGE_LABELS_SHORT[i]}</span>
                      <span className="text-[11px] font-bold text-gray-700 dark:text-gray-200">{val}</span>
                      <span className="text-[10px] text-gray-400 w-7 text-right">{pct}%</span>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
};

// ─── World map helpers (no external lib needed) ───────────────────────────────
// We fetch topoJSON from CDN and convert to SVG paths using a tiny built-in projection
const GEO_URL = "https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json";

// ─── Reusable Components ──────────────────────────────────────────────────────

const Badge = ({ status }) => {
  const styles = {
    active:    "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400 border-green-200 dark:border-green-800",
    paused:    "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400 border-amber-200 dark:border-amber-800",
    completed: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400 border-blue-200 dark:border-blue-800",
    draft:     "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-400 border-gray-200 dark:border-gray-700",
    rejected:  "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400 border-red-200 dark:border-red-800",
    pending:   "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400 border-yellow-200 dark:border-yellow-800",
  };
  return (
    <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${styles[(status || "").toLowerCase()] || styles.draft}`}>
      {status || "Unknown"}
    </span>
  );
};

const Card = ({ title, children, className = "", action, icon: Icon }) => (
  <div className={`bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm ${className}`}>
    {title && (
      <div className="flex justify-between items-center mb-5">
        <h3 className="text-base font-bold text-gray-900 dark:text-white flex items-center gap-2">
          {Icon && <Icon className="w-4 h-4 text-pink-500" />}
          {title}
        </h3>
        {action}
      </div>
    )}
    {children}
  </div>
);

const StatCard = ({ label, value, color = "blue", icon: Icon }) => {
  const colors = {
    blue:   "bg-blue-50 text-blue-600 dark:bg-blue-900/20 dark:text-blue-400",
    purple: "bg-purple-50 text-purple-600 dark:bg-purple-900/20 dark:text-purple-400",
    pink:   "bg-pink-50 text-pink-600 dark:bg-pink-900/20 dark:text-pink-400",
    orange: "bg-orange-50 text-orange-600 dark:bg-orange-900/20 dark:text-orange-400",
    green:  "bg-green-50 text-green-600 dark:bg-green-900/20 dark:text-green-400",
    red:    "bg-red-50 text-red-600 dark:bg-red-900/20 dark:text-red-400",
  };
  return (
    <div className="p-4 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 hover:shadow-md transition-shadow">
      <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-3 ${colors[color]}`}>
        <Icon className="w-5 h-5" />
      </div>
      <div className="text-2xl font-bold text-gray-900 dark:text-white mb-0.5">{value}</div>
      <div className="text-xs font-medium text-gray-500 dark:text-gray-400">{label}</div>
    </div>
  );
};

const InfoRow = ({ icon: Icon, label, value, mono = false }) => (
  <div className="flex items-start justify-between gap-4 py-3 border-b border-gray-100 dark:border-gray-800 last:border-0">
    <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide min-w-[130px] flex-shrink-0">
      <Icon className="w-3.5 h-3.5 flex-shrink-0" />
      {label}
    </div>
    <div className={`text-sm font-semibold text-gray-800 dark:text-gray-200 text-right break-all ${mono ? "font-mono text-xs" : ""}`}>
      {value ?? "—"}
    </div>
  </div>
);

const TagList = ({ items, color = "blue" }) => {
  const colors = {
    blue:   "bg-blue-50 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300",
    purple: "bg-purple-50 text-purple-700 dark:bg-purple-900/20 dark:text-purple-300",
    green:  "bg-green-50 text-green-700 dark:bg-green-900/20 dark:text-green-300",
  };
  if (!items || items.length === 0)
    return <span className="text-sm text-gray-400 italic">None</span>;
  return (
    <div className="flex flex-wrap gap-2">
      {items.map((item, i) => (
        <span key={i} className={`px-2.5 py-1 rounded-full text-xs font-semibold ${colors[color]}`}>
          {item}
        </span>
      ))}
    </div>
  );
};

const Avatar = ({ name, url, size = "w-8 h-8", textSize = "text-xs" }) => {
  const initials = (name || "U").split(" ").map(w => w[0]).slice(0, 2).join("").toUpperCase();
  if (url) {
    return (
      <img src={url} alt={name} className={`${size} rounded-full object-cover flex-shrink-0`}
        onError={e => { e.target.style.display = "none"; }} />
    );
  }
  return (
    <div className={`${size} rounded-full bg-gradient-to-br from-purple-500 to-indigo-500 flex items-center justify-center text-white ${textSize} font-bold flex-shrink-0`}>
      {initials}
    </div>
  );
};

// ─── Comment Item with Replies ────────────────────────────────────────────────

const CommentItem = ({ comment }) => {
  const [showReplies, setShowReplies]       = useState(false);
  const [replies, setReplies]               = useState([]);
  const [loadingReplies, setLoadingReplies] = useState(false);
  const [repliesFetched, setRepliesFetched] = useState(false);

  const toggleReplies = useCallback(async () => {
    if (repliesFetched) { setShowReplies(v => !v); return; }
    const fetchReplies = async () => {
      setLoadingReplies(true);
      try {
        const res = await api.get(`/ads/comments/${comment._id}/replies`);
        const data = Array.isArray(res.data) ? res.data : res.data?.replies || res.data?.data || [];
        setReplies(data);
        setRepliesFetched(true);
        setShowReplies(true);
      } catch (err) { console.error("Failed to fetch replies", err); }
      finally { setLoadingReplies(false); }
    };
    fetchReplies();
  }, [comment._id, repliesFetched]);

  const replyCount = comment.replies_count || comment.repliesCount || 0;
  const user       = comment.user_id || comment.user || {};
  const userName   = user.full_name || user.username || "User";
  const timeAgo    = comment.createdAt
    ? new Date(comment.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" }) : "";

  return (
    <div className="space-y-2">
      <div className="flex gap-3 items-start p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
        <Avatar name={userName} url={user.avatar_url || ""} />
        <div className="flex-1 min-w-0">
          <div className="flex justify-between items-center gap-2 mb-1">
            <span className="text-sm font-bold text-gray-900 dark:text-white truncate">{userName}</span>
            <span className="text-[10px] text-gray-400 whitespace-nowrap flex-shrink-0">{timeAgo}</span>
          </div>
          <p className="text-xs text-gray-600 dark:text-gray-300 leading-relaxed">
            {comment.text || comment.content || comment.comment || ""}
          </p>
          {replyCount > 0 && (
            <button onClick={toggleReplies} disabled={loadingReplies}
              className="mt-2 inline-flex items-center gap-1.5 text-[11px] font-semibold text-blue-600 dark:text-blue-400 hover:text-blue-700 transition-colors"
            >
              {loadingReplies ? <RefreshCw className="w-3 h-3 animate-spin" />
               : showReplies ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
              {showReplies ? "Hide replies" : `${replyCount} ${replyCount === 1 ? "reply" : "replies"}`}
            </button>
          )}
        </div>
      </div>
      {showReplies && replies.length > 0 && (
        <div className="ml-10 space-y-2">
          {replies.map((reply, idx) => {
            const rUser = reply.user_id || reply.user || {};
            const rName = rUser.full_name || rUser.username || "User";
            const rTime = reply.createdAt ? new Date(reply.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" }) : "";
            return (
              <div key={reply._id || idx} className="flex gap-2 items-start p-2.5 rounded-xl bg-blue-50/50 dark:bg-blue-900/10 border border-blue-100 dark:border-blue-900/30">
                <Avatar name={rName} url={rUser.avatar_url || ""} size="w-6 h-6" textSize="text-[10px]" />
                <div className="flex-1 min-w-0">
                  <div className="flex justify-between items-center gap-2 mb-0.5">
                    <span className="text-xs font-bold text-gray-900 dark:text-white truncate">{rName}</span>
                    <span className="text-[10px] text-gray-400 whitespace-nowrap">{rTime}</span>
                  </div>
                  <p className="text-xs text-gray-600 dark:text-gray-300 leading-relaxed">
                    {reply.text || reply.content || reply.comment || ""}
                  </p>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};

// ─── Gender Colors & Config ────────────────────────────────────────────────────

const GENDER_COLORS = {
  male:    "#3b82f6",
  female:  "#ec4899",
  other:   "#8b5cf6",
  unknown: "#9ca3af",
};

const GENDER_CONFIG = {
  male:   { label: "Male",   Icon: Mars,        gradient: "from-blue-500 to-cyan-400",   bg: "bg-blue-500/10",   text: "text-blue-400",   border: "border-blue-500/20"   },
  female: { label: "Female", Icon: Venus,       gradient: "from-pink-500 to-rose-400",   bg: "bg-pink-500/10",   text: "text-pink-400",   border: "border-pink-500/20"   },
  other:  { label: "Other",  Icon: Transgender, gradient: "from-purple-500 to-violet-400", bg: "bg-purple-500/10", text: "text-purple-400", border: "border-purple-500/20" },
};

// ─── Gender Donut Ring (SVG) ───────────────────────────────────────────────────

const GenderRing = ({ data, total }) => {
  const radius = 52;
  const circ   = 2 * Math.PI * radius;
  let offset   = 0;
  const segments = Object.entries(data)
    .filter(([, v]) => v > 0)
    .map(([key, val]) => {
      const color = GENDER_COLORS[key] || GENDER_COLORS.unknown;
      const dash  = (val / (total || 1)) * circ;
      const seg   = { key, val, color, dash, offset };
      offset += dash;
      return seg;
    });

  return (
    <svg viewBox="0 0 120 120" className="w-full h-full" style={{ transform: "rotate(-90deg)" }}>
      <circle cx="60" cy="60" r={radius} fill="none" stroke="currentColor" strokeWidth="14" className="text-gray-100 dark:text-gray-800" />
      {segments.map((seg) => (
        <circle
          key={seg.key}
          cx="60" cy="60" r={radius}
          fill="none"
          stroke={seg.color}
          strokeWidth="14"
          strokeDasharray={`${seg.dash} ${circ}`}
          strokeDashoffset={-seg.offset}
          strokeLinecap="round"
          style={{ transition: "stroke-dasharray 1.2s ease" }}
        />
      ))}
    </svg>
  );
};

// ─── Gender Analytics Section ─────────────────────────────────────────────────

const GenderAnalyticsSection = ({ genderData }) => {
  const total = Object.values(genderData).reduce((s, v) => s + v, 0);
  const fmt   = (n) => n >= 1000 ? `${(n / 1000).toFixed(1)}K` : String(n);
  const pct   = (v) => total > 0 ? Math.round((v / total) * 100) : 0;

  return (
    // <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 p-6 shadow-sm">
    //   {/* Header */}
    //   <div className="flex items-center gap-3 mb-6">
    //     <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-pink-500 to-purple-600 flex items-center justify-center">
    //       <Users className="w-4 h-4 text-white" />
    //     </div>
    //     <div>
    //       <h3 className="text-base font-bold text-gray-900 dark:text-white">Audience Gender</h3>
    //       <p className="text-xs text-gray-500 dark:text-gray-400">Viewer demographics breakdown</p>
    //     </div>
    //     <div className="ml-auto text-right">
    //       <div className="text-xl font-black text-gray-900 dark:text-white">{fmt(total)}</div>
    //       <div className="text-[10px] font-bold uppercase tracking-wider text-gray-400">Total Viewers</div>
    //     </div>
    //   </div>

    //   {total === 0 ? (
    //     <div className="flex flex-col items-center justify-center py-10 gap-3">
    //       <div className="w-14 h-14 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
    //         <Users className="w-7 h-7 text-gray-300 dark:text-gray-600" />
    //       </div>
    //       <p className="text-sm font-medium text-gray-400">No gender data available yet</p>
    //     </div>
    //   ) : (
    //     <>
    //       {/* Ring + Bars Row */}
    //       <div className="flex flex-col sm:flex-row items-center gap-6 mb-6">
    //         {/* Donut */}
    //         <div className="relative w-36 h-36 flex-shrink-0">
    //           <GenderRing data={genderData} total={total} />
    //           <div className="absolute inset-0 flex flex-col items-center justify-center">
    //             <span className="text-2xl font-black text-gray-900 dark:text-white">{fmt(total)}</span>
    //             <span className="text-[10px] font-bold uppercase tracking-wider text-gray-400">Total</span>
    //           </div>
    //         </div>

    //         {/* Progress bars */}
    //         <div className="flex-1 w-full space-y-3">
    //           {Object.entries(GENDER_CONFIG).map(([key, cfg]) => {
    //             const val  = genderData[key] || 0;
    //             const p    = pct(val);
    //             const Icon = cfg.Icon;
    //             return (
    //               <div key={key}>
    //                 <div className="flex items-center justify-between mb-1.5">
    //                   <div className="flex items-center gap-1.5">
    //                     <Icon className={`w-3.5 h-3.5 ${cfg.text}`} />
    //                     <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">{cfg.label}</span>
    //                   </div>
    //                   <div className="flex items-center gap-2">
    //                     <span className="text-xs font-bold text-gray-900 dark:text-white">{fmt(val)}</span>
    //                     <span className={`text-[10px] font-bold ${cfg.text} ${cfg.bg} px-1.5 py-0.5 rounded-full`}>{p}%</span>
    //                   </div>
    //                 </div>
    //                 <div className="h-2 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
    //                   <div
    //                     className={`h-full rounded-full bg-gradient-to-r ${cfg.gradient} transition-all duration-1000`}
    //                     style={{ width: `${p}%` }}
    //                   />
    //                 </div>
    //               </div>
    //             );
    //           })}
    //         </div>
    //       </div>

    //       {/* Summary pill cards */}
    //       <div className="grid grid-cols-3 gap-3">
    //         {Object.entries(GENDER_CONFIG).map(([key, cfg]) => {
    //           const val  = genderData[key] || 0;
    //           const p    = pct(val);
    //           const Icon = cfg.Icon;
    //           return (
    //             <div key={key} className={`rounded-2xl p-4 ${cfg.bg} border ${cfg.border} flex flex-col items-center gap-1.5`}>
    //               <Icon className={`w-5 h-5 ${cfg.text}`} />
    //               <div className={`text-xl font-black ${cfg.text}`}>{p}%</div>
    //               <div className="text-[10px] font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wide">{cfg.label}</div>
    //               <div className="text-xs font-semibold text-gray-600 dark:text-gray-400">{fmt(val)} viewers</div>
    //             </div>
    //           );
    //         })}
    //       </div>
    //     </>
    //   )}
    // </div>
    <></>
  );
};

// ─── Pure SVG World Map ── zero external deps, pure fetch + inline topoJSON decode ──

// Mercator projection (pure JS)
function mercatorProject(lon, lat, W, H) {
  const x      = ((lon + 180) / 360) * W;
  const latRad = (lat * Math.PI) / 180;
  const mercN  = Math.log(Math.tan(Math.PI / 4 + latRad / 2));
  const y      = H / 2 - (W * mercN) / (2 * Math.PI);
  return [x, y];
}

// Decode a TopoJSON delta-encoded arc → absolute quantized coords
function decodeArc(arc) {
  let x = 0, y = 0;
  return arc.map(([dx, dy]) => { x += dx; y += dy; return [x, y]; });
}

// Transform quantized → longitude/latitude using topo.transform
function transformPoint([qx, qy], { scale: [sx, sy], translate: [tx, ty] }) {
  return [qx * sx + tx, qy * sy + ty];
}

// Build SVG path string from a single ring of arc indices
function ringToD(arcIndices, topoArcs, transform, W, H) {
  const pts = arcIndices.flatMap(idx => {
    const raw = idx < 0 ? decodeArc(topoArcs[~idx]).reverse() : decodeArc(topoArcs[idx]);
    return raw.map(pt => transformPoint(pt, transform));
  });
  if (pts.length < 2) return "";
  return pts.map(([lon, lat], i) => {
    const [px, py] = mercatorProject(lon, lat, W, H);
    return `${i === 0 ? "M" : "L"}${px.toFixed(1)},${py.toFixed(1)}`;
  }).join(" ") + " Z";
}

// Convert a TopoJSON geometry object to full SVG path string
function topoGeomToPath(geom, topoArcs, transform, W, H) {
  if (!geom) return "";
  if (geom.type === "Polygon")
    return geom.arcs.map(ring => ringToD(ring, topoArcs, transform, W, H)).join(" ");
  if (geom.type === "MultiPolygon")
    return geom.arcs.flatMap(poly => poly.map(ring => ringToD(ring, topoArcs, transform, W, H))).join(" ");
  return "";
}

// ISO numeric → country name (covers ~180 countries)
const ISO_TO_NAME = {
  4:"Afghanistan",8:"Albania",12:"Algeria",24:"Angola",32:"Argentina",36:"Australia",40:"Austria",
  50:"Bangladesh",56:"Belgium",64:"Bhutan",68:"Bolivia",76:"Brazil",100:"Bulgaria",116:"Cambodia",
  120:"Cameroon",124:"Canada",144:"Sri Lanka",152:"Chile",156:"China",170:"Colombia",180:"DR Congo",
  188:"Costa Rica",191:"Croatia",192:"Cuba",196:"Cyprus",203:"Czech Republic",208:"Denmark",
  218:"Ecuador",818:"Egypt",231:"Ethiopia",246:"Finland",250:"France",276:"Germany",288:"Ghana",
  300:"Greece",320:"Guatemala",332:"Haiti",340:"Honduras",348:"Hungary",356:"India",360:"Indonesia",
  364:"Iran",368:"Iraq",372:"Ireland",376:"Israel",380:"Italy",388:"Jamaica",392:"Japan",
  400:"Jordan",398:"Kazakhstan",404:"Kenya",408:"North Korea",410:"South Korea",414:"Kuwait",
  422:"Lebanon",426:"Lesotho",430:"Liberia",434:"Libya",440:"Lithuania",442:"Luxembourg",
  450:"Madagascar",454:"Malawi",458:"Malaysia",484:"Mexico",504:"Morocco",508:"Mozambique",
  516:"Namibia",524:"Nepal",528:"Netherlands",554:"New Zealand",566:"Nigeria",578:"Norway",
  586:"Pakistan",591:"Panama",598:"Papua New Guinea",600:"Paraguay",604:"Peru",608:"Philippines",
  616:"Poland",620:"Portugal",634:"Qatar",642:"Romania",643:"Russia",646:"Rwanda",
  682:"Saudi Arabia",686:"Senegal",694:"Sierra Leone",703:"Slovakia",706:"Somalia",
  710:"South Africa",724:"Spain",729:"Sudan",752:"Sweden",756:"Switzerland",760:"Syria",
  764:"Thailand",792:"Turkey",800:"Uganda",804:"Ukraine",784:"United Arab Emirates",
  826:"United Kingdom",840:"United States of America",858:"Uruguay",862:"Venezuela",
  704:"Vietnam",887:"Yemen",894:"Zambia",716:"Zimbabwe",
};

// ─── World Heatmap Section ────────────────────────────────────────────────────

const WorldHeatmapSection = ({ locationRows }) => {
  const mapRef   = useRef(null);
  const svgRef   = useRef(null);
  const zoomRef  = useRef(null);
  const [tooltip,    setTooltip]    = useState(null);
  const [mapReady,   setMapReady]   = useState(false);
  const [zoomLevel,  setZoomLevel]  = useState(1);
  const [activeMetric, setActiveMetric] = useState("views");
  const activeMetricRef = useRef("views");

  const METRICS = [
    { key: "views",           label: "Views",     icon: "\uD83D\uDC41" },
    { key: "unique_viewers",  label: "Unique",    icon: "\uD83D\uDC64" },
    { key: "completed_views", label: "Completed", icon: "\u2705" },
    { key: "rewarded_views",  label: "Rewarded",  icon: "\uD83E\uDE99" },
  ];

  // Parse location strings like "Mumbai, India" → country = last comma segment
  const countryData = {};
  locationRows.forEach((row) => {
    const raw = (row.location || "").trim();
    if (!raw || raw.toLowerCase() === "unknown") return;
    const parts = raw.split(", ");
    const country = parts[parts.length - 1].trim();
    if (!country) return;
    if (!countryData[country]) {
      countryData[country] = { views: 0, unique_viewers: 0, completed_views: 0, rewarded_views: 0, total_coins_rewarded: 0 };
    }
    countryData[country].views                += row.views                || 0;
    countryData[country].unique_viewers       += row.unique_viewers       || 0;
    countryData[country].completed_views      += row.completed_views      || 0;
    countryData[country].rewarded_views       += row.rewarded_views       || 0;
    countryData[country].total_coins_rewarded += row.total_coins_rewarded || 0;
  });

  const hasData = Object.keys(countryData).length > 0;
  const fmt = (n) => n >= 1_000_000 ? `${(n/1_000_000).toFixed(1)}M` : n >= 1000 ? `${(n/1000).toFixed(1)}K` : String(n);

  // Interpolate colour on indigo-orange heat scale
  const HEAT_STOPS = [
    [0.00, [15,  23,  42 ]],
    [0.10, [30,  58,  138]],
    [0.30, [67,  56,  202]],
    [0.55, [99,  102, 241]],
    [0.75, [251, 146, 60 ]],
    [1.00, [249, 115, 22 ]],
  ];
  const getColorForValue = (val, maxV) => {
    if (!val || maxV === 0) return "#0f172a";
    const t = Math.pow(val / maxV, 0.45);
    for (let i = 1; i < HEAT_STOPS.length; i++) {
      const [lo, cLo] = HEAT_STOPS[i - 1];
      const [hi, cHi] = HEAT_STOPS[i];
      if (t <= hi) {
        const f = (t - lo) / (hi - lo);
        const r = Math.round(cLo[0] + f * (cHi[0] - cLo[0]));
        const g = Math.round(cLo[1] + f * (cHi[1] - cLo[1]));
        const b = Math.round(cLo[2] + f * (cHi[2] - cLo[2]));
        return `rgb(${r},${g},${b})`;
      }
    }
    return "rgb(249,115,22)";
  };

  // Build & mount D3 map once
  useEffect(() => {
    if (!mapRef.current) return;
    const container = mapRef.current;

    const loadScripts = (urls, cb) => {
      let pending = urls.length;
      urls.forEach(url => {
        if (document.querySelector(`script[src="${url}"]`)) { if (!--pending) cb(); return; }
        const s = Object.assign(document.createElement("script"), {
          src: url, onload: () => { if (!--pending) cb(); }
        });
        document.head.appendChild(s);
      });
    };

    loadScripts([
      "https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js",
      "https://cdnjs.cloudflare.com/ajax/libs/topojson/3.0.2/topojson.min.js",
    ], () => {
      const d3 = window.d3;
      const topojson = window.topojson;
      if (!d3 || !topojson) return;

      fetch("https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json")
        .then(r => r.json())
        .then(world => {
          container.innerHTML = "";
          const W = container.clientWidth || 900;
          const H = Math.max(container.clientHeight || 0, 520);

          const svg = d3.select(container)
            .append("svg")
            .attr("width", "100%")
            .attr("height", H)
            .attr("viewBox", `0 0 ${W} ${H}`)
            .style("display", "block")
            .style("background", "#060d1a");
          svgRef.current = svg;

          // Background rect
          svg.append("rect").attr("width", W).attr("height", H).attr("fill", "#060d1a");

          const projection = d3.geoNaturalEarth1()
            .scale(W / 5.8)
            .translate([W / 2, H / 2]);
          const pathGen = d3.geoPath().projection(projection);

          // idToName from world-atlas properties
          const idToName = {};
          world.objects.countries.geometries.forEach(g => {
            if (g.properties?.name) idToName[+g.id] = g.properties.name;
          });

          const countries = topojson.feature(world, world.objects.countries);

          // Graticule
          svg.append("path")
            .datum(d3.geoGraticule()())
            .attr("d", pathGen)
            .attr("fill", "none")
            .attr("stroke", "#0d2240")
            .attr("stroke-width", 0.4);

          // Main map group (zoom target)
          const g = svg.append("g").attr("class", "map-g");

          // Sphere
          g.append("path")
            .datum({ type: "Sphere" })
            .attr("d", pathGen)
            .attr("fill", "#0a1628")
            .attr("stroke", "#1e3a5f")
            .attr("stroke-width", 0.8);

          // Compute max for current metric
          const getMax = () => {
            const metric = activeMetricRef.current;
            return Math.max(...Object.values(countryData).map(d => d[metric] || 0), 1);
          };

          // Country paths
          const countryPaths = g.selectAll("path.country")
            .data(countries.features)
            .join("path")
            .attr("class", "country")
            .attr("d", pathGen)
            .attr("fill", d => {
              const name = idToName[+d.id] || "";
              const cd = countryData[name];
              if (!cd) return "#0f1e35";
              return getColorForValue(cd[activeMetricRef.current] || 0, getMax());
            })
            .attr("stroke", "#0d2240")
            .attr("stroke-width", 0.3)
            .style("cursor", d => countryData[idToName[+d.id]] ? "pointer" : "default");

          // Store refs for recolouring
          container.__countryPaths = countryPaths;
          container.__idToName     = idToName;
          container.__getMax       = getMax;
          container.__getColorFn   = getColorForValue;

          // Hover interactions
          countryPaths
            .on("mouseover", function(event, d) {
              const name = idToName[+d.id] || "";
              const cd = countryData[name];
              d3.select(this)
                .attr("stroke", cd ? "#f97316" : "#1e3a5f")
                .attr("stroke-width", cd ? 1.5 : 0.3);
              if (!cd) { setTooltip(null); return; }
              const [mx, my] = d3.pointer(event, container);
              setTooltip({ name, data: cd, x: mx, y: my });
            })
            .on("mousemove", function(event) {
              const [mx, my] = d3.pointer(event, container);
              setTooltip(t => t ? { ...t, x: mx, y: my } : null);
            })
            .on("mouseout", function(event, d) {
              const name = idToName[+d.id] || "";
              const cd = countryData[name];
              d3.select(this)
                .attr("stroke", "#0d2240")
                .attr("stroke-width", 0.3);
              setTooltip(null);
            });

          // ── Zoom behaviour ────────────────────────────────────────────────
          const zoom = d3.zoom()
            .scaleExtent([1, 12])
            .on("zoom", (event) => {
              g.attr("transform", event.transform);
              // Thin strokes at high zoom
              const k = event.transform.k;
              countryPaths.attr("stroke-width", 0.3 / k);
              setZoomLevel(Math.round(k * 10) / 10);
            });

          svg.call(zoom);
          zoomRef.current = zoom;
          container.__svg  = svg;
          container.__zoom = zoom;

          // Expose zoom helpers on container
          container.__zoomIn  = () => svg.transition().duration(350).call(zoom.scaleBy, 1.6);
          container.__zoomOut = () => svg.transition().duration(350).call(zoom.scaleBy, 0.625);
          container.__zoomReset = () => svg.transition().duration(500).call(zoom.transform, d3.zoomIdentity);

          setMapReady(true);
        })
        .catch(err => console.error("Map load error:", err));
    });

    return () => { container.innerHTML = ""; };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [locationRows]);

  // Recolour on metric change without full redraw
  useEffect(() => {
    activeMetricRef.current = activeMetric;
    const container = mapRef.current;
    if (!container || !container.__countryPaths || !window.d3) return;
    const maxV = container.__getMax();
    container.__countryPaths.attr("fill", d => {
      const name = container.__idToName[+d.id] || "";
      const cd = countryData[name];
      if (!cd) return "#0f1e35";
      return container.__getColorFn(cd[activeMetric] || 0, maxV);
    });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeMetric]);

  const metricValues = Object.values(countryData).map(d => d[activeMetric] || 0);
  const totalVal = metricValues.reduce((a, b) => a + b, 0);

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">

      {/* ── Header ── */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-6 py-5 border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 to-orange-500 flex items-center justify-center shadow-sm">
            <Globe className="w-4 h-4 text-white" />
          </div>
          <div>
            <h3 className="text-base font-bold text-gray-900 dark:text-white">Views by Location</h3>
            <p className="text-xs text-gray-400 mt-0.5">
              {hasData
                ? `${Object.keys(countryData).length} ${Object.keys(countryData).length === 1 ? "country" : "countries"} · ${fmt(totalVal)} ${METRICS.find(m => m.key === activeMetric)?.label.toLowerCase()}`
                : "No location data available"}
            </p>
          </div>
        </div>

        {/* Metric pills */}
        <div className="flex gap-1.5 flex-wrap">
          {METRICS.map(m => (
            <button key={m.key} onClick={() => setActiveMetric(m.key)}
              className={`px-3 py-1.5 rounded-full text-[11px] font-bold transition-all ${
                activeMetric === m.key
                  ? "bg-indigo-600 text-white shadow-sm"
                  : "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}>
              {m.icon} {m.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Map area ── */}
      {!hasData ? (
        <div className="flex flex-col items-center justify-center py-16 gap-3">
          <div className="w-16 h-16 rounded-2xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
            <Globe className="w-8 h-8 text-gray-300 dark:text-gray-600" />
          </div>
          <p className="text-sm font-medium text-gray-400">No location data to display</p>
        </div>
      ) : (
        <div className="relative" style={{ background: "#060d1a" }}>
          {/* D3 mount point */}
          <div ref={mapRef} className="w-full" style={{ minHeight: 520 }} />

          {/* Loading overlay */}
          {!mapReady && (
            <div className="absolute inset-0 flex items-center justify-center gap-3" style={{ background: "#060d1a" }}>
              <RefreshCw className="w-5 h-5 animate-spin text-indigo-400" />
              <span className="text-xs text-gray-400 font-medium">Loading map…</span>
            </div>
          )}

          {/* ── Zoom controls ── */}
          {mapReady && (
            <div className="absolute top-4 right-4 flex flex-col gap-1 z-10">
              {/* Zoom level badge */}
              <div className="text-center text-[10px] font-bold text-gray-400 mb-1 tabular-nums">
                {zoomLevel.toFixed(1)}×
              </div>
              <button
                onClick={() => mapRef.current?.__zoomIn?.()}
                className="w-8 h-8 rounded-lg bg-slate-800/90 border border-slate-700 text-white flex items-center justify-center hover:bg-indigo-700 transition-colors text-base font-bold"
                title="Zoom in"
              >+</button>
              <button
                onClick={() => mapRef.current?.__zoomOut?.()}
                className="w-8 h-8 rounded-lg bg-slate-800/90 border border-slate-700 text-white flex items-center justify-center hover:bg-indigo-700 transition-colors text-base font-bold"
                title="Zoom out"
              >−</button>
              <button
                onClick={() => mapRef.current?.__zoomReset?.()}
                className="w-8 h-8 rounded-lg bg-slate-800/90 border border-slate-700 text-white flex items-center justify-center hover:bg-orange-600 transition-colors"
                title="Reset zoom"
              >
                <RefreshCw className="w-3.5 h-3.5" />
              </button>
            </div>
          )}

          {/* ── Colour legend ── */}
          {mapReady && (
            <div className="absolute bottom-4 left-4 flex flex-col gap-1">
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold text-gray-400">Low</span>
                <div className="w-28 h-2.5 rounded-full" style={{
                  background: "linear-gradient(to right, #1e3a8a, #6366f1, #f97316)"
                }} />
                <span className="text-[10px] font-bold text-gray-400">High</span>
              </div>
              <p className="text-[9px] text-gray-600 ml-0.5">Scroll or pinch to zoom · drag to pan</p>
            </div>
          )}

          {/* ── Tooltip ── */}
          {tooltip && tooltip.data && (
            <div
              className="absolute z-20 pointer-events-none rounded-xl px-4 py-3 shadow-2xl text-white"
              style={{
                left: Math.min(tooltip.x + 16, (mapRef.current?.clientWidth || 800) - 220),
                top:  Math.max(tooltip.y - 110, 8),
                minWidth: 200,
                background: "rgba(6,13,26,0.97)",
                border: "1px solid rgba(99,102,241,0.4)",
                backdropFilter: "blur(8px)",
              }}
            >
              <div className="flex items-center gap-2 mb-2.5 pb-2 border-b border-white/10">
                <MapPin className="w-3.5 h-3.5 text-orange-400 flex-shrink-0" />
                <span className="text-sm font-bold leading-tight">{tooltip.name}</span>
              </div>
              <div className="space-y-1.5">
                {METRICS.map(m => {
                  const val = tooltip.data[m.key] || 0;
                  const isActive = activeMetric === m.key;
                  return (
                    <div key={m.key} className="flex items-center justify-between gap-4">
                      <span className={`text-xs ${isActive ? "text-orange-300 font-bold" : "text-gray-400"}`}>
                        {m.icon} {m.label}
                      </span>
                      <span className={`text-xs font-bold tabular-nums ${isActive ? "text-orange-300" : "text-gray-300"}`}>
                        {fmt(val)}
                      </span>
                    </div>
                  );
                })}
                {tooltip.data.total_coins_rewarded > 0 && (
                  <div className="flex items-center justify-between gap-4 pt-1.5 mt-1 border-t border-white/10">
                    <span className="text-xs text-amber-400 font-bold">🪙 Coins</span>
                    <span className="text-xs font-bold text-amber-400 tabular-nums">{fmt(tooltip.data.total_coins_rewarded)}</span>
                  </div>
                )}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
};




// ─── Heatmap Location Card (original table-style, kept) ───────────────────────

const HEATMAP_METRIC_OPTIONS = [
  { key: "views",                label: "Views",     color: { from: "#1e3a8a", mid: "#3b82f6", to: "#93c5fd" } },
  { key: "unique_viewers",       label: "Unique",    color: { from: "#4c1d95", mid: "#8b5cf6", to: "#c4b5fd" } },
  { key: "completed_views",      label: "Completed", color: { from: "#065f46", mid: "#10b981", to: "#6ee7b7" } },
  { key: "rewarded_views",       label: "Rewarded",  color: { from: "#78350f", mid: "#f59e0b", to: "#fde68a" } },
  { key: "total_coins_rewarded", label: "Coins",     color: { from: "#7c2d12", mid: "#f97316", to: "#fed7aa" } },
];

const LocationHeatmap = ({ locationRows }) => {
  const [activeMetric, setActiveMetric] = useState("views");
  const [hoveredRow, setHoveredRow]     = useState(null);

  const metricDef = HEATMAP_METRIC_OPTIONS.find(m => m.key === activeMetric);
  const maxVal    = Math.max(...locationRows.map(r => r[activeMetric] || 0), 1);
  const totalVal  = locationRows.reduce((s, r) => s + (r[activeMetric] || 0), 0);

  const intensity = (val) => Math.pow((val || 0) / maxVal, 0.6);

  const heatColor = (val) => {
    const t = intensity(val);
    return { opacity: Math.max(0.08, t), value: val || 0 };
  };

  const METRICS_DETAIL = [
    { key: "views",                label: "Total",     suffix: "" },
    { key: "unique_viewers",       label: "Unique",    suffix: "" },
    { key: "completed_views",      label: "Completed", suffix: "" },
    { key: "rewarded_views",       label: "Rewarded",  suffix: "" },
    { key: "total_coins_rewarded", label: "Coins",     suffix: "🪙" },
  ];

  const ranked = [...locationRows].sort((a, b) => (b[activeMetric] || 0) - (a[activeMetric] || 0));

  return (
    // <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
    //   <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 px-6 py-5 border-b border-gray-100 dark:border-gray-800">
    //     <div className="flex items-center gap-3">
    //       <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center">
    //         <MapPinned className="w-4 h-4 text-white" />
    //       </div>
    //       <div>
    //         <h3 className="text-base font-bold text-gray-900 dark:text-white">Location Breakdown</h3>
    //         <p className="text-xs text-gray-400 mt-0.5">{locationRows.length} locations tracked</p>
    //       </div>
    //     </div>
    //     <div className="flex gap-1.5 flex-wrap">
    //       {HEATMAP_METRIC_OPTIONS.map(m => (
    //         <button
    //           key={m.key}
    //           onClick={() => setActiveMetric(m.key)}
    //           className={`px-3 py-1.5 rounded-full text-[11px] font-bold transition-all ${
    //             activeMetric === m.key
    //               ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-sm"
    //               : "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700"
    //           }`}
    //         >
    //           {m.label}
    //         </button>
    //       ))}
    //     </div>
    //   </div>

    //   <div className="p-6">
    //     <div className="flex items-center gap-2 mb-5">
    //       <span className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">Low</span>
    //       <div className="flex-1 h-2 rounded-full overflow-hidden" style={{
    //         background: `linear-gradient(to right, ${metricDef.color.to}33, ${metricDef.color.mid}, ${metricDef.color.from})`
    //       }} />
    //       <span className="text-[10px] text-gray-400 font-bold uppercase tracking-wider">High</span>
    //       <span className="text-[10px] text-gray-500 ml-2 font-semibold">Total: {totalVal.toLocaleString()}</span>
    //     </div>

    //     <div className="space-y-2">
    //       {ranked.map((row, rankIdx) => {
    //         const val        = row[activeMetric] || 0;
    //         const pct        = totalVal > 0 ? ((val / totalVal) * 100).toFixed(1) : "0.0";
    //         const heat       = heatColor(val);
    //         const isHovered  = hoveredRow === rankIdx;

    //         return (
    //           <div
    //             key={rankIdx}
    //             onMouseEnter={() => setHoveredRow(rankIdx)}
    //             onMouseLeave={() => setHoveredRow(null)}
    //             className={`relative rounded-2xl overflow-hidden border transition-all duration-200 cursor-pointer ${
    //               rankIdx === 0 ? "border-blue-200 dark:border-blue-800" : "border-gray-100 dark:border-gray-800"
    //             } ${isHovered ? "scale-[1.005] shadow-md" : ""}`}
    //           >
    //             <div
    //               className="absolute inset-0 transition-opacity duration-300"
    //               style={{
    //                 background: `linear-gradient(135deg, ${metricDef.color.from}${Math.round(heat.opacity * 255).toString(16).padStart(2, "0")} 0%, ${metricDef.color.mid}${Math.round(heat.opacity * 0.6 * 255).toString(16).padStart(2, "0")} 60%, transparent 100%)`,
    //               }}
    //             />
    //             <div className="absolute bottom-0 left-0 h-0.5 transition-all duration-700"
    //               style={{ width: `${(val / maxVal) * 100}%`, background: `linear-gradient(to right, ${metricDef.color.from}, ${metricDef.color.mid})`, opacity: 0.7 }}
    //             />

    //             <div className="relative p-4">
    //               <div className="flex items-center gap-3">
    //                 <div className={`w-7 h-7 rounded-lg flex items-center justify-center text-xs font-black flex-shrink-0 ${
    //                   rankIdx === 0 ? "bg-blue-600 text-white" :
    //                   rankIdx === 1 ? "bg-purple-500 text-white" :
    //                   rankIdx === 2 ? "bg-pink-500 text-white" :
    //                   "bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300"
    //                 }`}>
    //                   {rankIdx + 1}
    //                 </div>

    //                 <div className="flex-1 min-w-0">
    //                   <div className="flex flex-col sm:flex-row sm:items-center gap-2 sm:gap-4">
    //                     <div className="flex items-center gap-1.5 min-w-0 sm:w-40 flex-shrink-0">
    //                       <MapPin className="w-3.5 h-3.5 text-gray-400 flex-shrink-0" />
    //                       <span className="text-sm font-bold text-gray-900 dark:text-white truncate">{row.location}</span>
    //                     </div>

    //                     <div className="flex flex-wrap gap-2 flex-1">
    //                       {METRICS_DETAIL.map(m => {
    //                         const v        = row[m.key] || 0;
    //                         const isActive = m.key === activeMetric;
    //                         return (
    //                           <div key={m.key} className={`flex flex-col items-start px-2.5 py-1.5 rounded-xl transition-all ${
    //                             isActive ? "bg-gray-900 dark:bg-white" : "bg-white/60 dark:bg-gray-800/60 border border-gray-100 dark:border-gray-700"
    //                           }`}>
    //                             <span className={`text-[9px] font-bold uppercase tracking-wider ${isActive ? "text-gray-400 dark:text-gray-600" : "text-gray-400 dark:text-gray-500"}`}>{m.label}</span>
    //                             <span className={`text-xs font-black ${isActive ? "text-white dark:text-gray-900" : "text-gray-800 dark:text-gray-200"}`}>
    //                               {m.suffix}{v.toLocaleString()}
    //                             </span>
    //                           </div>
    //                         );
    //                       })}
    //                     </div>

    //                     <div className="flex-shrink-0 text-right">
    //                       <div className="text-lg font-black text-gray-900 dark:text-white leading-none">{pct}%</div>
    //                       <div className="text-[10px] text-gray-400 mt-0.5">share</div>
    //                     </div>
    //                   </div>
    //                 </div>
    //               </div>
    //             </div>
    //           </div>
    //         );
    //       })}
    //     </div>

    //     <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800 grid grid-cols-5 gap-2">
    //       {METRICS_DETAIL.map(m => (
    //         <div key={m.key} className={`text-center py-2 rounded-xl ${m.key === activeMetric ? "bg-gray-100 dark:bg-gray-800" : ""}`}>
    //           <div className="text-[9px] font-bold uppercase tracking-wider text-gray-400 mb-0.5">{m.label}</div>
    //           <div className="text-xs font-black text-gray-900 dark:text-white">
    //             {m.suffix}{locationRows.reduce((s, r) => s + (r[m.key] || 0), 0).toLocaleString()}
    //           </div>
    //         </div>
    //       ))}
    //     </div>
    //   </div>
    // </div>
    <></>
  );
};

// ─── Likes & Dislikes Panel ───────────────────────────────────────────────────

const LikesDislikesPanel = ({ stats }) => {
  const [activeGender, setActiveGender] = useState(null);

  const totalLikes     = stats.likes?.total    || 0;
  const totalDislikes  = stats.dislikes?.total || 0;
  const totalReactions = totalLikes + totalDislikes;
  const likesByGender    = stats.likes?.by_gender    || {};
  const dislikesByGender = stats.dislikes?.by_gender || {};
  const genderKeys       = [...new Set([...Object.keys(likesByGender), ...Object.keys(dislikesByGender)])];

  const filteredLikes    = activeGender ? (likesByGender[activeGender]?.count    || 0) : totalLikes;
  const filteredDislikes = activeGender ? (dislikesByGender[activeGender]?.count || 0) : totalDislikes;
  const filteredTotal    = filteredLikes + filteredDislikes;
  const filteredLikesPct = filteredTotal > 0 ? (filteredLikes / filteredTotal) * 100 : 0;

  const genderConfig = {
    male:    { label: "Male",    color: "#3b82f6" },
    female:  { label: "Female",  color: "#ec4899" },
    other:   { label: "Other",   color: "#8b5cf6" },
    unknown: { label: "Unknown", color: "#9ca3af" },
  };

  return (
    <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
      <div className="px-6 py-5 border-b border-gray-100 dark:border-gray-800">
        <div className="flex items-center gap-3">
          <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-pink-500 to-red-500 flex items-center justify-center">
            <Heart className="w-4 h-4 text-white" />
          </div>
          <div>
            <h3 className="text-base font-bold text-gray-900 dark:text-white">Likes & Dislikes</h3>
            <p className="text-xs text-gray-400 mt-0.5">{totalReactions.toLocaleString()} total reactions</p>
          </div>
        </div>
      </div>

      <div className="p-6 space-y-7">
        {/* Big split bar */}
        <div>
          <div className="flex justify-between items-end mb-2">
            <div className="flex items-center gap-2">
              <Heart className="w-4 h-4 text-pink-500" />
              <span className="text-2xl font-black text-gray-900 dark:text-white">{filteredLikes.toLocaleString()}</span>
              <span className="text-sm text-gray-400">likes</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="text-sm text-gray-400">dislikes</span>
              <span className="text-2xl font-black text-gray-900 dark:text-white">{filteredDislikes.toLocaleString()}</span>
              <ThumbsDown className="w-4 h-4 text-red-400" />
            </div>
          </div>
          <div className="h-4 rounded-full overflow-hidden flex bg-gray-100 dark:bg-gray-800">
            <div
              className="h-full bg-gradient-to-r from-pink-500 to-rose-400 transition-all duration-700 flex items-center justify-end pr-2"
              style={{ width: `${filteredLikesPct}%`, minWidth: filteredLikes > 0 ? "2%" : "0%" }}
            >
              {filteredLikesPct > 20 && <span className="text-[10px] font-black text-white">{Math.round(filteredLikesPct)}%</span>}
            </div>
            <div
              className="h-full bg-gradient-to-r from-red-400 to-red-500 transition-all duration-700 flex items-center justify-start pl-2"
              style={{ width: `${100 - filteredLikesPct}%`, minWidth: filteredDislikes > 0 ? "2%" : "0%" }}
            >
              {(100 - filteredLikesPct) > 20 && <span className="text-[10px] font-black text-white">{Math.round(100 - filteredLikesPct)}%</span>}
            </div>
          </div>
          <div className="flex justify-between text-[10px] text-gray-400 mt-1.5 font-semibold">
            <span className="flex items-center gap-1"><div className="w-2 h-2 rounded-full bg-pink-500" /> Likes</span>
            <span className="flex items-center gap-1">Dislikes <div className="w-2 h-2 rounded-full bg-red-500" /></span>
          </div>
        </div>

        {/* Gender filter */}
        {genderKeys.length > 0 && (
          <div>
            <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-3">Filter by Gender</p>
            <div className="flex flex-wrap gap-2">
              <button
                onClick={() => setActiveGender(null)}
                className={`px-3 py-1.5 rounded-full text-xs font-bold border transition-all ${
                  activeGender === null
                    ? "bg-gray-900 dark:bg-white text-white dark:text-black border-transparent"
                    : "border-gray-200 dark:border-gray-700 text-gray-500 dark:text-gray-400"
                }`}
              >All</button>
              {genderKeys.map(g => {
                const cfg      = genderConfig[g] || genderConfig.unknown;
                const isActive = activeGender === g;
                return (
                  <button key={g}
                    onClick={() => setActiveGender(isActive ? null : g)}
                    className={`px-3 py-1.5 rounded-full text-xs font-bold border transition-all flex items-center gap-1.5 ${
                      isActive ? "border-transparent text-white" : "border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300"
                    }`}
                    style={isActive ? { backgroundColor: cfg.color } : {}}
                  >
                    <div className="w-2 h-2 rounded-full" style={{ backgroundColor: cfg.color }} />
                    {cfg.label}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Gender breakdown rows */}
        <div>
          <p className="text-[10px] font-bold uppercase tracking-wider text-gray-400 mb-3">By Gender</p>
          <div className="space-y-2.5">
            {genderKeys.map(g => {
              const cfg     = genderConfig[g] || genderConfig.unknown;
              const lCount  = likesByGender[g]?.count    || 0;
              const dCount  = dislikesByGender[g]?.count || 0;
              const gTotal  = lCount + dCount;
              const lPct    = gTotal > 0 ? (lCount / gTotal) * 100 : 0;
              return (
                <div key={g}
                  onClick={() => setActiveGender(activeGender === g ? null : g)}
                  className={`p-4 rounded-2xl border cursor-pointer transition-all duration-200 ${
                    activeGender === g ? "border-gray-300 dark:border-gray-600 shadow-sm"
                    : activeGender !== null ? "border-gray-100 dark:border-gray-800 opacity-50"
                    : "border-gray-100 dark:border-gray-800 hover:border-gray-200 dark:hover:border-gray-700"
                  }`}
                >
                  <div className="flex items-center justify-between mb-3">
                    <div className="flex items-center gap-2">
                      <div className="w-3 h-3 rounded-full" style={{ backgroundColor: cfg.color }} />
                      <span className="text-sm font-bold text-gray-900 dark:text-white capitalize">{g}</span>
                    </div>
                    <span className="text-xs text-gray-400 font-semibold">{gTotal.toLocaleString()} reactions</span>
                  </div>
                  <div className="h-2 rounded-full overflow-hidden flex bg-gray-100 dark:bg-gray-800 mb-2">
                    <div className="h-full transition-all duration-500" style={{ width: `${lPct}%`, backgroundColor: "#ec4899", minWidth: lCount > 0 ? "2%" : "0%" }} />
                    <div className="h-full transition-all duration-500" style={{ width: `${100 - lPct}%`, backgroundColor: "#ef4444", minWidth: dCount > 0 ? "2%" : "0%" }} />
                  </div>
                  <div className="flex justify-between text-xs">
                    <span className="text-pink-500 font-bold flex items-center gap-1">
                      <Heart className="w-3 h-3" /> {lCount.toLocaleString()}
                      <span className="text-gray-400 font-normal ml-0.5">({Math.round(lPct)}%)</span>
                    </span>
                    <span className="text-red-400 font-bold flex items-center gap-1">
                      <span className="text-gray-400 font-normal mr-0.5">({Math.round(100 - lPct)}%)</span>
                      {dCount.toLocaleString()} <ThumbsDown className="w-3 h-3" />
                    </span>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        {/* Sentiment score */}
        <div className="p-4 rounded-2xl bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-700">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-bold text-gray-500 uppercase tracking-wider mb-1">Sentiment Score</p>
              <p className="text-3xl font-black text-gray-900 dark:text-white">
                {filteredTotal > 0 ? Math.round((filteredLikes / filteredTotal) * 100) : 0}
                <span className="text-sm font-normal text-gray-400 ml-1">/ 100</span>
              </p>
              <p className="text-xs text-gray-400 mt-1">
                {(() => {
                  const s = filteredTotal > 0 ? (filteredLikes / filteredTotal) * 100 : 0;
                  if (s >= 80) return "Excellent reception";
                  if (s >= 60) return "Good reception";
                  if (s >= 40) return "Mixed reception";
                  return "Low positive reception";
                })()}
              </p>
            </div>
            <div className="relative w-16 h-16">
              <svg viewBox="0 0 64 64" className="w-full h-full -rotate-90">
                <circle cx="32" cy="32" r="26" fill="none" strokeWidth="8" stroke="currentColor" className="text-gray-200 dark:text-gray-700" />
                <circle cx="32" cy="32" r="26" fill="none" strokeWidth="8" stroke="#ec4899"
                  strokeDasharray={`${(filteredLikesPct / 100) * 163.4} 163.4`} strokeLinecap="round" />
              </svg>
              <div className="absolute inset-0 flex items-center justify-center">
                <Heart className="w-4 h-4 text-pink-500" />
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

// ─── Stats Section ─────────────────────────────────────────────────────────────

const StatsSection = ({ adId }) => {
  const [stats, setStats]     = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState("");

  useEffect(() => {
    if (!adId) return;
    const fetchStats = async () => {
      setLoading(true); setError("");
      try {
        const res = await api.get(`/ads/${adId}/stats`);
        setStats(res.data);
      } catch (err) {
        console.error("Stats fetch failed", err);
        setError(err?.response?.data?.message || "Failed to load stats");
      } finally { setLoading(false); }
    };
    fetchStats();
  }, [adId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center py-16 gap-3 text-gray-400">
        <RefreshCw className="w-5 h-5 animate-spin text-pink-500" />
        <span className="text-sm">Loading stats...</span>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center gap-3 p-5 rounded-2xl bg-red-50 dark:bg-red-900/10 border border-red-100 dark:border-red-900/30 text-red-600 dark:text-red-400">
        <AlertCircle className="w-5 h-5 flex-shrink-0" />
        <span className="text-sm">{error}</span>
      </div>
    );
  }

  if (!stats) return null;

  // ── Derived data ────────────────────────────────────────────────────────────

  const viewStats = [
    { label: "Total Views",     value: stats.views?.total     || 0, color: "blue",   icon: Eye         },
    { label: "Unique Views",    value: stats.views?.unique    || 0, color: "purple", icon: Users       },
    { label: "Completed Views", value: stats.views?.completed || 0, color: "green",  icon: CheckCircle },
  ];

  const locationRows = stats.views?.by_location || [];

  // Gender data — support multiple possible shapes from backend
  const rawGender = stats.gender || stats.views?.by_gender || stats.audience?.gender || {};
  const genderData = {
    male:   rawGender.male   || rawGender.Male   || 0,
    female: rawGender.female || rawGender.Female || 0,
    other:  rawGender.other  || rawGender.Other  || rawGender.non_binary || 0,
  };

  const genderPieData = Object.entries(stats.likes?.by_gender || {})
    .map(([key, val]) => ({ name: key.charAt(0).toUpperCase() + key.slice(1), value: val?.count || 0 }))
    .filter(d => d.value > 0);

  const pieTotal = genderPieData.reduce((s, d) => s + d.value, 0);

  return (
    <div className="space-y-8">

      {/* ── Views Overview ────────────────────────────────────────────────── */}
      <div>
        <h2 className="text-base font-bold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
          <Eye className="w-4 h-4 text-blue-500" /> Views Overview
        </h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          {viewStats.map((s, i) => (
            <StatCard key={i} label={s.label} value={s.value.toLocaleString()} color={s.color} icon={s.icon} />
          ))}
        </div>
      </div>

      {/* ── Age Breakdown Pie Charts ──────────────────────────────────────── */}
      <AgeBreakdownCharts stats={stats} />

      {/* ── Gender Analytics ─────────────────────────────────────────────── */}
      <GenderAnalyticsSection genderData={genderData} />

      {/* ── World Heatmap ─────────────────────────────────────────────────── */}
      <WorldHeatmapSection locationRows={locationRows} />

      {/* ── Likes & Dislikes ──────────────────────────────────────────────── */}
      {/* <LikesDislikesPanel stats={stats} /> */}

      {/* ── Audience by Gender Pie (from likes data) ─────────────────────── */}
      {genderPieData.length > 0 && (
        <Card title="Audience by Gender (Likes)" icon={PieIcon}>
          <p className="text-xs text-gray-400 -mt-2 mb-4">Based on who liked this ad</p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6 items-center">
            <div className="h-52">
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={genderPieData} cx="50%" cy="50%" innerRadius={55} outerRadius={80} paddingAngle={4} dataKey="value">
                    {genderPieData.map((entry, index) => (
                      <Cell key={index} fill={GENDER_COLORS[entry.name.toLowerCase()] || "#6366f1"} stroke="none" />
                    ))}
                  </Pie>
                  <Tooltip
                    contentStyle={{ borderRadius: "12px", border: "none", boxShadow: "0 4px 20px rgba(0,0,0,0.1)", fontSize: "12px" }}
                    formatter={(value, name) => [`${value} users`, name]}
                  />
                  <Legend verticalAlign="bottom" height={36} iconType="circle" iconSize={10}
                    formatter={(value) => <span style={{ fontSize: "11px", color: "#9ca3af" }}>{value}</span>}
                  />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="space-y-2">
              {genderPieData.map((item) => {
                const p     = pieTotal > 0 ? Math.round((item.value / pieTotal) * 100) : 0;
                const color = GENDER_COLORS[item.name.toLowerCase()] || "#6366f1";
                return (
                  <div key={item.name} className="flex items-center gap-3 p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                    <div className="w-3 h-3 rounded-full flex-shrink-0" style={{ backgroundColor: color }} />
                    <div className="min-w-0 flex-1">
                      <div className="text-xs font-semibold text-gray-700 dark:text-gray-200 capitalize">{item.name}</div>
                      <div className="flex items-center gap-1 mt-0.5">
                        <div className="flex-1 h-1.5 rounded-full bg-gray-200 dark:bg-gray-700 overflow-hidden">
                          <div className="h-full rounded-full" style={{ width: `${p}%`, backgroundColor: color }} />
                        </div>
                        <span className="text-[10px] font-bold text-gray-500 whitespace-nowrap">{p}%</span>
                      </div>
                    </div>
                    <span className="text-sm font-bold text-gray-900 dark:text-white">{item.value}</span>
                  </div>
                );
              })}
            </div>
          </div>
        </Card>
      )}

      {/* ── Location Table Heatmap ────────────────────────────────────────── */}
      {locationRows.length > 0 && <LocationHeatmap locationRows={locationRows} />}
    </div>
  );
};

// ─── Main Component ───────────────────────────────────────────────────────────

export default function AdDetails() {
  const { adId }   = useParams();
  const navigate   = useNavigate();

  const [ad, setAd]           = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError]     = useState("");

  const [comments, setComments]               = useState([]);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [commentsPage, setCommentsPage]       = useState(1);
  const [commentsTotal, setCommentsTotal]     = useState(0);
  const COMMENTS_PER_PAGE = 5;

  const [showAllLikes, setShowAllLikes] = useState(false);

  const [activeTab, setActiveTab] = useState("overview");

  const [walletHistory, setWalletHistory] = useState(null);
  const [walletLoading, setWalletLoading] = useState(false);
  const [walletError, setWalletError]     = useState("");
  const [walletPage, setWalletPage]       = useState(1);
  const WALLET_PER_PAGE = 5;

  const COLORS = ["#3b82f6", "#ec4899", "#8b5cf6", "#f59e0b", "#10b981", "#ef4444"];

  useEffect(() => {
    if (!adId) return;
    const fetchData = async () => {
      setLoading(true); setError("");
      try {
        const res = await api.get(`/ads/${adId}`);
        setAd(res.data?.ad || res.data);
      } catch (err) {
        console.error(err);
        setError("Failed to load ad details. Please try again.");
      } finally { setLoading(false); }
    };
    fetchData();
  }, [adId]);

  useEffect(() => {
    if (!adId) return;
    const fetchComments = async () => {
      setCommentsLoading(true);
      try {
        const res = await api.get(`/ads/${adId}/comments`, { params: { page: commentsPage, limit: COMMENTS_PER_PAGE } });
        const data  = Array.isArray(res.data) ? res.data : res.data?.comments || res.data?.data || [];
        const total = res.data?.total || res.data?.totalCount || data.length;
        setComments(data);
        setCommentsTotal(total);
      } catch (err) { console.error("Comments fetch failed", err); setComments([]); }
      finally { setCommentsLoading(false); }
    };
    fetchComments();
  }, [adId, commentsPage]);

  useEffect(() => {
    if (!adId) return;
    const fetchWalletHistory = async () => {
      setWalletLoading(true); setWalletError("");
      try {
        const res = await api.get(`/wallet/ads/${adId}/history`, { params: { page: walletPage, limit: WALLET_PER_PAGE } });
        setWalletHistory(res.data);
      } catch (err) {
        setWalletError(err?.response?.data?.message || "Failed to load transaction history");
      } finally { setWalletLoading(false); }
    };
    fetchWalletHistory();
  }, [adId, walletPage]);

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black flex items-center justify-center">
        <div className="text-center">
          <div className="w-12 h-12 border-4 border-pink-500 border-t-transparent rounded-full animate-spin mx-auto mb-4" />
          <p className="text-gray-500 font-medium">Loading ad details...</p>
        </div>
      </div>
    );
  }

  if (error || !ad) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-black flex items-center justify-center p-6">
        <div className="text-center max-w-md">
          <AlertCircle className="w-12 h-12 text-red-500 mx-auto mb-4" />
          <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Failed to Load</h2>
          <p className="text-gray-500 mb-6">{error || "Ad not found."}</p>
          <button onClick={() => navigate("/vendor/ads-management")}
            className="px-6 py-2.5 bg-blue-600 text-white rounded-xl font-bold text-sm hover:bg-blue-700 transition-colors">
            Back to Ads Management
          </button>
        </div>
      </div>
    );
  }

  const status         = ad.status || "draft";
  const media          = ad.media?.[0] || null;
  const thumbnail      = media?.thumbnails?.[0]?.fileUrl || null;
  const isVideo        = media?.media_type === "video";
  const totalBudget    = ad.total_budget_coins || 0;
  const coinsSpent     = ad.total_coins_spent  || 0;
  const coinsRemaining = totalBudget - coinsSpent;
  const spendPct       = totalBudget > 0 ? Math.round((coinsSpent / totalBudget) * 100) : 0;

  const likesList    = Array.isArray(ad.likes)    ? ad.likes    : [];
  const dislikesList = Array.isArray(ad.dislikes) ? ad.dislikes : [];
  const visibleLikes = showAllLikes ? likesList : likesList.slice(0, 8);

  const engagementData = [
    { name: "Likes",    value: ad.likes_count    || 0 },
    { name: "Dislikes", value: ad.dislikes_count || 0 },
    { name: "Comments", value: ad.comments_count || 0 },
  ].filter(d => d.value > 0);

  const totalCommentPages = Math.max(1, Math.ceil(commentsTotal / COMMENTS_PER_PAGE));

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
      <div className="max-w-7xl mx-auto p-4 md:p-8">
        <div className="pb-20 pt-2">

          {/* Header */}
          <div className="flex items-center gap-4 mb-8">
            <button onClick={() => navigate("/vendor/ads-management")}
              className="p-2.5 rounded-xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors shadow-sm flex-shrink-0">
              <ArrowLeft className="w-5 h-5 text-gray-600 dark:text-gray-300" />
            </button>
            <div>
              <div className="flex items-center gap-3 flex-wrap">
                <h1 className="text-2xl font-bold text-gray-900 dark:text-white">{ad.ad_title || ad.caption || "Ad Details"}</h1>
                <Badge status={status} />
              </div>
              <div className="text-sm text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2 flex-wrap">
                <span className="font-mono bg-gray-100 dark:bg-gray-800 px-1.5 py-0.5 rounded text-xs">ID: {ad._id}</span>
                <span>•</span>
                <span>{new Date(ad.createdAt).toLocaleDateString("en-IN", { dateStyle: "medium" })}</span>
              </div>
            </div>
          </div>

          {/* Tab Navigation */}
          <div className="flex gap-1 mb-8 bg-white dark:bg-gray-900 p-1 rounded-2xl border border-gray-100 dark:border-gray-800 w-fit shadow-sm">
            {[
              { id: "overview", label: "Overview",         icon: BarChart2 },
              { id: "stats",    label: "Stats & Analytics", icon: Activity  },
            ].map(tab => (
              <button key={tab.id} onClick={() => setActiveTab(tab.id)}
                className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-semibold transition-all ${
                  activeTab === tab.id
                    ? "bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-sm"
                    : "text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200"
                }`}
              >
                <tab.icon className="w-4 h-4" />
                {tab.label}
              </button>
            ))}
          </div>

          {/* ══ OVERVIEW TAB ═══════════════════════════════════════════════════ */}
          {activeTab === "overview" && (
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
              <div className="lg:col-span-2 space-y-8">

                {/* Media Preview */}
                {media && (
                  <Card title="Media Preview">
                    <div className="flex flex-col sm:flex-row gap-6 items-start">
                      <div className="relative w-36 flex-shrink-0 rounded-xl overflow-hidden bg-black" style={{ aspectRatio: "9/16" }}>
                        {thumbnail ? (
                          <img src={thumbnail} alt="thumbnail" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-gray-500">
                            <Film className="w-8 h-8" />
                          </div>
                        )}
                        {isVideo && (
                          <div className="absolute inset-0 flex items-center justify-center">
                            <div className="w-10 h-10 rounded-full bg-white/80 flex items-center justify-center shadow">
                              <div className="w-0 h-0 border-t-[6px] border-t-transparent border-b-[6px] border-b-transparent border-l-[10px] border-l-gray-800 ml-1" />
                            </div>
                          </div>
                        )}
                      </div>
                      <div className="flex-1 min-w-0">
                        <InfoRow icon={Film}    label="Type"   value={media.media_type} />
                        <InfoRow icon={Film}    label="File"   value={media.fileName} mono />
                        {isVideo && media.video_meta && (
                          <>
                            <InfoRow icon={Clock} label="Duration"   value={`${media.video_meta.final_duration?.toFixed(2)}s`} />
                            <InfoRow icon={Clock} label="Original"   value={`${media.video_meta.original_length_seconds?.toFixed(2)}s`} />
                            <InfoRow icon={Clock} label="Trim Range" value={`${media.video_meta.selected_start?.toFixed(2)}s – ${media.video_meta.selected_end?.toFixed(2)}s`} />
                          </>
                        )}
                        {media.crop_settings && (
                          <InfoRow icon={BarChart2} label="Aspect Ratio" value={media.crop_settings.aspect_ratio} />
                        )}
                        {media.image_editing?.filter?.name && (
                          <InfoRow icon={Tag} label="Filter" value={media.image_editing.filter.name} />
                        )}
                        <div className="pt-3">
                          <a href={media.fileUrl} target="_blank" rel="noopener noreferrer"
                            className="inline-flex items-center gap-2 px-4 py-2 rounded-xl bg-blue-600 text-white text-xs font-bold hover:bg-blue-700 transition-colors">
                            <Eye className="w-3.5 h-3.5" /> Open Media
                          </a>
                        </div>
                      </div>
                    </div>
                  </Card>
                )}

                {/* Stats Grid */}
                <div className="grid grid-cols-2 md:grid-cols-3 gap-4">
                  <StatCard label="Total Views"     value={(ad.views_count           || 0).toLocaleString()} icon={Eye}           color="blue"   />
                  <StatCard label="Unique Views"    value={(ad.unique_views_count    || 0).toLocaleString()} icon={Users}         color="purple" />
                  <StatCard label="Completed Views" value={(ad.completed_views_count || 0).toLocaleString()} icon={CheckCircle}   color="green"  />
                  <StatCard label="Likes"           value={(ad.likes_count           || 0).toLocaleString()} icon={Heart}         color="pink"   />
                  <StatCard label="Dislikes"        value={(ad.dislikes_count        || 0).toLocaleString()} icon={ThumbsDown}    color="red"    />
                  <StatCard label="Comments"        value={(ad.comments_count        || 0).toLocaleString()} icon={MessageCircle} color="orange" />
                </div>

                {/* Ad Info */}
                <Card title="Ad Information" icon={Megaphone}>
                  {ad.ad_title && <InfoRow icon={Megaphone}    label="Ad Title"       value={ad.ad_title} />}
                  {ad.ad_description && <InfoRow icon={Layers}  label="Description"    value={ad.ad_description} />}
                  <InfoRow icon={Hash}        label="Caption"        value={ad.caption}      />
                  <InfoRow icon={Tag}         label="Category"       value={ad.category}     />
                  {ad.sub_category && <InfoRow icon={Tag}      label="Sub-Category"   value={ad.sub_category} />}
                  <InfoRow icon={Film}        label="Content Type"   value={ad.content_type} />
                  <InfoRow icon={Layers}      label="Ad Type"        value={(ad.ad_type || "—").replace("_", " ")} />
                  <InfoRow icon={MapPin}      label="Location"       value={ad.location}     />
                  <InfoRow icon={AlertCircle} label="Status"         value={<Badge status={ad.status} />} />
                  {ad.compliance?.approval_status && (
                    <InfoRow icon={ShieldCheck} label="Review Status"
                      value={
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider border ${
                          ad.compliance.approval_status === "approved"
                            ? "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"
                            : ad.compliance.approval_status === "rejected"
                            ? "bg-red-100 text-red-700 border-red-200 dark:bg-red-900/30 dark:text-red-400 dark:border-red-800"
                            : "bg-yellow-100 text-yellow-700 border-yellow-200 dark:bg-yellow-900/30 dark:text-yellow-400 dark:border-yellow-800"
                        }`}>
                          {ad.compliance.approval_status}
                        </span>
                      }
                    />
                  )}
                  {ad.compliance?.policy_agreed !== undefined && (
                    <InfoRow icon={ShieldCheck} label="Policy Agreed"
                      value={
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold border ${
                          ad.compliance.policy_agreed
                            ? "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400"
                            : "bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:border-gray-700"
                        }`}>
                          {ad.compliance.policy_agreed ? "✓ Agreed" : "Not agreed"}
                        </span>
                      }
                    />
                  )}
                  {ad.rejection_reason && <InfoRow icon={AlertCircle} label="Reject Reason" value={ad.rejection_reason} />}
                  <InfoRow icon={Clock} label="Created At" value={new Date(ad.createdAt).toLocaleString("en-IN")} />
                  <InfoRow icon={Clock} label="Updated At" value={new Date(ad.updatedAt).toLocaleString("en-IN")} />
                  {/* Keywords */}
                  {(ad.keywords || []).length > 0 && (
                    <div className="pt-3 border-t border-gray-100 dark:border-gray-800">
                      <div className="text-xs font-bold text-gray-500 uppercase tracking-wide mb-2 flex items-center gap-1.5">
                        <Tag className="w-3.5 h-3.5" /> Keywords
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {ad.keywords.map((k, i) => (
                          <span key={i} className="px-2 py-0.5 rounded-md bg-gray-100 dark:bg-gray-800 text-xs text-gray-600 dark:text-gray-400 font-medium">{k}</span>
                        ))}
                      </div>
                    </div>
                  )}
                </Card>

                {/* Targeting */}
                <Card title="Targeting Settings" icon={Target}>
                  <div className="space-y-5">

                    {/* New structured targeting */}
                    {ad.targeting && Object.keys(ad.targeting).length > 0 && (
                      <>
                        {/* Age + Gender row */}
                        {(ad.targeting.age_min || ad.targeting.age_max || ad.targeting.gender) && (
                          <div className="grid grid-cols-2 gap-3">
                            {(ad.targeting.age_min || ad.targeting.age_max) && (
                              <div className="p-3 rounded-xl bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-100 dark:border-indigo-900">
                                <div className="text-[10px] font-bold text-indigo-400 uppercase tracking-wider mb-1">Age Range</div>
                                <div className="text-sm font-bold text-indigo-700 dark:text-indigo-300">
                                  {ad.targeting.age_min || 13} – {ad.targeting.age_max || 65} yrs
                                </div>
                              </div>
                            )}
                            {ad.targeting.gender && ad.targeting.gender !== "all" && (
                              <div className="p-3 rounded-xl bg-pink-50 dark:bg-pink-900/20 border border-pink-100 dark:border-pink-900">
                                <div className="text-[10px] font-bold text-pink-400 uppercase tracking-wider mb-1">Gender</div>
                                <div className="text-sm font-bold text-pink-700 dark:text-pink-300 capitalize">{ad.targeting.gender}</div>
                              </div>
                            )}
                          </div>
                        )}

                        {/* Countries */}
                        {(ad.targeting.countries || []).length > 0 && (
                          <div>
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                                <Globe className="w-3.5 h-3.5" /> Countries
                              </div>
                              <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">{ad.targeting.countries.length}</span>
                            </div>
                            <TagList items={ad.targeting.countries} color="blue" />
                          </div>
                        )}

                        {/* States */}
                        {(ad.targeting.states || []).length > 0 && (
                          <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                                <MapPin className="w-3.5 h-3.5" /> States / Regions
                              </div>
                              <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">{ad.targeting.states.length}</span>
                            </div>
                            <TagList items={ad.targeting.states} color="purple" />
                          </div>
                        )}

                        {/* Cities */}
                        {(ad.targeting.cities || []).length > 0 && (
                          <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                            <div className="flex items-center justify-between mb-2">
                              <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                                <MapPin className="w-3.5 h-3.5" /> Cities
                              </div>
                              <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">{ad.targeting.cities.length}</span>
                            </div>
                            <TagList items={ad.targeting.cities} color="green" />
                          </div>
                        )}

                        {/* Interests */}
                        {(ad.targeting.interests || []).length > 0 && (
                          <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                            <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                              <Zap className="w-3.5 h-3.5" /> Interests
                            </div>
                            <TagList items={ad.targeting.interests} color="purple" />
                          </div>
                        )}

                        {/* Device Types */}
                        {(ad.targeting.device_types || []).length > 0 && (
                          <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                            <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                              <Smartphone className="w-3.5 h-3.5" /> Device Types
                            </div>
                            <div className="flex flex-wrap gap-2">
                              {ad.targeting.device_types.map((d, i) => (
                                <span key={i} className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-gray-100 dark:bg-gray-800 text-xs font-semibold text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700">
                                  {d === "mobile" || d === "ios" || d === "android" ? <Smartphone className="w-3 h-3" /> : <Monitor className="w-3 h-3" />}
                                  {d}
                                </span>
                              ))}
                            </div>
                          </div>
                        )}
                      </>
                    )}

                    {/* Legacy flat targeting fields */}
                    {(ad.target_language || []).length > 0 && (
                      <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <Globe className="w-3.5 h-3.5" /> Target Languages
                          </div>
                          <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">{(ad.target_language || []).length}</span>
                        </div>
                        <TagList items={ad.target_language} color="blue" />
                      </div>
                    )}
                    {(ad.target_location || []).length > 0 && (
                      <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                        <div className="flex items-center justify-between mb-2">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <MapPin className="w-3.5 h-3.5" /> Target Locations
                          </div>
                          <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded-full font-semibold">{(ad.target_location || []).length}</span>
                        </div>
                        <TagList items={ad.target_location} color="purple" />
                      </div>
                    )}
                    {(ad.target_preferences || []).length > 0 && (
                      <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                        <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                          <Tag className="w-3.5 h-3.5" /> Preferences
                        </div>
                        <TagList items={ad.target_preferences} color="green" />
                      </div>
                    )}
                    {(ad.hashtags || []).length > 0 && (
                      <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                        <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                          <Hash className="w-3.5 h-3.5" /> Hashtags
                        </div>
                        <TagList items={ad.hashtags} color="green" />
                      </div>
                    )}

                    {/* Empty state */}
                    {!ad.targeting?.countries?.length && !ad.target_language?.length && !ad.target_location?.length && (
                      <div className="text-center py-6 text-gray-400">
                        <Target className="w-8 h-8 mx-auto mb-2 opacity-30" />
                        <p className="text-sm">No targeting configured — showing to all audiences</p>
                      </div>
                    )}
                  </div>
                </Card>

                {/* Engagement Controls */}
                <Card title="Engagement Controls">
                  <div className="space-y-3">
                    {[
                      { label: "Hide Likes Count",   value: ad.engagement_controls?.hide_likes_count   },
                      { label: "Disable Comments",   value: ad.engagement_controls?.disable_comments   },
                      { label: "Disable Share",      value: ad.engagement_controls?.disable_share      },
                      { label: "Disable Save",       value: ad.engagement_controls?.disable_save       },
                      { label: "Disable Report",     value: ad.engagement_controls?.disable_report     },
                      { label: "Moderation Enabled", value: ad.engagement_controls?.moderation_enabled },
                    ].map((ctrl, i) => (
                      <div key={i} className="flex items-center justify-between p-3.5 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                        <span className="text-sm font-semibold text-gray-700 dark:text-gray-200">{ctrl.label}</span>
                        <span className={`px-2.5 py-1 rounded-full text-[10px] font-bold border ${ctrl.value
                          ? "bg-red-100 text-red-700 border-red-200 dark:bg-red-900/30 dark:text-red-400 dark:border-red-800"
                          : "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"}`}>
                          {ctrl.value ? "On" : "Off"}
                        </span>
                      </div>
                    ))}
                  </div>
                </Card>

                {/* Comments */}
                <Card title={`Comments (${commentsTotal || ad.comments_count || 0})`}>
                  {commentsLoading ? (
                    <div className="flex items-center justify-center py-10 gap-3 text-gray-400">
                      <RefreshCw className="w-5 h-5 animate-spin" />
                      <span className="text-sm">Loading comments...</span>
                    </div>
                  ) : comments.length === 0 ? (
                    <div className="text-center py-10 text-gray-400">
                      <MessageCircle className="w-8 h-8 mx-auto mb-2 opacity-30" />
                      <p className="text-sm">No comments yet</p>
                    </div>
                  ) : (
                    <div className="space-y-3">
                      {comments.map(comment => <CommentItem key={comment._id} comment={comment} />)}
                    </div>
                  )}
                  {totalCommentPages > 1 && (
                    <div className="flex items-center justify-between mt-5 pt-4 border-t border-gray-100 dark:border-gray-800">
                      <button onClick={() => setCommentsPage(p => Math.max(1, p - 1))}
                        disabled={commentsPage === 1 || commentsLoading}
                        className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-40 disabled:cursor-not-allowed transition-colors">
                        ← Prev
                      </button>
                      <span className="text-xs text-gray-500">Page {commentsPage} of {totalCommentPages}</span>
                      <button onClick={() => setCommentsPage(p => Math.min(totalCommentPages, p + 1))}
                        disabled={commentsPage === totalCommentPages || commentsLoading}
                        className="px-4 py-2 rounded-xl text-xs font-bold border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-800 disabled:opacity-40 disabled:cursor-not-allowed transition-colors">
                        Next →
                      </button>
                    </div>
                  )}
                </Card>
              </div>

              {/* RIGHT COLUMN */}
              <div className="space-y-8">
                {/* Publisher */}
                <Card title="Publisher">
                  <div className="flex items-center gap-3 mb-4">
                    <Avatar name={ad.user_id?.full_name || "U"} url={ad.user_id?.avatar_url || ""} size="w-12 h-12" textSize="text-sm" />
                    <div>
                      <div className="font-bold text-sm text-gray-900 dark:text-white">{ad.user_id?.full_name || "—"}</div>
                      <div className="text-xs text-gray-500">@{ad.user_id?.username || "—"}</div>
                    </div>
                  </div>
                  <div className="pt-4 border-t border-gray-100 dark:border-gray-800">
                    <div className="flex items-center gap-2 text-xs text-gray-500 mb-1.5">
                      <Building2 className="w-3.5 h-3.5" />
                      <span className="font-bold uppercase tracking-wide">Business</span>
                    </div>
                    <div className="text-sm font-semibold text-gray-800 dark:text-gray-200 mb-2">{ad.vendor_id?.business_name || "—"}</div>
                    <span className={`inline-flex px-2.5 py-1 rounded-full text-[10px] font-bold border ${
                      ad.vendor_id?.validated
                        ? "bg-green-100 text-green-700 border-green-200 dark:bg-green-900/30 dark:text-green-400 dark:border-green-800"
                        : "bg-gray-100 text-gray-500 border-gray-200 dark:bg-gray-800 dark:border-gray-700"}`}>
                      {ad.vendor_id?.validated ? "✓ Verified" : "Unverified"}
                    </span>
                  </div>
                </Card>

                {/* Budget & Coins */}
                <Card title="Budget & Coins">
                  <div className="relative p-5 rounded-2xl bg-gradient-to-br from-gray-900 via-gray-800 to-black text-white overflow-hidden mb-5 shadow-lg">
                    <div className="absolute top-0 right-0 w-28 h-28 bg-orange-500/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
                    <div className="relative z-10">
                      <div className="text-[10px] text-gray-400 font-bold uppercase tracking-wider mb-1">Total Budget</div>
                      <div className="text-3xl font-extrabold mb-4 tracking-tight flex items-center gap-2">
                        <Coins className="w-6 h-6 text-yellow-400" />
                        {totalBudget.toLocaleString()}
                      </div>
                      <div className="grid grid-cols-2 gap-4 pt-3 border-t border-white/10">
                        <div>
                          <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Spent</div>
                          <div className="font-bold text-base text-red-400">{coinsSpent.toLocaleString()}</div>
                        </div>
                        <div>
                          <div className="text-gray-400 text-[10px] font-bold uppercase tracking-wider mb-0.5">Remaining</div>
                          <div className="font-bold text-base text-emerald-400">{coinsRemaining.toLocaleString()}</div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="mb-4">
                    <div className="flex justify-between text-xs text-gray-500 mb-1.5">
                      <span>Budget Used</span>
                      <span className="font-bold">{spendPct}%</span>
                    </div>
                    <div className="w-full bg-gray-100 dark:bg-gray-800 rounded-full h-2">
                      <div className="h-2 rounded-full bg-gradient-to-r from-orange-500 to-pink-500 transition-all" style={{ width: `${spendPct}%` }} />
                    </div>
                  </div>
                  {/* Extended budget fields */}
                  {ad.budget?.daily_budget_coins > 0 && (
                    <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400 py-2.5 border-t border-gray-100 dark:border-gray-800">
                      <span className="flex items-center gap-1.5"><CalendarClock className="w-3.5 h-3.5" /> Daily Limit</span>
                      <span className="font-semibold text-gray-800 dark:text-white">{ad.budget.daily_budget_coins.toLocaleString()} 🪙</span>
                    </div>
                  )}
                  {ad.budget?.start_date && (
                    <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400 py-2.5 border-t border-gray-100 dark:border-gray-800">
                      <span className="flex items-center gap-1.5"><Calendar className="w-3.5 h-3.5" /> Start Date</span>
                      <span className="font-semibold text-gray-800 dark:text-white">{new Date(ad.budget.start_date).toLocaleDateString("en-IN")}</span>
                    </div>
                  )}
                  {ad.budget?.end_date && (
                    <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400 py-2.5 border-t border-gray-100 dark:border-gray-800">
                      <span className="flex items-center gap-1.5"><Calendar className="w-3.5 h-3.5" /> End Date</span>
                      <span className="font-semibold text-gray-800 dark:text-white">{new Date(ad.budget.end_date).toLocaleDateString("en-IN")}</span>
                    </div>
                  )}
                  <div className="pt-3 border-t border-gray-100 dark:border-gray-800">
                    <div className="flex justify-between text-sm text-gray-500 dark:text-gray-400">
                      <span>Coins Reward</span>
                      <span className="font-semibold text-gray-800 dark:text-white">{ad.coins_reward ?? 0}</span>
                    </div>
                  </div>
                </Card>

                {/* Engagement Pie */}
                <Card title="Engagement Breakdown">
                  {engagementData.length > 0 ? (
                    <div className="h-52 w-full">
                      <ResponsiveContainer width="100%" height="100%">
                        <PieChart>
                          <Pie data={engagementData} cx="50%" cy="50%" innerRadius={50} outerRadius={70} paddingAngle={5} dataKey="value">
                            {engagementData.map((_, index) => <Cell key={index} fill={COLORS[index % COLORS.length]} />)}
                          </Pie>
                          <Tooltip contentStyle={{ borderRadius: "8px" }} />
                          <Legend verticalAlign="bottom" height={36} iconType="circle" />
                        </PieChart>
                      </ResponsiveContainer>
                    </div>
                  ) : (
                    <div className="text-center py-8 text-gray-400">
                      <BarChart2 className="w-8 h-8 mx-auto mb-2 opacity-30" />
                      <p className="text-sm">No engagement data yet</p>
                    </div>
                  )}
                </Card>

                {/* CTA Card */}
                {ad.cta && ad.cta.type && (
                  <Card title="Call-To-Action" icon={MousePointerClick}>
                    <div className="space-y-3">
                      <div className="flex items-center justify-between p-3.5 rounded-xl bg-indigo-50 dark:bg-indigo-900/20 border border-indigo-100 dark:border-indigo-900">
                        <span className="text-xs font-bold text-indigo-500 uppercase tracking-wider">CTA Type</span>
                        <span className="text-sm font-bold text-indigo-700 dark:text-indigo-300 capitalize">{(ad.cta.type || "").replace("_", " ")}</span>
                      </div>
                      {ad.cta.url && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <Link2 className="w-3.5 h-3.5" /> URL
                          </div>
                          <a href={ad.cta.url} target="_blank" rel="noopener noreferrer"
                            className="text-xs text-blue-600 dark:text-blue-400 font-semibold hover:underline max-w-[160px] truncate">
                            {ad.cta.url}
                          </a>
                        </div>
                      )}
                      {ad.cta.deep_link && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <Smartphone className="w-3.5 h-3.5" /> Deep Link
                          </div>
                          <span className="text-xs text-gray-700 dark:text-gray-300 font-mono max-w-[160px] truncate">{ad.cta.deep_link}</span>
                        </div>
                      )}
                      {ad.cta.phone_number && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <Phone className="w-3.5 h-3.5" /> Phone
                          </div>
                          <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">{ad.cta.phone_number}</span>
                        </div>
                      )}
                      {ad.cta.whatsapp_number && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-green-50 dark:bg-green-900/20 border border-green-100 dark:border-green-900">
                          <div className="flex items-center gap-2 text-xs font-bold text-green-600 uppercase tracking-wide">
                            <MessageSquare className="w-3.5 h-3.5" /> WhatsApp
                          </div>
                          <span className="text-xs font-semibold text-green-700 dark:text-green-400">{ad.cta.whatsapp_number}</span>
                        </div>
                      )}
                      {ad.cta.email && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide">
                            <Mail className="w-3.5 h-3.5" /> Email
                          </div>
                          <span className="text-xs font-semibold text-gray-700 dark:text-gray-300">{ad.cta.email}</span>
                        </div>
                      )}
                    </div>
                  </Card>
                )}

                {/* Tracking / UTM */}
                {ad.tracking && (ad.tracking.utm_source || ad.tracking.utm_campaign || ad.tracking.conversion_pixel_id) && (
                  <Card title="Tracking & UTM" icon={Target}>
                    <div className="space-y-2">
                      {[
                        { label: "Source",    value: ad.tracking.utm_source    },
                        { label: "Medium",    value: ad.tracking.utm_medium    },
                        { label: "Campaign",  value: ad.tracking.utm_campaign  },
                        { label: "Term",      value: ad.tracking.utm_term      },
                        { label: "Content",   value: ad.tracking.utm_content   },
                        { label: "Pixel ID",  value: ad.tracking.conversion_pixel_id },
                      ].filter(r => r.value).map((row, i) => (
                        <div key={i} className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <span className="text-xs font-bold text-gray-500 uppercase tracking-wider">UTM {row.label}</span>
                          <span className="text-xs font-mono font-semibold text-gray-700 dark:text-gray-300 max-w-[160px] truncate">{row.value}</span>
                        </div>
                      ))}
                    </div>
                  </Card>
                )}

                {/* A/B Testing */}
                {ad.ab_testing?.enabled && (ad.ab_testing.variants || []).length > 0 && (
                  <Card title="A/B Testing" icon={TestTube2}>
                    <div className="space-y-3">
                      <div className="flex items-center gap-2 p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-900/20 border border-emerald-100 dark:border-emerald-900">
                        <div className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                        <span className="text-xs font-bold text-emerald-700 dark:text-emerald-400">A/B Test Active — {ad.ab_testing.variants.length} variants</span>
                      </div>
                      {ad.ab_testing.variants.map((v, i) => (
                        <div key={i} className="p-3 rounded-xl border border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
                          <div className="text-xs font-bold text-gray-500 mb-1.5">Variant {i + 1}: {v.variant_id}</div>
                          {v.ad_title && <div className="text-sm font-semibold text-gray-800 dark:text-gray-200 truncate">{v.ad_title}</div>}
                          {v.ad_description && <div className="text-xs text-gray-400 mt-0.5 truncate">{v.ad_description}</div>}
                        </div>
                      ))}
                    </div>
                  </Card>
                )}

                {/* Scheduling */}
                {(ad.scheduling?.delivery_time_slots || []).length > 0 && (
                  <Card title="Delivery Schedule" icon={CalendarClock}>
                    <div className="space-y-2">
                      {ad.scheduling.delivery_time_slots.map((slot, i) => (
                        <div key={i} className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50 border border-gray-100 dark:border-gray-800">
                          <span className="text-xs font-bold text-gray-700 dark:text-gray-300 capitalize">{slot.day_of_week}</span>
                          <span className="text-xs font-mono text-indigo-600 dark:text-indigo-400 font-semibold">
                            {slot.start_time} – {slot.end_time}
                          </span>
                        </div>
                      ))}
                    </div>
                  </Card>
                )}

                {/* Views Breakdown */}
                <Card title="Views Breakdown">
                  <div className="space-y-2">
                    {[
                      { label: "Total Views",     value: ad.views_count           || 0, color: "bg-blue-500"   },
                      { label: "Unique Views",    value: ad.unique_views_count    || 0, color: "bg-purple-500" },
                      { label: "Completed Views", value: ad.completed_views_count || 0, color: "bg-green-500"  },
                    ].map((item, i) => (
                      <div key={i} className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                        <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                          <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${item.color}`} />
                          {item.label}
                        </div>
                        <span className="font-bold text-sm text-gray-900 dark:text-white">{item.value.toLocaleString()}</span>
                      </div>
                    ))}
                  </div>
                </Card>

                {/* Action Breakdown */}
                {walletHistory?.actions && (
                  <Card title="Action Breakdown">
                    <div className="space-y-2">
                      {[
                        { label: "Views",    data: walletHistory.actions.views,    color: "bg-blue-500",   icon: "👁️" },
                        { label: "Likes",    data: walletHistory.actions.likes,    color: "bg-pink-500",   icon: "❤️" },
                        { label: "Comments", data: walletHistory.actions.comments, color: "bg-orange-500", icon: "💬" },
                        { label: "Replies",  data: walletHistory.actions.replies,  color: "bg-purple-500", icon: "↩️" },
                        { label: "Saves",    data: walletHistory.actions.saves,    color: "bg-green-500",  icon: "🔖" },
                        { label: "Refunds",  data: walletHistory.actions.refunds,  color: "bg-red-500",    icon: "↩"  },
                      ].filter(a => a.data?.count > 0).map((item, i) => (
                        <div key={i} className="flex items-center justify-between p-3 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                          <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                            <div className={`w-2.5 h-2.5 rounded-full flex-shrink-0 ${item.color}`} />
                            <span>{item.icon} {item.label}</span>
                            <span className="text-xs text-gray-400">×{item.data.count}</span>
                          </div>
                          <span className="font-bold text-sm text-amber-600 dark:text-amber-400 flex items-center gap-1">
                            <Coins className="w-3.5 h-3.5" />{item.data.total_coins.toLocaleString()}
                          </span>
                        </div>
                      ))}
                      {walletHistory.unique_users > 0 && (
                        <div className="flex items-center justify-between p-3 rounded-xl bg-indigo-50 dark:bg-indigo-900/20 mt-2">
                          <div className="flex items-center gap-2 text-sm text-indigo-600 dark:text-indigo-400">
                            <UserCheck className="w-4 h-4" /> Unique Users Reached
                          </div>
                          <span className="font-bold text-sm text-indigo-700 dark:text-indigo-300">{walletHistory.unique_users.toLocaleString()}</span>
                        </div>
                      )}
                    </div>
                  </Card>
                )}

                {/* Likes & Dislikes list */}
                <Card title={`Likes (${ad.likes_count || 0})`}
                  action={likesList.length > 8 && (
                    <button onClick={() => setShowAllLikes(v => !v)} className="text-xs font-semibold text-blue-600 dark:text-blue-400 hover:underline">
                      {showAllLikes ? "Show Less" : `View All ${likesList.length}`}
                    </button>
                  )}>
                  {likesList.length === 0 ? (
                    <div className="text-center py-6 text-gray-400">
                      <Heart className="w-7 h-7 mx-auto mb-2 opacity-30" />
                      <p className="text-sm">No likes yet</p>
                    </div>
                  ) : (
                    <div className="flex flex-col gap-1.5">
                      {visibleLikes.map((like, i) => {
                        const u    = like.user_id || like.user || like;
                        const name = u.full_name || u.username || `User ${i + 1}`;
                        return (
                          <div key={like._id || i} className="flex items-center gap-2.5 p-2 rounded-xl bg-gray-50 dark:bg-gray-800/50 hover:bg-pink-50 dark:hover:bg-pink-900/10 transition-colors">
                            <Avatar name={name} url={u.avatar_url || ""} size="w-7 h-7" textSize="text-[10px]" />
                            <div className="min-w-0 flex-1">
                              <div className="text-xs font-semibold text-gray-900 dark:text-white truncate">{name}</div>
                              {u.username && <div className="text-[10px] text-gray-400 truncate">@{u.username}</div>}
                            </div>
                            <Heart className="w-3 h-3 text-pink-500 flex-shrink-0" />
                          </div>
                        );
                      })}
                    </div>
                  )}
                  {dislikesList.length > 0 && (
                    <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-800">
                      <div className="flex items-center gap-2 text-xs font-bold text-gray-500 uppercase tracking-wide mb-2">
                        <ThumbsDown className="w-3.5 h-3.5 text-red-400" /> Dislikes ({ad.dislikes_count || dislikesList.length})
                      </div>
                      <div className="flex flex-col gap-1.5">
                        {dislikesList.slice(0, 6).map((dislike, i) => {
                          const u    = dislike.user_id || dislike.user || dislike;
                          const name = u.full_name || u.username || `User ${i + 1}`;
                          return (
                            <div key={dislike._id || i} className="flex items-center gap-2.5 p-2 rounded-xl bg-gray-50 dark:bg-gray-800/50">
                              <Avatar name={name} url={u.avatar_url || ""} size="w-7 h-7" textSize="text-[10px]" />
                              <div className="min-w-0 flex-1">
                                <div className="text-xs font-semibold text-gray-900 dark:text-white truncate">{name}</div>
                                {u.username && <div className="text-[10px] text-gray-400 truncate">@{u.username}</div>}
                              </div>
                              <ThumbsDown className="w-3 h-3 text-red-400 flex-shrink-0" />
                            </div>
                          );
                        })}
                      </div>
                    </div>
                  )}
                </Card>
              </div>
            </div>
          )}

          {/* ══ STATS & ANALYTICS TAB ══════════════════════════════════════════ */}
          {activeTab === "stats" && <StatsSection adId={adId} />}

          {/* ── Transaction History (always visible) ─────────────────────────── */}
          <div className="mt-8">
            <div className="bg-white dark:bg-gray-900 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm overflow-hidden">
              <div className="flex items-center justify-between px-6 py-4 border-b border-gray-100 dark:border-gray-800">
                <div>
                  <h2 className="text-base font-bold text-gray-900 dark:text-white flex items-center gap-2">
                    <Activity className="w-4 h-4 text-pink-500" /> Transaction History
                  </h2>
                  <p className="text-xs text-gray-400 mt-0.5">All coin movements for this ad</p>
                </div>
                {walletHistory?.budget && (
                  <div className="flex items-center gap-6 text-sm">
                    <div className="text-right">
                      <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold">Budget</div>
                      <div className="font-bold text-gray-900 dark:text-white flex items-center gap-1">
                        <Coins className="w-3.5 h-3.5 text-yellow-500" />
                        {(walletHistory.budget.total_budget_coins || 0).toLocaleString()}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold">Spent</div>
                      <div className="font-bold text-red-500 flex items-center gap-1">
                        <TrendingDown className="w-3.5 h-3.5" />
                        {(walletHistory.budget.total_coins_spent || 0).toLocaleString()}
                      </div>
                    </div>
                    <div className="text-right">
                      <div className="text-[10px] text-gray-400 uppercase tracking-wider font-bold">Remaining</div>
                      <div className="font-bold text-green-600 flex items-center gap-1">
                        <TrendingUp className="w-3.5 h-3.5" />
                        {(walletHistory.budget.balance_remaining || 0).toLocaleString()}
                      </div>
                    </div>
                    <div className="w-28">
                      <div className="flex justify-between text-[10px] text-gray-400 mb-1">
                        <span>Used</span>
                        <span className="font-bold">{Math.round(walletHistory.budget.spent_percentage || 0)}%</span>
                      </div>
                      <div className="h-1.5 rounded-full bg-gray-100 dark:bg-gray-800 overflow-hidden">
                        <div className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-500"
                          style={{ width: `${Math.min(100, walletHistory.budget.spent_percentage || 0)}%` }} />
                      </div>
                    </div>
                  </div>
                )}
              </div>

              {walletLoading ? (
                <div className="flex items-center justify-center py-14 gap-3">
                  <RefreshCw className="w-6 h-6 animate-spin text-pink-500" />
                  <span className="text-sm text-gray-400">Loading transactions…</span>
                </div>
              ) : walletError ? (
                <div className="flex items-center justify-center py-14 gap-3 text-red-500">
                  <AlertCircle className="w-5 h-5" />
                  <span className="text-sm">{walletError}</span>
                </div>
              ) : !walletHistory?.transactions?.length ? (
                <div className="flex flex-col items-center justify-center py-14 gap-3 text-gray-400">
                  <Wallet className="w-10 h-10 opacity-30" />
                  <p className="text-sm font-medium">No transactions yet</p>
                </div>
              ) : (
                <div className="overflow-x-auto">
                  <table className="w-full text-left">
                    <thead>
                      <tr className="border-b border-gray-100 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50">
                        {["User", "Transaction", "Amount", "Direction", "Status", "Date"].map(h => (
                          <th key={h} className="px-5 py-3 text-[10px] font-bold uppercase tracking-wider text-gray-400">{h}</th>
                        ))}
                      </tr>
                    </thead>
                    <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                      {walletHistory.transactions.map((tx) => {
                        const u = tx.user || {};
                        const userName = u.full_name || u.username || "User";
                        return (
                          <tr key={tx._id} className="hover:bg-gray-50 dark:hover:bg-gray-800/40 transition-colors">
                            <td className="px-5 py-3">
                              <div className="flex items-center gap-2.5">
                                {u.avatar_url ? (
                                  <img src={u.avatar_url} alt={userName} className="w-8 h-8 rounded-full object-cover flex-shrink-0" />
                                ) : (
                                  <div className="w-8 h-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold flex-shrink-0">
                                    {userName[0]?.toUpperCase()}
                                  </div>
                                )}
                                <div className="min-w-0">
                                  <div className="text-xs font-semibold text-gray-900 dark:text-white truncate">{userName}</div>
                                  {u.username && <div className="text-[10px] text-gray-400 truncate">@{u.username}</div>}
                                </div>
                              </div>
                            </td>
                            <td className="px-5 py-3">
                              <div className="text-xs font-semibold text-gray-800 dark:text-gray-200">{tx.label || tx.type || "—"}</div>
                              {tx.description && <div className="text-[10px] text-gray-400 mt-0.5 max-w-[180px] truncate">{tx.description}</div>}
                            </td>
                            <td className="px-5 py-3">
                              <span className={`text-sm font-bold flex items-center gap-1 ${tx.direction === "credit" ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"}`}>
                                <Coins className="w-3.5 h-3.5 text-yellow-500" />
                                {tx.direction === "credit" ? "+" : "-"}{Number(tx.amount).toLocaleString()}
                              </span>
                            </td>
                            <td className="px-5 py-3">
                              <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-bold ${
                                tx.direction === "credit"
                                  ? "bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400"
                                  : "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400"}`}>
                                {tx.direction === "credit" ? <ArrowDownLeft className="w-3 h-3" /> : <ArrowUpRight className="w-3 h-3" />}
                                {tx.direction === "credit" ? "Credit" : "Debit"}
                              </span>
                            </td>
                            <td className="px-5 py-3">
                              <span className={`inline-flex items-center gap-1 text-xs font-semibold ${
                                tx.status === "SUCCESS" ? "text-green-600 dark:text-green-400"
                                : tx.status === "FAILED" ? "text-red-600 dark:text-red-400"
                                : "text-amber-600 dark:text-amber-400"}`}>
                                {tx.status === "SUCCESS" ? "✓" : tx.status === "FAILED" ? "✗" : "⏳"} {tx.status}
                              </span>
                            </td>
                            <td className="px-5 py-3 text-xs text-gray-400 whitespace-nowrap">
                              {tx.created_at ? new Date(tx.created_at).toLocaleString("en-IN", {
                                day: "2-digit", month: "short", year: "numeric", hour: "2-digit", minute: "2-digit"
                              }) : "—"}
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              )}

              {/* Pagination */}
              {(() => {
                const txTotal = walletHistory?.pagination?.total ?? (walletHistory?.transactions?.length ?? 0);
                const totalPg = Math.ceil(txTotal / WALLET_PER_PAGE);
                if (!walletHistory || totalPg <= 1) return null;
                const windowSize = Math.min(5, totalPg);
                let start = Math.max(1, walletPage - Math.floor(windowSize / 2));
                let end   = start + windowSize - 1;
                if (end > totalPg) { end = totalPg; start = Math.max(1, end - windowSize + 1); }
                const pages = Array.from({ length: end - start + 1 }, (_, i) => start + i);
                return (
                  <div className="flex items-center justify-between px-6 py-4 border-t border-gray-100 dark:border-gray-800">
                    <span className="text-xs text-gray-400">Page {walletPage} of {totalPg} · {txTotal} transactions</span>
                    <div className="flex items-center gap-1.5">
                      <button onClick={() => setWalletPage(p => Math.max(1, p - 1))} disabled={walletPage === 1 || walletLoading}
                        className="p-2 rounded-xl border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                        <ChevronLeft className="w-4 h-4" />
                      </button>
                      {pages.map(p => (
                        <button key={p} onClick={() => setWalletPage(p)}
                          className={`w-8 h-8 rounded-xl text-xs font-bold transition-colors ${
                            walletPage === p
                              ? "bg-gradient-to-r from-pink-600 to-orange-500 text-white shadow-sm"
                              : "border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-300"}`}>
                          {p}
                        </button>
                      ))}
                      <button onClick={() => setWalletPage(p => Math.min(totalPg, p + 1))} disabled={walletPage === totalPg || walletLoading}
                        className="p-2 rounded-xl border border-gray-200 dark:border-gray-700 disabled:opacity-40 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                        <ChevronRight className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                );
              })()}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}