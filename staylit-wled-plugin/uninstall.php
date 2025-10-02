<?php
/**
 * Uninstall script for Stay Lit WLED Plugin
 * 
 * This file is executed when the plugin is deleted through the WordPress admin.
 * 
 * IMPORTANT: This script does NOT delete your WLED devices and presets!
 * Your data is preserved for safety. Only plugin-specific settings are removed.
 * 
 * @package StayLit_WLED
 */

// If uninstall not called from WordPress, then exit
if (!defined('WP_UNINSTALL_PLUGIN')) {
    exit;
}

// SAFETY FIRST: We do NOT delete WLED devices and presets
// Your data is valuable and should be preserved even if you remove the plugin
// 
// If you want to delete your WLED data, you must do it manually through:
// 1. WordPress Admin → WLED Devices → Select All → Delete
// 2. WordPress Admin → WLED Presets → Select All → Delete
// 
// Or use this SQL query in your database (USE WITH EXTREME CAUTION):
// DELETE FROM wp_posts WHERE post_type IN ('wled_device', 'wled_preset');
// DELETE FROM wp_postmeta WHERE post_id NOT IN (SELECT ID FROM wp_posts);

// Only remove capabilities from all roles (safe to do)
$roles = ['subscriber', 'contributor', 'author', 'editor', 'administrator'];
$capabilities = [
    'create_wled_devices',
    'edit_wled_devices',
    'edit_published_wled_devices',
    'edit_private_wled_devices',
    'publish_wled_devices',
    'read_private_wled_devices',
    'delete_wled_devices',
    'delete_private_wled_devices',
    'delete_published_wled_devices',
    'edit_others_wled_devices',
    'delete_others_wled_devices',
    'create_wled_presets',
    'edit_wled_presets',
    'edit_published_wled_presets',
    'edit_private_wled_presets',
    'publish_wled_presets',
    'read_private_wled_presets',
    'delete_wled_presets',
    'delete_private_wled_presets',
    'delete_published_wled_presets',
    'edit_others_wled_presets',
    'delete_others_wled_presets',
];

foreach ($roles as $role_name) {
    $role = get_role($role_name);
    if ($role) {
        foreach ($capabilities as $cap) {
            $role->remove_cap($cap);
        }
    }
}

// We intentionally do NOT remove:
// 1. WLED devices and presets (your valuable data)
// 2. User meta fields (billing info, installation date, warranty)
// 3. Post meta fields (device settings, preset configurations)
// 
// These are preserved for your safety and business continuity.
