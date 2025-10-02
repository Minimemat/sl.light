<?php
/**
 * Data Recovery Script for Stay Lit WLED Plugin
 * 
 * This script will attempt to recover and fix any WLED posts that might be hidden
 */

// Only run if we're in admin and user is admin
if (is_admin() && current_user_can('manage_options')) {
    
    // Add admin page for data recovery
    add_action('admin_menu', function() {
        add_management_page(
            'WLED Data Recovery',
            'WLED Data Recovery',
            'manage_options',
            'wled-data-recovery',
            'wled_data_recovery_page'
        );
    });
    
    function wled_data_recovery_page() {
        global $wpdb;
        
        if (isset($_POST['recover_data'])) {
            echo '<div class="notice notice-success"><p>Recovery process started...</p></div>';
            
            // Find any posts that might be WLED posts but have wrong post_type
            $potential_wled_posts = $wpdb->get_results("
                SELECT ID, post_title, post_type, post_status 
                FROM {$wpdb->posts} 
                WHERE (post_title LIKE '%wled%' OR post_content LIKE '%wled%' OR post_excerpt LIKE '%wled%')
                AND post_type NOT IN ('wled_device', 'wled_preset', 'revision', 'nav_menu_item')
                AND post_status IN ('publish', 'private', 'draft')
            ");
            
            $recovered = 0;
            foreach ($potential_wled_posts as $post) {
                // Check if it has WLED-specific meta
                $mqtt_id = get_post_meta($post->ID, 'mqtt_client_id', true);
                $fx = get_post_meta($post->ID, 'fx', true);
                
                if ($mqtt_id) {
                    // This looks like a WLED device
                    $wpdb->update(
                        $wpdb->posts,
                        ['post_type' => 'wled_device'],
                        ['ID' => $post->ID]
                    );
                    $recovered++;
                    echo '<p>✅ Recovered device: ' . esc_html($post->post_title) . '</p>';
                } elseif ($fx !== '') {
                    // This looks like a WLED preset
                    $wpdb->update(
                        $wpdb->posts,
                        ['post_type' => 'wled_preset'],
                        ['ID' => $post->ID]
                    );
                    $recovered++;
                    echo '<p>✅ Recovered preset: ' . esc_html($post->post_title) . '</p>';
                }
            }
            
            if ($recovered > 0) {
                echo '<div class="notice notice-success"><p><strong>Recovered ' . $recovered . ' posts!</strong></p></div>';
                echo '<p><a href="' . admin_url('edit.php?post_type=wled_device') . '" class="button">View WLED Devices</a> ';
                echo '<a href="' . admin_url('edit.php?post_type=wled_preset') . '" class="button">View WLED Presets</a></p>';
            } else {
                echo '<div class="notice notice-warning"><p>No recoverable posts found.</p></div>';
            }
        }
        
        if (isset($_POST['fix_post_status'])) {
            // Fix any posts that might be in wrong status
            $wpdb->query("
                UPDATE {$wpdb->posts} 
                SET post_status = 'publish' 
                WHERE post_type IN ('wled_device', 'wled_preset') 
                AND post_status = 'trash'
            ");
            
            $fixed = $wpdb->rows_affected;
            echo '<div class="notice notice-success"><p><strong>Fixed ' . $fixed . ' posts status!</strong></p></div>';
        }
        
        // Show current status
        $device_count = $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = 'wled_device'");
        $preset_count = $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->posts} WHERE post_type = 'wled_preset'");
        
        ?>
        <div class="wrap">
            <h1>WLED Data Recovery</h1>
            
            <div class="card">
                <h2>Current Status</h2>
                <p><strong>WLED Devices:</strong> <?php echo $device_count; ?></p>
                <p><strong>WLED Presets:</strong> <?php echo $preset_count; ?></p>
            </div>
            
            <div class="card">
                <h2>Recovery Actions</h2>
                
                <form method="post" style="margin-bottom: 20px;">
                    <p>This will search for any posts that might be WLED devices or presets but have the wrong post type.</p>
                    <input type="submit" name="recover_data" class="button button-primary" value="Recover Lost WLED Posts" onclick="return confirm('This will modify your database. Are you sure?')">
                </form>
                
                <form method="post">
                    <p>This will restore any WLED posts that might be in trash status.</p>
                    <input type="submit" name="fix_post_status" class="button" value="Fix Post Status" onclick="return confirm('This will modify your database. Are you sure?')">
                </form>
            </div>
            
            <div class="card">
                <h2>Manual Database Check</h2>
                <p>You can also check your database directly:</p>
                <ul>
                    <li><strong>WLED Devices:</strong> <code>SELECT * FROM wp_posts WHERE post_type = 'wled_device'</code></li>
                    <li><strong>WLED Presets:</strong> <code>SELECT * FROM wp_posts WHERE post_type = 'wled_preset'</code></li>
                    <li><strong>All WLED-related:</strong> <code>SELECT * FROM wp_posts WHERE post_title LIKE '%wled%' OR post_content LIKE '%wled%'</code></li>
                </ul>
            </div>
        </div>
        <?php
    }
}
