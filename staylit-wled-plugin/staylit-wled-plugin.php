<?php
/**
 * Plugin Name: Stay Lit WLED Plugin
 * Plugin URI: https://staylit.com
 * Description: Custom WLED device and preset management functionality for Stay Lit app integration.
 * Version: 1.0.0
 * Author: Stay Lit
 * Author URI: https://staylit.com
 * Text Domain: staylit-wled
 * Domain Path: /languages
 * Requires at least: 5.0
 * Tested up to: 6.4
 * Requires PHP: 7.4
 * License: GPL v2 or later
 * License URI: https://www.gnu.org/licenses/gpl-2.0.html
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Define plugin constants
define('STAYLIT_WLED_VERSION', '1.0.0');
define('STAYLIT_WLED_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('STAYLIT_WLED_PLUGIN_URL', plugin_dir_url(__FILE__));
define('STAYLIT_WLED_PLUGIN_FILE', __FILE__);

/**
 * Main plugin class
 */
class StayLit_WLED_Plugin {
    
    /**
     * Single instance of the plugin
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
        add_action('init', array($this, 'init'));
        add_action('plugins_loaded', array($this, 'load_textdomain'));
        
        // Also try loading on plugins_loaded as backup
        add_action('plugins_loaded', array($this, 'init'), 20);
        
        // Activation and deactivation hooks
        register_activation_hook(__FILE__, array($this, 'activate'));
        register_deactivation_hook(__FILE__, array($this, 'deactivate'));
    }
    
    /**
     * Initialize the plugin
     */
    public function init() {
        // Debug: Log plugin initialization
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Initializing...');
        }
        
        // Load plugin modules
        $this->load_modules();
        
        // Recovery tools available but not auto-loaded to prevent notices
        // Access via Tools → WLED Data Recovery if needed
        
        // Debug: Log after modules loaded
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Modules loaded');
            error_log('StayLit WLED Plugin: Post Types class exists: ' . (class_exists('StayLit_WLED_Post_Types') ? 'Yes' : 'No'));
        }
    }
    
    /**
     * Load plugin modules
     */
    private function load_modules() {
        // Core functionality (admin class excluded to prevent conflicts)
        $files = [
            'includes/class-post-types.php',
            'includes/class-rest-api.php',
            // 'includes/class-admin.php', // Excluded to prevent duplicate columns
            'includes/class-user-meta.php',
            'includes/class-capabilities.php'
        ];
        
        foreach ($files as $file) {
            $file_path = STAYLIT_WLED_PLUGIN_DIR . $file;
            if (file_exists($file_path)) {
                require_once $file_path;
                if (defined('WP_DEBUG') && WP_DEBUG) {
                    error_log("StayLit WLED Plugin: Loaded $file");
                }
            } else {
                if (defined('WP_DEBUG') && WP_DEBUG) {
                    error_log("StayLit WLED Plugin: ERROR - File not found: $file_path");
                }
            }
        }
        
        // Initialize classes (Admin class completely disabled to prevent conflicts)
        if (class_exists('StayLit_WLED_Post_Types')) {
            StayLit_WLED_Post_Types::get_instance();
        }
        if (class_exists('StayLit_WLED_REST_API')) {
            StayLit_WLED_REST_API::get_instance();
        }
        // StayLit_WLED_Admin completely disabled - using emergency fallback instead
        if (class_exists('StayLit_WLED_User_Meta')) {
            StayLit_WLED_User_Meta::get_instance();
        }
        if (class_exists('StayLit_WLED_Capabilities')) {
            StayLit_WLED_Capabilities::get_instance();
        }
    }
    
    /**
     * Load plugin textdomain
     */
    public function load_textdomain() {
        load_plugin_textdomain('staylit-wled', false, dirname(plugin_basename(__FILE__)) . '/languages');
    }
    
    /**
     * Plugin activation
     */
    public function activate() {
        // Register post types first
        $this->load_modules();
        
        // Flush rewrite rules
        flush_rewrite_rules();
        
        // Grant capabilities to existing roles
        StayLit_WLED_Capabilities::get_instance()->grant_capabilities_to_roles();
    }
    
    /**
     * Plugin deactivation
     */
    public function deactivate() {
        // Flush rewrite rules
        flush_rewrite_rules();
        
        // Log deactivation for safety
        if (defined('WP_DEBUG') && WP_DEBUG) {
            $device_count = wp_count_posts('wled_device');
            $preset_count = wp_count_posts('wled_preset');
            error_log("StayLit WLED Plugin: Deactivated. Devices: {$device_count->publish}, Presets: {$preset_count->publish}");
        }
    }
}

