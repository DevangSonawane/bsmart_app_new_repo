import { useState, useRef, useEffect } from "react";
import { useSelector } from "react-redux";
import api from "../../lib/api";

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

const Select = ({ options, value, onChange, disabled, placeholder }) => {
  const [open, setOpen] = useState(false);
  const ref = useRef(null);
  useEffect(() => {
    const handler = (e) => {
      if (!ref.current || ref.current.contains(e.target)) return;
      setOpen(false);
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);
  const current = value || "";
  const choose = (v) => {
    onChange({ target: { value: v } });
    setOpen(false);
  };
  const display = current || placeholder || "Select";
  return (
    <div className="relative" ref={ref}>
      <button
        type="button"
        disabled={disabled}
        onClick={() => !disabled && setOpen((v) => !v)}
        className="w-full px-3.5 py-2.5 rounded-xl text-sm transition-all outline-none 
          bg-gray-50 dark:bg-gray-900 
          border border-gray-200 dark:border-gray-800 
          text-gray-900 dark:text-white 
          placeholder:text-gray-400 dark:placeholder:text-gray-600
          focus:ring-2 focus:ring-insta-pink/20 focus:border-insta-pink
          disabled:opacity-60 disabled:cursor-not-allowed
          flex items-center justify-between"
      >
        <span className={`${current ? "" : "text-gray-400 dark:text-gray-600"}`}>{display}</span>
        <svg
          className={`w-4 h-4 ml-2 transition-transform ${open ? "rotate-180" : ""}`}
          viewBox="0 0 20 20"
          fill="currentColor"
          aria-hidden="true"
        >
          <path fillRule="evenodd" d="M5.23 7.21a.75.75 0 011.06.02L10 10.94l3.71-3.71a.75.75 0 111.06 1.06l-4.24 4.24a.75.75 0 01-1.06 0L5.21 8.29a.75.75 0 01.02-1.08z" clipRule="evenodd" />
        </svg>
      </button>
      {open && !disabled && (
        <div className="absolute z-20 mt-2 w-full rounded-xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-lg">
          <div className="max-h-60 overflow-auto py-1">
            {placeholder && (
              <div
                onClick={() => choose("")}
                className={`px-3.5 py-2 text-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 ${current === "" ? "bg-insta-pink/10 text-insta-pink" : "text-gray-700 dark:text-gray-300"}`}
              >
                {placeholder}
              </div>
            )}
            {options.map((opt) => {
              const active = opt === current;
              return (
                <div
                  key={opt}
                  onClick={() => choose(opt)}
                  className={`px-3.5 py-2 text-sm cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800 ${active ? "bg-insta-pink/10 text-insta-pink" : "text-gray-700 dark:text-gray-300"}`}
                >
                  {opt}
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

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

// ─── Empty form defaults ──────────────────────────────────────────────────────
const EMPTY_FORM = {
  // from company_details (read-only display)
  companyName: "",
  registeredName: "",
  regNumber: "",
  taxId: "",
  yearEstablished: "",
  companyType: "",
  // from user_id (read-only display)
  userEmail: "",
  userPhone: "",
  userFullName: "",
  // editable — business_details
  industry: "",
  businessNature: "",
  coverage: "",
  country: "",
  // editable — online_presence
  website: "",
  email: "",
  phone: "",
  addressLine1: "",
  addressLine2: "",
  city: "",
  pincode: "",
  state: "",
  addressCountry: "",
  // editable — social_media_links
  instagram: "",
  facebook: "",
  linkedin: "",
  twitter: "",
  // editable — company_description
  description: "",
};

// ─── Map API response → form state ───────────────────────────────────────────
const mapApiToForm = (data) => ({
  // company_details (read-only)
  companyName:      data.company_details?.company_name     ?? "",
  registeredName:   data.company_details?.registered_name  ?? "",
  regNumber:        data.company_details?.registration_number ?? "",
  taxId:            data.company_details?.tax_id            ?? "",
  yearEstablished:  data.company_details?.year_established  ?? "",
  companyType:      data.company_details?.company_type      ?? "",
  // user_id info (read-only)
  userEmail:        data.user_id?.email                     ?? "",
  userPhone:        data.user_id?.phone                     ?? "",
  userFullName:     data.user_id?.full_name                 ?? "",
  // business_details
  industry:         data.business_details?.industry_category ?? "",
  businessNature:   data.business_details?.business_nature  ?? "",
  coverage:         data.business_details?.service_coverage  ?? "",
  country:          data.business_details?.country           ?? "",
  // online_presence
  website:          data.online_presence?.website_url        ?? "",
  email:            data.online_presence?.company_email      ?? "",
  phone:            data.online_presence?.phone_number       ?? "",
  addressLine1:     data.online_presence?.address?.address_line1 ?? "",
  addressLine2:     data.online_presence?.address?.address_line2 ?? "",
  city:             data.online_presence?.address?.city      ?? "",
  pincode:          data.online_presence?.address?.pincode   ?? "",
  state:            data.online_presence?.address?.state     ?? "",
  addressCountry:   data.online_presence?.address?.country   ?? "",
  // social_media_links
  instagram:        data.social_media_links?.instagram       ?? "",
  facebook:         data.social_media_links?.facebook        ?? "",
  linkedin:         data.social_media_links?.linkedin        ?? "",
  twitter:          data.social_media_links?.twitter         ?? "",
  // company_description
  description:      data.company_description                 ?? "",
  // meta
  profileCompletion: data.profile_completion_percentage      ?? 0,
});

// ─── Map form state → POST request body ──────────────────────────────────────
const mapFormToBody = (form) => ({
  business_details: {
    industry_category: form.industry       || "",
    business_nature:   form.businessNature || "",
    service_coverage:  form.coverage       || "",
    country:           form.country        || "",
  },
  online_presence: {
    website_url:    form.website  || "",
    company_email:  form.email    || "",
    phone_number:   form.phone    || "",
    address: {
      address_line1: form.addressLine1   || "",
      address_line2: form.addressLine2   || "",
      city:          form.city           || "",
      pincode:       form.pincode        || "",
      state:         form.state          || "",
      country:       form.addressCountry || "",
    },
  },
  social_media_links: {
    instagram: form.instagram || "",
    facebook:  form.facebook  || "",
    linkedin:  form.linkedin  || "",
    twitter:   form.twitter   || "",
  },
  company_description: form.description || "",
});

// ─── Sub Tab: Company Information ────────────────────────────────────────────
const CompanyInfo = () => {
  const { userObject } = useSelector((state) => state.auth);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [logoPreview, setLogoPreview] = useState(null);
  const fileRef = useRef();

  const [form, setForm] = useState(EMPTY_FORM);

  const userId = userObject?._id || userObject?.id;

  // ── Fetch profile ────────────────────────────────────────────────────────
  const fetchProfile = async () => {
    if (!userId) return;
    setLoading(true);
    setError("");
    try {
      const res = await api.get(`/vendors/profile/${userId}`);
      if (res.data) {
        setForm(mapApiToForm(res.data));
      }
    } catch (err) {
      console.error("Failed to fetch vendor profile:", err);
      setError("Failed to load profile. Please refresh.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchProfile();
  }, [userId]);

  const set = (k) => (e) => setForm((p) => ({ ...p, [k]: e.target.value }));

  // ── Save (POST) then re-fetch ────────────────────────────────────────────
  const handleSave = async () => {
    if (!userId) return;
    setSaving(true);
    setError("");
    try {
      await api.post(`/vendors/profile/${userId}`, mapFormToBody(form));
      await fetchProfile(); // re-fetch fresh data
      setSaved(true);
      setEditing(false);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      console.error("Failed to save vendor profile:", err);
      setError("Failed to save changes. Please try again.");
    } finally {
      setSaving(false);
    }
  };

  const handleLogo = (e) => {
    const f = e.target.files[0];
    if (f) setLogoPreview(URL.createObjectURL(f));
  };

  const D = !editing;
  const pct = form.profileCompletion;

  if (loading) {
    return (
      <div className="flex items-center justify-center py-20">
        <div className="flex flex-col items-center gap-3">
          <div className="w-8 h-8 border-2 border-pink-500 border-t-transparent rounded-full animate-spin" />
          <span className="text-sm text-gray-400 dark:text-gray-500">Loading profile...</span>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">

      {/* Header row */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Company Information</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage your business profile and registration details.</p>
        </div>
        <div className="flex items-center gap-3">
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
                onClick={() => { setEditing(false); setError(""); }}
                disabled={saving}
                className="px-3 py-2 rounded-xl text-sm font-medium text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors disabled:opacity-50"
              >
                Cancel
              </button>
              <button
                onClick={handleSave}
                disabled={saving}
                className="px-4 py-2 rounded-xl text-sm font-semibold bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-lg shadow-pink-500/20 hover:shadow-pink-500/30 transition-all disabled:opacity-60 flex items-center gap-2"
              >
                {saving && <span className="w-3.5 h-3.5 border-2 border-white border-t-transparent rounded-full animate-spin" />}
                {saving ? "Saving..." : "Save Changes"}
              </button>
            </div>
          )}
        </div>
      </div>

      {saved && (
        <div className="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-600 dark:text-green-400 px-4 py-3 rounded-xl text-sm font-semibold flex items-center gap-2 animate-fade-in">
          ✅ Profile updated successfully.
        </div>
      )}

      {error && (
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 px-4 py-3 rounded-xl text-sm font-semibold flex items-center gap-2">
          ⚠️ {error}
        </div>
      )}

      <CompletionBar pct={pct} />

      {/* Logo / Company header */}
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
          <div className="text-base font-bold text-gray-900 dark:text-white">{form.companyName || "—"}</div>
          <div className="text-sm text-gray-500 dark:text-gray-400 mt-0.5">
            {[form.userFullName, form.userEmail].filter(Boolean).join(" · ")}
          </div>
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

        {/* ── Registration Details (read-only from GET) ── */}
        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-2">
          Registration Details
        </div>

        <Field label="Company Name" required span={1}><Input value={form.companyName} disabled placeholder="Company Name" /></Field>
        <Field label="Registered Name" required span={1}><Input value={form.registeredName} disabled placeholder="Legal registered name" /></Field>
        <Field label="Registration Number" span={1}><Input value={form.regNumber} disabled placeholder="CIN / Reg. No." /></Field>
        <Field label="Tax ID / VAT / GST" span={1}><Input value={form.taxId} disabled placeholder="GSTIN / VAT ID" /></Field>
        <Field label="Year Established" span={1}><Input value={form.yearEstablished} disabled placeholder="Year" /></Field>
        <Field label="Company Type" span={1}><Input value={form.companyType} disabled placeholder="Company type" /></Field>

        {/* ── Business Details (editable) ── */}
        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Business Details
        </div>

        <Field label="Industry Category" span={1}>
          <Select value={form.industry} onChange={set("industry")} disabled={D}
            options={["Digital Marketing", "E-Commerce", "FMCG", "Healthcare", "Education", "Finance", "Real Estate", "Technology", "Retail", "Shoes", "Other"]}
            placeholder="Select industry" />
        </Field>
        <Field label="Business Nature" span={1}>
          <Select value={form.businessNature} onChange={set("businessNature")} disabled={D}
            options={["Advertising Agency", "Brand / Advertiser", "Publisher", "Influencer Network", "Reseller", "Technology Partner", "Manufacturer", "Retailer"]}
            placeholder="Select nature" />
        </Field>
        <Field label="Service Coverage" span={1}>
          <Select value={form.coverage} onChange={set("coverage")} disabled={D}
            options={["Pan India", "Regional", "City-Level", "International"]}
            placeholder="Select coverage" />
        </Field>
        <Field label="Country" span={1}>
          <Select value={form.country} onChange={set("country")} disabled={D}
            options={["India", "United States", "United Kingdom", "UAE", "Singapore", "Australia", "Canada"]}
            placeholder="Select country" />
        </Field>

        {/* ── Contact & Online Presence (editable) ── */}
        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Contact & Online Presence
        </div>

        <Field label="Website URL" span={1}><Input type="url" value={form.website} onChange={set("website")} disabled={D} icon="🌐" placeholder="https://yourwebsite.com" /></Field>
        <Field label="Company Email" required span={1}><Input type="email" value={form.email} onChange={set("email")} disabled={D} icon="✉️" placeholder="company@email.com" /></Field>
        <Field label="Phone Number" span={1}><Input type="tel" value={form.phone} onChange={set("phone")} disabled={D} icon="📞" placeholder="+91 00000 00000" /></Field>

        {/* Address fields */}
        <Field label="Address Line 1" span={1}><Input value={form.addressLine1} onChange={set("addressLine1")} disabled={D} placeholder="Street / Building" /></Field>
        <Field label="Address Line 2" span={1}><Input value={form.addressLine2} onChange={set("addressLine2")} disabled={D} placeholder="Area / Locality" /></Field>
        <Field label="City" span={1}><Input value={form.city} onChange={set("city")} disabled={D} placeholder="City" /></Field>
        <Field label="Pincode" span={1}><Input value={form.pincode} onChange={set("pincode")} disabled={D} placeholder="Pincode" /></Field>
        <Field label="State" span={1}><Input value={form.state} onChange={set("state")} disabled={D} placeholder="State" /></Field>
        <Field label="Address Country" span={1}><Input value={form.addressCountry} onChange={set("addressCountry")} disabled={D} placeholder="Country" /></Field>

        {/* ── Company Description (editable) ── */}
        <div className="col-span-1 md:col-span-2 text-xs font-bold text-pink-600 uppercase tracking-widest border-b border-pink-100 dark:border-pink-900/30 pb-2 mb-1 mt-4">
          Company Description
        </div>
        <Field label="About the Company" span={2}>
          <Textarea value={form.description} onChange={set("description")} disabled={D} rows={4}
            placeholder="Describe what your company does, services offered, target audience..." />
        </Field>

        {/* ── Social Media Links (editable) ── */}
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
  const { userObject } = useSelector((state) => state.auth);
  const userId = userObject?._id || userObject?.id;

  const [contacts, setContacts] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [addOpen, setAddOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [newContact, setNewContact] = useState({
    name: "",
    email: "",
    phone: "",
    position: "",
    notes: ""
  });
  const [addError, setAddError] = useState("");

  // Fetch contacts
  const fetchContacts = async () => {
    if (!userId) return;
    setLoading(true);
    try {
      const res = await api.get(`/vendors/${userId}/contacts`);
      setContacts(res.data || []);
    } catch (err) {
      console.error("Failed to fetch contacts", err);
      setError("Failed to load contacts.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchContacts();
  }, [userId]);

  const toggleEdit = (id) => setContacts(c => c.map(x => x._id === id ? { ...x, editing: !x.editing } : x));
  
  const remove = async (id) => {
    if (!window.confirm("Are you sure you want to delete this contact?")) return;
    try {
      await api.delete(`/vendors/${userId}/contacts/${id}`);
      setContacts(c => c.filter(x => x._id !== id));
    } catch (err) {
      console.error("Failed to delete contact", err);
      alert("Failed to delete contact.");
    }
  };

  const setField = (id, k, v) => setContacts(c => c.map(x => x._id === id ? { ...x, [k]: v } : x));

  const saveEdit = async (contact) => {
    try {
      const payload = {
        name: contact.name,
        email: contact.email,
        phone: contact.phone,
        position: contact.position,
        notes: contact.notes
      };
      await api.put(`/vendors/${userId}/contacts/${contact._id}`, payload);
      toggleEdit(contact._id);
    } catch (err) {
      console.error("Failed to update contact", err);
      alert("Failed to update contact.");
    }
  };

  const openAdd = () => {
    setAddError("");
    setNewContact({ name: "", email: "", phone: "", position: "", notes: "" });
    setAddOpen(true);
  };
  
  const closeAdd = () => {
    setAddError("");
    setAddOpen(false);
  };
  
  const setNew = (k) => (e) => setNewContact((p) => ({ ...p, [k]: e.target.value }));
  
  const saveNew = async () => {
    const name = (newContact.name || "").trim();
    const email = (newContact.email || "").trim();
    if (!name || !email) {
      setAddError("Name and Email are required.");
      return;
    }
    
    setSaving(true);
    try {
      const payload = {
        name,
        email,
        phone: (newContact.phone || "").trim(),
        position: (newContact.position || "").trim(),
        notes: (newContact.notes || "").trim()
      };
      const res = await api.post(`/vendors/${userId}/contacts`, payload);
      setContacts(prev => [...prev, res.data]);
      closeAdd();
    } catch (err) {
      console.error("Failed to add contact", err);
      setAddError(err.response?.data?.message || "Failed to add contact.");
    } finally {
      setSaving(false);
    }
  };

  useEffect(() => {
    if (!addOpen) return;
    const onKey = (e) => {
      if (e.key === "Escape") closeAdd();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [addOpen]);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-lg font-bold text-gray-900 dark:text-white">Primary Contact Persons</h2>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage who handles communications and ad approvals.</p>
        </div>
        <button
          onClick={openAdd}
          className="px-4 py-2 rounded-xl text-sm font-semibold bg-gray-900 dark:bg-white text-white dark:text-black hover:opacity-90 transition-opacity"
        >
          + Add Contact
        </button>
      </div>

      {loading && <div className="text-center py-10 text-gray-500">Loading contacts...</div>}
      {error && <div className="text-center py-10 text-red-500">{error}</div>}

      {addOpen && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/40 backdrop-blur-sm"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) closeAdd();
          }}
        >
          <div className="w-full max-w-2xl rounded-2xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 shadow-2xl">
            <div className="p-5 sm:p-6 border-b border-gray-100 dark:border-gray-800 flex items-start justify-between gap-4">
              <div>
                <div className="text-lg font-bold text-gray-900 dark:text-white">Add Contact</div>
                <div className="text-sm text-gray-500 dark:text-gray-400 mt-1">Add a primary contact person for your vendor account.</div>
              </div>
              <button
                type="button"
                onClick={closeAdd}
                className="px-3 py-1.5 rounded-xl text-sm font-semibold bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
              >
                ✕
              </button>
            </div>

            <div className="p-5 sm:p-6">
              {addError && (
                <div className="mb-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-600 dark:text-red-400 px-4 py-3 rounded-xl text-sm font-semibold">
                  {addError}
                </div>
              )}

              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <Field label="Full Name" required span={1}><Input value={newContact.name} onChange={setNew("name")} placeholder="Full Name" /></Field>
                <Field label="Email" required span={1}><Input type="email" value={newContact.email} onChange={setNew("email")} icon="✉️" placeholder="email@company.com" /></Field>
                <Field label="Phone" span={1}><Input type="tel" value={newContact.phone} onChange={setNew("phone")} icon="📱" placeholder="+91 00000 00000" /></Field>
                <Field label="Position" span={1}><Input value={newContact.position} onChange={setNew("position")} placeholder="e.g. Marketing Head" /></Field>
                <Field label="Notes" span={2}><Input value={newContact.notes} onChange={setNew("notes")} placeholder="Additional notes..." /></Field>
              </div>
            </div>

            <div className="p-5 sm:p-6 border-t border-gray-100 dark:border-gray-800 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={closeAdd}
                disabled={saving}
                className="px-4 py-2 rounded-xl text-sm font-semibold bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={saveNew}
                disabled={saving}
                className="px-4 py-2 rounded-xl text-sm font-semibold bg-gradient-to-r from-purple-600 to-pink-600 text-white shadow-lg shadow-pink-500/20 hover:shadow-pink-500/30 transition-all flex items-center gap-2"
              >
                {saving && <span className="w-3 h-3 border-2 border-white border-t-transparent rounded-full animate-spin" />}
                Add Contact
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="grid gap-4">
        {contacts.map((c) => (
          <div key={c._id} className="p-5 rounded-2xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 transition-all hover:border-gray-200 dark:hover:border-gray-700">
            <div className="flex flex-wrap justify-between items-start gap-4 mb-4">
              <div className="flex items-center gap-4">
                <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-purple-500 to-pink-500 text-white font-bold text-lg flex items-center justify-center flex-shrink-0">
                  {c.name ? c.name[0].toUpperCase() : "?"}
                </div>
                {!c.editing && (
                  <div>
                    <div className="font-bold text-gray-900 dark:text-white">{c.name || "New Contact"}</div>
                    <div className="text-sm text-gray-500 dark:text-gray-400">{c.position}</div>
                    <div className="flex flex-wrap gap-2 mt-2">
                      <span className="text-xs text-gray-400 dark:text-gray-500 flex items-center gap-1">✉️ {c.email}</span>
                      <span className="text-xs text-gray-400 dark:text-gray-500 flex items-center gap-1">📱 {c.phone}</span>
                    </div>
                  </div>
                )}
              </div>
              <div className="flex gap-2">
                <button
                  onClick={() => c.editing ? saveEdit(c) : toggleEdit(c._id)}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                >
                  {c.editing ? "✓ Save" : "✏️ Edit"}
                </button>
                <button
                  onClick={() => remove(c._id)}
                  className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-50 dark:bg-red-900/20 text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/30 transition-colors"
                >
                  🗑 Remove
                </button>
              </div>
            </div>

            {c.editing && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4 pt-4 border-t border-gray-100 dark:border-gray-800 animate-fade-in">
                <Field label="Full Name" required span={1}><Input value={c.name} onChange={e => setField(c._id, "name", e.target.value)} placeholder="Full Name" /></Field>
                <Field label="Email" required span={1}><Input type="email" value={c.email} onChange={e => setField(c._id, "email", e.target.value)} icon="✉️" placeholder="email@company.com" /></Field>
                <Field label="Phone" span={1}><Input type="tel" value={c.phone} onChange={e => setField(c._id, "phone", e.target.value)} icon="📱" placeholder="+91 00000 00000" /></Field>
                <Field label="Position" span={1}><Input value={c.position} onChange={e => setField(c._id, "position", e.target.value)} placeholder="e.g. Marketing Head" /></Field>
                <Field label="Notes" span={2}><Input value={c.notes} onChange={e => setField(c._id, "notes", e.target.value)} placeholder="Additional notes..." /></Field>
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
