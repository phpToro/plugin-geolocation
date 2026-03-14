phpToro.geolocation = {
    getCurrentPosition: function() {
        return phpToro.nativeCall('geolocation', 'getCurrentPosition', {});
    },
    requestPermission: function() {
        return phpToro.nativeCall('geolocation', 'requestPermission', {});
    },
    checkPermission: function() {
        return phpToro.nativeCall('geolocation', 'checkPermission', {});
    }
};
