# SafeSpend

> **v1.0.0** — Phase 1 Release | Build: `1.0.0+1` | Target: Android | Flutter 3.41+

A local-first, offline Android personal finance and ledger tracker built with Flutter. Track fixed monthly bills, variable daily spending, and savings goals — all with a single glance at your **Safe-to-Spend** number.

---

## Screenshots

> *Add screenshots here once you've run the app.*

---

## Features

### 🧭 Bottom Navigation

- **Home** — Safe-to-Spend dashboard with upcoming bills, savings, and recent activity.
- **Reports** — Month-by-month income versus spending, category breakdown, daily spending chart, bill payment progress, savings progress, and transaction history.
- **Goals** — Savings goals and contributions.
- **Bills** — Recurring rent, WiFi, phone, and other monthly bills.
- **Bill Reminders** — Optional local Android reminders one day before each bill is due.
- **Center Add Button** — Quickly add an expense, update income, add a bill, or create a savings goal.

### 🏠 Command Center (Dashboard)

- **Safe-to-Spend Dashboard** — One big number that accounts for income, expenses, bills, and this month's savings contributions.
- **Recurring Bills** — Add your own monthly bills such as room rent, WiFi, phone, or insurance with a due day and paid/pending status.
- **Quick Actions** — Add expenses, bills, goals, or open Activity from the dashboard.
- **Recent Transactions** — The 5 most recent entries from your transaction history.

### 💸 Expense Logger (Fast Entry)

- **Android Keyboard Input** — Amount fields use the device's regular numeric keyboard.
- **Category Chips** — Select from Groceries, Transit, Dining, and more.
- **Date Picker** — Defaults to today; change with a single tap.
- **Optional Notes** — Add details to any transaction.

### 🏦 Savings Jars

- **Goal Tracking** — Create savings goals with a target amount and optional deadline.
- **Monthly Plans** — Set a planned monthly saving amount for each goal.
- **Progress Bars** — Visualize how close you are to each goal.
- **Quick Add Funds** — Tap any jar to add money via a bottom sheet.

### 🔒 Privacy

- **Local-only storage** — Financial data stays in the device's SQLite database.
- **App lock** — Protect the app with a local PIN and device security when available.
- **Encrypted backups** — Export and restore local data with a separate backup password.

---

## Tech Stack

| Category | Technology |
|----------|-----------|
| Framework | Flutter (Android) |
| Language | Dart |
| Local Database | `sqflite` + SQLite |
| State Management | `provider` |
| Routing | `go_router` |
| Charts | `fl_chart` |
| Currency Formatting | `intl` (Japanese Yen `¥`, no decimals) |
| Typography | `google_fonts` (Inter) |
| Design System | Material 3 |
| Privacy | Local SQLite + `local_auth` app lock |

---

## Architecture

```text
lib/
├── core/
│   ├── database/          # SQLite helper, table creations, migrations
│   ├── theme/             # Material 3 color schemes, text themes
│   └── utils/             # Currency formatter (¥), Date extensions
├── shared/
│   ├── models/            # Category, Transaction, SavingsGoal
│   └── widgets/           # Reusable cards, progress bars, and status pills
├── features/
│   ├── dashboard/
│   │   ├── providers/     # Safe-to-Spend business logic
│   │   └── screens/       # Command Center UI
│   ├── expenses/
│   │   ├── providers/     # Transaction CRUD logic
│   │   └── screens/       # Expense Logger
│   ├── bills/              # Recurring monthly bills
│   ├── transactions/       # Full transaction history
│   └── savings/
│       ├── providers/     # Goal creation & funding logic
│       └── screens/       # Savings Jars UI
└── main.dart              # App entry point, providers, routing
```

---

## Database Schema

### `categories`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `name` | TEXT | e.g., "Rent", "Groceries" |
| `type` | TEXT | `fixed_bill` or `variable_expense` |
| `expected_monthly_amount` | REAL (nullable) | Default amount for fixed bills |
| `due_day` | INTEGER | Monthly due day from 1 to 31 |
| `archived` | INTEGER | Removed recurring bills stay archived so payment history is preserved |

**Seed Data:** Rent, Water, Electricity, WiFi (fixed bills) · Groceries, Transit, Dining (variable expenses)

### `transactions`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `category_id` | INTEGER FK | References `categories.id` |
| `amount` | REAL | Transaction amount |
| `date_paid` | TEXT | ISO-8601 date |
| `note` | TEXT (nullable) | Optional details |

### `savings_goals`

| Column | Type | Description |
|--------|------|-------------|
| `id` | INTEGER PK | Auto-increment |
| `title` | TEXT | e.g., "Samsung Galaxy S26 Ultra" |
| `target_amount` | REAL | Goal amount |
| `current_amount` | REAL | Default 0.0 |
| `monthly_contribution` | REAL | Planned monthly saving |
| `target_date` | TEXT (nullable) | ISO-8601 deadline |

### `savings_contributions`

Stores each amount added to a goal so the dashboard can calculate this month's reserved savings separately from lifetime goal progress.

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.41+)
- Android device or emulator

### Install & Run

```bash
# 1. Clone the repository
cd safespend

# 2. Install dependencies
flutter pub get

# 3. Run on a connected device or emulator
flutter run

# 4. Build a release APK
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## Reusable Components

| Widget | Description |
|--------|-------------|
| `CurrencyText` | Formats a double as `¥200,000` (no decimals) |
| `TransactionCard` | ListTile with icon, title, date, amount, note |
| `StatusPill` | "Paid" (green) / "Pending" (yellow) chip |
| `ProgressJarCard` | Goal card with linear progress bar and percentage |

---

## Design Principles

- **Offline-First** — Everything is stored locally in SQLite. No server required.
- **Local Currency** — All amounts display in Japanese Yen (`¥`) without decimals.
- **Semantic Colors** — Green for savings/income, red/orange for expenses, yellow for pending.
- **Material 3** — Clean, modern UI with Inter typography.
- **Dashboard-first navigation** — Quick actions replace the bottom navigation bar.
- **DRY Components** — Reusable cards, pills, and progress widgets power the main flows.

---

## Future Phases

- Spending search and filters
- Budget categories with spending limits
- Charts and spending analytics (`fl_chart` integration)
- CSV export / import
- Scheduled operating-system bill notifications

---

## License

MIT
