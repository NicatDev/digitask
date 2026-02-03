# Project Rules (AI Instructions)

These rules are REQUIRED. Follow them exactly when generating code.

---

# Project information

Project name is "Digitask". Logo is "logo.svg".

## Frontend Rules

### Tech Stack
- MUST use **React + Vite**.
- MUST use **Ant Design (antd)** for UI components and layout.
- MUST use **Context API** for state management (no Redux unless explicitly requested).
- MUST use **react-leaflet** for map + live tracking UI.
- MUST use **WebSocket** for group chat realtime features.

### Styling
- MUST use **CSS Modules with SCSS**:
  - Each component MUST have a `style.module.scss`.
- MUST NOT use global CSS for component styling (except `src/styles/global.scss` if needed for resets).

### Folder Structure
- MUST place page-level components inside: `src/pages/components/`
  - Pages are route-level components only.
- MUST place reusable UI components inside: `src/components/ui/`
  - Example: buttons, inputs, modals, tables, cards, small wrappers.
- MUST place advanced/complex components inside: `src/components/advance/`
  - Example: map tracking widget, chat panel, analytics widgets, multi-step forms.

- Must have: Pagination, filter and search in every page
### Component Structure Convention
- Every component folder MUST contain:
  - `index.jsx`
  - `style.module.scss`
- Component naming MUST be PascalCase for folders and components.
- Imports SHOULD be clean and grouped (react, libs, components, styles).

---

## Backend Rules
use jwt for authentication
### Tech Stack
- MUST use **Django + Django REST Framework (DRF)** for APIs.
- MUST use **Django Channels** for:
  - group chat realtime
  - live tracking realtime (location streaming)

### Project Structure
- MUST split backend into multiple Django apps (domain-based).
- MUST follow the folder structure below inside each app:
  - Views MUST be in: `views/<subject>.py`
  - Serializers MUST be in: `serializers/<subject>.py`
  - Models MUST be in: `models/<subject>.py`
- MUST follow and reuse the model definitions from: `model_structure/` folder (as source of truth).

### Naming & Organization
- Files MUST be grouped by subject (e.g. `tasks.py`, `chat.py`, `inventory.py`, `tracking.py`).
- Code MUST be modular and readable (no huge single files).

---

## Design Rules (UI/UX)
must modern and interactive design
- MUST implement a **simple, modern** design.
- MUST be **responsive** for:
  - Mobile
  - Tablet
  - Desktop
- SHOULD use Ant Design grid/layout utilities for responsiveness.
- SHOULD keep UI clean: consistent spacing, clear typography, minimal clutter.

---

## Realtime Requirements Summary
- Chat:
  - MUST be group-based (no direct messages unless requested).
  - MUST use WebSocket on frontend + Django Channels on backend.
- Tracking:
  - MUST show live location on map using react-leaflet.
  - MUST stream updates via Django Channels.


## Mobile Requirements Summary
- MUST use **Flutter** for mobile app.
- MUST use **Dio** for API calls.
- MUST use **Senior Flutter Developer** for mobile app development.
- MUST use **Django Channels** for:
  - group chat realtime
  - live tracking realtime (location streaming)
- Dont change backend for mobile app development.