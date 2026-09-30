import Foundation

let results = SleepDetectorTests.run()
var failedCount = 0

print("Running SleepDetectorTests (\(results.count) tests)...")
for r in results {
    if r.passed {
        print("  ✅ PASS: \(r.name)")
    } else {
        print("  ❌ FAIL: \(r.name) - \(r.detail)")
        failedCount += 1
    }
}

if results.count != 18 {
    print("❌ Expected 18 tests, but ran \(results.count)")
    exit(1)
}

if failedCount > 0 {
    print("❌ \(failedCount) tests failed.")
    exit(1)
} else {
    print("✅ All \(results.count) SleepDetectorTests passed successfully.")
    exit(0)
}
