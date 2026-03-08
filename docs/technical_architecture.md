# Solana Shield VPN: Technical Architecture

## Overview
Solana Shield VPN is not just another wrapper; it is a meticulously architected mobile application designed to bridge high-performance networking with the emerging standards of Web3 authentication. Built primarily on **Flutter** for a fluid, reactive UI, the application leverages deeply integrated **Solana Mobile Wallet Adapter (MWA)** protocols and a custom **gRPC/Protobuf-based routing core**.

---

## 1. Application Layer (Frontend)
The frontend is engineered to provide a premium, 120fps experience across devices, adhering strictly to modern declarative UI paradigms.

*   **Framework:** Flutter (Dart). Chosen for its compilation to native ARM machine code and unparalleled UI customization capabilities.
*   **State Management:** `hooks_riverpod` combined with `riverpod_annotation`. This ensures immutable, testable, and strictly typed state across the application, preventing race conditions during rapid connection state changes.
*   **Routing:** `go_router` utilizing a `StatefulShellRoute` strategy. This allows for persistent bottom navigation state while completely isolating the authentication flows from the main application logic.
*   **Aesthetics Engine:** A custom-built theming engine utilizing dynamic `ThemeExtension` classes to render complex Solana-native gradients (Hyper-Green, Deep Purple) and dynamic glow effects that react to the VPN connection state.

## 2. Web3 Authentication Layer (Solana MWA)
The traditional centralized authentication database has been entirely ripped out and replaced with a decentralized cryptographic architecture.

*   **MWA Protocol:** We utilize the official `solana_mobile_client` SDK to interact with installed wallets via the `LocalAssociationScenario`.
*   **The Flow:**
    1.  The app requests `authorize()` via a deep link/intent.
    2.  The wallet (e.g., Phantom) overlays the screen, prompting the user to sign the connection request.
    3.  Upon approval, an `auth_token` and the user's `PublicKey` are returned.
*   **Security:** The `auth_token` is securely persisted in the device's keystore (via `SharedPreferences` in the current iteration, transitioning to `flutter_secure_storage`). We *never* have access to the user's private keys.
*   **Session Persistence:** The `RoutingConfigNotifier` acts as a gatekeeper, instantly validating the presence of a valid Solana token on boot. If invalid, the user is seamlessly dropped back to the `/solana-auth` route.

## 3. VPN Routing Core (The Engine)
At the heart of Solana Shield is a highly optimized connection engine designed to handle complex routing rules and high-throughput data streams.

*   **Protocol Communication:** The UI communicates with the low-level VPN services via **gRPC (Google Remote Procedure Calls)** and **Protocol Buffers**. This ensures strict data contracts, incredibly fast serialization, and cross-platform compatibility for our future Desktop/iOS clients.
*   **Routing Logic:** The core supports standard direct connections, proxy protocols, and advanced obfuscation techniques to bypass deep packet inspection (DPI).
*   **Data Persistence:** Local configuration, connection history, and routing profiles are stored in a reactive **SQLite database** via the `drift` package, allowing the UI to instantly reflect changes in connection status or node latency.

## 4. Platform-Specific Implementations
While the UI is cross-platform, the networking stack is natively implemented to leverage OS-level APIs.

*   **Android (v1.0):** Utilizes Android's `VpnService` API to intercept and route all device traffic natively. The `MainActivity.kt` acts as the bridge, dynamically requesting required OS permissions (`REQUEST_ROUTE_TO_HOST`, `BIND_VPN_SERVICE`) upon user intent.

---

>[!NOTE]
>**[Diagram Placeholder]**
>*Please inset an architectural diagram here showing:*
>*Flutter UI <--> Riverpod State <--> MWA Intent (Phantom) & gRPC Core <--> Local SQLite & OS VpnService*
