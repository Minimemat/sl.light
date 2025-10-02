<?php
/**
 * WLED Admin Interface
 * 
 * @package StayLit_WLED
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class StayLit_WLED_Admin {
    
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
        if (is_admin()) {
            add_action('add_meta_boxes', array($this, 'add_meta_boxes'));
            add_action('save_post', array($this, 'save_meta_boxes'));
            add_filter('manage_wled_device_posts_columns', array($this, 'device_admin_columns'));
            add_action('manage_wled_device_posts_custom_column', array($this, 'device_admin_column_content'), 10, 2);
            add_filter('manage_wled_preset_posts_columns', array($this, 'preset_admin_columns'));
            add_action('manage_wled_preset_posts_custom_column', array($this, 'preset_admin_column_content'), 10, 2);
        }
    }
    
    /**
     * Add meta boxes for better editing experience
     */
    public function add_meta_boxes() {
        // WLED Device meta boxes
        add_meta_box(
            'wled_device_settings',
            'WLED Device Settings',
            array($this, 'wled_device_meta_box_callback'),
            'wled_device',
            'normal',
            'high'
        );
        
        add_meta_box(
            'wled_device_users',
            'Device Access & Users',
            array($this, 'wled_device_users_meta_box_callback'),
            'wled_device',
            'side',
            'default'
        );
        
        // WLED Preset meta boxes
        add_meta_box(
            'wled_preset_settings',
            'WLED Preset Settings',
            array($this, 'wled_preset_meta_box_callback'),
            'wled_preset',
            'normal',
            'high'
        );
        
        add_meta_box(
            'wled_preset_advanced',
            'Advanced WLED Settings',
            array($this, 'wled_preset_advanced_meta_box_callback'),
            'wled_preset',
            'normal',
            'default'
        );
    }

    /**
     * WLED Device settings meta box
     */
    public function wled_device_meta_box_callback($post) {
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

    /**
     * WLED Device users meta box
     */
    public function wled_device_users_meta_box_callback($post) {
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

    /**
     * Main preset settings meta box
     */
    public function wled_preset_meta_box_callback($post) {
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
                    <span style="margin-left: 10px; font-size: 24px;"><?php echo $this->get_icon_emoji($icon_name); ?></span>
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
                        $color = $this->get_category_color($cat);
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

    /**
     * Advanced settings meta box
     */
    public function wled_preset_advanced_meta_box_callback($post) {
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

    /**
     * Save meta box data
     */
    public function save_meta_boxes($post_id) {
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
    }

    /**
     * Admin columns for WLED Devices
     */
    public function device_admin_columns($columns) {
        $columns['ip_address'] = 'IP Address';
        $columns['allowed_users'] = 'Allowed Users';
        return $columns;
    }

    public function device_admin_column_content($column, $post_id) {
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
    }

    /**
     * Enhanced Admin columns for WLED Presets
     */
    public function preset_admin_columns($columns) {
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
    }

    public function preset_admin_column_content($column, $post_id) {
        switch ($column) {
            case 'icon_name':
                $icon = get_post_meta($post_id, 'icon_name', true);
                if ($icon) {
                    $icon_emoji = $this->get_icon_emoji($icon);
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
                        $color = $this->get_category_color($cat);
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
    }

    /**
     * Helper function to get category colors
     */
    private function get_category_color($category) {
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

    /**
     * Helper function to get icon emojis
     */
    private function get_icon_emoji($icon_name) {
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
}
