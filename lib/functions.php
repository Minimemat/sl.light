<?php
// WLED Device Custom Post Type
function register_wled_device_post_type() {
    register_post_type('wled_device', [
        'labels' => [
            'name' => 'WLED Devices',
            'singular_name' => 'WLED Device',
        ],
        'public' => true,
        'show_in_rest' => true,
        'show_ui' => true,
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

// WLED Preset Custom Post Type
function register_wled_preset_post_type() {
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
        ],
        'public' => true,
        'show_in_rest' => true,
        'show_ui' => true,
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

add_action('init', 'register_wled_device_post_type');
add_action('init', 'register_wled_preset_post_type');

// Grant WLED capabilities to authenticated users
add_action('init', 'grant_wled_capabilities_to_users');
function grant_wled_capabilities_to_users() {
    // Grant capabilities to all user roles (including subscribers)
    $roles = ['subscriber', 'contributor', 'author', 'editor', 'administrator'];
    
    foreach ($roles as $role_name) {
        $role = get_role($role_name);
        if ($role) {
            // WLED Device capabilities
            $role->add_cap('create_wled_devices');
            $role->add_cap('edit_wled_devices');
            $role->add_cap('edit_published_wled_devices');
            $role->add_cap('edit_private_wled_devices');
            $role->add_cap('publish_wled_devices');
            $role->add_cap('read_private_wled_devices');
            $role->add_cap('delete_wled_devices');
            $role->add_cap('delete_private_wled_devices');
            $role->add_cap('delete_published_wled_devices');
            
            // Additional capabilities for administrators
            if ($role_name === 'administrator') {
                $role->add_cap('edit_others_wled_devices');
                $role->add_cap('delete_others_wled_devices');
            }
            
            // WLED Preset capabilities
            $role->add_cap('create_wled_presets');
            $role->add_cap('edit_wled_presets');
            $role->add_cap('edit_published_wled_presets');
            $role->add_cap('edit_private_wled_presets');
            $role->add_cap('publish_wled_presets');
            $role->add_cap('read_private_wled_presets');
            $role->add_cap('delete_wled_presets');
            $role->add_cap('delete_private_wled_presets');
            $role->add_cap('delete_published_wled_presets');
            
            // Additional capabilities for administrators
            if ($role_name === 'administrator') {
                $role->add_cap('edit_others_wled_presets');
                $role->add_cap('delete_others_wled_presets');
            }
        }
    }
}

// Debug: Log when WLED devices are saved
add_action('save_post_wled_device', function($post_id, $post, $update) {
    if (defined('WP_DEBUG') && WP_DEBUG) {
        $allowed_users = get_post_meta($post_id, 'allowed_users', true);
        $ip_address = get_post_meta($post_id, 'ip_address', true);
        error_log("WLED Device Saved - ID: $post_id, Allowed Users: " . print_r($allowed_users, true) . ", IP: $ip_address");
    }
}, 10, 3);

// Assign posts to the authenticated user
add_action('wp_insert_post', function ($post_id, $post, $update) {
    if ($post->post_type === 'wled_device' && !$update) {
        $user = wp_get_current_user();
        if ($user->ID) {
            wp_update_post([
                'ID' => $post_id,
                'post_author' => $user->ID,
            ]);
        }
    }
}, 10, 3);

// Ensure meta fields are writable via REST API and add user email to allowed_users
add_filter('rest_pre_insert_wled_device', function ($prepared_post, $request) {
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
}, 10, 2);

// Prevent duplicate wled_device posts by mqtt_client_id for new posts only
add_filter('rest_pre_insert_wled_device', function ($prepared_post, $request) {
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
}, 9, 2);

// Allow post author to retrieve their own private wled_device posts
add_filter('rest_wled_device_query', function ($args, $request) {
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
}, 10, 2);

// WLED Preset REST API - Handle privacy and user access
add_filter('rest_wled_preset_query', function ($args, $request) {
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
}, 10, 2);

// Auto-assign presets to authenticated user and set default to private
add_action('wp_insert_post', function ($post_id, $post, $update) {
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
}, 10, 3);

add_filter('rest_prepare_wled_device', function ($response, $post, $request) {
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
}, 10, 3);

// Admin columns for WLED Devices
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
        
        // Debug: Show raw data
        if (defined('WP_DEBUG') && WP_DEBUG) {
            echo '<div style="font-size: 10px; color: #999;">Debug: ' . print_r($allowed, true) . '</div>';
        }
        
        if (is_array($allowed)) {
            echo implode(', ', $allowed);
        } else if (is_string($allowed) && !empty($allowed)) {
            // Handle case where it might be stored as comma-separated string
            $users = array_map('trim', explode(',', $allowed));
            echo implode(', ', $users);
        } else {
            echo '<span style="color: #999;">No users (raw: ' . var_export($allowed, true) . ')</span>';
        }
    }
}, 10, 2);

