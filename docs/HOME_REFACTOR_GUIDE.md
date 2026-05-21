# Home Screen Refactor — Step-by-Step (You Write the Code)

Empty placeholder files are in `lib/widgets/home/`, `lib/dialogs/`, and `lib/utils/`.
Each file has a comment header describing what to put there.

**Do not change `home_screen.dart` until the end.** Build and test each piece first.

---

## Folder tree

```
lib/
  screens/
    home_screen.dart          ← slim coordinator (keep until step 10)
  widgets/home/
    home_app_bar.dart
    home_search_field.dart
    orders_list_view.dart
    city_expansion_tile.dart
    pvz_expansion_tile.dart
    order_tile_widget.dart
    order_photo_preview.dart
    order_action_buttons.dart
  dialogs/
    order_bottom_sheet.dart
    order_comment_dialog.dart
    order_delay_dialog.dart
    order_payment_dialog.dart
  utils/
    order_grouping.dart
    pvz_style.dart
```

---

## Order of work (recommended)

| Step | File | Why this order |
|------|------|----------------|
| 1 | `pvz_style.dart` | No dependencies |
| 2 | `order_grouping.dart` | No UI, easy to test mentally |
| 3 | `order_photo_preview.dart` | Small widget |
| 4 | `order_action_buttons.dart` | Uses camera / QR |
| 5 | `order_comment_dialog.dart` | Small dialog |
| 6 | `order_delay_dialog.dart` | Stateful dropdown |
| 7 | `order_payment_dialog.dart` | Small dialog |
| 8 | `order_bottom_sheet.dart` | Opens dialogs from step 5–7 |
| 9 | `order_tile_widget.dart` | Combines 3–4 and 8 |
| 10 | `pvz_expansion_tile.dart` | Uses order tile |
| 11 | `city_expansion_tile.dart` | Uses PVZ tile |
| 12 | `orders_list_view.dart` | Uses city tile |
| 13 | `home_search_field.dart` | Simple |
| 14 | `home_app_bar.dart` | Logout flow |
| 15 | `home_screen.dart` | Wire everything + delete old code |

---

## Step 1 — `lib/utils/pvz_style.dart`

**Goal:** One function that returns color + initials for a PVZ name.

1. Create a small class or record, e.g. `PvzStyle { Color color; String initials; }`
2. Copy the `if (cNameLower.contains('wildberries'))` logic from `home_screen.dart`
3. Export: `PvzStyle getPvzStyle(String companyName)`

**Test:** Call from `main` or a temporary print — no UI needed.

---

## Step 2 — `lib/utils/order_grouping.dart`

**Goal:** Move all list logic out of `build`.

Implement:

```text
filterOrdersBySearch(Map<String, List<OrderModel>> all, String query)
  → if query empty: return all
  → else filter each group's orders by clientName, companyName, companyAddress

groupOrdersByCity(Map<String, List<OrderModel>> filtered)
  → for each folderKey + orders:
      city = orders[0].deliveryCity.trim() or "Неизвестный город"
      return Map<city, Map<folderKey, orders>>

sortOrders(List<OrderModel> orders)
  → copy list, sort "Готово" to bottom (do NOT sort inside build)
```

**Important:** Never call `.sort()` on the original list inside `build` — always copy first.

---

## Step 3 — `order_photo_preview.dart`

**Widget type:** `StatelessWidget`

**Parameters:**
- `String orderId`
- `String urlPhoto`
- `VoidCallback onDeleted`

**UI:** Copy Stack + `Image.network` + close button from `home_screen.dart`.
On close: `DatabaseService().clearOrderPhoto(orderId)` then `onDeleted()`.

---

## Step 4 — `order_action_buttons.dart`

**Parameters:** `OrderModel order`, `BuildContext context`, `VoidCallback onRefresh`

**UI:** Copy the green Row (camera, QR, delete QR).
- Camera: `ImagePicker` → `uploadOrderPhoto` → `onRefresh`
- QR: `Navigator.push` `QRScannerScreen` → `updateOrderQr` → `onRefresh`
- Delete QR: `clearOrderQr` → `onRefresh`

---

## Step 5–7 — Dialogs

Each dialog: static method is easiest:

```dart
static Future<void> show(BuildContext context, { required String orderId, ... })
```

