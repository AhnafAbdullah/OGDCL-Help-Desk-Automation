# OGDCL Help Desk — Mobile Client

Flutter mobile client for the Help Desk module of the OGDCL Workflow
Automation System FYP. Submit, track, pick up, resolve, and rate complaints.
Talks to the existing [.NET backend](https://github.com/AhnafAbdullah/OGDCL-Help-Desk-Automation)
when available, or runs entirely standalone against a built-in mock backend
(see [Demo / mock mode](#demo--mock-mode) below).

Scope: **Help Desk only, and Employee/Handler roles only.** Visitor Entry,
Gate Desk, Smart Parking, and full Settings are reachable from the nav
drawer but render a "Coming Soon" stub. **Admin is a web-dashboard-only
role** — org-wide stats, reassignment, and Critical-complaint approval all
live on the existing Blazor dashboard; an Admin account is blocked from
signing into this app with a message pointing to the web dashboard instead.

## Help Desk workflow

- **Severity is chosen by the complainer** at submission time: Critical,
  Urgent, Medium, or Low (not auto-computed from category).
- **Critical complaints require admin approval** before being routed to a
  department — they sit in a read-only "Pending Approval" state on mobile
  until approved (or rejected, with a reason) on the web dashboard.
- Everything else lands directly in its department's open queue.
- **Handlers self-assign**: any handler in a matching department can browse
  the "Available" tab and pick up an open complaint themselves — there's no
  admin-driven reassignment on mobile.
- **Complaint numbers** encode severity, sequence, department, and date:
  `{SeverityLetter}-{Sequence}-{DeptCode}-{YYYYMMDD}`, e.g. `U-0007-IT-20260710`
  for an Urgent IT Support complaint. Letters: C = Critical, U = Urgent,
  M = Medium, L = Low.
- **SLA / overdue alerts**: each severity has an expected resolution window
  (Critical 4h, Urgent 24h, Medium 72h, Low 120h — app-side defaults, no
  backend SLA concept yet). A complaint past its window shows an "Overdue"
  badge and raises a notification to its handler.

## Stack

- Riverpod (`flutter_riverpod`) for state management
- `go_router` for navigation, with an auth-aware redirect guard
- `dio` for HTTP, with a queued interceptor that injects the JWT and
  transparently refreshes it on a 401
- `flutter_secure_storage` for the token pair
- `signalr_netcore` for realtime notifications (`/hubs/notifications`)
- `file_picker` / `path_provider` / `open_filex` for complaint attachments
- Material 3, themed from the OGDCL brand palette used by the Blazor dashboard

No code generation (no `freezed`/`json_serializable`/`build_runner`) — all
models hand-write their own `fromJson`.

## Demo / mock mode

[`lib/core/config/env.dart`](lib/core/config/env.dart) has
`Env.useMockBackend`, currently `true`. While on, the entire app runs against
an in-memory mock backend ([`lib/mock/`](lib/mock)) seeded with demo
complaints in every status (including one Pending Approval and one
Rejected) — no server, network, or setup required. Flip it to `false` to
point the app at a real running backend instead; every screen is written
against the same repository interfaces either way.

**Backend gaps when `useMockBackend = false`:** the real .NET API doesn't
yet support complainer-chosen severity (it auto-computes priority from
category), the approval/rejection workflow, or handler self-assignment
(its `/assign` endpoint is Admin-only). Those three features only fully
work against the mock backend until the server gains matching endpoints.

## Running

1. Install Flutter dependencies:
   ```
   flutter pub get
   ```
2. Run on an emulator/simulator/browser:
   ```
   flutter run
   ```
   In mock mode this is all you need — log in with any seeded account below.
3. To use the real backend instead, set `Env.useMockBackend = false` and
   start it first (from the `OGDCL-Help-Desk-Automation` repo):
   ```
   cd backend && dotnet run --project src/Ogdcl.Api --urls http://localhost:5080
   ```

### Pointing the app at the real backend

[`lib/core/config/env.dart`](lib/core/config/env.dart) resolves the API host
automatically:

| Target | Host used |
|---|---|
| Android emulator | `10.0.2.2` (the emulator's alias for the host machine) |
| iOS simulator / Windows / macOS / Linux desktop / web | `localhost` |
| A physical phone on the same network | not auto-detected — set `Env.overrideHost` to your machine's LAN IP |

The API port (`5080`) matches the `--urls` flag above; change
`Env.apiPort` if you run the backend on a different port.

### Seeded accounts

Employee and Handler accounts work identically in mock mode or against the
real backend's dev seeder. Admin accounts exist in the mock seed data only
so login can correctly *reject* them.

| Username | Password | Role |
|---|---|---|
| `ayan` / `umer` / `ibrahim` | `Employee@123` | Employee |
| `it.handler1` / `it.handler2` / `maint.handler1` / `hr.handler1` / `fac.handler1` / `civil.handler1` | `Handler@123` | Handler (per department) |
| `admin` | `Admin@123` | Admin — **blocked on mobile**, use the web dashboard |

## App icon

Generated from `assets/logo.png` (the OGDCL mark) directly into the
Android/iOS/web/Windows icon slots via `flutter_launcher_icons` (config in
`pubspec.yaml`) — run `dart run flutter_launcher_icons` after `pub get` to
regenerate them if the logo changes.

## Structure

```
lib/
  core/            # theme, env config, network client, secure storage, routing
  domain/          # hand-written models shared across features (Complaint, User, enums, ...)
  features/
    auth/          # login, session bootstrap, JWT refresh, admin-blocked message
    dashboard/     # role-aware home screen + Visitor/Parking coming-soon tiles
    complaints/    # list (role-based tabs incl. Available), new-complaint popup, detail + actions
    notifications/ # REST list + SignalR live push
    shell/         # bottom nav + drawer chrome + centered "New Complaint" button
    coming_soon/   # placeholder for out-of-scope modules
  mock/            # in-memory backend used when Env.useMockBackend is true
  shared/widgets/  # status/severity/overdue badges, avatar, empty/error/loading states
```

### Complaint status actions

The available action buttons on the complaint detail screen
([`lib/features/complaints/domain/complaint_actions.dart`](lib/features/complaints/domain/complaint_actions.dart))
mirror the mock backend's transition rules exactly, so the UI never offers
an action the backend would reject. URL paths and JSON field names in
[`lib/features/complaints/data/`](lib/features/complaints/data) intentionally
still say "ticket" — that's the real backend's fixed wire contract; only the
in-app Dart/UI terminology was renamed to "complaint".