// Initialize the plugin
StayLit_WLED_Plugin::get_instance();

// Emergency fallback: Register post types directly if classes fail to load
add_action('init', function() {
    if (!post_type_exists('wled_device')) {
        // Direct post type registration as fallback
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
        ]);
        
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Emergency fallback - wled_device registered directly');
        }
        
        // Register meta fields for WLED devices
        $device_meta_fields = [
            'mqtt_client_id' => 'string',
            'mqtt_username' => 'string',
            'mqtt_password' => 'string',
            'ip_address' => 'string',
            'allowed_users' => 'array',
            'timers_json' => 'string',
            'is_connected' => 'boolean',
            'on' => 'boolean',
            'bri' => 'integer',
            'last_mqtt_command' => 'string',
            'last_state_update' => 'string',
        ];

        foreach ($device_meta_fields as $key => $type) {
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
    
    if (!post_type_exists('wled_preset')) {
        // Direct post type registration as fallback
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
        ]);
        
        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('StayLit WLED Plugin: Emergency fallback - wled_preset registered directly');
        }
        
        // Register meta fields for WLED presets
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
            'on' => 'boolean',
            'mainseg' => 'integer',
            
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
}, 5); // Priority 5 to run early

// Emergency fallback: Add meta boxes for editing
add_action('add_meta_boxes', function() {
    // WLED Device meta boxes
    add_meta_box(
        'wled_device_settings',
        'WLED Device Settings',
        'wled_device_meta_box_callback',
        'wled_device',
        'normal',
        'high'
    );
    
    add_meta_box(
        'wled_device_users',
        'Device Access & Users',
        'wled_device_users_meta_box_callback',
        'wled_device',
        'side',
        'default'
    );
});

// Hide custom fields meta box for WLED devices and presets (except for administrators)
add_action('add_meta_boxes', function() {
    // Only hide custom fields for non-administrators
    if (!current_user_can('manage_options')) {
        remove_meta_box('postcustom', 'wled_device', 'normal');
        remove_meta_box('postcustom', 'wled_preset', 'normal');
    }
}, 20);

// Add admin notice for administrators about custom fields
add_action('admin_notices', function() {
    if (current_user_can('manage_options') && (get_current_screen()->post_type === 'wled_device' || get_current_screen()->post_type === 'wled_preset')) {
        echo '<div class="notice notice-info is-dismissible"><p><strong>Admin Note:</strong> Custom fields are visible for administrators. Regular users see only the organized meta boxes.</p></div>';
    }
});

// WLED Device settings meta box callback
function wled_device_meta_box_callback($post) {
    wp_nonce_field('wled_device_meta_box', 'wled_device_meta_box_nonce');
    
    // Get current values
    $mqtt_client_id = get_post_meta($post->ID, 'mqtt_client_id', true) ?: '';
    $mqtt_username = get_post_meta($post->ID, 'mqtt_username', true) ?: '';
    $mqtt_password = get_post_meta($post->ID, 'mqtt_password', true) ?: '';
    $ip_address = get_post_meta($post->ID, 'ip_address', true) ?: '';
    $is_connected = get_post_meta($post->ID, 'is_connected', true);
    $on = get_post_meta($post->ID, 'on', true);
    $bri = get_post_meta($post->ID, 'bri', true) ?: 128;
    $last_mqtt_command = get_post_meta($post->ID, 'last_mqtt_command', true) ?: '';
    $last_state_update = get_post_meta($post->ID, 'last_state_update', true) ?: '';
    
    ?>
    <table class="form-table">
        <tr>
            <th scope="row"><label for="ip_address">IP Address</label></th>
            <td>
                <input type="text" id="ip_address" name="ip_address" value="<?php echo esc_attr($ip_address); ?>" class="regular-text" />
                <p class="description">Device IP address on the network</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="mqtt_client_id">MQTT Client ID</label></th>
            <td>
                <input type="text" id="mqtt_client_id" name="mqtt_client_id" value="<?php echo esc_attr($mqtt_client_id); ?>" class="regular-text" />
                <p class="description">Unique MQTT client identifier (usually MAC address)</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="mqtt_username">MQTT Username</label></th>
            <td>
                <input type="text" id="mqtt_username" name="mqtt_username" value="<?php echo esc_attr($mqtt_username); ?>" class="regular-text" />
                <p class="description">MQTT broker username</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="mqtt_password">MQTT Password</label></th>
            <td>
                <input type="password" id="mqtt_password" name="mqtt_password" value="<?php echo esc_attr($mqtt_password); ?>" class="regular-text" />
                <p class="description">MQTT broker password</p>
            </td>
        </tr>
        
        <?php if ($last_mqtt_command): ?>
        <tr>
            <th scope="row">Last MQTT Command</th>
            <td>
                <textarea readonly class="large-text" rows="3"><?php echo esc_textarea($last_mqtt_command); ?></textarea>
                <p class="description">Last command sent to the device</p>
            </td>
        </tr>
        <?php endif; ?>
        
        <?php if ($last_state_update): ?>
        <tr>
            <th scope="row">Last State Update</th>
            <td>
                <input type="text" value="<?php echo esc_attr($last_state_update); ?>" class="regular-text" readonly />
                <p class="description">Last time device state was updated</p>
            </td>
        </tr>
        <?php endif; ?>
    </table>
    <?php
}

