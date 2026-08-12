# Naharym

Customer-facing ordering app — Phase 1 / MVP, item 1 of the five workplaces
described in `../Naharym-predlozhenie-RU.pptx` (slide 5).

Screens follow the approved mock-ups in `../Naharym-mockups-RU/`
(`cust_home.png`, `cust_cart.png`, `cust_track.png`).

## What it does

- **Browse the menu** — categories, search, a weekly promo banner, favorites.
- **Order in three taps** (proposal slide 5): pick a dish, set quantity/note,
  add to cart, checkout.
- **Address on the map** — a pin the customer drops, plus the microdistrict
  fields Ashgabat's address system actually runs on (mkr., dom, подъезд,
  этаж), not a street form.
- **"Сдача с какой суммы"** — the customer states the note size so the
  courier arrives with the right change ready.
- **Live courier tracking** — map, route, ETA and distance, once a courier is
  assigned.
- **Order history + one-tap reorder.**
- **Rating** after delivery.
- **Turkmen and Russian** from the first launch.
- Cash on delivery for this phase — card payment is shown but disabled
  ("2-й этап", proposal slide 14).

## Running it

```bash
flutter run
```

Ships in demo mode: `AppConfig.useMockData = true` serves the catalogue from
`core/data/mock/mock_data.dart` and simulates the order life-cycle locally
(see "How tracking works" below) since there is no backend yet.
**Sign in with any phone number and the code `0000`.**

## Configuration

Everything server-side lives in
[`lib/core/constants/app_config.dart`](lib/core/constants/app_config.dart):

| Constant | Purpose |
|---|---|
| `apiBaseUrl` | Backend. Point at the customer's own server at install time. |
| `useMockData` | `false` switches every repository call to the real backend. |
| `mapTileUrl` | Our tile server — same one the courier app uses. |
| `osrmBaseUrl` | Routing endpoint. |
| `deliveryFee` | Flat delivery charge added at checkout. |

Backend paths are listed in `ApiPaths`
([`lib/core/network/api_client.dart`](lib/core/network/api_client.dart)).

## Dish photography

There is no food photography yet. [`Dish.imageUrl`](lib/core/models/dish.dart)
is a single field — an asset path (`assets/images/dishes/<id>.jpg`) or a
network URL — and [`DishThumbnail`](lib/core/widgets/dish_thumbnail.dart) falls
back to a plain neutral tile wherever it's missing or fails to load. Drop real
photos in under the id used in `mock_data.dart` (e.g. `somsa-meat.jpg`) and
they appear everywhere that dish is shown — no code change needed.

## Onboarding

First launch only ([`OnboardingProvider`](lib/modules/onboarding/onboarding_provider.dart)
remembers it's done): two hero slides, then our own delivery mark with the
language pick. The two hero images aren't part of this change either — drop
`onboarding_1.png` and `onboarding_2.png` into
`assets/images/onboarding/`; until then those slides show a plain neutral
card instead of breaking. Skipping or finishing goes straight to the menu —
this never asks for sign-in, same as the rest of browsing.

## Structure

```
lib/
  core/
    constants/     app_config.dart — every server address and tuning value
    data/          repositories + the demo catalogue/order data
    localization/  AppStrings (ru / tk) and the language provider
    models/        dish, cart item, address, order, order status
    network/       Dio client and the endpoint list
    services/      location (one-shot, for address picking), routing,
                    connectivity, tile cache
    theme/         colours, type, icons — identical palette to the courier app
    widgets/       map, markers, dish thumbnail, buttons, order status chip
  modules/
    auth/          phone + SMS code sign-in
    home/          menu browsing, dish detail sheet (courier_list.png style)
    favorites/     hearted dishes
    cart/          the cart tab
    checkout/      address, change note, payment choice, place order
    orders/        history, reorder, live tracking screen
    profile/       language, map cache, support, sign-out
    shell/         bottom-nav shell + tab switcher
```

### How tracking works

Real status changes come from the operator, the kitchen and the courier's own
GPS (proposal slide 4) — this app only ever reads them. In demo mode there is
no backend to push those changes, so
[`OrderProvider._simulate`](lib/modules/orders/order_provider.dart) plays the
same sequence out locally on a compressed clock (accepted → cooked → courier
assigned → delivered) purely so the tracking screen has something honest to
show. The courier marker moves along an actual route fetched from the routing
service, the same way the courier app draws its own line — not a straight-line
guess.

## Permissions

Location is requested once, on demand, only when the customer picks a
delivery point on the map ("use my location") — never continuously, never in
the background, never sent anywhere.

## Assets

- `assets/fonts/` — Gilroy, matching the courier app and the other Naharym
  surfaces.
- `assets/animations/delivery_loader.mp4` — the loading animation.
- `assets/icons/car_marker.svg` — the courier's map marker.
- `assets/images/dishes/` — drop real dish photos here (see above).

## Tests

```bash
flutter test
```

Covers dish pricing/discounts, cart totals, order-status transitions, address
line formatting and money/distance formatting.
