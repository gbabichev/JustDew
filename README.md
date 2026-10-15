<div align="center">

<img src="docs/icon.png" alt="JustDew icon" width="100">

## JustDew

A focused dew point weather app for iPhone, Mac, and Apple Watch.

[Website](https://gbabichev.github.io/JustDew/) ·
[Changelog](CHANGELOG.md) ·
[Support](https://gbabichev.github.io/JustDew/Support.html) ·
[Privacy](https://gbabichev.github.io/JustDew/PrivacyPolicy.html)

</div>

<p align="center">
  <a href="docs/ios-1.jpg"><img src="docs/readme-ios.jpg" width="30%" alt="JustDew iPhone app"></a>
  <a href="docs/mac-1.jpg"><img src="docs/readme-mac.jpg" width="30%" alt="JustDew Mac widget"></a>
  <a href="docs/watch-2.png"><img src="docs/readme-watch.jpg" width="30%" alt="JustDew Apple Watch complication"></a>
</p>

<p align="center">
  <strong>Product website:</strong>
  <a href="https://gbabichev.github.io/JustDew/">gbabichev.github.io/JustDew</a>
</p>

JustDew is a small weather utility built around one useful number: dew point. It uses WeatherKit to show the current dew point for your current location or a saved city, then keeps that value visible through widgets and Apple Watch complications.

## Features

- Dew point, air temperature, humidity, location, and last update time
- Up to 10 days of forecast data, including today and nine upcoming days
- Saved locations with swipeable pages on iPhone and iPad
- Add, select, and remove cities through the Locations list
- iPhone and Mac widgets, including Always Dark and configurable location widgets
- Apple Watch app and complications
- Blue to yellow to red dew point comfort scale
- No analytics, ads, tracking, or developer-side location logging

## Requirements

- iOS 26.0 or later
- macOS 26.0 or later
- watchOS 26.0 or later
- Apple WeatherKit availability

## Build From Source

```bash
git clone https://github.com/gbabichev/JustDew.git
cd JustDew
open JustDew.xcodeproj
```

## Locations and Widgets

Open **Locations** and type a city or ZIP code to see Apple Maps autocomplete
suggestions. Select a suggestion to resolve and save that exact place, or use
Current Location.
On iPhone and iPad, swipe between saved location pages. On Mac and Apple Watch,
choose a location from the Locations list. Swipe to delete a saved location on
mobile devices, or use its context menu on Mac.

**Dew Point** and **Dew Point · Always Dark** always follow your current location.
Browsing a saved city in the app does not change them.
All four iOS and Mac widget styles offer a large size with current conditions
and the next seven days of dew point forecasts.

Use **Dew Point · Location** or **Dew Point · Location · Always Dark** to pin a
widget to a city saved on that device. Both offer small, medium, and large sizes; the
Location widget also supports Lock Screen sizes and an Always Dark switch.
Edit a location widget to choose its location. Each widget keeps its own choice.
System tinting and Lock Screen rendering still control widget presentation.

On Apple Watch, **Current Location** always follows your device.
Add **Saved Location** to your watch face or Smart Stack,
then configure its Location to choose a city saved in the Watch app. Each
complication keeps its own selection when you browse other locations in the app.
Locations are saved separately on each device.

## Storage Checks

Run the focused persistence checks without WeatherKit credentials:

```bash
swiftc -module-cache-path /tmp/JustDewSwiftModuleCache \
  SharedCore/DewPointModels.swift SharedCore/DewPointConfiguration.swift \
  SharedCore/DewPointStore.swift Tests/DewPointStoreTests.swift \
  -o /tmp/JustDewStoreTests
/tmp/JustDewStoreTests
```

## Changelog

### 1.1 (Upcoming)

- Primary Dew Point widgets, Always Dark widgets, and standard Watch complications
  now follow Current Location instead of the last city viewed in the app.
- To keep a widget on a saved city, use a Location widget or complication.
- Widgets without location access show their last cached Current Location reading
  when available; they do not substitute the app's selected city.

### 1.0.0

- Initial Release

## Support

Support is handled through [GitHub Issues](https://github.com/gbabichev/JustDew/issues).

## Privacy

See the [Privacy Policy](https://gbabichev.github.io/JustDew/PrivacyPolicy.html).
