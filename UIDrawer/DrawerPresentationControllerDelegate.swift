import Foundation

public protocol DrawerPresentationControllerDelegate: class {
    func drawerMovedTo(position: DraweSnapPoint)
}

public enum DraweSnapPoint {
    case top
    case middle
    case close
}
