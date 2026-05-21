# Arash Courier — How the Whole App Is Built

Guide for building and understanding the app from scratch (you implement the code).

---

## 1. What the app does

Courier app for **Arash Courier**:
- Login with email/password (Supabase Auth)
- View orders grouped by **city** → **PVZ (pickup point)** → **client**
- Update status, photo, QR, comment, payment, delay
- Create new orders
- Role from `profiles` table (`courier` filters some statuses)

---

## 2. Tech stack

| Layer | Technology |
|-------|------------|
| UI | Flutter (Material 3) |
| Backend | Supabase (Postgres + Auth + Storage) |
| Packages | `supabase_flutter`, `image_picker`, `mobile_scanner` |

---

## 3. Project layout (full app)

```
lib/
  main.dart                 ← entry: Supabase init, MyApp, session check
  models/
    order_model.dart        ← data class: fields, fromJson, toJson, copyWith
  services/
    auth_service.dart       ← signIn, signOut, getUserRole
    database_service.dart   ← orders CRUD, photo upload, grouping fetch
  screens/
    login_screen.dart       ← email/password form
    home_screen.dart        ← main list (refactor to use widgets/)
    add_order_screen.dart   ← create/edit order form
    qr_scanner_screen.dart  ← camera QR scan, pop result
  widgets/home/             ← split UI from home (you fill these)
  dialogs/                  ← order menus and forms
  utils/                      ← grouping + PVZ styling
docs/
  HOME_REFACTOR_GUIDE.md      ← refactor steps
  APPLICATION_BUILD_GUIDE.md  ← this file
```

---

## 4. Build order (if starting from zero)

### Phase A — Backend (Supabase)

1. Create Supabase project
2. Table **`orders`** — columns matching `OrderModel.toJson` keys
3. Table **`profiles`** — `id` (uuid, matches auth.users), `role` (text)
4. Storage bucket **`packages`** — public or signed URLs for photos
5. **RLS policies** — authenticated users can read/write their data
6. Create test users in Auth + rows in `profiles`

### Phase B — Flutter shell

1. `flutter create` project, add dependencies in `pubspec.yaml`
2. **`main.dart`**
   - `WidgetsFlutterBinding.ensureInitialized()` if needed
   - `await Supabase.initialize(url, anonKey)`
   - `runApp(MyApp())`
   - `MyApp`: if `currentSession != null` → `HomeScreen` else `LoginScreen`

### Phase C — Data layer

3. **`order_model.dart`**
   - All fields from DB
   - `fromJson` / `toJson`
   - `_translateStatus` for English → Russian statuses

4. **`auth_service.dart`**
   - `signInWithEmail`, `signOut`, `getUserRole` from `profiles`

5. **`database_service.dart`**
   - `fetchAndSortOrders(role)` — select orders, filter for courier, group by folder key
   - `updateOrderComment`, `updateClientPayment`, `delayOrder`
   - `uploadOrderPhoto`, `clearOrderPhoto`, `updateOrderQr`, `clearOrderQr`
   - `updateOrderStatus`, `createOrder`

### Phase D — Screens

6. **`login_screen.dart`**
   - Controllers for email/password
   - Call `AuthService.signInWithEmail`
   - On success: `pushReplacement` to `HomeScreen`

7. **`home_screen.dart`**
   - Load role + orders in `initState`
   - Timer refresh every 30s
   - Search, grouped list, FAB → `AddOrderScreen`
   - **Refactor:** follow `HOME_REFACTOR_GUIDE.md`

8. **`qr_scanner_screen.dart`**
   - `MobileScanner`, on first barcode → `Navigator.pop(context, rawValue)`

9. **`add_order_screen.dart`**
   - Form fields → build `OrderModel` → `Navigator.pop(context, order)`
   - HomeScreen calls `createOrder` then `_refreshOrders`

### Phase E — Polish

10. Error messages (SnackBar), loading states
11. Permissions: camera in `AndroidManifest.xml` / iOS `Info.plist`
12. Move Supabase keys to `--dart-define` or `.env` (not hardcoded in git)

---

## 5. Data flow diagram

```
main.dart
  └─ MyApp
       ├─ LoginScreen ──► AuthService ──► Supabase Auth
       └─ HomeScreen
            ├─ AuthService.getUserRole() ──► profiles
            ├─ DatabaseService.fetchAndSortOrders() ──► orders
            ├─ OrderTile actions ──► DatabaseService updates / Storage
            └─ FAB ──► AddOrderScreen ──► createOrder ──► refresh list
```

---

## 6. Supabase ↔ Flutter field map

| DB column (snake_case) | OrderModel field |
|------------------------|------------------|
| id | id |
| date_created | dateCreated |
| updated_at | dateUpdated |
| company_name | companyName |
| company_address | companyAddress |
| responsible_person | responsiblePerson |
| client_name | clientName |
| delivery_city | deliveryCity |
| pvz_qr_code | pvzQrCode |
| client_qr_code | clientQrCode |
| url_photo | urlPhoto |
| status | status (translate on read) |
| comment | comment |
| cancel_reason | cancelReason |
| client_payment | clientPayment |
| debt_amount | debtAmount |
| delivery_price | deliveryPrice |
| points_deduction | pointsDeduction |

---

## 7. Status values

**Written to DB (examples):** `READY`, `SHIPPING`, `delayed`, etc.

**Shown in UI (Russian):** via `OrderModel._translateStatus` — e.g. `READY` → `Готово`

Toggle on home: `Готово` ↔ `SHIPPING` / `READY`.

---

## 8. Commands you use daily

```bash
# Get packages
flutter pub get

# Run on device/emulator
flutter run

# Check errors
dart analyze lib

# Build APK
flutter build apk --debug
```

---

## 9. Common problems

| Problem | Check |
|---------|--------|
| Blank list after login | RLS on `orders`, user authenticated |
| Login fails | Email confirmed in Supabase, correct password |
| Photo upload fails | Bucket name `packages`, storage policy |
| QR scan black screen | Camera permission |
| Lag on home | See performance section in `HOME_REFACTOR_GUIDE.md` |

---

## 10. Your current task

1. Open each placeholder in `lib/widgets/home/`, `lib/dialogs/`, `lib/utils/`
2. Read the header comment in each file
3. Follow **`docs/HOME_REFACTOR_GUIDE.md`** steps 1–15
4. Keep `home_screen.dart` working until step 15

When stuck, compare with the original code still in `home_screen.dart` — copy UI block by block into the new file.

---

## 11. After refactor is done

Optional next features:
- Pull-to-refresh only (disable or lengthen Timer)
- `cached_network_image`
- Admin vs courier UI by role
- Realtime Supabase subscription instead of polling
