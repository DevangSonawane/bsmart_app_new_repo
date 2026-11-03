import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { Provider } from 'react-redux';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { createServer } from 'vite';

const vite = await createServer({ server: { middlewareMode: true }, appType: 'custom' });
try {
  const { default: reducer, acceptBooking, declineBooking, proposeBookingTime, completeBooking } = await vite.ssrLoadModule('/src/store/bookingsSlice.js');
  const { default: Bookings } = await vite.ssrLoadModule('/src/myStore/pages/Bookings.jsx');
  const { filterBookings, localDate, validProposal } = await vite.ssrLoadModule('/src/myStore/data/bookingHelpers.js');
  const store = configureStore({ reducer: { bookings: reducer } });
  const items = () => store.getState().bookings.items;
  const get = (id) => items().find((item) => item.id === id);
  assert.equal(filterBookings(items()).length, 4);
  assert.equal(filterBookings(items(), { search: 'Divya' }).length, 1);
  assert.equal(filterBookings(items(), { tab: 'Confirmed', date: localDate() }).length, 1);
  assert.equal(validProposal('2020-01-01', '12:00'), false);
  assert.equal(validProposal('2099-02-30', '12:00'), false);
  assert.equal(validProposal('2099-10-01', '25:00'), false);
  store.dispatch(completeBooking('BK-201'));
  assert.equal(get('BK-201').status, 'New');
  store.dispatch(acceptBooking('BK-201'));
  assert.equal(get('BK-201').status, 'Confirmed');
  store.dispatch(completeBooking('BK-201'));
  assert.equal(get('BK-201').status, 'Completed');
  store.dispatch(declineBooking('BK-201'));
  assert.equal(get('BK-201').status, 'Completed');
  store.dispatch(proposeBookingTime({ id: 'BK-202', date: '2020-01-01', time: '12:00' }));
  assert.equal(get('BK-202').status, 'New');
  const future = new Date(); future.setDate(future.getDate() + 3);
  store.dispatch(proposeBookingTime({ id: 'BK-202', date: localDate(future), time: '12:00' }));
  assert.equal(get('BK-202').status, 'Proposed');
  assert.equal(get('BK-202').date, '2026-09-07');
  store.dispatch(acceptBooking('BK-202'));
  assert.equal(get('BK-202').status, 'Proposed');
  const render = (path) => renderToStaticMarkup(React.createElement(Provider, { store }, React.createElement(MemoryRouter, { initialEntries: [path] }, React.createElement(Routes, null,
    React.createElement(Route, { path: '/bookings', element: React.createElement(Bookings) }),
    React.createElement(Route, { path: '/bookings/:bookingId', element: React.createElement(Bookings) }),
  ))));
  const list = render('/bookings');
  assert.ok(list.includes('Search bookings') && list.includes('Today’s services') && list.includes('Ravi Chandran'));
  const detail = render('/bookings/BK-203');
  for (const text of ['Booking request', 'Customer note', 'Payment secured', 'Your earnings', 'Accept', 'Propose new time', 'Decline']) assert.ok(detail.includes(text));
  assert.ok(render('/bookings/BK-202').includes('awaiting customer confirmation'));
  assert.ok(render('/bookings/not-found').includes('Booking not found'));
  store.dispatch(declineBooking('BK-203'));
  assert.equal(get('BK-203').status, 'Declined');
  assert.ok(filterBookings(items(), { tab: 'Completed' }).some((item) => item.id === 'BK-203'));
  console.log('PASS: filters, today’s services, request actions, proposal validation, list/detail rendering, and invalid-booking fallback.');
} finally {
  await vite.close();
}
