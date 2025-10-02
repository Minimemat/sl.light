<?php
/**
 * WLED User Meta Management
 * 
 * @package StayLit_WLED
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

class StayLit_WLED_User_Meta {
    
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
        add_action('rest_api_init', array($this, 'register_user_meta_for_rest'));
        add_filter('rest_pre_insert_user', array($this, 'handle_user_meta_on_create'), 10, 2);
        add_action('show_user_profile', array($this, 'show_warranty_user_fields'));
        add_action('edit_user_profile', array($this, 'show_warranty_user_fields'));
        add_action('personal_options_update', array($this, 'save_warranty_user_fields'));
        add_action('edit_user_profile_update', array($this, 'save_warranty_user_fields'));
    }
    
    /**
     * Register user billing meta for REST + allow meta on user create/update
     */
    public function register_user_meta_for_rest() {
        $meta_fields = [
            // Standard WooCommerce billing keys
            'billing_first_name' => 'string',
            'billing_last_name'  => 'string',
            'billing_phone'      => 'string',
            'billing_address_1'  => 'string',
            'billing_address_2'  => 'string',
            'billing_city'       => 'string',
            'billing_state'      => 'string',
            'billing_postcode'   => 'string',
            'billing_country'    => 'string',
            // App-specific
            'installation_date'  => 'string',
            'warranty_registered'=> 'boolean',
        ];

        foreach ($meta_fields as $key => $type) {
            register_meta('user', $key, [
                'type'         => $type,
                'single'       => true,
                'show_in_rest' => true,
                'auth_callback' => function() {
                    // Allow site admins/app password owner to set these over REST
                    return current_user_can('edit_users');
                }
            ]);
        }
    }

    /**
     * Ensure posted `meta` is persisted on create/update via wp/v2/users
     */
    public function handle_user_meta_on_create($prepared, $request) {
        $params = $request->get_params();
        if (!empty($params['meta']) && is_array($params['meta']) && is_object($prepared)) {
            // Let core handle saving via meta_input so registered keys persist
            $prepared->meta_input = $params['meta'];
        }
        return $prepared;
    }

    /**
     * Show Installation Date & Warranty Registered on user profile
     */
    public function show_warranty_user_fields($user) { ?>
        <h2>Stay Lit Warranty</h2>
        <table class="form-table" role="presentation">
            <tr>
                <th><label for="installation_date">Installation Date</label></th>
                <td>
                    <input type="text" name="installation_date" id="installation_date" 
                           value="<?php echo esc_attr(get_user_meta($user->ID, 'installation_date', true)); ?>" 
                           class="regular-text" placeholder="YYYY-MM-DD or ISO8601" />
                    <p class="description">Stored as string (ISO8601 recommended).</p>
                </td>
            </tr>
            <tr>
                <th><label for="warranty_registered">Warranty Registered</label></th>
                <td>
                    <?php $wr = get_user_meta($user->ID, 'warranty_registered', true); ?>
                    <label><input type="checkbox" name="warranty_registered" id="warranty_registered" value="1" <?php checked($wr, '1'); checked($wr, 1); checked($wr, true); ?> /> Yes</label>
                </td>
            </tr>
        </table>
    <?php }

    /**
     * Save warranty user fields
     */
    public function save_warranty_user_fields($user_id) {
        if (!current_user_can('edit_user', $user_id)) return false;
        if (isset($_POST['installation_date'])) {
            update_user_meta($user_id, 'installation_date', sanitize_text_field($_POST['installation_date']));
        }
        // Store as '1' when checked, otherwise delete to keep clean
        if (isset($_POST['warranty_registered'])) {
            update_user_meta($user_id, 'warranty_registered', '1');
        } else {
            delete_user_meta($user_id, 'warranty_registered');
        }
    }
}
