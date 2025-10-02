# Stay Lit WLED Plugin

A WordPress plugin that provides custom WLED device and preset management functionality for the Stay Lit mobile app integration.

## Features

### WLED Device Management
- Custom post type for WLED devices
- MQTT client ID tracking and duplicate prevention
- IP address and connection status management
- User access control with allowed users list
- REST API endpoints for device state updates

### WLED Preset Management
- Custom post type for WLED presets
- Effect parameters (FX, colors, palette, speed, intensity)
- Custom parameters (C1, C2, C3) and options (O1, O2, O3)
- Category and icon management
- Public/private preset visibility

### User Management
- Extended user meta fields for billing information
- Installation date and warranty registration tracking
- REST API support for user meta fields

### Admin Interface
- Custom admin columns for devices and presets
- Meta boxes for easy editing
- Visual category and color displays
- Icon and emoji support

## REST API Endpoints

### Devices
- `GET /wp-json/wp/v2/wled_device` - List devices (filtered by user access)
- `POST /wp-json/wp/v2/wled_device` - Create new device
- `GET /wp-json/wp/v2/wled_device/{id}` - Get device details
- `POST /wp-json/wled/v1/devices/{id}/state` - Update device state

### Presets
- `GET /wp-json/wp/v2/wled_preset` - List presets (public + user's private)
- `POST /wp-json/wp/v2/wled_preset` - Create new preset
- `GET /wp-json/wp/v2/wled_preset/{id}` - Get preset details

### Users
- `GET /wp-json/wp/v2/users/{id}` - Get user with extended meta
- `POST /wp-json/wp/v2/users` - Create user with meta fields

## Installation

1. Upload the plugin folder to `/wp-content/plugins/`
2. Activate the plugin through the 'Plugins' menu in WordPress
3. The plugin will automatically register post types and grant capabilities

## Requirements

- WordPress 5.0 or higher
- PHP 7.4 or higher

## Security

- All REST API endpoints require proper authentication
- User access is controlled through allowed_users meta field
- Presets are private by default and filtered by ownership
- All inputs are sanitized and outputs are escaped

## Development

The plugin is organized into modular classes:
- `StayLit_WLED_Post_Types` - Custom post type registration
- `StayLit_WLED_REST_API` - REST API endpoints and filters
- `StayLit_WLED_Admin` - Admin interface and meta boxes
- `StayLit_WLED_User_Meta` - User meta field management
- `StayLit_WLED_Capabilities` - Role and capability management

## Changelog

### 1.0.0
- Initial release
- WLED device and preset management
- REST API integration
- Admin interface
- User meta extensions
