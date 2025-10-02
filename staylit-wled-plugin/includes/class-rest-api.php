<?php
/**
 * WLED REST API
 * 
 * @package StayLit_WLED
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class StayLit_WLED_REST_API {
    
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
        add_action('rest_api_init', array($this, 'init'));
    }
    
    /**
     * Initialize REST API
     */
    public function init() {
        // Device REST API filters
        add_filter('rest_pre_insert_wled_device', array($this, 'handle_device_meta_fields'), 10, 2);
        add_filter('rest_pre_insert_wled_device', array($this, 'prevent_duplicate_devices'), 9, 2);
        add_filter('rest_wled_device_query', array($this, 'filter_device_queries'), 10, 2);
        add_filter('rest_prepare_wled_device', array($this, 'filter_device_response'), 10, 3);
        
        // Preset REST API filters
        add_filter('rest_wled_preset_query', array($this, 'filter_preset_queries'), 10, 2);
        
        // Auto-assign presets
        add_action('wp_insert_post', array($this, 'auto_assign_presets'), 10, 3);
        
        // Register custom routes
        $this->register_device_state_routes();
    }
    
    /**
     * Ensure meta fields are writable via REST API and add user email to allowed_users
     */
    public function handle_device_meta_fields($prepared_post, $request) {
        if (isset($request['meta'])) {
            $meta = $request['meta'];
            $user = wp_get_current_user();
            
            // Debug logging
            if (defined('WP_DEBUG') && WP_DEBUG) {
                error_log('WLED Device Creation - Meta received: ' . print_r($meta, true));
                error_log('WLED Device Creation - User: ' . ($user->user_email ?? 'no user'));
            }
            
            if ($user->ID && $user->user_email && !isset($request['id'])) {
                $existing_allowed = (array) ($meta['allowed_users'] ?? []);
                $meta['allowed_users'] = array_unique(array_merge($existing_allowed, [$user->user_email]));
                
                // Debug logging
                if (defined('WP_DEBUG') && WP_DEBUG) {
                    error_log('WLED Device Creation - Final allowed_users: ' . print_r($meta['allowed_users'], true));
                }
            }
            $prepared_post->meta = $meta;
        }
        return $prepared_post;
    }

    /**
     * Prevent duplicate wled_device posts by mqtt_client_id for new posts only
     */
    public function prevent_duplicate_devices($prepared_post, $request) {
        if (isset($request['id'])) {
            return $prepared_post; // Skip for updates
        }

        if (!isset($request['meta']['mqtt_client_id'])) {
            return new WP_Error(
                'missing_mqtt_client_id',
                'MQTT Client ID is required',
                ['status' => 400]
            );
        }

        $mqtt_client_id = $request['meta']['mqtt_client_id'];
        $existing_posts = get_posts([
            'post_type' => 'wled_device',
            'post_status' => ['publish', 'private'],
            'meta_query' => [
                [
                    'key' => 'mqtt_client_id',
                    'value' => $mqtt_client_id,
                    'compare' => '=',
                ],
            ],
            'numberposts' => 1,
        ]);

        if (!empty($existing_posts)) {
            return new WP_Error(
                'duplicate_mqtt_client_id',
                'A device with this MQTT Client ID is already registered',
                ['status' => 400]
            );
        }

        return $prepared_post;
    }

    /**
     * Allow post author to retrieve their own private wled_device posts
     */
    public function filter_device_queries($args, $request) {
        $user = wp_get_current_user();
        if ($user->ID) {
            // Authenticated users can see:
            // 1. Their own devices (published or private) 
            // 2. Devices where they are in allowed_users
            $args['post_status'] = ['publish', 'private'];
            
            // Use a custom where clause to filter properly
            add_filter('posts_where', function($where, $wp_query) use ($user) {
                // Only apply this filter to our device queries
                if ($wp_query->get('post_type') === 'wled_device') {
                    global $wpdb;
                    
                    // Query for devices where:
                    // 1. User is the author, OR
                    // 2. User's email is in the allowed_users meta field
                    $where .= " AND (({$wpdb->posts}.post_author = {$user->ID}) OR ";
                    $where .= "EXISTS (SELECT 1 FROM {$wpdb->postmeta} pm WHERE pm.post_id = {$wpdb->posts}.ID ";
                    $where .= "AND pm.meta_key = 'allowed_users' AND pm.meta_value LIKE '%{$user->user_email}%'))";
                    
                    // Remove this filter after use to avoid affecting other queries
                    remove_filter('posts_where', __FUNCTION__, 10);
                }
                return $where;
            }, 10, 2);
        }
        return $args;
    }

    /**
     * WLED Preset REST API - Handle privacy and user access
     */
    public function filter_preset_queries($args, $request) {
        $user = wp_get_current_user();
        
        if ($user->ID) {
            // Authenticated users can see:
            // 1. Their own presets (published or private)
            // 2. Public (published) presets from other users
            $args['post_status'] = ['publish', 'private'];
            
            // Use a custom where clause to filter properly
            add_filter('posts_where', function($where, $wp_query) use ($user) {
                // Only apply this filter to our preset queries
                if ($wp_query->get('post_type') === 'wled_preset') {
                    global $wpdb;
                    $where .= " AND (({$wpdb->posts}.post_status = 'publish') OR ({$wpdb->posts}.post_status = 'private' AND {$wpdb->posts}.post_author = {$user->ID}))";
                    
                    // Remove this filter after use to avoid affecting other queries
                    remove_filter('posts_where', __FUNCTION__, 10);
                }
                return $where;
            }, 10, 2);
            
        } else {
            // Non-authenticated users only see published (public) presets
            $args['post_status'] = 'publish';
        }
        
        return $args;
    }

    /**
     * Auto-assign presets to authenticated user and set default to private
     */
    public function auto_assign_presets($post_id, $post, $update) {
        if ($post->post_type === 'wled_preset' && !$update) {
            $user = wp_get_current_user();
            if ($user->ID) {
                // Set post author and force private status
                wp_update_post([
                    'ID' => $post_id,
                    'post_author' => $user->ID,
                    'post_status' => 'private', // Always start private
                ]);
            }
        }
    }

    /**
     * Filter device response for public access
     */
    public function filter_device_response($response, $post, $request) {
        // Only filter for GET requests (not POST/PUT)
        if ($request->get_method() !== 'GET') {
            return $response;
        }

        // Get current user
        $user = wp_get_current_user();
        $is_authenticated = $user && $user->ID;

        // Only allow public access to mqtt_client_id
        if (!$is_authenticated) {
            $meta = $response->get_data()['meta'];
            $filtered_meta = [
                'mqtt_client_id' => isset($meta['mqtt_client_id']) ? $meta['mqtt_client_id'] : '',
            ];
            $data = $response->get_data();
            $data['meta'] = $filtered_meta;
            $response->set_data($data);
        }

        return $response;
    }

    /**
     * Register device state routes
     */
    private function register_device_state_routes() {
        register_rest_route('wled/v1', '/devices/(?P<id>\d+)/state', [
            'methods' => 'POST',
            'callback' => array($this, 'update_wled_device_state'),
            'permission_callback' => array($this, 'wled_device_permission_check'),
            'args' => [
                'is_connected' => [
                    'type' => 'boolean',
                ],
                'on' => [
                    'type' => 'boolean',
                ],
                'bri' => [
                    'type' => 'integer',
                    'minimum' => 0,
                    'maximum' => 255,
                ],
                'last_mqtt_command' => [
                    'type' => 'string',
                ],
                'last_state_update' => [
                    'type' => 'string',
                ],
            ],
        ]);
    }

    /**
     * Permission check for device state updates
     */
    public function wled_device_permission_check($request) {
        $post_id = $request['id'];
        $user = wp_get_current_user();
        if (!$user->ID) return false;
        $allowed_users = get_post_meta($post_id, 'allowed_users', true);
        if (is_array($allowed_users) && in_array($user->user_email, $allowed_users)) {
            return true;
        }
        return false;
    }

    /**
     * Update device state
     */
    public function update_wled_device_state($request) {
        $post_id = $request['id'];
        $params = $request->get_params();
        $updated = [];
        if (isset($params['is_connected'])) {
            update_post_meta($post_id, 'is_connected', (bool) $params['is_connected']);
            $updated['is_connected'] = (bool) $params['is_connected'];
        }
        if (isset($params['on'])) {
            update_post_meta($post_id, 'on', (bool) $params['on']);
            $updated['on'] = (bool) $params['on'];
        }
        if (isset($params['bri'])) {
            update_post_meta($post_id, 'bri', intval($params['bri']));
            $updated['bri'] = intval($params['bri']);
        }
        if (isset($params['last_mqtt_command'])) {
            update_post_meta($post_id, 'last_mqtt_command', sanitize_text_field($params['last_mqtt_command']));
            $updated['last_mqtt_command'] = sanitize_text_field($params['last_mqtt_command']);
        }
        if (isset($params['last_state_update'])) {
            update_post_meta($post_id, 'last_state_update', sanitize_text_field($params['last_state_update']));
            $updated['last_state_update'] = sanitize_text_field($params['last_state_update']);
        }
        return [
            'success' => true,
            'updated' => $updated,
        ];
    }
}
