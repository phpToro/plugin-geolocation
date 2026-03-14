<?php

namespace PhpToro\Plugins\Geolocation;

class Geolocation
{
    public static function getCurrentPosition(): array
    {
        $json = phptoro_native_call('geolocation', 'getCurrentPosition', '{}');
        return json_decode($json, true) ?? [];
    }

    public static function checkPermission(): string
    {
        $json = phptoro_native_call('geolocation', 'checkPermission', '{}');
        $result = json_decode($json, true) ?? [];
        return $result['status'] ?? 'unknown';
    }

    public static function requestPermission(): array
    {
        $json = phptoro_native_call('geolocation', 'requestPermission', '{}');
        return json_decode($json, true) ?? [];
    }
}
