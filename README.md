# Fatora

Fatora is a comprehensive Flutter application designed for personal finance management, specifically focused on tracking debts and payments. It allows users to manage debtor profiles, record detailed debt transactions, track payments, and visualize financial statistics through an intuitive dashboard.

## 🚀 Features

### Debtor Management
*   **Create & Manage Profiles:** Add, edit, and delete debtor information including name, phone number, email, and notes.
*   **Search & Filter:** Efficiently search for debtors by name or phone number and filter lists based on debt status.
*   **Detailed Views:** View comprehensive history of debts and payments for each debtor.

### Financial Tracking
*   **Debt Recording:** Add detailed debt records including specific items, quantities, and prices.
*   **Payment Processing:** Record full or partial payments with support for multiple payment methods (Cash, Bank Transfer, Check, etc.).
*   **Transaction History:** View chronological lists of all debts and payments.
*   **Status Tracking:** Mark debts as paid/unpaid and track outstanding balances.

### Dashboard & Analytics
*   **Real-time Overview:** Instant view of total debtors, active debtors, total outstanding debt, and total amounts paid.
*   **Visualizations:** Interactive charts (via `fl_chart`) displaying debt distribution and payment trends.
*   **Key Performance Indicators:** Metrics such as average debt per debtor and overall payment rates.

### User Experience
*   **Authentication:** Secure Google Sign-In integration via Firebase Authentication.
*   **Localization:** Complete support for **English** and **Arabic** languages.
*   **Theming:** toggleable **Light** and **Dark** modes with a modern Material Design 3 UI.
*   **Offline Support:** Implements local caching strategies (LRU Cache) to optimize performance and reduce database reads.

## 🛠️ Tech Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **Backend:** [Firebase](https://firebase.google.com/)
    *   **Authentication:** For user sign-in and security.
    *   **Cloud Firestore:** NoSQL database for storing debtors, debts, and payments.
*   **State Management:** [Provider](https://pub.dev/packages/provider) pattern.
*   **UI Components:**
    *   `fl_chart` for statistical graphs.
    *   `google_fonts` for typography.
    *   `font_awesome_flutter` for icons.
*   **Utilities:**
    *   `shared_preferences` for persisting local settings (Theme, Language).
    *   `intl` for date and number formatting.

## 📂 Project Structure

```
lib/
├── custom_widgets/      # Reusable UI components (StatCard, TransactionTile, etc.)
├── firestore_services/  # Logic for Firebase interactions (Auth, Debtors, Payments)
├── l10n/                # Localization resources (.arb files)
├── models/              # Data models (Debtor, DebtTransaction, PaymentTransaction)
├── providers/           # State management classes (DebtorProvider, ThemeProvider, etc.)
├── screens/             # Application screens (Dashboard, Settings, Details, etc.)
├── themes/              # Theme configuration (Colors, Text Styles)
├── firebase_options.dart # Firebase configuration
└── main.dart            # Application entry point
```

## ⚙️ Setup & Installation

### Prerequisites
*   Flutter SDK installed.
*   A Firebase project created and configured.

### Installation
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/your-username/fatora.git
    cd fatora
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration:**
    *   Ensure `firebase_options.dart` is present in `lib/`.
    *   If not, configure it using the FlutterFire CLI:
        ```bash
        flutterfire configure
        ```

4.  **Run the App:**
    ```bash
    flutter run
    ```

## 📝 Usage

1.  **Authentication:** Sign in using a Google account.
2.  **Dashboard:** Navigate the main dashboard to see summaries and quick actions.
3.  **Adding a Debtor:** Use the "Add Debtor" action or navigate to the Debtors list to create a new profile.
4.  **Recording Transactions:**
    *   Go to a debtor's details.
    *   Click "Add Debt" to record a new liability.
    *   Click "Add Payment" to record a repayment.
5.  **Settings:** Use the settings screen to toggle Dark Mode or switch between English and Arabic.

## ⚠️ Notes

*   The application relies on Firestore indexes for complex queries. Monitor the debug console for index creation links if queries fail.
*   Optimistic locking and caching mechanisms are implemented in the service layer to handle data consistency and performance.

## 📄 License

This project is intended for personal or educational use. Please refer to the repository license file for specific terms.
