export const localDate = (date = new Date()) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
export const bookingDate = (date) => new Date(`${date}T12:00:00`).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
export const bookingTime = (time) => {
  const [hours, minutes] = time.split(':').map(Number);
  return `${hours % 12 || 12}:${String(minutes).padStart(2, '0')} ${hours >= 12 ? 'PM' : 'AM'}`;
};
export const bookingStatus = (status) => ({ New: 'New request', Proposed: 'New time proposed', Confirmed: 'Confirmed', Completed: 'Completed', Declined: 'Declined' }[status] || status);
export const BOOKING_TABS = ['Requests', 'Confirmed', 'Completed'];
export function filterBookings(bookings, { tab = 'Requests', search = '', date = '' } = {}) {
  const statuses = { Requests: ['New', 'Proposed'], Confirmed: ['Confirmed'], Completed: ['Completed', 'Declined'] }[tab] || ['New', 'Proposed'];
  return bookings.filter((booking) => statuses.includes(booking.status)
    && `${booking.service} ${booking.customer} ${booking.id}`.toLowerCase().includes(search.trim().toLowerCase())
    && (!date || booking.date === date)).sort((a, b) => a.date.localeCompare(b.date));
}
export function validProposal(date, time, now = new Date()) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) return false;
  const proposed = new Date(`${date}T${time}:00`);
  return localDate(proposed) === date && proposed > now;
}