// Enhanced Admin columns for WLED Presets
add_filter('manage_wled_preset_posts_columns', function($columns) {
    // Remove default columns we don't need
    unset($columns['date']);
    
    // Add our custom columns in specific order
    $new_columns = array();
    $new_columns['cb'] = $columns['cb'];
    $new_columns['title'] = $columns['title'];
    $new_columns['icon_name'] = 'Icon';
    $new_columns['categories'] = 'Categories';
    $new_columns['fx'] = 'Effect ID';
    $new_columns['palette_id'] = 'Palette';
    $new_columns['sx_ix'] = 'Speed/Intensity';
    $new_columns['c1_c2_c3'] = 'Custom Params';
    $new_columns['o1_o2_o3'] = 'Options';
    $new_columns['colors'] = 'Colors';
    $new_columns['visibility'] = 'Visibility';
    $new_columns['author'] = 'Author';
    $new_columns['date'] = 'Date';
    
    return $new_columns;
});

add_action('manage_wled_preset_posts_custom_column', function($column, $post_id) {
    switch ($column) {
        case 'icon_name':
            $icon = get_post_meta($post_id, 'icon_name', true);
            if ($icon) {
                $icon_emoji = _get_icon_emoji($icon);
                echo '<span style="font-size: 24px;">' . $icon_emoji . '</span> <small style="color: #666; display: block; text-align: center;">' . esc_html($icon) . '</small>';
            } else {
                echo '<span style="color: #999; font-size: 24px;">💡</span><small style="color: #999; display: block; text-align: center;">lightbulb</small>';
            }
            break;

        case 'categories':
            $categories = get_post_meta($post_id, 'categories', true);
            
            // Debug: Show raw category data
            if (defined('WP_DEBUG') && WP_DEBUG) {
                echo '<div style="font-size: 10px; color: #999;">Debug: ' . print_r($categories, true) . '</div>';
            }
            
            if (is_array($categories) && !empty($categories)) {
                $category_tags = array_map(function($cat) {
                    $color = _get_category_color($cat);
                    return '<span style="background: ' . $color . '; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px; margin-right: 3px;">' . esc_html($cat) . '</span>';
                }, $categories);
                echo implode(' ', $category_tags);
            } else {
                echo '<span style="color: #999;">No categories (raw: ' . var_export($categories, true) . ')</span>';
            }
            break;
            
        case 'fx':
            $fx = get_post_meta($post_id, 'fx', true);
            echo '<strong style="color: #2271b1;">' . esc_html($fx ? $fx : '0') . '</strong>';
            break;
            
        case 'palette_id':
            $palette_id = get_post_meta($post_id, 'palette_id', true);
            echo '<strong style="color: #666;">' . esc_html($palette_id ? $palette_id : '0') . '</strong>';
            break;
            
        case 'sx_ix':
            $sx = get_post_meta($post_id, 'sx', true);
            $ix = get_post_meta($post_id, 'ix', true);
            echo '<small style="color: #666;">S:' . esc_html($sx ? $sx : '128') . ' I:' . esc_html($ix ? $ix : '128') . '</small>';
            break;
            
        case 'c1_c2_c3':
            $c1 = get_post_meta($post_id, 'c1', true);
            $c2 = get_post_meta($post_id, 'c2', true);
            $c3 = get_post_meta($post_id, 'c3', true);
            echo '<small style="color: #666;">C1:' . esc_html($c1 ? $c1 : '128') . ' C2:' . esc_html($c2 ? $c2 : '128') . ' C3:' . esc_html($c3 ? $c3 : '16') . '</small>';
            break;
            
        case 'o1_o2_o3':
            $o1 = get_post_meta($post_id, 'o1', true);
            $o2 = get_post_meta($post_id, 'o2', true);
            $o3 = get_post_meta($post_id, 'o3', true);
            $options = [];
            if ($o1) $options[] = 'O1';
            if ($o2) $options[] = 'O2';
            if ($o3) $options[] = 'O3';
            if (empty($options)) {
                echo '<small style="color: #999;">None</small>';
            } else {
                echo '<small style="color: #00a32a;">' . esc_html(implode(', ', $options)) . '</small>';
            }
            break;
            
        case 'colors':
            $colors = get_post_meta($post_id, 'colors', true);
            if (is_array($colors) && !empty($colors)) {
                $color_swatches = array_slice($colors, 0, 3); // Show max 3 colors
                foreach ($color_swatches as $color) {
                    $hex_color = '#' . ltrim($color, '#');
                    echo '<span style="display: inline-block; width: 20px; height: 20px; background-color: ' . esc_attr($hex_color) . '; border: 1px solid #ddd; border-radius: 3px; margin-right: 3px; vertical-align: middle;"></span>';
                }
                if (count($colors) > 3) {
                    echo '<span style="color: #666; font-size: 11px;">+' . (count($colors) - 3) . ' more</span>';
                }
            } else {
                $palette_id = get_post_meta($post_id, 'palette_id', true);
                if ($palette_id) {
                    echo '<span style="color: #666;">Palette #' . esc_html($palette_id) . '</span>';
                } else {
                    echo '<span style="color: #999;">No colors</span>';
                }
            }
            break;
            
        case 'visibility':
            $post_status = get_post_status($post_id);
            if ($post_status === 'publish') {
                echo '<span style="color: #00a32a; font-weight: bold;">🌐 Public</span>';
            } else if ($post_status === 'private') {
                echo '<span style="color: #d63638; font-weight: bold;">🔒 Private</span>';
            } else {
                echo '<span style="color: #999;">📝 ' . ucfirst($post_status) . '</span>';
            }
            break;
    }
}, 10, 2);

