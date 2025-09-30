const String baseUrl = 'https://staylit.lighting';
const String wpApiUrl = '$baseUrl/wp-json';
const String jwtAuthUrl = '$wpApiUrl/jwt-auth/v1/token';
const String wledDevicesUrl = '$wpApiUrl/wp/v2/wled_device';
const String wledPresetsUrl = '$wpApiUrl/wp/v2/wled_preset';
const String forgotPasswordUrl = '$baseUrl/wp-login.php?action=lostpassword';

const String adminUsername = 'Minimemat';
const String applicationPassword = 'CpVp lTEq ghU3 yIAw LpyA MIjD';

const String mqttBroker = 'staylit.lighting';
const int mqttPort = 1883;
const int mqttWebSocketPort = 9001; // Updated: Test showed port 9001 works!
const String mqttBaseTopic = '/wled/';
