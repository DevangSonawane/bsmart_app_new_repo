import { useId } from 'react';
import serviceIcon from '../../assets/service-icon.png';

export default function ServiceIcon({ size = 24, className = '', ...props }) {
  const maskId = useId();

  return (
    <svg width={size} height={size} viewBox="0 0 256 256" fill="currentColor" className={className} aria-hidden="true" {...props}>
      <defs>
        <mask id={maskId} x="0" y="0" width="256" height="256" maskUnits="userSpaceOnUse" className="[mask-type:alpha]">
          <image href={serviceIcon} width="256" height="256" />
        </mask>
      </defs>
      <rect width="256" height="256" mask={`url(#${maskId})`} />
    </svg>
  );
}