// Helper function to get category colors
function _get_category_color($category) {
    $colors = [
        'Christmas' => '#c41e3a',
        'Halloween' => '#ff6600',
        'Events' => '#2271b1',
        'Other' => '#666666',
        'Architectural' => '#8b4513',
        'Canada' => '#ff0000',
        'Easter' => '#ffb6c1',
        'Winter' => '#87ceeb',
        'Spring' => '#90ee90',
        'Summer' => '#ffd700',
        'Fall' => '#ff8c00',
        'Sports' => '#32cd32',
        'Diwali' => '#ffa500',
        'Valentines' => '#ff69b4',
        'St. Patrick\'s Day' => '#00ff00',
        'Ramadan' => '#228b22',
    ];
    return isset($colors[$category]) ? $colors[$category] : '#666666';
}

// Helper function to get icon emojis
function _get_icon_emoji($icon_name) {
    $emojis = [
        'color_lens' => '🎨',
        'pattern' => '🔷',
        'directions_run' => '🏃',
        'waves' => '🌊',
        'lightbulb' => '💡',
        'power_off' => '⏻',
        'local_drink' => '🥤',
        'local_florist' => '🌸',
        'local_fire_department' => '🔥',
        'directions_car' => '🚗',
        'cake' => '🎂',
        'attractions' => '🎡',
        'nights_stay' => '🌙',
        'directions' => '🧭',
    ];
    return isset($emojis[$icon_name]) ? $emojis[$icon_name] : '💡';
}

