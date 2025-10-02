<?php
/**
 * WLED Post Types
 * 
 * @package StayLit_WLED
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class StayLit_WLED_Post_Types {
    
    /**
     * Single instance of the class
     */
    private static $instance = null;
    
    /**
     * Get single instance
     */
    public static function get_instance() {
        if (null === self::$instance) {
            self::$instance = new self();
        }
        return self::$instance;
    }
    
    /**
     * Constructor
     */
    private function __construct() {
        add_action('init', array($this, 'register_wled_device_post_type'));
        add_action('init', array($this, 'register_wled_preset_post_type'));
        add_action('save_post_wled_device', array($this, 'log_wled_device_save'), 10, 3);
        add_action('wp_insert_post', array($this, 'assign_posts_to_user'), 10, 3);
    }
    
    /**
     * Register WLED Device Custom Post Type
     */
    public function register_wled_device_post_type() {
        // Debug: Log post type registration
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Registering WLED Device post type');
        }
        register_post_type('wled_device', [
            'labels' => [
                'name' => 'WLED Devices',
                'singular_name' => 'WLED Device',
                'add_new' => 'Add New Device',
                'add_new_item' => 'Add New WLED Device',
                'edit_item' => 'Edit WLED Device',
                'new_item' => 'New WLED Device',
                'view_item' => 'View WLED Device',
                'search_items' => 'Search WLED Devices',
                'not_found' => 'No WLED Devices found',
                'not_found_in_trash' => 'No WLED Devices found in trash',
                'all_items' => 'All WLED Devices',
            ],
            'public' => true,
            'show_in_rest' => true,
            'show_ui' => true,
            'show_in_menu' => true,
            'menu_position' => 20,
            'menu_icon' => 'dashicons-admin-network',
            'supports' => ['title', 'custom-fields', 'author'],
            'capability_type' => 'wled_device',
            'capabilities' => [
                'create_posts' => 'create_wled_devices',
                'edit_posts' => 'edit_wled_devices',
                'edit_others_posts' => 'edit_others_wled_devices',
                'publish_posts' => 'publish_wled_devices',
                'read_private_posts' => 'read_private_wled_devices',
                'delete_posts' => 'delete_wled_devices',
                'delete_private_posts' => 'delete_private_wled_devices',
                'delete_published_posts' => 'delete_published_wled_devices',
                'delete_others_posts' => 'delete_others_wled_devices',
                'edit_private_posts' => 'edit_private_wled_devices',
                'edit_published_posts' => 'edit_published_wled_devices',
            ],
            'map_meta_cap' => true,
        ]);

        $meta_fields = [
            'mqtt_client_id' => 'string',
            'mqtt_username' => 'string',
            'mqtt_password' => 'string',
            'ip_address' => 'string',
            'allowed_users' => 'array',
            'timers_json' => 'string', // Added for timer sync
            'is_connected' => 'boolean',
            'on' => 'boolean',
            'bri' => 'integer',
            'last_mqtt_command' => 'string',
            'last_state_update' => 'string',
        ];

        foreach ($meta_fields as $key => $type) {
            register_meta('post', $key, [
                'object_subtype' => 'wled_device',
                'type' => $type,
                'single' => true,
                'show_in_rest' => [
                    'schema' => [
                        'type' => $type === 'array' ? 'array' : $type,
                        'items' => $type === 'array' ? ['type' => 'string'] : null,
                    ],
                ],
            ]);
        }
    }

    /**
     * Register WLED Preset Custom Post Type
     */
    public function register_wled_preset_post_type() {
        // Debug: Log post type registration
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Registering WLED Preset post type');
        }
        register_post_type('wled_preset', [
            'labels' => [
                'name' => 'WLED Presets',
                'singular_name' => 'WLED Preset',
                'add_new' => 'Add New Preset',
                'add_new_item' => 'Add New WLED Preset',
                'edit_item' => 'Edit WLED Preset',
                'new_item' => 'New WLED Preset',
                'view_item' => 'View WLED Preset',
                'search_items' => 'Search WLED Presets',
                'not_found' => 'No WLED Presets found',
                'not_found_in_trash' => 'No WLED Presets found in trash',
                'all_items' => 'All WLED Presets',
            ],
            'public' => true,
            'show_in_rest' => true,
            'show_ui' => true,
            'show_in_menu' => true,
            'menu_position' => 21,
            'menu_icon' => 'dashicons-lightbulb',
            'supports' => ['title', 'editor', 'custom-fields'],
            'capability_type' => 'wled_preset',
            'capabilities' => [
                'create_posts' => 'create_wled_presets',
                'edit_posts' => 'edit_wled_presets',
                'edit_others_posts' => 'edit_others_wled_presets',
                'publish_posts' => 'publish_wled_presets',
                'read_private_posts' => 'read_private_wled_presets',
                'delete_posts' => 'delete_wled_presets',
                'delete_private_posts' => 'delete_private_wled_presets',
                'delete_published_posts' => 'delete_published_wled_presets',
                'delete_others_posts' => 'delete_others_wled_presets',
                'edit_private_posts' => 'edit_private_wled_presets',
                'edit_published_posts' => 'edit_published_wled_presets',
            ],
            'map_meta_cap' => true,
            'menu_icon' => 'dashicons-lightbulb',
        ]);

        $preset_meta_fields = [
            // Core WLED effect parameters
            'fx' => 'integer',
            'colors' => 'array',
            'palette_id' => 'integer',
            'sx' => 'integer',
            'ix' => 'integer',
            'c1' => 'integer',
            'c2' => 'integer',
            'c3' => 'integer',
            'o1' => 'boolean',
            'o2' => 'boolean',
            'o3' => 'boolean',
            
            // Global state parameters
            'on' => 'boolean',         // On/off state
            'mainseg' => 'integer',    // Main segment ID
            
            // App-specific metadata
            'categories' => 'array',
            'icon_name' => 'string',
        ];

        foreach ($preset_meta_fields as $key => $type) {
            register_meta('post', $key, [
                'object_subtype' => 'wled_preset',
                'type' => $type,
                'single' => true,
                'show_in_rest' => [
                    'schema' => [
                        'type' => $type === 'array' ? 'array' : $type,
                        'items' => $type === 'array' ? ['type' => 'string'] : null,
                    ],
                ],
            ]);
        }
    }

    /**
     * Debug: Log when WLED devices are saved
     */
    public function log_wled_device_save($post_id, $post, $update) {
        if (defined('WP_DEBUG') && WP_DEBUG) {
            $allowed_users = get_post_meta($post_id, 'allowed_users', true);
            $ip_address = get_post_meta($post_id, 'ip_address', true);
            error_log("WLED Device Saved - ID: $post_id, Allowed Users: " . print_r($allowed_users, true) . ", IP: $ip_address");
        }
    }

    /**
     * Assign posts to the authenticated user
     */
    public function assign_posts_to_user($post_id, $post, $update) {
        if ($post->post_type === 'wled_device' && !$update) {
            $user = wp_get_current_user();
            if ($user->ID) {
                wp_update_post([
                    'ID' => $post_id,
                    'post_author' => $user->ID,
                ]);
            }
        }
    }
}
