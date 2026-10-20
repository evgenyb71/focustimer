import Foundation

protocol KeyValueStore {
    func data(forKey key: String) -> Data?
    func setData(_ data: Data, forKey key: String)
}

extension UserDefaults: KeyValueStore {
    func setData(_ data: Data, forKey key: String) {
        set(data, forKey: key)
    }
}