// Add meta boxes for better editing experience
add_action('add_meta_boxes', function() {
    // WLED Device meta boxes
    add_meta_box(
        'wled_device_settings',
        'WLED Device Settings',
        '_wled_device_meta_box_callback',
        'wled_device',
        'normal',
        'high'
    );
    
    add_meta_box(
        'wled_device_users',
        'Device Access & Users',
        '_wled_device_users_meta_box_callback',
        'wled_device',
        'side',
        'default'
    );
    
    // WLED Preset meta boxes
    add_meta_box(
        'wled_preset_settings',
        'WLED Preset Settings',
        '_wled_preset_meta_box_callback',
        'wled_preset',
        'normal',
        'high'
    );
    
    add_meta_box(
        'wled_preset_advanced',
        'Advanced WLED Settings',
        '_wled_preset_advanced_meta_box_callback',
        'wled_preset',
        'normal',
        'default'
    );
});

// WLED Device settings meta box
function _wled_device_meta_box_callback($post) {
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

// WLED Device users meta box
function _wled_device_users_meta_box_callback($post) {
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

// Main preset settings meta box
function _wled_preset_meta_box_callback($post) {
    wp_nonce_field('wled_preset_meta_box', 'wled_preset_meta_box_nonce');
    
    // Get current values
    $fx = get_post_meta($post->ID, 'fx', true) ?: 0;
    $categories = get_post_meta($post->ID, 'categories', true) ?: ['Other'];
    $colors = get_post_meta($post->ID, 'colors', true) ?: [];
    $palette_id = get_post_meta($post->ID, 'palette_id', true) ?: 0;
    $sx = get_post_meta($post->ID, 'sx', true) ?: 128;
    $ix = get_post_meta($post->ID, 'ix', true) ?: 128;
    $icon_name = get_post_meta($post->ID, 'icon_name', true) ?: 'lightbulb';
    
    ?>
    <table class="form-table">
        <tr>
            <th scope="row"><label for="icon_name">Icon</label></th>
            <td>
                <select id="icon_name" name="icon_name">
                    <?php
                    $icons = [
                        'lightbulb' => '💡 Lightbulb',
                        'color_lens' => '🎨 Color Lens',
                        'pattern' => '🔷 Pattern',
                        'directions_run' => '🏃 Running',
                        'waves' => '🌊 Waves',
                        'power_off' => '⏻ Power Off',
                        'local_drink' => '🥤 Drink',
                        'local_florist' => '🌸 Flower',
                        'local_fire_department' => '🔥 Fire',
                        'directions_car' => '🚗 Car',
                        'cake' => '🎂 Cake',
                        'attractions' => '🎡 Attractions',
                        'nights_stay' => '🌙 Night',
                        'directions' => '🧭 Compass',
                    ];
                    foreach ($icons as $value => $label) {
                        $selected = ($icon_name === $value) ? 'selected' : '';
                        echo '<option value="' . esc_attr($value) . '" ' . $selected . '>' . esc_html($label) . '</option>';
                    }
                    ?>
                </select>
                <span style="margin-left: 10px; font-size: 24px;"><?php echo _get_icon_emoji($icon_name); ?></span>
                <p class="description">Icon to display in the app</p>
            </td>
        </tr>

        <tr>
            <th scope="row"><label for="categories">Categories</label></th>
            <td>
                <?php
                $available_categories = ['Christmas', 'Halloween', 'Events', 'Other', 'Architectural', 'Canada', 'Easter', 'Winter', 'Spring', 'Summer', 'Fall', 'Sports', 'Diwali', 'Valentines', 'St. Patrick\'s Day', 'Ramadan'];
                if (!is_array($categories)) $categories = [$categories];
                foreach ($available_categories as $cat) {
                    $checked = in_array($cat, $categories) ? 'checked' : '';
                    $color = _get_category_color($cat);
                    echo '<label style="margin-right: 15px;"><input type="checkbox" name="categories[]" value="' . esc_attr($cat) . '" ' . $checked . '> ';
                    echo '<span style="background-color: ' . $color . '; color: white; padding: 2px 6px; border-radius: 3px; font-size: 11px;">' . esc_html($cat) . '</span></label>';
                }
                ?>
                <p class="description">Select preset categories</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="fx">Effect ID</label></th>
            <td>
                <input type="number" id="fx" name="fx" value="<?php echo esc_attr($fx); ?>" min="0" max="200" />
                <p class="description">WLED effect ID (0-200)</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="colors">Colors</label></th>
            <td>
                <input type="text" id="colors" name="colors" value="<?php echo esc_attr(implode(',', $colors)); ?>" class="large-text" />
                <?php if (!empty($colors)): ?>
                    <div style="margin-top: 8px;">
                        <?php foreach ($colors as $color): ?>
                            <span style="display: inline-block; width: 20px; height: 20px; background-color: #<?php echo esc_attr($color); ?>; border: 1px solid #ccc; margin-right: 5px; border-radius: 3px;"></span>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>
                <p class="description">Comma-separated hex colors (without #): FF0000,00FF00,0000FF</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row"><label for="palette_id">Palette ID</label></th>
            <td>
                <input type="number" id="palette_id" name="palette_id" value="<?php echo esc_attr($palette_id); ?>" min="0" max="70" />
                <p class="description">WLED palette ID (0-70, 0 for custom colors)</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row">Speed & Intensity</th>
            <td>
                <label>Speed: <input type="number" name="sx" value="<?php echo esc_attr($sx); ?>" min="0" max="255" style="width: 80px;" /></label>
                <label style="margin-left: 20px;">Intensity: <input type="number" name="ix" value="<?php echo esc_attr($ix); ?>" min="0" max="255" style="width: 80px;" /></label>
                <p class="description">Speed and intensity values (0-255)</p>
            </td>
        </tr>
    </table>
    <?php
}

// Advanced settings meta box
function _wled_preset_advanced_meta_box_callback($post) {
    // Get advanced values
    $c1 = get_post_meta($post->ID, 'c1', true) ?: 128;
    $c2 = get_post_meta($post->ID, 'c2', true) ?: 128;
    $c3 = get_post_meta($post->ID, 'c3', true) ?: 16;
    $o1 = get_post_meta($post->ID, 'o1', true);
    $o2 = get_post_meta($post->ID, 'o2', true);
    $o3 = get_post_meta($post->ID, 'o3', true);
    
    ?>
    <table class="form-table">
        <tr>
            <th scope="row">Custom Parameters</th>
            <td>
                <label>C1: <input type="number" name="c1" value="<?php echo esc_attr($c1); ?>" min="0" max="255" style="width: 80px;" /></label>
                <label style="margin-left: 15px;">C2: <input type="number" name="c2" value="<?php echo esc_attr($c2); ?>" min="0" max="255" style="width: 80px;" /></label>
                <label style="margin-left: 15px;">C3: <input type="number" name="c3" value="<?php echo esc_attr($c3); ?>" min="0" max="255" style="width: 80px;" /></label>
                <p class="description">Custom effect parameters (0-255)</p>
            </td>
        </tr>
        
        <tr>
            <th scope="row">Options</th>
            <td>
                <label><input type="checkbox" name="o1" value="1" <?php checked($o1, 1); ?> /> Option 1</label>
                <label style="margin-left: 20px;"><input type="checkbox" name="o2" value="1" <?php checked($o2, 1); ?> /> Option 2</label>
                <label style="margin-left: 20px;"><input type="checkbox" name="o3" value="1" <?php checked($o3, 1); ?> /> Option 3</label>
                <p class="description">Effect-specific boolean options</p>
            </td>
        </tr>
    </table>
    <?php
}

// Save WLED Device meta box data
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
        
        return; // Exit early for device posts
    }
    
    // Handle WLED Preset meta box
    if (!isset($_POST['wled_preset_meta_box_nonce']) || !wp_verify_nonce($_POST['wled_preset_meta_box_nonce'], 'wled_preset_meta_box')) {
        return;
    }
    
    if (defined('DOING_AUTOSAVE') && DOING_AUTOSAVE) {
        return;
    }
    
    if (!current_user_can('edit_post', $post_id)) {
        return;
    }
    
    // Save basic settings
    $fields = ['fx', 'palette_id', 'sx', 'ix', 'icon_name', 'c1', 'c2', 'c3'];
    foreach ($fields as $field) {
        if (isset($_POST[$field])) {
            $value = sanitize_text_field($_POST[$field]);
            // Convert to integer for numeric fields
            if (in_array($field, ['fx', 'palette_id', 'sx', 'ix', 'c1', 'c2', 'c3'])) {
                $value = intval($value);
            }
            update_post_meta($post_id, $field, $value);
        }
    }
    
    // Save categories (array)
    if (isset($_POST['categories'])) {
        update_post_meta($post_id, 'categories', array_map('sanitize_text_field', $_POST['categories']));
    } else {
        update_post_meta($post_id, 'categories', ['Other']);
    }
    
    // Save colors (array)
    if (isset($_POST['colors']) && !empty($_POST['colors'])) {
        $colors = array_map('trim', explode(',', $_POST['colors']));
        $colors = array_filter($colors); // Remove empty values
        update_post_meta($post_id, 'colors', $colors);
    } else {
        delete_post_meta($post_id, 'colors');
    }
    
    // Save boolean fields - ensure they are properly saved as integers
    $bool_fields = ['o1', 'o2', 'o3'];
    foreach ($bool_fields as $field) {
        $value = isset($_POST[$field]) ? 1 : 0;
        update_post_meta($post_id, $field, $value);
    }
    
    // Debug logging
    if (defined('WP_DEBUG') && WP_DEBUG) {
        error_log("WLED Preset Saved - ID: $post_id");
        error_log("FX: " . get_post_meta($post_id, 'fx', true));
        error_log("Palette ID: " . get_post_meta($post_id, 'palette_id', true));
        error_log("SX: " . get_post_meta($post_id, 'sx', true));
        error_log("IX: " . get_post_meta($post_id, 'ix', true));
        error_log("C1: " . get_post_meta($post_id, 'c1', true));
        error_log("C2: " . get_post_meta($post_id, 'c2', true));
        error_log("C3: " . get_post_meta($post_id, 'c3', true));
        error_log("O1: " . get_post_meta($post_id, 'o1', true));
        error_log("O2: " . get_post_meta($post_id, 'o2', true));
        error_log("O3: " . get_post_meta($post_id, 'o3', true));
    }
});

