# SafeSpend

> **v1.0.0** — Phase 1 Release | Build: `1.0.0+1` | Target: Android | Flutter 3.41+

A local-first, offline Android personal finance and ledger tracker built with Flutter. Track fixed monthly bills, variable daily spending, and savings goals — all with a single glance at your **Safe-to-Spend** number.

---

## Screenshots

> *Add screenshots here once you've run the app.*

---

## Features

### 🏠 Command Center (Dashboard)

- **Safe-to-Spend Header** — One big number that tells you exactly how much disposable income you have left:  
  `Income – Paid Fixed Bills – Pending Fixed Bills – Allocated Savings`
- **Fixed Bills Scroll** — Horizontal list of Rent, Water, Electricity, and WiFi. Tap a pending bill to mark it paid with today's date.
- **Recent Transactions** — The 5 most recent entries from your transaction history.

### 💸 Expense Logger (Fast Entry)

- **Custom Numeric Keypad** — Large, touch-friendly number pad for rapid entry (no system keyboard needed).
- **Category Chips** — Select from Groceries, Transit, Dining, and more.
- **Date Picker** — Defaults to today; change with a single tap.
- **Optional Notes** — Add details to any transaction.

### 🏦 Savings Jars

- **Goal Tracking** — Create savings goals with a target amount and optional deadline.
- **Progress Bars** — Visualize how close you are to each goal.
- **Quick Add Funds** — Tap any jar to add money via a bottom sheet.

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
│   └── widgets/           # Reusable UI components (Numpad, Cards, Pills)
├── features/
│   ├── dashboard/
│   │   ├── providers/     # Safe-to-Spend business logic
│   │   └── screens/       # Command Center UI
│   ├── expenses/
│   │   ├── providers/     # Transaction CRUD logic
│   │   └── screens/       # Expense Logger with Numpad
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
| `target_date` | TEXT (nullable) | ISO-8601 deadline |

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
| `CustomNumPad` | 0–9 grid with backspace and clear |
| `ProgressJarCard` | Goal card with linear progress bar and percentage |

---

## Design Principles

- **Offline-First** — Everything is stored locally in SQLite. No server required.
- **Local Currency** — All amounts display in Japanese Yen (`¥`) without decimals.
- **Semantic Colors** — Green for savings/income, red/orange for expenses, yellow for pending.
- **Material 3** — Clean, modern UI with Inter typography.
- **DRY Components** — 5 reusable widgets power all 3 screens.

---

## Future Phases

- Monthly income configuration (settings screen)
- Full transaction history with search/filter
- Budget categories with spending limits
- Charts and spending analytics (`fl_chart` integration)
- CSV export / import
- Recurring transaction automation

---

## License

MIT