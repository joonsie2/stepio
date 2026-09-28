@tool
extends EditorExportPlugin
## Adds the native step reading code to Android and iOS exports.
##
## Android: the Health Connect plugin AAR (built from android/plugin) and its
## Maven dependencies. The AAR's own manifest adds the READ_STEPS permission.
## iOS: HealthKit framework and the Info.plist usage text. The native code is a
## GDExtension (stepio_health.gdextension); the HealthKit entitlement is set in
## the iOS export preset under entitlements/additional.

const HEALTH_SHARE_USAGE := "step.io reads your step count so your steps can power the game."

# Keep in sync with android/plugin/build.gradle.kts.
const ANDROID_DEPENDENCIES := [
	"androidx.health.connect:connect-client:1.1.0-rc01",
	"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0",
]


func _get_name() -> String:
	return "StepioHealth"


func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid or platform is EditorExportPlatformIOS


func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	var variant := "debug" if debug else "release"
	return PackedStringArray(["stepio_health/bin/android/StepioHealth-%s.aar" % variant])


func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray(ANDROID_DEPENDENCIES)


func _export_file(path: String, _type: String, features: PackedStringArray) -> void:
	# The GDExtension only has an iOS library. Leaving it out of other exports
	# avoids a "no library found" error at startup.
	if path.get_extension() == "gdextension" and path.begins_with("res://addons/stepio_health/") and not features.has("ios"):
		skip()


func _export_begin(features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	if not features.has("ios"):
		return
	add_apple_embedded_platform_framework("HealthKit.framework")
	add_apple_embedded_platform_plist_content(
		"<key>NSHealthShareUsageDescription</key>\n<string>%s</string>" % HEALTH_SHARE_USAGE
	)
