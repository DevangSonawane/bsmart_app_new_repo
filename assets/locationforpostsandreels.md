Location Search API — Frontend Integration Prompt
Base URL

https://api.bebsmart.in/api/location/search
Auth

Authorization: Bearer <jwt_token>
API Endpoint

GET /api/location/search

Query Parameters:
  query         – string, required, min 2 characters (what user types)
  sessionToken  – string, optional UUID (for billing optimization)

Response 200:
{
  "places": [
    {
      "placeId":  "ChIJwe1EZjDG5zsRaYxkjY_tpF0",
      "name":     "Mumbai",
      "address":  "Maharashtra, India",
      "fullText": "Mumbai, Maharashtra, India"
    },
    {
      "placeId":  "ChIJ4zLP2oAP5DsRme",
      "name":     "Mumbai Central Station",
      "address":  "Mumbai, Maharashtra, India",
      "fullText": "Mumbai Central Station, Mumbai, Maharashtra, India"
    }
  ]
}

Response 400:
{ "message": "Query must be at least 2 characters" }
Behaviour Rules
Call the API on every keystroke after 2+ characters typed
Debounce the call by 300ms — do not call on every single keystroke, wait 300ms after user stops typing
Show a loading spinner while fetching
Show empty state if places array is empty
When user selects a place → close the dropdown and fill the input with place.fullText
When user clears the input → clear the results list
sessionToken — generate one UUID when the user focuses the search input. Send the same token with every keystroke. Generate a new UUID after the user selects a result or clears the field
sessionToken Logic

// On input focus → generate once
let sessionToken = crypto.randomUUID();

// Send with every search call
GET /api/location/search?query=Mumbai&sessionToken=<uuid>

// On place selected or input cleared → reset
sessionToken = crypto.randomUUID();
What to Store After User Selects a Place

{
  "placeId":  "ChIJwe1EZjDG5zsRaYxkjY_tpF0",
  "name":     "Mumbai",
  "address":  "Maharashtra, India",
  "fullText": "Mumbai, Maharashtra, India"
}
Store all 4 fields. Use name for display, fullText for the input field, placeId as the unique identifier.

UI Behaviour (Instagram / Zomato style)

User taps location field
  → input becomes focused
  → sessionToken generated
  → placeholder: "Search city, area, building..."

User types "Mum"
  → 300ms debounce fires
  → API called
  → dropdown appears below input:

  ┌─────────────────────────────────┐
  │ 📍 Mumbai                       │
  │    Maharashtra, India           │
  ├─────────────────────────────────┤
  │ 📍 Mumbai Central Station       │
  │    Mumbai, Maharashtra, India   │
  ├─────────────────────────────────┤
  │ 📍 Mumbai Airport T2            │
  │    Sahar, Mumbai, Maharashtra   │
  └─────────────────────────────────┘

User taps "Mumbai"
  → input fills with "Mumbai, Maharashtra, India"
  → dropdown closes
  → sessionToken reset
  → selected place saved: { placeId, name, address, fullText }
React Implementation

import { useState, useRef, useCallback } from 'react';

export default function LocationSearch({ onSelect, token }) {
  const [query, setQuery]     = useState('');
  const [places, setPlaces]   = useState([]);
  const [loading, setLoading] = useState(false);
  const sessionToken = useRef(crypto.randomUUID());
  const debounceRef  = useRef(null);

  const search = useCallback(async (value) => {
    if (value.length < 2) return setPlaces([]);
    setLoading(true);
    try {
      const res = await fetch(
        `/api/location/search?query=${encodeURIComponent(value)}&sessionToken=${sessionToken.current}`,
        { headers: { Authorization: `Bearer ${token}` } }
      );
      const data = await res.json();
      setPlaces(data.places || []);
    } catch {
      setPlaces([]);
    } finally {
      setLoading(false);
    }
  }, [token]);

  const handleChange = (e) => {
    const value = e.target.value;
    setQuery(value);
    clearTimeout(debounceRef.current);
    if (!value) return setPlaces([]);
    debounceRef.current = setTimeout(() => search(value), 300);
  };

  const handleSelect = (place) => {
    setQuery(place.fullText);
    setPlaces([]);
    sessionToken.current = crypto.randomUUID();
    onSelect(place); // { placeId, name, address, fullText }
  };

  const handleClear = () => {
    setQuery('');
    setPlaces([]);
    sessionToken.current = crypto.randomUUID();
  };

  return (
    <div style={{ position: 'relative' }}>
      <input
        value={query}
        onChange={handleChange}
        placeholder="Search city, area, building..."
      />
      {query && <button onClick={handleClear}>✕</button>}

      {loading && <div>Searching...</div>}

      {places.length > 0 && (
        <ul style={{ position: 'absolute', zIndex: 999, background: '#fff', width: '100%' }}>
          {places.map((p) => (
            <li key={p.placeId} onClick={() => handleSelect(p)} style={{ cursor: 'pointer', padding: '10px' }}>
              <div><strong>{p.name}</strong></div>
              <div style={{ fontSize: 12, color: '#888' }}>{p.address}</div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
Usage in a Form

<LocationSearch
  token={userToken}
  onSelect={(place) => {
    setFormData(prev => ({
      ...prev,
      location: {
        placeId:  place.placeId,
        name:     place.name,
        address:  place.address,
        fullText: place.fullText,
      }
    }));
  }}
/>