| File | Saves via | After save |
|------|-----------|------------|
| `order_comment_dialog.dart` | `updateOrderComment` | `Navigator.pop` + callback |
| `order_delay_dialog.dart` | `delayOrder` | pop dialog + sheet + callback |
| `order_payment_dialog.dart` | `updateClientPayment` | pop + callback |

Copy UI from `home_screen.dart` bottom sheet section.

---

## Step 8 — `order_bottom_sheet.dart`

**Static method:** `show(context, order, onRefresh)`

**UI:** `showModalBottomSheet` with 3 `ListTile`s:
- Comment → `OrderCommentDialog.show(...)`
- Delay → `OrderDelayDialog.show(...)`
- Payment → `OrderPaymentDialog.show(...)`

---

## Step 9 — `order_tile_widget.dart`

**Parameters:** `OrderModel order`, `VoidCallback onRefresh`

**Structure:**
- `bool isDone = order.status == 'Готово'`
- Leading: tap toggles `SHIPPING` / `READY` via `updateOrderStatus` → `onRefresh`
- Title: client name (strikethrough if done)
- Subtitle: Column — status, QR text, `OrderPhotoPreview`, `OrderActionButtons`
- Trailing: more icon OR entire `onTap` opens `OrderBottomSheet.show`

**Key:** `key: ValueKey(order.id)` on the root widget.

---

## Step 10 — `pvz_expansion_tile.dart`

**Parameters:** `String folderKey`, `List<OrderModel> orders`, `VoidCallback onRefresh`

1. Call `sortOrders` from `order_grouping.dart` on a **copy** of orders
2. `getPvzStyle(companyName)` for avatar
3. `completedCount` / `totalCount` for trailing text
4. `ExpansionTile` children: `orders.map((o) => OrderTileWidget(...)).toList()`

---

## Step 11 — `city_expansion_tile.dart`

**Parameters:** `String city`, `Map<String, List<OrderModel>> pvzGroups`, `onRefresh`

- One `ExpansionTile` per city
- Children: each entry → `PvzExpansionTile(folderKey: key, orders: list, ...)`

---

## Step 12 — `orders_list_view.dart`

**Parameters:**
- `bool isLoading`
- `Map<String, Map<String, List<OrderModel>>>? cityGroups` (or build from parent)
- `Future<void> Function() onRefresh`

**Logic:**
- if loading → `CircularProgressIndicator`
- if empty → "Заказов не найдено"
- else `RefreshIndicator` + `ListView.builder` → `CityExpansionTile`

---

## Step 13 — `home_search_field.dart`

**Parameters:** `ValueChanged<String> onChanged`

Copy `TextField` + decoration from `home_screen.dart`.

**Optional (performance):** debounce 300ms before calling parent `onChanged`.

---

## Step 14 — `home_app_bar.dart`

Return `AppBar` with logout `IconButton` and confirmation dialog.
On confirm: `AuthService().signOut()` → `Navigator.pushReplacement` to `LoginScreen`.

---

## Step 15 — Slim `home_screen.dart`

**Keep in State:**
- `_allOrders`, `_isLoading`, `_userRole`, `_searchQuery`, `_pollingTimer`
- `_initData`, `_refreshOrders`, `dispose`

**In `build`:**
```text
Scaffold(
  appBar: HomeAppBar(...) or PreferredSizeWidget from your widget,
  body: Column(
    HomeSearchField(onChanged: (v) => setState(() => _searchQuery = v.toLowerCase())),
    Expanded(
      child: OrdersListView(
        isLoading: _isLoading,
        cityGroups: groupOrdersByCity(filterOrdersBySearch(_allOrders ?? {}, _searchQuery)),
        onRefresh: _refreshOrders,
      ),
    ),
  ),
  floatingActionButton: ... (keep FAB here — navigate AddOrderScreen),
)
```

Delete the old nested Builder / ExpansionTile / map code.

---

## Performance checklist (after refactor)

- [ ] Search debounced (not every keystroke rebuilding everything)
- [ ] Sort only on data load or on copy, not in `build`
- [ ] `ValueKey(order.id)` on order tiles
- [ ] Consider `cached_network_image` for photos later
- [ ] Timer 30s — OK; or increase to 60s if still laggy

---

## Verify

```bash
dart analyze lib
flutter run
```

Test: login → list loads → search → expand city/PVZ → photo → QR → comment → logout.
