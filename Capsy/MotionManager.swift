import CoreMotion
import Observation

/// Publishes the device roll angle so the liquid can tilt with the phone.
/// On the simulator roll stays 0 and the water falls back to ambient waves.
@Observable
final class MotionManager {
    static let shared = MotionManager()

    var roll: Double = 0

    private let motion = CMMotionManager()

    private init() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let data else { return }
            self?.roll = data.attitude.roll
        }
    }
}
