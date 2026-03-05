import { useState, useRef } from "react";


// ─── Reusable Field Components ───────────────────────────────────────────────

const Field = ({ label, children, required, span = 1 }) => (
  <div className={`col-span-${span} sm:col-span-${span}`}>
    <label className="block text-xs font-semibold mb-1.5 tracking-wide text-gray-500 dark:text-gray-400">
      {label}{required && <span className="text-insta-pink ml-1">*</span>}
    </label>
    {children}
  </div>
);

const Input = ({ type = "text", placeholder, value, onChange, disabled, icon }) => (
  <div className="relative">
    {icon && <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm opacity-50">{icon}</span>}
    <input
      type={type}
      placeholder={placeholder}
      value={value}
      onChange={onChange}
      disabled={disabled}
      className={`w-full px-3.5 py-2.5 rounded-xl text-sm transition-all outline-none 
        bg-gray-50 dark:bg-gray-900 
        border border-gray-200 dark:border-gray-800 
        text-gray-900 dark:text-white 
        placeholder:text-gray-400 dark:placeholder:text-gray-600
        focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink
        disabled:opacity-60 disabled:cursor-not-allowed
        ${icon ? 'pl-9' : ''}
      `}
    />
  </div>
);

const Select = ({ options, value, onChange, disabled, placeholder }) => (
  <select 
    value={value} 
    onChange={onChange} 
    disabled={disabled} 
    className="w-full px-3.5 py-2.5 rounded-xl text-sm transition-all outline-none 
      bg-gray-50 dark:bg-gray-900 
      border border-gray-200 dark:border-gray-800 
      text-gray-900 dark:text-white 
      focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink
      disabled:opacity-60 disabled:cursor-not-allowed appearance-none"
  >
    {placeholder && <option value="">{placeholder}</option>}
    {options.map(o => <option key={o} value={o}>{o}</option>)}
  </select>
);

const Textarea = ({ placeholder, value, onChange, disabled, rows = 4 }) => (
  <textarea
    placeholder={placeholder}
    value={value}
    onChange={onChange}
    disabled={disabled}
    rows={rows}
    className="w-full px-3.5 py-2.5 rounded-xl text-sm transition-all outline-none 
      bg-gray-50 dark:bg-gray-900 
      border border-gray-200 dark:border-gray-800 
      text-gray-900 dark:text-white 
      placeholder:text-gray-400 dark:placeholder:text-gray-600
      focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink
      disabled:opacity-60 disabled:cursor-not-allowed resize-y"
  />
);

// ─── Completion Bar ───────────────────────────────────────────────────────────
const CompletionBar = ({ pct }) => (
  <div className="p-4 md:p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
    <div className="flex justify-between items-center mb-2">
      <span className="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Profile Completion</span>
      <span className="text-sm font-bold bg-clip-text text-transparent bg-gradient-to-r from-orange-500 to-pink-600">
        {pct}%
      </span>
    </div>
    <div className="h-1.5 w-full bg-gray-100 dark:bg-gray-800 rounded-full overflow-hidden">
      <div 
        className="h-full rounded-full bg-gradient-to-r from-orange-500 to-pink-600 transition-all duration-500 ease-out" 
        style={{ width: `${pct}%` }} 
      />
    </div>
    {pct < 100 && (
      <p className="text-xs mt-2 text-gray-400 dark:text-gray-500">
        Complete all fields to submit for verification
      </p>
    )}
  </div>
);

// ─── Status Badge ─────────────────────────────────────────────────────────────
const Badge = ({ status }) => {
  const styles = {
    verified: "bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400",
    pending: "bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400",
    draft: "bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400",
  };
  const label = { verified: "Verified ✓", pending: "Pending Review", draft: "Draft" };
  
  return (
    <span className={`text-[10px] font-bold px-2.5 py-1 rounded-full uppercase tracking-wider ${styles[status] || styles.draft}`}>
      {label[status] || label.draft}
    </span>
  );
};

// ─── Sub Tab: Company Information ────────────────────────────────────────────
const CompanyInfo = () => {
  const [editing, setEditing] = useState(false);
  const [saved, setSaved] = useState(false);
  const [logoPreview, setLogoPreview] = useState(null);
  const fileRef = useRef();

  const [form, setForm] = useState({
    companyName: "Pixel Media Pvt. Ltd.",
    registeredName: "Pixel Media Private Limited",
    regNumber: "U74999MH2018PTC123456",
    taxId: "27AABCU9603R1ZX",
    yearEstablished: "2018",
    companyType: "Private Limited",
    industry: "Digital Marketing",
    businessNature: "Advertising Agency",
    website: "https://pixelmedia.in",
    email: "hello@pixelmedia.in",
    phone: "+91 98765 43210",
    address: "304, Nucleus Mall, Link Road, Andheri West, Mumbai – 400053",
    country: "India",
    coverage: "Pan India",
    description: "Pixel Media is a full-service digital advertising agency specializing in social media campaigns, influencer marketing, and performance ads across major platforms.",
    instagram: "https://instagram.com/pixelmedia",
    facebook: "https://facebook.com/pixelmedia",
    linkedin: "https://linkedin.com/company/pixelmedia",
    twitter: "",
  });

  const set = (k) => (e) => setForm((p) => ({ ...p, [k]: e.target.value }));

  const handleSave = () => {
    setSaved(true);
    setEditing(false);
    setTimeout(() => setSaved(false), 3000);
  };

  const handleLogo = (e) => {
    const f = e.target.files[0];
    if (f) setLogoPreview(URL.createObjectURL(f));
  };

  const filled = Object.values(form).filter(Boolean).length;
  const pct = Math.round((filled / Object.keys(form).length) * 100);

  const D = !editing;

  return (
    <div className="space-y-6">
      {/* Header row */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Company Information</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage your official business profile and registration details.</p>
        </div>
        <div className="flex items-center gap-3">
          <Badge status="verified" />
          {!editing ? (
            <button 
              onClick={() => setEditing(true)}
              className="px-4 py-2 rounded-xl text-sm font-semibold border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
            >
              ✏️ Edit Profile
            </button>
          ) : (
            <div className="flex gap-2">
              <button 
                onClick={() => setEditing(false)}
                className="px-3 py-2 rounded-xl text-sm font-medium text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
              >
                Cancel
              </button>
              <button 
                onClick={handleSave}
                className="px-4 py-2 rounded-xl text-sm font-semibold bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-lg shadow-pink-500/20 hover:shadow-pink-500/30 transition-all"
              >
                Save Changes
              </button>
            </div>
          )}
        </div>
      </div>

      {saved && (
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-600 dark:text-green-400 px-4 py-3 rounded-xl text-sm font-semibold flex items-center gap-2 animate-fade-in">
          ✅ Profile submitted for verification. Admin review in 24–48 hrs.
        </div>
      )}

      <CompletionBar pct={pct} />

      {/* Logo Upload */}
      <div className="flex items-center gap-5 p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800">
        <div
          onClick={() => editing && fileRef.current.click()}
          className={`w-20 h-20 rounded-2xl flex items-center justify-center overflow-hidden flex-shrink-0 bg-gray-100 dark:bg-gray-800 transition-all
            ${editing ? "cursor-pointer ring-2 ring-dashed ring-pink-500/50 hover:bg-gray-200 dark:hover:bg-gray-700" : ""}
          `}
        >
          {logoPreview
            ? <img src={logoPreview} alt="logo" className="w-full h-full object-cover" />
            : <span className="text-3xl">🏢</span>}
        </div>
        <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={handleLogo} />
        <div>
          <div className="text-base font-bold text-gray-900 dark:text-white">{form.companyName}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">{form.industry} · {form.country}</div>
          {editing && (
            <button 
              onClick={() => fileRef.current.click()}
              className="text-xs font-semibold text-pink-600 dark:text-pink-400 mt-2 hover:underline"
            >
              Change Logo
            </button>
          )}
        </div>
      </div>

      {/* Form Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-x-5 gap-y-5">

        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-2">
          Registration Details
        </div>

        <Field label="Company Name" required span={1}><Input value={form.companyName} onChange={set("companyName")} disabled={D} placeholder="Company Name" /></Field>
        <Field label="Registered Name" required span={1}><Input value={form.registeredName} onChange={set("registeredName")} disabled={D} placeholder="Legal registered name" /></Field>
        <Field label="Registration Number" span={1}><Input value={form.regNumber} onChange={set("regNumber")} disabled={D} placeholder="CIN / Reg. No." /></Field>
        <Field label="Tax ID / VAT / GST" span={1}><Input value={form.taxId} onChange={set("taxId")} disabled={D} placeholder="GSTIN / VAT ID" /></Field>
        <Field label="Year Established" span={1}>
          <Select value={form.yearEstablished} onChange={set("yearEstablished")} disabled={D}
            options={Array.from({ length: 50 }, (_, i) => String(2024 - i))} placeholder="Select year" />
        </Field>
        <Field label="Company Type" span={1}>
          <Select value={form.companyType} onChange={set("companyType")} disabled={D}
            options={["Private Limited", "Public Limited", "LLP", "Partnership", "Sole Proprietorship", "NGO / Trust"]} placeholder="Select type" />
        </Field>

        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Business Details
        </div>

        <Field label="Industry Category" span={1}>
          <Select value={form.industry} onChange={set("industry")} disabled={D}
            options={["Digital Marketing", "E-Commerce", "FMCG", "Healthcare", "Education", "Finance", "Real Estate", "Technology", "Retail", "Other"]} placeholder="Select industry" />
        </Field>
        <Field label="Business Nature" span={1}>
          <Select value={form.businessNature} onChange={set("businessNature")} disabled={D}
            options={["Advertising Agency", "Brand / Advertiser", "Publisher", "Influencer Network", "Reseller", "Technology Partner"]} placeholder="Select nature" />
        </Field>
        <Field label="Service Coverage" span={1}>
          <Select value={form.coverage} onChange={set("coverage")} disabled={D}
            options={["Pan India", "Regional", "City-Level", "International"]} placeholder="Select coverage" />
        </Field>
        <Field label="Country" span={1}>
          <Select value={form.country} onChange={set("country")} disabled={D}
            options={["India", "United States", "United Kingdom", "UAE", "Singapore", "Australia", "Canada"]} placeholder="Select country" />
        </Field>

        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Contact & Online Presence
        </div>

        <Field label="Website URL" span={1}><Input type="url" value={form.website} onChange={set("website")} disabled={D} icon="🌐" placeholder="https://yourwebsite.com" /></Field>
        <Field label="Company Email" required span={1}><Input type="email" value={form.email} onChange={set("email")} disabled={D} icon="✉️" placeholder="company@email.com" /></Field>
        <Field label="Phone Number" span={1}><Input type="tel" value={form.phone} onChange={set("phone")} disabled={D} icon="📞" placeholder="+91 00000 00000" /></Field>
        <Field label="Address" span={2}><Textarea value={form.address} onChange={set("address")} disabled={D} placeholder="Full business address..." rows={3} /></Field>

        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Company Description
        </div>
        <Field label="About the Company" span={2}><Textarea value={form.description} onChange={set("description")} disabled={D} rows={4} placeholder="Describe what your company does, services offered, target audience..." /></Field>

        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Social Media Links
        </div>
        <Field label="Instagram" span={1}><Input type="url" value={form.instagram} onChange={set("instagram")} disabled={D} icon="📸" placeholder="https://instagram.com/..." /></Field>
        <Field label="Facebook" span={1}><Input type="url" value={form.facebook} onChange={set("facebook")} disabled={D} icon="👤" placeholder="https://facebook.com/..." /></Field>
        <Field label="LinkedIn" span={1}><Input type="url" value={form.linkedin} onChange={set("linkedin")} disabled={D} icon="💼" placeholder="https://linkedin.com/..." /></Field>
        <Field label="Twitter / X" span={1}><Input type="url" value={form.twitter} onChange={set("twitter")} disabled={D} icon="🐦" placeholder="https://twitter.com/..." /></Field>
      </div>
    </div>
  );
};

// ─── Sub Tab: Primary Contact ─────────────────────────────────────────────────
const PrimaryContact = () => {
  const [contacts, setContacts] = useState([
    { id: 1, name: "Rahul Sharma", role: "Marketing Head", dept: "Marketing", email: "rahul@pixelmedia.in", mobile: "+91 98765 43210", whatsapp: "+91 98765 43210", auth: "Admin", editing: false },
    { id: 2, name: "Priya Mehta", role: "Campaign Manager", dept: "Operations", email: "priya@pixelmedia.in", mobile: "+91 87654 32109", whatsapp: "", auth: "Marketing", editing: false },
  ]);

  const toggleEdit = (id) => setContacts(c => c.map(x => x.id === id ? { ...x, editing: !x.editing } : x));
  const remove = (id) => setContacts(c => c.filter(x => x.id !== id));
  const setField = (id, k, v) => setContacts(c => c.map(x => x.id === id ? { ...x, [k]: v } : x));

  const add = () => setContacts(c => [...c, { id: Date.now(), name: "", role: "", dept: "", email: "", mobile: "", whatsapp: "", auth: "Viewer", editing: true }]);

  const authColors = { 
    Admin: "bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400", 
    Marketing: "bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400", 
    Viewer: "bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400" 
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Primary Contact Persons</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage who handles communications and ad approvals.</p>
        </div>
        <button 
          onClick={add}
          className="px-4 py-2 rounded-xl text-sm font-semibold bg-gray-900 dark:bg-white text-white dark:text-black hover:opacity-90 transition-opacity"
        >
          + Add Contact
        </button>
      </div>

      <div className="grid gap-4">
        {contacts.map((c) => (
          <div key={c.id} className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 transition-all hover:border-gray-200 dark:hover:border-gray-700">
            <div className="flex flex-wrap justify-between items-start gap-4 mb-4">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 text-white font-bold text-lg flex items-center justify-center flex-shrink-0">
                  {c.name ? c.name[0].toUpperCase() : "?"}
                </div>
                {!c.editing && (
                  <div>
                    <div className="font-bold text-gray-900 dark:text-white">{c.name || "New Contact"}</div>
                    <div className="text-sm text-gray-500 dark:text-gray-400">{c.role} · {c.dept}</div>
                    <div className="flex flex-wrap gap-2 mt-2">
                      <span className={`text-[10px] font-bold px-2 py-0.5 rounded-md uppercase tracking-wider ${authColors[c.auth]}`}>
                        {c.auth}
                      </span>
                      <span className="text-xs text-gray-400 dark:text-gray-500 flex items-center gap-1">✉️ {c.email}</span>
                      <span className="text-xs text-gray-400 dark:text-gray-500 flex items-center gap-1">📱 {c.mobile}</span>
                    </div>
                  </div>
                )}
              </div>
              <div className="flex gap-2">
                <button 
                  onClick={() => toggleEdit(c.id)}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                >
                  {c.editing ? "✓ Save" : "✏️ Edit"}
                </button>
                <button 
                  onClick={() => remove(c.id)}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/30 transition-colors"
                >
                  🗑 Remove
                </button>
              </div>
            </div>

            {c.editing && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4 pt-4 border-t border-gray-100 dark:border-gray-800 animate-fade-in">
                <Field label="Full Name" required span={1}><Input value={c.name} onChange={e => setField(c.id, "name", e.target.value)} placeholder="Full Name" /></Field>
                <Field label="Role / Designation" span={1}><Input value={c.role} onChange={e => setField(c.id, "role", e.target.value)} placeholder="e.g. Marketing Head" /></Field>
                <Field label="Department" span={1}><Input value={c.dept} onChange={e => setField(c.id, "dept", e.target.value)} placeholder="e.g. Operations" /></Field>
                <Field label="Authorization Level" span={1}>
                  <Select value={c.auth} onChange={e => setField(c.id, "auth", e.target.value)} options={["Admin", "Marketing", "Viewer"]} />
                </Field>
                <Field label="Official Email" span={1}><Input type="email" value={c.email} onChange={e => setField(c.id, "email", e.target.value)} icon="✉️" placeholder="email@company.com" /></Field>
                <Field label="Mobile Number" span={1}><Input type="tel" value={c.mobile} onChange={e => setField(c.id, "mobile", e.target.value)} icon="📱" placeholder="+91 00000 00000" /></Field>
                <Field label="WhatsApp Number" span={1}><Input type="tel" value={c.whatsapp} onChange={e => setField(c.id, "whatsapp", e.target.value)} icon="💬" placeholder="+91 00000 00000" /></Field>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

// ─── Sub Tab: Sales Officer ───────────────────────────────────────────────────
const SalesOfficer = () => {
  const officer = {
    name: "Arjun Kapoor",
    empId: "EMP-20491",
    email: "arjun.kapoor@socialads.in",
    phone: "+91 99887 76655",
    assignedDate: "15 Jan 2024",
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Associated Sales Officer</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Your dedicated account manager from our sales team.</p>
        </div>
        <span className="text-[10px] font-bold px-3 py-1 rounded-full bg-gray-100 dark:bg-gray-800 text-gray-500 dark:text-gray-400 uppercase tracking-widest">
          Read Only
        </span>
      </div>

      <div className="flex flex-col md:flex-row gap-6 items-center p-6 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 shadow-sm">
        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-blue-500 to-indigo-600 flex items-center justify-center text-white font-bold text-2xl shadow-lg shadow-blue-500/20">
          A
        </div>
        <div className="flex-1 text-center md:text-left">
          <div className="text-xl font-bold text-gray-900 dark:text-white">{officer.name}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">Sales Account Manager · Employee ID: {officer.empId}</div>
          <div className="flex flex-wrap justify-center md:justify-start gap-4 mt-3">
            {[
              { icon: "✉️", val: officer.email },
              { icon: "📞", val: officer.phone },
              { icon: "📅", val: `Assigned: ${officer.assignedDate}` },
            ].map((item, i) => (
              <span key={i} className="text-xs font-medium text-gray-600 dark:text-gray-300 flex items-center gap-1.5 bg-gray-50 dark:bg-gray-800 px-2 py-1 rounded-lg border border-gray-100 dark:border-gray-700">
                <span>{item.icon}</span> {item.val}
              </span>
            ))}
          </div>
        </div>
        <div className="flex flex-col gap-2 min-w-[160px]">
          <button className="px-4 py-2 rounded-xl text-sm font-semibold bg-blue-600 text-white hover:bg-blue-700 transition-colors shadow-lg shadow-blue-500/20">
            ✉️ Email Officer
          </button>
          <button className="px-4 py-2 rounded-xl text-sm font-semibold bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors">
            🔄 Reassign
          </button>
        </div>
      </div>

      <div className="p-6 rounded-2xl bg-gray-50 dark:bg-gray-900/50 border border-gray-100 dark:border-gray-800">
        <div className="text-xs font-bold text-pink-600 uppercase tracking-widest mb-4">Officer Details</div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {[
            ["Sales Officer Name", officer.name],
            ["Employee ID", officer.empId],
            ["Email Address", officer.email],
            ["Phone Number", officer.phone],
            ["Assigned Since", officer.assignedDate],
          ].map(([label, value]) => (
            <div key={label}>
              <div className="text-[10px] font-bold text-gray-400 dark:text-gray-500 uppercase tracking-wider mb-1">{label}</div>
              <div className="text-sm font-semibold text-gray-900 dark:text-white">{value}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
};

// ─── Root Component ───────────────────────────────────────────────────────────
export default function VendorProfile() {
  const [tab, setTab] = useState(0);
  const tabs = ["🏢 Company Information", "👤 Primary Contact", "🤝 Sales Officer"];

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-black font-sans transition-colors duration-300">
    

      <div className="max-w-7xl mx-auto p-6 md:p-8">

        {/* Page Header */}
        <div className="mb-8 animate-fade-in">
          <h1 className="text-3xl md:text-4xl font-extrabold tracking-tight mb-2">
            <span className="bg-clip-text text-transparent bg-gradient-to-r from-orange-500 via-red-500 to-pink-600">
              Vendor Profile
            </span>
          </h1>
          <p className="text-gray-500 dark:text-gray-400">Manage your business identity, team, and account settings</p>
        </div>

        {/* Sub-Tabs */}
        <div className="flex flex-wrap gap-1 mb-8 p-1.5 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl w-fit shadow-sm">
          {tabs.map((t, i) => (
            <button
              key={i}
              onClick={() => setTab(i)}
              className={`px-4 py-2 rounded-xl text-sm font-bold transition-all duration-200 
                ${tab === i 
                  ? "bg-gray-900 dark:bg-white text-white dark:text-black shadow-md" 
                  : "text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-800"
                }`}
            >
              {t}
            </button>
          ))}
        </div>

        {/* Tab Content */}
        <div className="animate-fade-in">
          {tab === 0 && <CompanyInfo />}
          {tab === 1 && <PrimaryContact />}
          {tab === 2 && <SalesOfficer />}
        </div>

      </div>
    </div>
  );
}