// WLED Device users meta box callback
function wled_device_users_meta_box_callback($post) {
    // Get current values
    $allowed_users = get_post_meta($post->ID, 'allowed_users', true) ?: [];
    $mqtt_client_id = get_post_meta($post->ID, 'mqtt_client_id', true) ?: '';
    
    // Get post author
    $author = get_user_by('ID', $post->post_author);
    
    ?>
    <div class="wled-device-users">
        <h4>📋 Device Information</h4>
        <p><strong>Device ID:</strong> <?php echo esc_html($mqtt_client_id ?: 'Not set'); ?></p>
        <p><strong>Created:</strong> <?php echo get_the_date('M j, Y g:i A', $post); ?></p>
        <p><strong>Modified:</strong> <?php echo get_the_modified_date('M j, Y g:i A', $post); ?></p>
        
        <h4>🔧 Device Owner</h4>
        <?php if ($author): ?>
            <div style="background: #e7f3ff; padding: 10px; border-radius: 4px; margin-bottom: 15px;">
                <p><strong>Name:</strong> <?php echo esc_html($author->display_name); ?></p>
                <p><strong>Email:</strong> <?php echo esc_html($author->user_email); ?></p>
            </div>
        <?php else: ?>
            <p style="color: #999;">No owner assigned</p>
        <?php endif; ?>
        
        <h4>👥 Allowed Users</h4>
        <textarea name="allowed_users_textarea" class="widefat" rows="4" placeholder="Enter email addresses, one per line"><?php 
            if (is_array($allowed_users)) {
                echo esc_textarea(implode("\n", $allowed_users));
            }
        ?></textarea>
        <p class="description">Users who can access this device (one email per line)</p>
        
        <?php if (is_array($allowed_users) && !empty($allowed_users)): ?>
        <div style="margin-top: 10px;">
            <strong>Current allowed users:</strong>
            <ul style="margin: 5px 0 0 20px;">
                <?php foreach ($allowed_users as $user_email): ?>
                    <li><?php echo esc_html($user_email); ?></li>
                <?php endforeach; ?>
            </ul>
        </div>
        <?php endif; ?>
    </div>
    
    <style>
    .wled-device-users h4 {
        margin: 15px 0 8px 0;
        font-size: 14px;
    }
    .wled-device-users p {
        margin: 4px 0;
    }
    </style>
    <?php
}

// Save meta box data
add_action('save_post', function($post_id) {
    // Handle WLED Device meta box
    if (isset($_POST['wled_device_meta_box_nonce']) && wp_verify_nonce($_POST['wled_device_meta_box_nonce'], 'wled_device_meta_box')) {
        if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
            return;
        }
        
        if (!current_user_can('edit_post', $post_id)) {
            return;
        }
        
        // Save device settings
        $device_fields = ['mqtt_client_id', 'mqtt_username', 'mqtt_password', 'ip_address', 'last_mqtt_command', 'last_state_update'];
        foreach ($device_fields as $field) {
            if (isset($_POST[$field])) {
                update_post_meta($post_id, $field, sanitize_text_field($_POST[$field]));
            }
        }
        
        // Save allowed users (from textarea)
        if (isset($_POST['allowed_users_textarea'])) {
            $users_text = sanitize_textarea_field($_POST['allowed_users_textarea']);
            if (!empty($users_text)) {
                $users_array = array_filter(array_map('trim', explode("\n", $users_text)));
                update_post_meta($post_id, 'allowed_users', $users_array);
            } else {
                delete_post_meta($post_id, 'allowed_users');
            }
        }
    }
});

