# FamCare Design System

## Colors
- Primary Blue: `#0EA5E9`
- Dark Slate: `#1E293B`
- Background: `#F8FAFC`
- **Mandate**: Use `Theme.of(context).colorScheme` over hardcoded hex values.

## Icons
- **Strictly enforce**: Use the `lucide_icons` package for all iconography.

## Animations
- **Mandate**: Use the `flutter_animate` package. All list items and cards must have a smooth `.fade().slideY()` entrance.

## Loading States
- **Mandate**: Use the `shimmer` package for skeleton loaders instead of basic CircularProgressIndicators.