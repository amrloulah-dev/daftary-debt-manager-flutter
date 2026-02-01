# Fatora - Debt Management Application

Fatora is a comprehensive Flutter-based application designed to help users efficiently manage debts, debtors, and payments. It provides a user-friendly interface for tracking financial transactions, offering detailed insights through statistics and a dashboard.

## Project Overview

The primary goal of Fatora is to simplify the process of recording and monitoring debts. Users can easily add debtors, log specific debts and payments, and view the financial status of each contact. The app leverages Firebase for secure data storage and authentication, ensuring data persistence and accessibility across devices.

## Project Structure

The project follows a standard Flutter architecture with a separation of concerns between UI, business logic, and data services.

*   **`lib/main.dart`**: The application entry point. It initializes Firebase, configures the theme and locale providers, and sets up the root widget.
*   **`lib/screens/`**: Contains the user interface (UI) code for various screens, including:
    *   **Authentication**: `auth_screen.dart`, `auth_wrapper.dart`
    *   **Dashboard**: `dashboard_page.dart`
    *   **Debtor Management**: `debtors_list_screen.dart`, `add_edit_debtor_screen.dart`, `debtor_details_screen.dart`
    *   **Transaction Management**: `add_edit_debt_screen.dart`, `add_edit_payment_screen.dart`, `debt_details_screen.dart`
    *   **Analysis & Config**: `statistics_screen.dart`, `settings_screen.dart`
*   **`lib/models/`**: Defines the data structures for the application:
    *   `debtor_model.dart`
    *   `debts_model.dart`
    *   `payment_model.dart`
*   **`lib/firestore_services/`**: Handles all interactions with Firebase Firestore:
    *   `auth_service.dart`: Manages user authentication.
    *   `debtor_services.dart`, `debts_services.dart`, `payment_services.dart`: CRUD operations for their respective data models.
*   **`lib/providers/`**: Implements state management using the Provider package (e.g., `theme_provider.dart`, `locale_provider.dart`, `debtor_provider.dart`).
*   **`lib/custom_widgets/`**: Reusable UI components like `stat_card.dart`, `transaction_tile.dart`, and `quick_action_button.dart`.
*   **`lib/l10n/`**: Localization files (`.arb`) for English and Arabic support.

## Technologies & Dependencies

Fatora is built using the following technologies:

*   **Framework**: [Flutter](https://flutter.dev/) (Dart)
*   **Backend**: [Firebase](https://firebase.google.com/)
    *   **Authentication**: `firebase_auth`, `google_sign_in`
    *   **Database**: `cloud_firestore` (with offline persistence enabled)
    *   **Storage**: `firebase_storage`
    *   **Messaging**: `firebase_messaging`
*   **State Management**: `provider`
*   **Localization**: `flutter_localizations`, `intl`
*   **UI & Visualization**:
    *   `fl_chart`: For rendering statistical charts.
    *   `percent_indicator`: For progress visualization.
    *   `font_awesome_flutter` & `simple_icons`: For iconography.
    *   `google_fonts`: For custom typography.
*   **Utilities**: `uuid` (unique IDs), `shared_preferences` (local config storage).

## Key Features

*   **Authentication**: Secure login via Google and Facebook integration.
*   **Dashboard**: A central hub displaying quick actions, summary statistics, and recent transactions.
*   **Debtor Management**:
    *   Add, edit, and delete debtor profiles.
    *   Store contact details (Name, Phone, Email).
    *   Search and filter debtors.
*   **Transaction Tracking**:
    *   Record specific debts (Borrowed) and payments (Paid).
    *   Categorize payments by method (Cash, Bank Transfer, Check, Other).
    *   View transaction history per debtor.
*   **Statistics & Analysis**:
    *   Visual charts for debt distribution and payment trends.
    *   Metrics for total outstanding debt, total paid, and payment rates.
*   **Localization**: Full support for **English** and **Arabic** languages.
*   **Theme Customization**: Built-in **Light** and **Dark** themes.
*   **Offline Support**: Firestore persistence ensures the app remains functional without an active internet connection.

## Setup & Usage

To run this project locally, ensure you have the Flutter SDK installed.

1.  **Clone the repository**:
    ```bash
    git clone <repository-url>
    cd fatora
    ```

2.  **Install dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Firebase Configuration**:
    *   This project relies on Firebase. You must provide the necessary configuration files:
        *   **Android**: Place `google-services.json` in `android/app/`.
        *   **iOS/macOS**: Place `GoogleService-Info.plist` in `ios/Runner/` and `macos/Runner/`.

4.  **Run the application**:
    ```bash
    flutter run
    ```

## Notes & Limitations

*   **Platform Support**: The project is configured for Android, iOS, Windows, macOS, Linux, and Web, though Firebase configuration specifics usually target Mobile/Web primarily.
*   **Private Package**: The `pubspec.yaml` is configured with `publish_to: 'none'`, indicating this is a private application not intended for public publication on pub.dev.
*   **Web Persistence**: Firestore persistence settings are explicitly handled for Web and Non-Web platforms in `main.dart`.