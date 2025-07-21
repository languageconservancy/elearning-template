# Elearning Platform Template

This is a starter template for creating a new elearning platform. It uses a submodule approach where the core platform is a git submodule and platform-specific content is managed separately.

# Ways to Use This Template

1. Clone this repo and edit the remote origin and push to newly created repo that you own.
1. Fork this repo and clone it from your own account.

## Quick Start

1. **Fork this template** to your organization and name it the name of your platform/app.

1. **Clone your fork**:

   ```bash
   git clone git@github.com:your-org/your-platform.git
   cd your-platform
   ```

1. **Initialize the core submodules**:

   ```bash
   npm run init
   # or
   git submodule update --init --recursive
   ```

1. **Install dependencies**:

   ```bash
   npm run core install-dependencies
   ```

1. **Customize your platform**:

   - Edit `platform/assets/` with your content
   - Update `platform/config/` with your settings

1. **Upload demo database to phpMyAdmin**:

   - Import core/demo/elearning_demo_db.sql to phpMyAdmin

1. **Copy demo assets to core/backend/webroot**:

   ```bash
   npm run core copy-demo-assets
   ```

1. **Set the environment variable for your local web server root directory**:
   This example points to where MAMP places its web server root.

   ```bash
   echo "export WWW_PATH='/Applications/MAMP/htdocs'" >> ~/.bash_profile
   ```

1. **Copy backend to your local web server root directory**:

   ```bash
   npm run core update-local-backend
   ```

1. **Build and Serve your platform**:
   ```bash
   npm run serve:demo
   ```

## File Structure

See the [elearning-core/README.md](https://github.com/languageconservancy/elearning-core)

## Build Process

The build process:

1. **Copies platform assets** to core directories
1. **Take your config variables and generates files from templates** in the core directories
1. **Builds frontend** using Angular CLI
1. **Outputs** to `frontend/dist/`
1. **Updates Android & iOS projects** with latest web code

### Build Commands

To see all the commands, run:

```bash
npm run core
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
```

## Troubleshooting

### Build Fails

1. Ensure submodules are initialized: `npm run init`
2. Check that platform assets exist
3. Verify platofrm config files are correct

### Submodule Issues

1. Update submodules: `npm run update-core`
2. Reset submodules: `git submodule update --init --recursive --force`

## Contributing

1. Fork the template
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

Mozilla Public License - see LICENSE file for details.
