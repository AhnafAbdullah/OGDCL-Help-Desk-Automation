# OGDCL Workflow Automation System

Enterprise-grade facility management system for OGDCL headquarters: Help Desk,
Smart Parking, and Visitor Entry Management on a single platform. Final Year
Project — Air University Islamabad (Muhammad Umer 231607, Ibrahim Ahmad 231571,
Muhammad Ayan 231664).

The scope document (`OGDCL_Proposal_.docx`) and the phased implementation plan
(`OGDCL_Implementation_Plan.docx`) live in the parent folder.

## Current status

| Piece | Status |
|---|---|
| Backend API (.NET 8, Clean Architecture) | ✅ Implemented and verified |
| Authentication (JWT + provider-switchable AD/dev) | ✅ Implemented |
| Help Desk module (severity, urgent approval, handler accept/reject, escalation, attachments) | ✅ Implemented and verified |
| Visitor Entry module (pre-registration, OTP, RFID card issue/return) | ✅ Implemented (software side) |
| In-app notifications (SignalR + persisted) | ✅ Implemented |
| Blazor Server web dashboard (Phase 2) | ✅ Implemented and verified in-browser |
| Smart Parking module (IoT/MQTT) | ⏸ Deferred — hardware-dependent |
| RFID zone-scan ingestion | ⏸ Deferred with IoT |
| Flutter mobile app | 🔜 Next |

## Backend layout (`backend/`)

```
Ogdcl.sln
src/
  Ogdcl.Domain          entities + enums, no dependencies
  Ogdcl.Application     business services, DTOs, interfaces (unit-testable)
  Ogdcl.Infrastructure  EF Core (SQLite/SQL Server), auth providers, JWT, OTP store, file storage
  Ogdcl.Api             controllers, SignalR hub, Swagger, exception middleware, seeding
  Ogdcl.Web             Blazor Server dashboard (login, Help Desk, Visitors, Gate Desk, Settings)
tests/
  Ogdcl.Tests           xUnit suite (assignment engine, OTP lifecycle, ticket workflow, visit lifecycle)
```

## Running it

