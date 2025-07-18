# Elearning Platform Template

This is a starter template for creating a new elearning platform. It uses a submodule approach where the core platform is a git submodule and platform-specific content is managed separately.

## Quick Start

1. **Fork this template** to your organization
2. **Clone your fork**:

   ```bash
   git clone https://github.com/your-org/your-platform.git
   cd your-platform
   ```

3. **Initialize the core submodules**:

   ```bash
   npm run init
   # or
   git submodule update --init --recursive
   ```

4. **Customize your platform**:

   - Edit `platform-assets/` with your content
   - Update `platform-config.json` with your settings
   - Modify environment files in `platform-assets/environments/`

5. **Build your platform**:
   ```bash
   npm run build
   # or
   ./build.sh
   ```

## File Structure

```
template/
├── build.sh                 # Build script
├── package.json             # NPM scripts
├── .gitmodules              # Git submodule definitions
├── platform-config.json     # Platform configuration
├── platform-assets/         # Platform-specific content
│   ├── assets/
│   │   ├── images/          # Platform images (logo, favicon, etc.)
│   │   ├── fonts/           # Custom fonts
│   │   └── scss/            # Platform-specific styles
│   ├── translations/        # Platform translations
│   ├── environments/        # Environment configuration files
│   └── backend-config/      # Backend configuration files
└── README.md               # This file
```

## Platform Customization

### 1. Platform Configuration

Edit `platform-config.json` to set your platform metadata:

```json
{
  "platform": {
    "name": "my-platform",
    "displayName": "My Learning Platform",
    "language": "en",
    "region": "US"
  }
}
```

### 2. Platform Assets

#### Images

Place your platform-specific images in `platform-assets/assets/images/`:

- `logo.png` - Your platform logo
- `favicon.ico` - Your platform favicon
- `hero-image.jpg` - Hero/banner images

#### Styles

Create custom styles in `platform-assets/assets/scss/`:

- `_platform-theme.scss` - Override default theme variables
- `_custom-components.scss` - Custom component styles

#### Fonts

Add custom fonts to `platform-assets/assets/fonts/`

### 3. Translations

Add platform-specific translations in `platform-assets/translations/`:

- `en.json` - English translations
- `es.json` - Spanish translations
- etc.

### 4. Environment Configuration

Configure environment-specific settings in `platform-assets/environments/`:

- `environment.local.ts` - Local development
- `environment.staging.ts` - Staging environment
- `environment.production.ts` - Production environment

### 5. Backend Configuration

Add backend configuration files in `platform-assets/backend-config/`:

- `app.platform.php` - Platform-specific app config
- `database.php` - Database configuration
- `email.php` - Email configuration

## Build Process

The build process:

1. **Updates core submodules** to latest versions
2. **Copies platform assets** to core directories
3. **Builds frontend** using Angular CLI
4. **Builds backend** using Composer
5. **Outputs** to `frontend/dist/` and `backend/webroot/`

### Build Commands

```bash
# Build for production
npm run build:production

# Build for staging
npm run build:staging

# Build for local development
npm run build:local

# Serve for development
npm run serve

# Update core submodules
npm run update-core

# Clean build outputs
npm run clean
```

## Development Workflow

### 1. Initial Setup

```bash
git clone your-platform-repo
cd your-platform
npm run init
npm install
```

### 2. Development

```bash
# Make changes to platform assets
# Edit files in platform-assets/

# Build and test
npm run build:local

# Serve for development
npm run serve
```

### 3. Updating Core

```bash
# Update to latest core version
npm run update-core

# Test with new core
npm run build:local
```

### 4. Deployment

```bash
# Build for production
npm run build:production

# Deploy frontend/dist/ and backend/webroot/
```

## Core Submodules

This template uses the following core submodules:

- **frontend**: Angular application
- **backend**: CakePHP application
- **demo-assets**: Mock assets for development

## Troubleshooting

### Build Fails

1. Ensure submodules are initialized: `npm run init`
2. Check that platform assets exist
3. Verify environment files are correct

### Submodule Issues

1. Update submodules: `npm run update-core`
2. Reset submodules: `git submodule update --init --recursive --force`

### Environment Issues

1. Check environment files in `platform-assets/environments/`
2. Verify API URLs and configuration
3. Check backend configuration files

## Contributing

1. Fork the template
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.
