import { createRef } from 'react';

// CallOverlay/GroupCallOverlay are mounted once, globally, in App.jsx (so
// incoming calls ring no matter what page the user is on) — but the
// "start a call" buttons live on individual pages (ChatPage's 1:1/group
// headers). These shared ref singletons let any page reach the globally-
// mounted overlay instances' imperative handles (startCall/startGroupCall)
// without prop-drilling or a context provider.
export const callOverlayRef = createRef();
export const groupCallOverlayRef = createRef();
