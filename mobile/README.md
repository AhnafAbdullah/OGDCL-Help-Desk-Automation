# OGDCL Help Desk — Mobile Client

Flutter mobile client for the Help Desk module of the OGDCL Workflow
Automation System FYP. Submit, track, assign, resolve, and rate complaints
against the existing [.NET backend](https://github.com/AhnafAbdullah/OGDCL-Help-Desk-Automation).

Scope: **Help Desk only**. Visitor Entry, Gate Desk, Smart Parking, and full
Settings are reachable from the nav drawer but render a "Coming Soon" stub —
those modules belong to other parts of the FYP or are hardware-dependent.

## Stack

- Riverpod (`flutter_riverpod`) for state management
- `go_router` for navigation, with an auth-aware redirect guard
- `dio` for HTTP, with a queued interceptor that injects the JWT and
  transparently refreshes it on a 401
- `flutter_secure_storage` for the token pair
- `signalr_netcore` for realtime notifications (`/hubs/notifications`)
- `file_picker` / `path_provider` / `open_filex` for ticket attachments
- Material 3, themed from the OGDCL brand palette used by the Blazor dashboard

No code generation (no `freezed`/`json_serializable`/`build_runner`) — all
models hand-write their own `fromJson`.

## Running

1. Start the backend (from the `OGDCL-Help-Desk-Automation` repo):
   ```
   cd backend && dotnet run --project src/Ogdcl.Api --urls http://localhost:5080
   ```
2. Install Flutter dependencies:
   ```
   flutter pub get
   ```
   This machine didn't have the Flutter SDK installed, so `pubspec.yaml`'s
   version floors (`^x.y.z`) were set from memory rather than verified
   against pub.dev — `pub get` should still resolve them to whatever's
   current. If any single package fails to resolve, loosen just that line
   (e.g. `file_picker: ^8.0.0` → `file_picker: any`) and re-run.
3. Run on an emulator/simulator:
   ```
   flutter run
   ```

### Pointing the app at the backend

[`lib/core/config/env.dart`](lib/core/config/env.dart) resolves the API host
automatically:

| Target | Host used |
|---|---|
| Android emulator | `10.0.2.2` (the emulator's alias for the host machine) |
| iOS simulator / Windows / macOS / Linux desktop / web | `localhost` |
| A physical phone on the same network | not auto-detected — set `Env.overrideHost` to your machine's LAN IP |

The API port (`5080`) matches the `--urls` flag above; change
`Env.apiPort` if you run the backend on a different port.

### Seeded accounts (from the backend's dev seeder)

| Username | Password | Role |
|---|---|---|
| `admin` | `Admin@123` | Admin |
| `ayan` / `umer` / `ibrahim` | `Employee@123` | Employee |
| `it.handler1` / `it.handler2` / `maint.handler1` / `hr.handler1` / `fac.handler1` / `civil.handler1` | `Handler@123` | Handler (per department) |

## App icon

Generated from `assets/logo.png` (the OGDCL mark) directly into the
Android/iOS/web/Windows icon slots, since building this on a machine without
the Flutter SDK meant `flutter_launcher_icons` couldn't be run here. The
`flutter_launcher_icons` config in `pubspec.yaml` is still in place — running
`dart run flutter_launcher_icons` after `pub get` will regenerate them from
the same source if the logo changes.

## Structure

```
lib/
  core/            # theme, env config, network client, secure storage, routing
  domain/          # hand-written models shared across features (Ticket, User, enums, ...)
  features/
    auth/          # login, session bootstrap, JWT refresh
    dashboard/     # role-aware home screen
    tickets/       # list (role-based tabs), new complaint form, detail + actions
    notifications/ # REST list + SignalR live push
    shell/         # bottom nav + drawer chrome
    coming_soon/   # placeholder for out-of-scope modules
  shared/widgets/  # status/priority badges, empty/error/loading states
```

### Ticket status actions

The available action buttons on the ticket detail screen
([`lib/features/tickets/domain/ticket_actions.dart`](lib/features/tickets/domain/ticket_actions.dart))
mirror the backend's `TicketService.AllowedTransitions` and per-role checks
exactly, so the UI never offers an action the server would reject.
