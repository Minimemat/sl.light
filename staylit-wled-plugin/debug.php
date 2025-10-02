<?php
/**
 * Debug script for Stay Lit WLED Plugin
 * 
 * Add this to your wp-config.php temporarily to run diagnostics:
 * require_once ABSPATH . 'wp-content/plugins/staylit-wled-plugin/debug.php';
 */

// Only run if we're in admin and user is admin
if (is_admin() && current_user_can('manage_options')) {
    add_action('admin_notices', function() {
        echo '<div class="notice notice-info"><p><strong>Stay Lit WLED Debug Info:</strong></p>';
        
        // Check if plugin files exist
        $plugin_dir = WP_PLUGIN_DIR . '/staylit-wled-plugin/';
        $files = [
            'staylit-wled-plugin.php',
            'includes/class-post-types.php',
            'includes/class-rest-api.php',
            'includes/class-admin.php',
            'includes/class-user-meta.php',
            'includes/class-capabilities.php'
        ];
        
        echo '<ul>';
        foreach ($files as $file) {
            $exists = file_exists($plugin_dir . $file);
            $status = $exists ? '✅' : '❌';
            echo '<li>' . $status . ' ' . $file . '</li>';
        }
        echo '</ul>';
        
        // Check if post types are registered
        $post_types = get_post_types(['public' => true], 'names');
        $wled_device = in_array('wled_device', $post_types) ? '✅' : '❌';
        $wled_preset = in_array('wled_preset', $post_types) ? '✅' : '❌';
        
        echo '<p><strong>Post Types:</strong></p>';
        echo '<ul>';
        echo '<li>' . $wled_device . ' wled_device</li>';
        echo '<li>' . $wled_preset . ' wled_preset</li>';
        echo '</ul>';
        
        // Check current user capabilities
        $current_user = wp_get_current_user();
        echo '<p><strong>Current User:</strong> ' . $current_user->user_login . ' (' . implode(', ', $current_user->roles) . ')</p>';
        
        $capabilities = [
            'create_wled_devices',
            'edit_wled_devices',
            'create_wled_presets',
            'edit_wled_presets'
        ];
        
        echo '<p><strong>User Capabilities:</strong></p>';
        echo '<ul>';
        foreach ($capabilities as $cap) {
            $has_cap = current_user_can($cap) ? '✅' : '❌';
            echo '<li>' . $has_cap . ' ' . $cap . '</li>';
        }
        echo '</ul>';
        
        // Check if classes exist
        $classes = [
            'StayLit_WLED_Plugin',
            'StayLit_WLED_Post_Types',
            'StayLit_WLED_REST_API',
            'StayLit_WLED_Admin',
            'StayLit_WLED_User_Meta',
            'StayLit_WLED_Capabilities'
        ];
        
        echo '<p><strong>Classes Loaded:</strong></p>';
        echo '<ul>';
        foreach ($classes as $class) {
            $exists = class_exists($class) ? '✅' : '❌';
            echo '<li>' . $exists . ' ' . $class . '</li>';
        }
        echo '</ul>';
        
        echo '</div>';
    });
}
