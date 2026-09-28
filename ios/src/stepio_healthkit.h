#pragma once

#include <godot_cpp/classes/object.hpp>

namespace godot {

// Reads step counts from Apple HealthKit for the step.io step reading test.
//
// Registered as the engine singleton "StepioHealth", with the same methods and
// signals as the Android Health Connect plugin, so GDScript does not need to
// know which platform it is on.
class StepioHealthKit : public Object {
	GDCLASS(StepioHealthKit, Object);

protected:
	static void _bind_methods();

public:
	String get_status() const;
	void check_permission();
	void request_permission();
	void query_steps(int64_t p_start_unix, int64_t p_end_unix, int p_request_id);
	void open_settings();
};

} // namespace godot
