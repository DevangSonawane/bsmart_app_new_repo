import React from 'react';
import { MapPin } from 'lucide-react';

const LocationLink = ({ location, className = '', iconSize = 11 }) => {
  if (!location) return null;

  const isObj = typeof location === 'object' && location !== null && location.placeId;

  let displayName, mapsUrl;

  if (isObj) {
    // Structured location object — use name, fall back to first segment of fullText
    displayName = location.name || (location.fullText || '').split(',')[0].trim();
    mapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(location.fullText || location.name || '')}&query_place_id=${location.placeId}`;
  } else {
    // Plain string — show first segment as display name, search Maps by full string
    const str = String(location).trim();
    displayName = str.split(',')[0].trim();
    mapsUrl = `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(str)}`;
  }

  if (!displayName) return null;

  return (
    <a
      href={mapsUrl}
      target="_blank"
      rel="noopener noreferrer"
      className={`inline-flex items-center gap-1 hover:underline ${className}`}
      onClick={(e) => e.stopPropagation()}
    >
      <MapPin size={iconSize} className="flex-shrink-0" />
      {displayName}
    </a>
  );
};

export default LocationLink;
