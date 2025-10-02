<?php
/**
 * Recovery Check Script for Stay Lit WLED Plugin
 * 
 * Add this temporarily to your wp-config.php to check for lost data:
 * require_once ABSPATH . 'wp-content/plugins/staylit-wled-plugin/recovery-check.php';
 */

// Only run if we're in admin and user is admin
if (is_admin() && current_user_can('manage_options')) {
    add_action('admin_notices', function() {
        global $wpdb;
        
        echo '<div class="notice notice-info"><p><strong>Stay Lit WLED Data Recovery Check:</strong></p>';
        
        // Check for WLED devices in database
        $device_posts = $wpdb->get_results("
            SELECT ID, post_title, post_status, post_author, post_date 
            FROM {$wpdb->posts} 
            WHERE post_type = 'wled_device' 
            ORDER BY post_date DESC
        ");
        
        echo '<h4>WLED Devices in Database:</h4>';
        if ($device_posts) {
            echo '<ul>';
            foreach ($device_posts as $post) {
                $ip = get_post_meta($post->ID, 'ip_address', true);
                $mqtt_id = get_post_meta($post->ID, 'mqtt_client_id', true);
                echo '<li><strong>' . esc_html($post->post_title) . '</strong> (ID: ' . $post->ID . ')';
                echo ' - Status: ' . $post->post_status;
                echo ' - IP: ' . ($ip ? esc_html($ip) : 'Not set');
                echo ' - MQTT ID: ' . ($mqtt_id ? esc_html($mqtt_id) : 'Not set');
                echo ' - Date: ' . $post->post_date;
                echo '</li>';
            }
            echo '</ul>';
        } else {
            echo '<p style="color: red;">❌ No WLED devices found in database</p>';
        }
        
        // Check for WLED presets in database
        $preset_posts = $wpdb->get_results("
            SELECT ID, post_title, post_status, post_author, post_date 
            FROM {$wpdb->posts} 
            WHERE post_type = 'wled_preset' 
            ORDER BY post_date DESC
        ");
        
        echo '<h4>WLED Presets in Database:</h4>';
        if ($preset_posts) {
            echo '<ul>';
            foreach ($preset_posts as $post) {
                $fx = get_post_meta($post->ID, 'fx', true);
                $categories = get_post_meta($post->ID, 'categories', true);
                echo '<li><strong>' . esc_html($post->post_title) . '</strong> (ID: ' . $post->ID . ')';
                echo ' - Status: ' . $post->post_status;
                echo ' - FX: ' . ($fx ? esc_html($fx) : 'Not set');
                echo ' - Categories: ' . (is_array($categories) ? implode(', ', $categories) : 'Not set');
                echo ' - Date: ' . $post->post_date;
                echo '</li>';
            }
            echo '</ul>';
        } else {
            echo '<p style="color: red;">❌ No WLED presets found in database</p>';
        }
        
        // Check post type registration
        $registered_types = get_post_types(['public' => true], 'names');
        echo '<h4>Registered Post Types:</h4>';
        echo '<ul>';
        echo '<li>wled_device: ' . (in_array('wled_device', $registered_types) ? '✅ Registered' : '❌ Not registered') . '</li>';
        echo '<li>wled_preset: ' . (in_array('wled_preset', $registered_types) ? '✅ Registered' : '❌ Not registered') . '</li>';
        echo '</ul>';
        
        // Check for any posts with wled in the title or content
        $any_wled_posts = $wpdb->get_results("
            SELECT ID, post_title, post_type, post_status 
            FROM {$wpdb->posts} 
            WHERE (post_title LIKE '%wled%' OR post_content LIKE '%wled%') 
            AND post_type NOT IN ('revision', 'nav_menu_item')
            ORDER BY post_date DESC
            LIMIT 10
        ");
        
        if ($any_wled_posts) {
            echo '<h4>Any Posts with "wled" in title/content:</h4>';
            echo '<ul>';
            foreach ($any_wled_posts as $post) {
                echo '<li><strong>' . esc_html($post->post_title) . '</strong> (Type: ' . $post->post_type . ', Status: ' . $post->post_status . ')</li>';
            }
            echo '</ul>';
        }
        
        echo '</div>';
    });
}
