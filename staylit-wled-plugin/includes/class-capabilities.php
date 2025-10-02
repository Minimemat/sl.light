<?php
/**
 * WLED Capabilities Management
 * 
 * @package StayLit_WLED
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class StayLit_WLED_Capabilities {
    
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
        add_action('init', array($this, 'grant_capabilities_to_roles'));
    }
    
    /**
     * Grant WLED capabilities to authenticated users
     */
    public function grant_capabilities_to_roles() {
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
}