Requires the .NET 8 SDK. The dashboard talks to the API, so run **both** (two
terminals). The API must be on port 5080 (the web app's default `Api:BaseUrl`).

**Easiest — double-click the launchers** in this folder (they work from any
directory): **`run-api.cmd`** first, then **`run-web.cmd`**.

Or by hand, from `backend/` (relative paths need that working directory):

```bash
cd backend
# terminal 1 — API
dotnet run --project src/Ogdcl.Api --urls http://localhost:5080
# terminal 2 — web dashboard
dotnet run --project src/Ogdcl.Web --urls http://localhost:5090
```

Then open **http://localhost:5090** in your browser and sign in with a seeded
account below. Swagger UI for the raw API is at http://localhost:5080/swagger
(click **Authorize** and paste the access token from `POST /api/auth/login`).

On first run the API creates `ogdcl_dev.db` (SQLite) and seeds demo data.
Delete the file to reset. Tests: `dotnet test`.

### How a complaint flows

1. An **employee** submits it with a **severity** (Low / Medium / Urgent) and
   optional file or image attachments. Only employees may raise complaints —
   admins must sign in with an employee account to do so.
2. **Urgent** complaints go to **PendingApproval** and must be approved by that
   department's floor admin (or a super admin) before handlers can see them.
   Everything else opens immediately.
3. Complaints are **never auto-assigned**. They sit in the department's queue;
   any handler there can **Accept** or **Pass on**. The system shows the
   **suggested handler** (least-loaded, skipping those who passed) to handlers
   and admins as advice only.
4. The accepting handler works it: Assigned → In Progress → Resolved. The author
   closes it and rates the service.
5. **Anti-starvation:** every waiting complaint runs a severity-based timer. When
   it elapses the complaint is auto-escalated one step (Low → Medium → Urgent →
   Critical), flagged **⚠ Overdue**, the timer restarts, and handlers/admins are
   alerted. Critical is only ever reached this way. Tune the budgets under
   `Escalation` in `appsettings.json` (dev defaults are short so it is
   demonstrable).

### What each role sees in the dashboard

- **Employee** — submit complaints (severity + attachments), track them, register visitors.
- **Handler** — an **Available** queue for their department (Accept / Pass on) and **Assigned to me**.
- **Security** — the Gate Desk: verify visitor OTPs, issue/return RFID cards.
- **Floor Admin** (per department) — approves urgent complaints, and sees the
  complaints and handler performance **of their own department only**.
- **Super Admin** — the same across **all** departments, plus global Settings
  (routing rules, categories, zones). Neither admin can raise complaints.

### Seeded dev accounts

| Username | Password | Role |
|---|---|---|
| `admin` | `Admin@123` | Super Admin (all departments + settings) |
| `it.admin`, `hr.admin`, `fac.admin`, `maint.admin`, `civil.admin` | `Floor@123` | Floor Admin (own department only) |
| `ayan`, `umer`, `ibrahim` | `Employee@123` | Employee |
| `it.handler1`, `it.handler2`, `maint.handler1`, `hr.handler1`, `fac.handler1`, `civil.handler1` | `Handler@123` | Handler (per department) |
| `guard1`, `guard2` | `Guard@123` | Security |

> The schema changed with this feature. If you have an old `ogdcl_dev.db`, delete
> it (in `src/Ogdcl.Api`) so it is recreated and reseeded — `EnsureCreated` does
> not migrate an existing database.

## Configuration switches (`src/Ogdcl.Api/appsettings.json`)

- `Auth:Provider` — `Dev` (seeded store) now; `Ldap` for OGDCL Active Directory
  at deployment. The LDAP provider is a stub until OGDCL supplies the AD
  endpoint and service account.
- `Database:Provider` — `Sqlite` now; `SqlServer` + connection string for the
  MSSQL deployment.
- `Otp:TtlHours` / `Otp:MaxAttempts` — visitor OTP lifetime and attempt lockout.
- `Jwt:*` — token issuer/audience/key/lifetimes. **Replace the key before any
  deployment.**

## API surface (summary)

- `POST /api/auth/login|refresh|logout`, `GET /api/auth/me`
- `GET /api/categories`
- `POST /api/tickets`, `GET /api/tickets/mine|assigned|{id}`,
  `PATCH /api/tickets/{id}/status|assign`, `POST /api/tickets/{id}/feedback`,
  `POST/GET /api/tickets/{id}/attachments`
- `POST /api/visits`, `GET /api/visits/mine|pending|active|{id}`,
  `POST /api/visits/{id}/verify-otp|resend-otp|issue-card|close|cancel`
- `GET/POST /api/zones`
- `GET /api/notifications`, `POST /api/notifications/{id}/read`
- `GET /api/admin/departments|users|tickets|assignment-rules`,
  `POST /api/admin/assignment-rules|categories`
- SignalR hub: `/hubs/notifications` (JWT via `access_token` query parameter,
  event name `notification`)

## Engineering notes

- **Dev database uses `EnsureCreated`** for zero-friction onboarding. Before the
  schema stabilises for the MSSQL deployment, switch to EF Core migrations
  (`dotnet ef migrations add InitialCreate`) and replace the `EnsureCreatedAsync`
  call in `Program.cs` with `MigrateAsync`.
- **OTP store is in-memory** (codes are lost on restart). The `IOtpStore`
  contract is Redis-shaped; swap in a Redis implementation when the docker
  stack lands.
- **Notifications** persist to the database and push over SignalR. FCM can be
  added later as a second `INotificationChannel` without touching business code.
- Attachment uploads are extension-whitelisted, size-capped (10 MB), and stored
  under GUID names so uploaded filenames can't traverse paths.
