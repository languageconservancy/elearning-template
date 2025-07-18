# Android Drawable Assets

This directory contains platform-specific drawable assets for Android applications.

## Structure

```
drawable/
├── drawable/           # General drawable resources
├── drawable-hdpi/     # High density drawables
├── drawable-mdpi/     # Medium density drawables
├── drawable-xhdpi/    # Extra high density drawables
├── drawable-xxhdpi/   # Extra extra high density drawables
├── drawable-xxxhdpi/  # Extra extra extra high density drawables
├── drawable-land/     # Landscape orientation drawables
├── drawable-port/     # Portrait orientation drawables
└── mipmap-*/         # App icons and launcher icons
```

## Usage

Place your platform-specific drawable assets in the appropriate density folders. These will be copied to the Android app during the build process.

## Supported Formats

- PNG (recommended for icons and graphics)
- JPEG (for photos)
- WebP (for better compression)
- Vector drawables (XML)

## Naming Convention

- Use lowercase letters
- Separate words with underscores
- Use descriptive names
- Example: `app_icon.png`, `background_image.jpg`
