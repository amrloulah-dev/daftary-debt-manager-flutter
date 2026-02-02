# Daftary (Fatora)

Daftary is a smart digital ledger application built with Flutter, designed to help individuals and small businesses efficiently manage debts, track payments, and organize financial relationships with debtors. It serves as a modern replacement for traditional paper notebooks.

## Project Overview

**Daftary** solves the problem of tracking money owed by multiple individuals. It provides a centralized system to record borrowing and repayment transactions, automatically calculate balances, and assess the risk level of debtors.

**Key capabilities include:**
- comprehensive debtor profiles.
- Transaction recording (Debts & Payments).
- Real-time balance calculations.
- Financial statistics and dashboards.
- Multi-language and Multi-theme support.

## Project Structure

The project follows a standard Flutter architecture with a separation of concerns between data, state management, and UI.

```
lib/
├── custom_widgets/    # Reusable UI components (Tiles, Cards, Buttons)
├── l10n/              # Localization files (.arb) and generated delegates
├── models/            # Data models and Isar database schemas
│   ├── debtor_model.dart
│   ├── debts_model.dart
│   └── payment_model.dart
├── providers/         # State management (Provider pattern)
│   ├── debtor_provider.dart
│   ├── debts_provider.dart
│   ├── locale_provider.dart
│   └── ...
├── screens/           # Application screens (Pages)
│   ├── dashboard_page.dart
│   ├── debtors_list_screen.dart
│   ├── statistics_screen.dart
│   └── ...
├── services/          # Business logic and Data Access Layer
│   ├── isar_service.dart
│   └── transaction_service.dart
├── themes/            # App theming and styling definitions
└── main.dart          # Application entry point and initialization
```

## Technologies & Dependencies

### Core Framework
- **Flutter:** SDK ^3.7.2
- **Dart:** Language

### Key Libraries
- **State Management:** `provider`
- **Local Database:** `isar`, `isar_flutter_libs` (NoSQL database)
- **Localization:** `flutter_localizations`, `intl`
- **UI & Design:** `google_fonts`, `font_awesome_flutter`, `simple_icons`, `percent_indicator`, `fl_chart`
- **Utilities:** `uuid`, `shared_preferences`, `path_provider`

### Code Generation
- `build_runner` and `isar_generator` are used to generate type adapters and database code.

## Key Features

### 1. Dashboard & Analytics
- **Overview:** Displays total active debtors, total outstanding debt, total collected payments, and recent activity.
- **Visuals:** Uses charts and stat cards to provide a quick financial health check.

### 2. Debtor Management
- **Profiles:** Create and manage detailed debtor profiles (Name, Phone, Email, Notes).
- **Risk Assessment:** Automatically categorizes debtors (e.g., Safe, High Risk) based on their current debt level.
- **Communication:** Call or message debtors directly (implied by contact fields).

### 3. Transaction Tracking
- **Add Debt:** Record items or amounts borrowed by a debtor.
- **Record Payment:** Log payments received via various methods (Cash, Bank Transfer, etc.).
- **History:** View full transaction history for every debtor.

### 4. Customization
- **Localization:** Complete support for **English** and **Arabic**.
- **Theming:** Fully supported **Light** and **Dark** modes (Material 3).

## Setup & Usage

### Prerequisites
- Flutter SDK installed and configured.
- Android Studio / VS Code with Flutter extensions.

### Installation
1.  **Clone the repository.**
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Generate Code (if modifying models):**
    ```bash
    dart run build_runner build --delete-conflicting-outputs
    ```
4.  **Run the App:**
    ```bash
    flutter run
    ```

## Notes

- **Data Persistence:** The app uses Isar, a high-performance local database. All data is stored locally on the device.
- **Architecture:** The app uses `ChangeNotifier` providers to bridge the UI and the Service layer. Logic for updating balances and transaction history is handled within `TransactionService`.