add_action('rest_api_init', 'register_wled_device_state_routes');

function register_wled_device_state_routes() {
    register_rest_route('wled/v1', '/devices/(?P<id>\d+)/state', [
        'methods' => 'POST',
        'callback' => 'update_wled_device_state',
        'permission_callback' => 'wled_device_permission_check',
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

function wled_device_permission_check($request) {
    $post_id = $request['id'];
    $user = wp_get_current_user();
    if (!$user->ID) return false;
    $allowed_users = get_post_meta($post_id, 'allowed_users', true);
    if (is_array($allowed_users) && in_array($user->user_email, $allowed_users)) {
        return true;
    }
    return false;
}

function update_wled_device_state($request) {
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

/**
 * Salient functions and definitions.
 *
 * @package Salient
 * @since 1.0
 */


 /**
  * Define Constants.
  */
define( 'NECTAR_THEME_DIRECTORY', get_template_directory() );
define( 'NECTAR_FRAMEWORK_DIRECTORY', get_template_directory_uri() . '/nectar/' );
define( 'NECTAR_THEME_NAME', 'salient' );


if ( ! function_exists( 'get_nectar_theme_version' ) ) {
	function nectar_get_theme_version() {
		return '17.1.0';
	}
}


/**
 * Load text domain.
 */
add_action( 'after_setup_theme', 'nectar_lang_setup' );

if ( ! function_exists( 'nectar_lang_setup' ) ) {
	function nectar_lang_setup() {
		load_theme_textdomain( 'salient', get_template_directory() . '/lang' );
	}
}


/**
 * General WordPress.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/wp-general.php';


/**
 * Get Salient theme options.
 */
function get_nectar_theme_options() {

	$legacy_options  = get_option( 'salient' );
	$current_options = get_option( 'salient_redux' );
	
	if ( ! empty( $current_options ) && is_array($current_options) ) {
		return $current_options;
	} elseif ( ! empty( $legacy_options ) && is_array($legacy_options) ) {
		return $legacy_options;
	} else {
		return array();
	}
}

$nectar_options                    = get_nectar_theme_options();
$nectar_get_template_directory_uri = get_template_directory_uri();


require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-theme-manager.php';


/**
 * Register/Enqueue theme assets.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/icon-collections.php';
require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-element-assets.php';
require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-element-styles.php';
require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-lazy.php';
require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-delay-js.php';
require_once NECTAR_THEME_DIRECTORY . '/includes/class-nectar-login.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/enqueue-scripts.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/enqueue-styles.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/dynamic-styles.php';


/**
 * Salient Plugin notices.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/plugin-notices/salient-plugin-notices.php';


/**
 * Salient welcome page.
 */
 require_once NECTAR_THEME_DIRECTORY . '/nectar/welcome/welcome-page.php';


/**
 * Theme hooks & actions.
 */
function nectar_hooks_init() {

	require_once NECTAR_THEME_DIRECTORY . '/nectar/hooks/hooks.php';
	require_once NECTAR_THEME_DIRECTORY . '/nectar/hooks/actions.php';

}

add_action( 'after_setup_theme', 'nectar_hooks_init', 10 );


/**
 * Post category meta.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/meta/category-meta.php';


/**
 * Media and theme image sizes.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/media.php';


/**
 * Navigation menus
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/assets/functions/wp-menu-custom-items/menu-item-custom-fields.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/nav-menus.php';


/**
 * TGM Plugin inclusion.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/tgm-plugin-activation/class-tgm-plugin-activation.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/tgm-plugin-activation/required_plugins.php';


/**
 * WPBakery functionality.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/wpbakery-init.php';


/**
 * Theme skin specific class and assets.
 */
$nectar_theme_skin    = NectarThemeManager::$skin;
$nectar_header_format = ( ! empty( $nectar_options['header_format'] ) ) ? $nectar_options['header_format'] : 'default';

add_filter( 'body_class', 'nectar_theme_skin_class' );

function nectar_theme_skin_class( $classes ) {
	global $nectar_theme_skin;
	$classes[] = $nectar_theme_skin;
	return $classes;
}


function nectar_theme_skin_css() {
	global $nectar_theme_skin;
	wp_enqueue_style( 'skin-' . $nectar_theme_skin );
}

add_action( 'wp_enqueue_scripts', 'nectar_theme_skin_css' );



/**
 * Search related.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/search.php';


/**
 * Register Widget areas.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/widget-related.php';


/**
 * Header navigation helpers.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/header.php';


/**
 * Blog helpers.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/blog.php';


/**
 * Page helpers.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/page.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/footer.php';

/**
 * Theme options panel (Redux).
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/redux-salient.php';


/**
 * WordPress block editor helpers (Gutenberg).
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/gutenberg.php';


/**
 * Admin assets.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/admin-enqueue.php';


/**
 * Pagination Helpers.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/pagination.php';


/**
 * Page header.
 */
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/page-header.php';


/**
 * Third party.
 */
require_once NECTAR_THEME_DIRECTORY . '/includes/third-party-integrations/seo.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/wpml.php';
require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/woocommerce.php';


/**
 * v10.5 update assist.
 */
 require_once NECTAR_THEME_DIRECTORY . '/nectar/helpers/update-assist.php';