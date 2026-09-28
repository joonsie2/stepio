#include "stepio_healthkit.h"

#import <HealthKit/HealthKit.h>
#import <UIKit/UIKit.h>

#include <godot_cpp/core/class_db.hpp>

using namespace godot;

static HKHealthStore *health_store() {
	static HKHealthStore *store = [[HKHealthStore alloc] init];
	return store;
}

static NSSet<HKObjectType *> *read_types() {
	return [NSSet setWithObject:[HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount]];
}

static String to_godot(NSString *p_string) {
	return p_string ? String::utf8([p_string UTF8String]) : String();
}

void StepioHealthKit::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_status"), &StepioHealthKit::get_status);
	ClassDB::bind_method(D_METHOD("check_permission"), &StepioHealthKit::check_permission);
	ClassDB::bind_method(D_METHOD("request_permission"), &StepioHealthKit::request_permission);
	ClassDB::bind_method(D_METHOD("query_steps", "start_unix", "end_unix", "request_id"), &StepioHealthKit::query_steps);
	ClassDB::bind_method(D_METHOD("open_settings"), &StepioHealthKit::open_settings);

	ADD_SIGNAL(MethodInfo("permission_result",
			PropertyInfo(Variant::BOOL, "granted"),
			PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("steps_result",
			PropertyInfo(Variant::INT, "request_id"),
			PropertyInfo(Variant::INT, "total"),
			PropertyInfo(Variant::INT, "excluding_manual"),
			PropertyInfo(Variant::STRING, "error")));
}

String StepioHealthKit::get_status() const {
	return [HKHealthStore isHealthDataAvailable] ? "available" : "unsupported";
}

// HealthKit never tells an app whether the player allowed reading (a denied
// read just looks like zero steps). The closest we can report is whether the
// permission sheet has already been shown.
void StepioHealthKit::check_permission() {
	if (![HKHealthStore isHealthDataAvailable]) {
		call_deferred("emit_signal", "permission_result", false, "HealthKit is not available on this device");
		return;
	}
	[health_store() getRequestStatusForAuthorizationToShareTypes:[NSSet set]
													   readTypes:read_types()
													  completion:^(HKAuthorizationRequestStatus status, NSError *error) {
														  if (error) {
															  call_deferred("emit_signal", "permission_result", false, to_godot(error.localizedDescription));
														  } else if (status == HKAuthorizationRequestStatusUnnecessary) {
															  call_deferred("emit_signal", "permission_result", true, "Permission sheet already answered (iOS does not say whether reading was allowed)");
														  } else {
															  call_deferred("emit_signal", "permission_result", false, "Step access not requested yet");
														  }
													  }];
}

void StepioHealthKit::request_permission() {
	if (![HKHealthStore isHealthDataAvailable]) {
		call_deferred("emit_signal", "permission_result", false, "HealthKit is not available on this device");
		return;
	}
	[health_store() requestAuthorizationToShareTypes:nil
										   readTypes:read_types()
										  completion:^(BOOL success, NSError *error) {
											  String message = success
													  ? String("Permission sheet answered (iOS does not say whether reading was allowed)")
													  : to_godot(error.localizedDescription);
											  call_deferred("emit_signal", "permission_result", (bool)success, message);
										  }];
}

// Runs a cumulative-sum statistics query. HealthKit merges overlapping samples
// from the phone and a watch, so the sum is not double counted.
static void run_sum_query(NSPredicate *p_predicate, void (^p_done)(int64_t steps, NSError *error)) {
	HKQuantityType *type = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierStepCount];
	HKStatisticsQuery *query = [[HKStatisticsQuery alloc] initWithQuantityType:type
													   quantitySamplePredicate:p_predicate
																	   options:HKStatisticsOptionCumulativeSum
															 completionHandler:^(HKStatisticsQuery *q, HKStatistics *result, NSError *error) {
																 if (error && error.code != HKErrorNoData) {
																	 p_done(-1, error);
																	 return;
																 }
																 HKQuantity *sum = result.sumQuantity;
																 p_done(sum ? (int64_t)[sum doubleValueForUnit:[HKUnit countUnit]] : 0, nil);
															 }];
	[health_store() executeQuery:query];
}

void StepioHealthKit::query_steps(int64_t p_start_unix, int64_t p_end_unix, int p_request_id) {
	if (![HKHealthStore isHealthDataAvailable]) {
		call_deferred("emit_signal", "steps_result", p_request_id, -1, -1, "HealthKit is not available on this device");
		return;
	}

	NSDate *start = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)p_start_unix];
	NSDate *end = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)p_end_unix];
	NSPredicate *in_range = [HKQuery predicateForSamplesWithStartDate:start endDate:end options:HKQueryOptionStrictStartDate];
	NSPredicate *not_manual = [NSPredicate predicateWithFormat:@"metadata.%K != YES", HKMetadataKeyWasUserEntered];
	NSPredicate *in_range_not_manual = [NSCompoundPredicate andPredicateWithSubpredicates:@[ in_range, not_manual ]];

	run_sum_query(in_range, ^(int64_t total, NSError *error) {
		if (error) {
			call_deferred("emit_signal", "steps_result", p_request_id, -1, -1, to_godot(error.localizedDescription));
			return;
		}
		run_sum_query(in_range_not_manual, ^(int64_t excluding_manual, NSError *error2) {
			if (error2) {
				call_deferred("emit_signal", "steps_result", p_request_id, total, -1, to_godot(error2.localizedDescription));
				return;
			}
			call_deferred("emit_signal", "steps_result", p_request_id, total, excluding_manual, String());
		});
	});
}

void StepioHealthKit::open_settings() {
	dispatch_async(dispatch_get_main_queue(), ^{
		// There is no public link to the app's page inside the Health app, so this
		// opens the Health app itself. Steps access lives under
		// Sharing > Apps > step.io there.
		NSURL *health = [NSURL URLWithString:@"x-apple-health://"];
		[[UIApplication sharedApplication] openURL:health options:@{} completionHandler:nil];
	});
}
