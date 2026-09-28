# B-Smart Frontend Documentation (Main App)

This document outlines the frontend architecture and key modules of the main B-Smart application to provide context for dashboard development.

## **Architecture Overview**
- **Framework**: React 18+
- **Build Tool**: Vite
- **Styling**: Tailwind CSS
- **State Management**: Redux Toolkit
- **API Client**: Axios
- **Real-time**: Socket.io-client

---

## **Project Structure**

### **1. Core Folders**
- `src/components/`: Reusable UI components (Modals, Nav, Cards).
- `src/pages/`: Main application views (Home, Profile, Ads, Chat).
- `src/services/`: API abstraction layer for backend communication.
- `src/store/`: Redux slices and store configuration.
- `src/lib/`: Utilities and API configuration ([api.js](file:///c:/Asynk%20clients/B-smart/b-smart/src/lib/api.js)).

### **2. Key Services ([src/services/](file:///c:/Asynk%20clients/B-smart/b-smart/src/services/))**
- `authService.js`: Handles login, logout, and session persistence.
- `chatService.js`: Messaging logic and history.
- `followService.js`: User relationship management.
- `commentService.js`: Post and Ad comments.
- `socketService.js`: Global socket initialization.

### **3. State Management ([src/store/](file:///c:/Asynk%20clients/B-smart/b-smart/src/store/))**
- `authSlice.js`: Current user info, token, and authentication status.
- `walletSlice.js`: User's coin balance and transaction history.
- `chatSlice.js`: Active conversations and message states.
- `themeSlice.js`: Dark/Light mode preferences.

---

## **Key Components for Reference**

### **UI & Layout**
- `Layout.jsx`: Main wrapper with Sidebar and TopBar.
- `BottomNav.jsx`: Navigation for mobile users.
- `Sidebar.jsx`: Desktop navigation.

### **Content Display**
- `PostCard.jsx`: Displays posts and reels with engagement actions.
- `TweetComponent.jsx`: Text-based post display.
- `PromoteCard.jsx`: Specialized display for sponsored content (Ads).

### **Modals & Interaction**
- `CreatePostModal.jsx`: Multi-step post creation with media handling.
- `PostDetailModal.jsx`: Expanded view with comments.
- `ShareContentModal.jsx`: Social sharing logic.

---

## **Dashboard Integration Context**
- **API Shared Logic**: The dashboard uses a similar API pattern ([apiBase.js](file:///c:/Asynk%20clients/B-smart/bsmart-dashboard/src/lib/apiBase.js)). Refer to `b-smart/src/services` for existing endpoint implementations.
- **Data Schemas**: When adding features to the dashboard (e.g., viewing user posts), refer to `PostCard.jsx` and `Post.js` (backend) for expected fields like `media`, `likes_count`, and `caption`.
- **Media Handling**: The main app handles complex media processing (cropping, filters). If the dashboard needs to edit media, check `AvatarCropModal.jsx` for implementation patterns.
