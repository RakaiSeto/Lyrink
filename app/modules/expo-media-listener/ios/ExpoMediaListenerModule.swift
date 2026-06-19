import ExpoModulesCore

public class ExpoMediaListenerModule: Module {
  public func definition() -> ModuleDefinition {
    Name("ExpoMediaListener")

    Function("startListening") {
      // iOS does not support reading other apps' notifications
    }

    Function("stopListening") {
      // no-op
    }

    Function("isListening") { () -> Bool in
      return false
    }

    Function("requestPermission") {
      // no-op
    }

    Function("isPermissionGranted") { () -> Bool in
      return false
    }

    Function("getCurrentMetadata") { () -> [String: Any]? in
      return nil
    }
  }
}
