import Foundation

public class DrawerPresentationController: UIPresentationController {

    // Optional attributes
    public weak var drawerDelegate: DrawerPresentationControllerDelegate?

    // Public setable attributes
    public var blurEffectStyle: UIBlurEffect.Style = .light
    public var topGap: CGFloat = 88
    public var modalWidth: CGFloat = 0
    public var bounce: Bool = false
    public var cornerRadius: CGFloat = 20

    // Frame for the modally presented view.
    override public var frameOfPresentedViewInContainerView: CGRect {
        return CGRect(origin: CGPoint(x: 0, y: containerView!.frame.height/2), size: CGSize(width: (modalWidth == 0 ? containerView!.frame.width : modalWidth), height: containerView!.frame.height-topGap))
    }

    // Private Attributes
    private var currentSnapPoint: DraweSnapPoint = .middle
    private let roundedCorners: UIRectCorner = [.topLeft, .topRight]

    private lazy var blurEffectView: UIVisualEffectView = {
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: blurEffectStyle))
        blur.isUserInteractionEnabled = true
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blur.addGestureRecognizer(tapGestureRecognizer)
        return blur
    }()

    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        return UITapGestureRecognizer(target: self, action: #selector(dismiss))
    }()

    private lazy var panGesture: UIPanGestureRecognizer = {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        return pan
    }()

    // Initializers
    public convenience init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, drawerDelegate: DrawerPresentationControllerDelegate? = nil, blurEffectStyle: UIBlurEffect.Style = .light, topGap: CGFloat = 88, modalWidth: CGFloat = 0, cornerRadius: CGFloat = 20) {
        self.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        self.drawerDelegate = drawerDelegate
        self.blurEffectStyle = blurEffectStyle
        self.topGap = topGap
        self.modalWidth = modalWidth
        self.cornerRadius = cornerRadius
    }
    /// Regular init.
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }

    override public func dismissalTransitionWillBegin() {
        self.presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
            self.blurEffectView.alpha = 0
        }, completion: { (UIViewControllerTransitionCoordinatorContext) in
            self.blurEffectView.removeFromSuperview()
        })
    }

    override public func presentationTransitionWillBegin() {
        blurEffectView.alpha = 0
        guard let presenterView = containerView else { return }
        presenterView.addSubview(blurEffectView)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) in
            self.blurEffectView.alpha = 1
        }, completion: { (UIViewControllerTransitionCoordinatorContext) in })
    }

    override public func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let presentedView = presentedView else { return }

        presentedView.layer.masksToBounds = true
        presentedView.roundCorners(corners: roundedCorners, radius: cornerRadius)
        presentedView.addGestureRecognizer(panGesture)
    }

    override public func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        guard let presenterView = containerView else { return }
        guard let presentedView = presentedView else { return }

        // Set the frame and position of the modal
        presentedView.frame = frameOfPresentedViewInContainerView
        presentedView.frame.origin.x = (presenterView.frame.width - presentedView.frame.width) / 2
        presentedView.center = CGPoint(x: presentedView.center.x, y: presenterView.center.y * 2)

        blurEffectView.frame = presenterView.bounds
    }

    @objc func dismiss() {
       presentedViewController.dismiss(animated: true, completion: nil)
    }

    @objc func drag(_ gesture:UIPanGestureRecognizer) {
        guard let presentedView = presentedView else { return }
        switch gesture.state {
        case .changed:
            presentingViewController.view.bringSubviewToFront(presentedView)
            let translation = gesture.translation(in: presentingViewController.view)
            let y = presentedView.center.y + translation.y

            let preventBounce: Bool = bounce ? true : (y - (topGap / 2) > presentingViewController.view.center.y)
            // If bounce enabled or view went over the maximum y postion.
            if preventBounce {
                presentedView.center = CGPoint(x: presentedView.center.x, y: y)
            }
            gesture.setTranslation(CGPoint.zero, in: presentingViewController.view)
        case .ended:
            let height = presentingViewController.view.frame.height
            let position = presentedView.convert(presentingViewController.view.frame, to: nil).origin.y
            if position < 0 || position < (1/4 * height) {
                // TOP SNAP POINT
                sendToTop()
                currentSnapPoint = .top
            } else if (position < (height / 2)) || (position > (height / 2) && position < (height / 3)) {
                // MIDDLE SNAP POINT
                sendToMiddle()
                currentSnapPoint = .middle
            } else {
                // BOTTOM SNAP POINT
                currentSnapPoint = .close
                dismiss()
            }
            if let d = drawerDelegate {
                d.drawerMovedTo(position: currentSnapPoint)
            }
            gesture.setTranslation(CGPoint.zero, in: presentingViewController.view)
        default:
            return
        }
    }

    func sendToTop() {
        guard let presentedView = presentedView else { return }
        let topYPosition: CGFloat = (presentingViewController.view.center.y + CGFloat(topGap / 2))
        UIView.animate(withDuration: 0.25) {
            presentedView.center = CGPoint(x: presentedView.center.x, y: topYPosition)
        }
    }

    func sendToMiddle() {
        if let presentedView = presentedView {
            let y = presentingViewController.view.center.y * 2
            UIView.animate(withDuration: 0.25) {
                presentedView.center = CGPoint(x: presentedView.center.x, y: y)
            }
        }
    }
}

private extension UIView {
    func roundCorners(corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
}
