# iOS Assets.xcassets

This directory contains platform-specific assets for iOS applications.

## Structure

```
Assets.xcassets/
├── AppIcon.appiconset/     # App icon images
├── LaunchImage.imageset/    # Launch screen images
├── CustomImages.imageset/   # Custom image assets
└── README.md               # This file
```

## Usage

Place your platform-specific iOS assets in the appropriate folders. These will be copied to the iOS app during the build process.

## Supported Formats

- PNG (recommended)
- JPEG
- PDF (for vector graphics)
- SVG (converted to PDF)

## Image Set Structure

Each image set should contain:

- `Contents.json` - Metadata file
- `image.png` - Main image
- `image@2x.png` - Retina display image
- `image@3x.png` - Super retina display image

## Naming Convention

- Use camelCase for asset names
- Use descriptive names
- Example: `appIcon`, `launchImage`, `customBackground`
