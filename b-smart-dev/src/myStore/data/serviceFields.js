export const SERVICE_CATEGORIES = ['Home Services', 'Business Consulting', 'Health & Wellness', 'Photography', 'Delivery', 'Education', 'Other'];
export const RATE_TYPES = ['Starting from', 'Fixed price', 'Per hour', 'Per session'];
export const DURATIONS = ['30 minutes', '1 hour', '2 hours', '2–3 hours', 'Half day', 'Full day'];
export const METHODS = ['At customer location', 'Online', 'At my location'];
export const DAYS = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
export const defaultAvailability = () => DAYS.map((day, index) => ({ day, slots: index < 5 ? [{ start: '09:00', end: '17:00' }] : [] }));
export const servicePrice = ({ price, rateType }) => {
  const amount = `₹${Number(price || 0).toLocaleString()}`;
  return rateType === 'Starting from' ? `From ${amount}` : `${amount}${rateType === 'Per hour' ? ' / hour' : rateType === 'Per session' ? ' / session' : ''}`;
};

export const textToList = (value) => String(value || '').split(',').map((item) => item.trim()).filter(Boolean);
export const listToText = (value) => (Array.isArray(value) ? value.join(', ') : '');

// service_time (general offered hours) and service_area (coverage areas) are
// required by the API on create, optional on update (omit to keep existing).
export function validateServiceTimeArea({ serviceTime, serviceAreaText, isCreate }) {
  const hasTime = serviceTime.start || serviceTime.end;
  if (isCreate || hasTime) {
    if (!serviceTime.start || !serviceTime.end) return 'Enter the start and end time for when this service is offered.';
    if (serviceTime.start >= serviceTime.end) return 'Service hours start must be before the end time.';
  }
  if (isCreate || serviceAreaText.trim()) {
    if (!textToList(serviceAreaText).length) return 'Enter at least one coverage area for this service.';
  }
  return '';
}

export const isBlankSubservice = (subservice) => !subservice.name.trim() && subservice.hours === '' && subservice.price === '' && !subservice.sqft;

export function validateSubservices(subservices) {
  for (const subservice of subservices) {
    if (isBlankSubservice(subservice)) continue;
    if (!subservice.name.trim()) return 'Enter a name for each subservice.';
    if (subservice.hours !== '' && subservice.hours != null && (!Number.isFinite(Number(subservice.hours)) || Number(subservice.hours) <= 0)) return 'Enter a valid number of hours (or leave it blank) for each subservice.';
    if (subservice.price === '' || !Number.isFinite(Number(subservice.price)) || Number(subservice.price) < 0) return 'Enter a valid price for each subservice.';
    if (subservice.sqft !== '' && subservice.sqft != null && (!Number.isFinite(Number(subservice.sqft)) || Number(subservice.sqft) < 0)) return 'Enter a valid sqft (or leave it blank) for each subservice.';
  }
  return '';
}

export function validateService(form, availability, draft = false, subservices = []) {
  if (!draft) {
    if (!form.name.trim() || !form.description.trim()) return 'Enter a service name and description.';
    if (form.price === '' || !Number.isFinite(Number(form.price)) || Number(form.price) < 0) return 'Enter a valid price of zero or more.';
    const subserviceError = validateSubservices(subservices);
    if (subserviceError) return subserviceError;
    if (!availability.some((day) => day.slots.length)) return 'Add at least one availability slot.';
    if (form.method === 'At my location' && !form.address.trim()) return 'Enter your service address.';
  }
  for (const { day, slots } of availability) {
    const sorted = [...slots].sort((a, b) => a.start.localeCompare(b.start));
    if (sorted.some((slot, index) => !slot.start || !slot.end || slot.end <= slot.start || (index > 0 && sorted[index - 1].end > slot.start))) {
      return `${day}: use valid start and end times without overlapping slots.`;
    }
  }
  return '';
}
