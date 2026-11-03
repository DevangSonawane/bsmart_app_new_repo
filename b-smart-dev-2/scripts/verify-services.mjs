import assert from 'node:assert/strict';
import React from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { Provider } from 'react-redux';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { configureStore } from '@reduxjs/toolkit';
import { createServer } from 'vite';

const vite = await createServer({ server: { middlewareMode: true }, appType: 'custom' });
try {
  const { default: reducer, addService, updateService, deleteService } = await vite.ssrLoadModule('/src/store/servicesSlice.js');
  const { default: ServiceForm } = await vite.ssrLoadModule('/src/myStore/components/ServiceForm.jsx');
  const { default: EditService } = await vite.ssrLoadModule('/src/pages/EditService.jsx');
  const { default: Services } = await vite.ssrLoadModule('/src/myStore/pages/Services.jsx');
  const { validateService, defaultAvailability } = await vite.ssrLoadModule('/src/myStore/data/serviceFields.js');
  const store = configureStore({ reducer: { services: reducer } });
  const render = (element, entry = '/') => renderToStaticMarkup(
    React.createElement(Provider, { store }, React.createElement(MemoryRouter, { initialEntries: [entry] }, element)),
  );
  const original = store.getState().services.items[0];
  const edited = {
    ...original, name: 'Test consulting', description: 'A focused planning session.', price: 47.5,
    rateType: 'Per hour', method: 'At my location', address: 'Test studio',
    availability: [{ day: 'Monday', slots: [{ start: '10:00', end: '12:00' }, { start: '14:00', end: '16:00' }] }],
  };
  store.dispatch(updateService(edited));
  assert.equal(store.getState().services.items[0].bookings, original.bookings);
  const editHtml = render(React.createElement(ServiceForm, { service: store.getState().services.items[0] }));
  for (const value of ['Test consulting', 'A focused planning session.', '47.5', 'Test studio', '10:00', '14:00', 'Save Changes', 'Service Images']) {
    assert.ok(editHtml.includes(value), `Edit form must prefill ${value}`);
  }
  assert.ok(!editHtml.includes('Product Images') && !editHtml.includes('Stock Quantity'));
  const addHtml = render(React.createElement(ServiceForm));
  assert.ok(addHtml.includes('Add Service') && addHtml.includes('Publish Service') && addHtml.includes('Save Draft'));
  assert.ok(addHtml.includes('Listing Preview') && addHtml.includes('Listing completeness'));
  const count = store.getState().services.items.length;
  store.dispatch(addService({ ...edited, name: 'Draft service', status: 'Draft' }));
  const draft = store.getState().services.items.at(-1);
  assert.equal(draft.bookings, 0);
  assert.equal(store.getState().services.items.length, count + 1);
  assert.notEqual(draft.id, original.id);
  assert.ok(!render(React.createElement(Services)).includes('Draft service'));
  assert.ok(render(React.createElement(Services), { pathname: '/', state: { serviceTab: 'Draft' } }).includes('Draft service'));
  store.dispatch(updateService({ id: draft.id, status: 'Published' }));
  const listing = render(React.createElement(Services));
  assert.ok(listing.includes('Draft service') && listing.includes(`/market/edit-service/${draft.id}`));
  store.dispatch(updateService({ id: draft.id, visible: false }));
  assert.ok(render(React.createElement(Services)).includes('Hidden'));
  store.dispatch(deleteService(draft.id));
  assert.equal(store.getState().services.items.length, count);
  const missing = render(React.createElement(Routes, null, React.createElement(Route, {
    path: '/market/edit-service/:serviceId', element: React.createElement(EditService),
  })), '/market/edit-service/99999');
  assert.ok(missing.includes('Service not found.'));
  assert.equal(validateService(edited, edited.availability), '');
  assert.ok(validateService({ ...edited, name: '  ' }, edited.availability));
  assert.ok(validateService({ ...edited, price: -1 }, edited.availability));
  assert.ok(validateService({ ...edited, address: '' }, edited.availability));
  assert.ok(validateService(edited, []));
  assert.ok(validateService(edited, [{ day: 'Monday', slots: [{ start: '12:00', end: '09:00' }] }]));
  assert.ok(validateService(edited, [{ day: 'Monday', slots: [{ start: '09:00', end: '12:00' }, { start: '11:00', end: '13:00' }] }]));
  assert.equal(validateService({ name: '', description: '', price: '' }, defaultAvailability(), true), '');
  console.log('PASS: service CRUD, draft/published listing, edit prefill, form rendering, invalid IDs, and validation.');
} finally {
  await vite.close();
}
