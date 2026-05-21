# Project structure (quick reference)

```
arash_curier/
├── docs/
│   ├── APPLICATION_BUILD_GUIDE.md   ← whole app: how to build everything
│   ├── HOME_REFACTOR_GUIDE.md       ← split home_screen: step-by-step
│   └── STRUCTURE.md                 ← this file
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── order_model.dart
│   ├── services/
│   │   ├── auth_service.dart
│   │   └── database_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── login_screen.dart
│   │   ├── add_order_screen.dart
│   │   └── qr_scanner_screen.dart
│   ├── widgets/home/          ← YOU implement (placeholders only)
│   │   ├── home_app_bar.dart
│   │   ├── home_search_field.dart
│   │   ├── orders_list_view.dart
│   │   ├── city_expansion_tile.dart
│   │   ├── pvz_expansion_tile.dart
│   │   ├── order_tile_widget.dart
│   │   ├── order_photo_preview.dart
│   │   └── order_action_buttons.dart
│   ├── dialogs/               ← YOU implement
│   │   ├── order_bottom_sheet.dart
│   │   ├── order_comment_dialog.dart
│   │   ├── order_delay_dialog.dart
│   │   └── order_payment_dialog.dart
│   └── utils/                 ← YOU implement
│       ├── order_grouping.dart
│       └── pvz_style.dart
└── pubspec.yaml
```

**Note:** Placeholder `.dart` files contain comments only — no runnable code yet.
`home_screen.dart` is unchanged and still runs the full UI.
