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

# Health Connect 1.1.0 refuses to build with an older Android Gradle plugin than
# this, and Godot 4.7's Android build template ships 8.6.1.
const MIN_ANDROID_GRADLE_PLUGIN := "8.9.1"
const ANDROID_BUILD_CONFIG := "res://android/build/config.gradle"

# Keep in sync with android/plugin/build.gradle.kts.
const ANDROID_DEPENDENCIES := [
	"androidx.health.connect:connect-client:1.1.0",
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
	if features.has("android"):
		_raise_android_gradle_plugin_version()
	if not features.has("ios"):
		return
	add_apple_embedded_platform_framework("HealthKit.framework")
	add_apple_embedded_platform_plist_content(
		"<key>NSHealthShareUsageDescription</key>\n<string>%s</string>" % HEALTH_SHARE_USAGE
	)


## Raises the Android Gradle plugin version in the installed Android build
## template (android/build, created by Project > Install Android Build Template).
## Runs before Gradle does, so every Android export gets the fix.
func _raise_android_gradle_plugin_version() -> void:
	if not FileAccess.file_exists(ANDROID_BUILD_CONFIG):
		return
	var text := FileAccess.get_file_as_string(ANDROID_BUILD_CONFIG)
	var regex := RegEx.create_from_string("androidGradlePlugin\\s*:\\s*'([0-9.]+)'")
	var found := regex.search(text)
	if found == null:
		push_warning("StepioHealth: could not find the Android Gradle plugin version in %s" % ANDROID_BUILD_CONFIG)
		return
	var current := found.get_string(1)
	if _version_less(current, MIN_ANDROID_GRADLE_PLUGIN):
		text = text.replace(found.get_string(0), "androidGradlePlugin: '%s'" % MIN_ANDROID_GRADLE_PLUGIN)
		var file := FileAccess.open(ANDROID_BUILD_CONFIG, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		print("StepioHealth: raised Android Gradle plugin %s -> %s" % [current, MIN_ANDROID_GRADLE_PLUGIN])


static func _version_less(a: String, b: String) -> bool:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := pa[i].to_int() if i < pa.size() else 0
		var y := pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x < y
	return false