// Emergency fallback: Add basic admin columns
add_action('admin_init', function() {
    if (post_type_exists('wled_device')) {
        add_filter('manage_wled_device_posts_columns', function($columns) {
            $columns['ip_address'] = 'IP Address';
            $columns['allowed_users'] = 'Allowed Users';
            return $columns;
        });
        
        add_action('manage_wled_device_posts_custom_column', function($column, $post_id) {
            if ($column === 'ip_address') {
                $ip = get_post_meta($post_id, 'ip_address', true);
                echo esc_html($ip ?: 'Not set');
            } elseif ($column === 'allowed_users') {
                $allowed = get_post_meta($post_id, 'allowed_users', true);
                if (is_array($allowed)) {
                    echo implode(', ', $allowed);
                } else if (is_string($allowed) && !empty($allowed)) {
                    $users = array_map('trim', explode(',', $allowed));
                    echo implode(', ', $users);
                } else {
                    echo '<span style="color: #999;">No users</span>';
                }
            }
        }, 10, 2);
    }
    
    if (post_type_exists('wled_preset')) {
        add_filter('manage_wled_preset_posts_columns', function($columns) {
            unset($columns['date']);
            $new_columns = array();
            $new_columns['cb'] = $columns['cb'];
            $new_columns['title'] = $columns['title'];
            $new_columns['icon_name'] = 'Icon';
            $new_columns['categories'] = 'Categories';
            $new_columns['fx'] = 'Effect ID';
            $new_columns['colors'] = 'Colors';
            $new_columns['author'] = 'Author';
            $new_columns['date'] = 'Date';
            return $new_columns;
        });
        
        add_action('manage_wled_preset_posts_custom_column', function($column, $post_id) {
            switch ($column) {
                case 'icon_name':
                    $icon = get_post_meta($post_id, 'icon_name', true);
                    $emojis = [
                        'color_lens' => '🎨', 'pattern' => '🔷', 'directions_run' => '🏃',
                        'waves' => '🌊', 'lightbulb' => '💡', 'power_off' => '⏻',
                        'local_drink' => '🥤', 'local_florist' => '🌸', 'local_fire_department' => '🔥',
                        'directions_car' => '🚗', 'cake' => '🎂', 'attractions' => '🎡',
                        'nights_stay' => '🌙', 'directions' => '🧭',
                    ];
                    $emoji = isset($emojis[$icon]) ? $emojis[$icon] : '💡';
                    echo '<span style="font-size: 24px;">' . $emoji . '</span>';
                    break;
                    
                case 'categories':
                    $categories = get_post_meta($post_id, 'categories', true);
                    if (is_array($categories) && !empty($categories)) {
                        echo implode(', ', $categories);
                    } else {
                        echo '<span style="color: #999;">No categories</span>';
                    }
                    break;
                    
                case 'fx':
                    $fx = get_post_meta($post_id, 'fx', true);
                    echo '<strong>' . esc_html($fx ? $fx : '0') . '</strong>';
                    break;
                    
                case 'colors':
                    $colors = get_post_meta($post_id, 'colors', true);
                    if (is_array($colors) && !empty($colors)) {
                        // Remove duplicates and empty values
                        $colors = array_unique(array_filter($colors));
                        foreach (array_slice($colors, 0, 3) as $color) {
                            $hex_color = '#' . ltrim($color, '#');
                            echo '<span style="display: inline-block; width: 20px; height: 20px; background-color: ' . esc_attr($hex_color) . '; border: 1px solid #ddd; border-radius: 3px; margin-right: 3px;"></span>';
                        }
                        if (count($colors) > 3) {
                            echo '<span style="color: #666; font-size: 11px;">+' . (count($colors) - 3) . ' more</span>';
                        }
                    } else {
                        echo '<span style="color: #999;">No colors</span>';
                    }
                    break;
            }
        }, 10, 2);
    }
});

// Admin notices removed - plugin runs silently
