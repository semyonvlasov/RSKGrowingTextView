//
// Copyright 2015-present Ruslan Skorb, http://ruslanskorb.com/
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this work except in compliance with the License.
// You may obtain a copy of the License in the LICENSE file, or at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

/// The type of the block which contains user defined actions that will run during the height change.
public typealias HeightChangeUserActionsBlockType = ((_ oldHeight: CGFloat, _ newHeight: CGFloat) -> Void)

/// The `RSKGrowingTextViewDelegate` protocol extends the `UITextViewDelegate` protocol by providing a set of optional methods you can use to receive messages related to the change of the height of `RSKGrowingTextView` objects.
@objc public protocol RSKGrowingTextViewDelegate: UITextViewDelegate {
    ///
    /// Tells the delegate that the growing text view did change height.
    ///
    /// - Parameters:
    ///     - textView: The growing text view object that has changed the height.
    ///     - growingTextViewHeightBegin: CGFloat that identifies the start height of the growing text view.
    ///     - growingTextViewHeightEnd: CGFloat that identifies the end height of the growing text view.
    ///
    @objc optional func growingTextView(_ textView: RSKGrowingTextView, didChangeHeightFrom growingTextViewHeightBegin: CGFloat, to growingTextViewHeightEnd: CGFloat)
    
    ///
    /// Tells the delegate that the growing text view will change height.
    ///
    /// - Parameters:
    ///     - textView: The growing text view object that will change the height.
    ///     - growingTextViewHeightBegin: CGFloat that identifies the start height of the growing text view.
    ///     - growingTextViewHeightEnd: CGFloat that identifies the end height of the growing text view.
    ///
    @objc optional func growingTextView(_ textView: RSKGrowingTextView, willChangeHeightFrom growingTextViewHeightBegin: CGFloat, to growingTextViewHeightEnd: CGFloat)
}

/// A light-weight UITextView subclass that automatically grows and shrinks based on the size of user input and can be constrained by maximum and minimum number of lines.
@IBDesignable open class RSKGrowingTextView: RSKPlaceholderTextView {
    
    
    
    // MARK: - Private Properties
    
    fileprivate var calculatedHeight: CGFloat {
        let calculationTextStorage = NSTextStorage(attributedString: attributedText)
        calculationTextStorage.addLayoutManager(calculationLayoutManager)
        
        calculationTextContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        calculationTextContainer.size = textContainer.size
        
        calculationLayoutManager.ensureLayout(for: calculationTextContainer)
        
        var height = calculationLayoutManager.usedRect(for: calculationTextContainer).height + contentInset.top + contentInset.bottom + textContainerInset.top + textContainerInset.bottom
        if height < minHeight {
            height = minHeight
        } else if height > maxHeight {
            height = maxHeight
        }
        
        return height
    }
    
    fileprivate let calculationLayoutManager = NSLayoutManager()
    
    fileprivate let calculationTextContainer = NSTextContainer()
    
    fileprivate weak var heightConstraint: NSLayoutConstraint?
    
    fileprivate var maxHeight: CGFloat { return max(heightForNumberOfLines(maximumNumberOfLines), maximumHeight) }
    
    fileprivate var minHeight: CGFloat { return minimumHeight }
    
    // MARK: - Public Properties
    
    /// A Boolean value that determines whether the animation of the height change is enabled. Default value is `true`.
    @IBInspectable open var animateHeightChange: Bool = true
    
    /// The receiver's delegate.
    open weak var growingTextViewDelegate: RSKGrowingTextViewDelegate? { didSet { delegate = growingTextViewDelegate } }
    
    /// The duration of the animation of the height change. The default value is `0.35`.
    @IBInspectable open var heightChangeAnimationDuration: Double = 0.35
    
    /// The block which contains user defined actions that will run during the height change.
    open var heightChangeUserActionsBlock: HeightChangeUserActionsBlockType?
    
    /// The maximum number of lines before enabling scrolling. The default value is `5`.
    @IBInspectable open var maximumNumberOfLines: Int = 5 {
        didSet {
            if maximumNumberOfLines < 1 {
                maximumNumberOfLines = 1
            }
            refreshHeightIfNeededAnimated(false)
        }
    }
    
    /// The minimum number of lines. The default value is `1`.
    //    @IBInspectable open var minimumNumberOfLines: Int = 1 {
    //        didSet {
    //            if minimumNumberOfLines < 1 {
    //                minimumNumberOfLines = 1
    //            } else if minimumNumberOfLines > maximumNumberOfLines {
    //                minimumNumberOfLines = maximumNumberOfLines
    //            }
    //            refreshHeightIfNeededAnimated(false)
    //        }
    //    }
    
    @IBInspectable open var maximumHeight: CGFloat = 72.0 {
        didSet {
            if maximumHeight < minimumHeight {
                maximumHeight = minimumHeight
            }
            refreshHeightIfNeededAnimated(false)
        }
    }
    
    @IBInspectable open var minimumHeight: CGFloat = 32.0 {
        didSet {
            if minimumHeight > maximumHeight {
                minimumHeight = maximumHeight
            }
            refreshHeightIfNeededAnimated(false)
        }
    }
    
    /// The current displayed number of lines. This value is calculated based on the height of text lines.
    open var numberOfLines: Int {
        guard let font = self.font else {
            return 0
        }
        
        let textRectHeight = contentSize.height - contentInset.top - contentInset.bottom - textContainerInset.top - textContainerInset.bottom
        let numberOfLines = textRectHeight / font.lineHeight
        
        return lround(Double(numberOfLines))
    }
    
    // MARK: - Superclass Properties
    
    override open var attributedText: NSAttributedString! {
        didSet {
            superview?.layoutIfNeeded()
        }
    }
    
    override open var contentSize: CGSize {
        didSet {
            guard window != nil && !oldValue.equalTo(contentSize) else {
                return
            }
            if isFirstResponder {
                refreshHeightIfNeededAnimated(animateHeightChange)
            } else {
                refreshHeightIfNeededAnimated(false)
            }
            
            if centerText {
                var topCorrection = (bounds.size.height - contentSize.height * zoomScale) / 2.0
                topCorrection = max(0, topCorrection)
                self.contentInset = UIEdgeInsetsMake(topCorrection, 0, 0, 0)
            } else {
                self.contentInset = UIEdgeInsetsMake(topInset, 0, bottomInset, 0)
            }
        }
    }
    
    // MARK: - Object Lifecycle
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInitializer()
    }
    
    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInitializer()
    }
    
    // MARK: - Layout
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.textContainerInset = UIEdgeInsetsMake(topInset, leftInset, bottomInset, rightInset)
    }
    
    override open var intrinsicContentSize: CGSize {
        if heightConstraint != nil {
            return CGSize(width: UIViewNoIntrinsicMetric, height: UIViewNoIntrinsicMetric)
        } else {
            return CGSize(width: UIViewNoIntrinsicMetric, height: calculatedHeight)
        }
    }
    
    // MARK: - Helper Methods
    
    fileprivate func commonInitializer() {
        scrollsToTop = false
        
        for constraint in constraints {
            if constraint.firstAttribute == .height && constraint.relation == .equal {
                heightConstraint = constraint
                break
            }
        }
        calculationLayoutManager.addTextContainer(calculationTextContainer)
    }
    
    fileprivate func heightForNumberOfLines(_ numberOfLines: Int) -> CGFloat {
        var height = contentInset.top + contentInset.bottom + textContainerInset.top + textContainerInset.bottom
        if let font = self.font {
            height += font.lineHeight * CGFloat(numberOfLines)
        }
        return ceil(height)
    }
    
    fileprivate func refreshHeightIfNeededAnimated(_ animated: Bool) {
        let oldHeight = bounds.height
        let newHeight = calculatedHeight
        
        if oldHeight != newHeight {
            typealias HeightChangeSetHeightBlockType = ((_ oldHeight: CGFloat, _ newHeight: CGFloat) -> Void)
            let heightChangeSetHeightBlock: HeightChangeSetHeightBlockType = { (oldHeight: CGFloat, newHeight: CGFloat) -> Void in
                self.setHeight(newHeight)
                self.heightChangeUserActionsBlock?(oldHeight, newHeight)
                self.superview?.layoutIfNeeded()
            }
            typealias HeightChangeCompletionBlockType = ((_ oldHeight: CGFloat, _ newHeight: CGFloat) -> Void)
            let heightChangeCompletionBlock: HeightChangeCompletionBlockType = { (oldHeight: CGFloat, newHeight: CGFloat) -> Void in
                self.layoutManager.ensureLayout(for: self.textContainer)
                self.scrollToVisibleCaretIfNeeded()
                self.growingTextViewDelegate?.growingTextView?(self, didChangeHeightFrom: oldHeight, to: newHeight)
            }
            growingTextViewDelegate?.growingTextView?(self, willChangeHeightFrom: oldHeight, to: newHeight)
            if animated {
                UIView.animate(
                    withDuration: heightChangeAnimationDuration,
                    delay: 0.0,
                    options: [.allowUserInteraction, .beginFromCurrentState],
                    animations: { () -> Void in
                        heightChangeSetHeightBlock(oldHeight, newHeight)
                },
                    completion: { (finished: Bool) -> Void in
                        heightChangeCompletionBlock(oldHeight, newHeight)
                }
                )
            } else {
                heightChangeSetHeightBlock(oldHeight, newHeight)
                heightChangeCompletionBlock(oldHeight, newHeight)
            }
        } else {
            scrollToVisibleCaretIfNeeded()
        }
    }
    
    fileprivate func scrollRectToVisibleConsideringInsets(_ rect: CGRect) {
        let insets = UIEdgeInsetsMake(contentInset.top + textContainerInset.top, contentInset.left + textContainerInset.left + textContainer.lineFragmentPadding, contentInset.bottom + textContainerInset.bottom, contentInset.right + textContainerInset.right)
        
        let visibleRect = UIEdgeInsetsInsetRect(bounds, insets)
        
        guard !visibleRect.contains(rect) else {
            return
        }
        
        var contentOffset = self.contentOffset
        if rect.minY < visibleRect.minY {
            contentOffset.y = rect.minY - insets.top * 2
        } else {
            contentOffset.y = rect.maxY + insets.bottom * 2 - bounds.height
        }
        setContentOffset(contentOffset, animated: false)
    }
    
    fileprivate func scrollToVisibleCaretIfNeeded() {
        guard let textPosition = selectedTextRange?.end else {
            return
        }
        
        if textStorage.editedRange.location == NSNotFound && !isDragging && !isDecelerating {
            let caretRect = self.caretRect(for: textPosition)
            let caretCenterRect = CGRect(x: caretRect.midX, y: caretRect.midY, width: 0.0, height: 0.0)
            scrollRectToVisibleConsideringInsets(caretCenterRect)
        }
    }
    
    fileprivate func setHeight(_ height: CGFloat) {
        if let heightConstraint = self.heightConstraint {
            heightConstraint.constant = height
        } else if !constraints.isEmpty {
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        } else {
            frame.size.height = height
        }
    }
}

@IBDesignable open class RSKPlaceholderTextView: UITextView {
    
    // MARK: - Private Properties
    
    private var placeholderAttributes: [String: Any] {
        var placeholderAttributes = typingAttributes
        if placeholderAttributes[NSFontAttributeName] == nil {
            placeholderAttributes[NSFontAttributeName] = typingAttributes[NSFontAttributeName] ?? font ?? UIFont.systemFont(ofSize: UIFont.systemFontSize)
        }
        if placeholderAttributes[NSParagraphStyleAttributeName] == nil {
            let typingParagraphStyle = typingAttributes[NSParagraphStyleAttributeName]
            if typingParagraphStyle == nil {
                let paragraphStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.alignment = textAlignment
                paragraphStyle.lineBreakMode = textContainer.lineBreakMode
                placeholderAttributes[NSParagraphStyleAttributeName] = paragraphStyle
            } else {
                placeholderAttributes[NSParagraphStyleAttributeName] = typingParagraphStyle
            }
        }
        placeholderAttributes[NSForegroundColorAttributeName] = self.isActive ? placeholderActiveColor : placeholderDefaultColor
        
        return placeholderAttributes
    }
    
    private var isActive = false
    
    private var placeholderInsets: UIEdgeInsets {
        let placeholderInsets = UIEdgeInsets(top: contentInset.top + textContainerInset.top,
                                             left: contentInset.left + textContainerInset.left + textContainer.lineFragmentPadding,
                                             bottom: contentInset.bottom + textContainerInset.bottom,
                                             right: contentInset.right + textContainerInset.right + textContainer.lineFragmentPadding)
        return placeholderInsets
    }
    
    private lazy var placeholderLayoutManager: NSLayoutManager = NSLayoutManager()
    
    private lazy var placeholderTextContainer: NSTextContainer = NSTextContainer()
    
    // MARK: - Public Properties
    
    /// The attributed string that is displayed when there is no other text in the placeholder text view. This value is `nil` by default.
    @NSCopying open var attributedPlaceholder: NSAttributedString? {
        didSet {
            guard isEmpty == true else {
                return
            }
            setNeedsDisplay()
        }
    }
    
    /// Determines whether or not the placeholder text view contains text.
    open var isEmpty: Bool { return text.isEmpty }
    
    /// Trim white space and newline characters when end editing
    
    @IBInspectable open var trimWhiteSpaceWhenEndEditing: Bool = true
    
    /// The string that is displayed when there is no other text in the placeholder text view. This value is `nil` by default.
    @IBInspectable open var placeholder: NSString? {
        get {
            return attributedPlaceholder?.string as NSString?
        }
        set {
            if let newValue = newValue as String? {
                attributedPlaceholder = NSAttributedString(string: newValue, attributes: placeholderAttributes)
            } else {
                attributedPlaceholder = nil
            }
        }
    }
    
    /// The color of the placeholder. This property applies to the entire placeholder string. The default placeholder color is `UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)`.
    @IBInspectable open var placeholderDefaultColor: UIColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) {
        didSet {
            if let placeholder = placeholder as String? {
                attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
            }
        }
    }
    
    @IBInspectable open var placeholderActiveColor: UIColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0) {
        didSet {
            if let placeholder = placeholder as String? {
                attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
            }
        }
    }
    
    @IBInspectable open var cornerRadius: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderWidth: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderWidthActive: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var borderActiveColor: UIColor = UIColor(white: 0.8, alpha: 1.0) {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var attributedPlaceHolder: NSAttributedString? {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable open var placeHolderLeftMargin: CGFloat = 5 {
        didSet { setNeedsDisplay() }
    }
    
    @IBInspectable public var bottomInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var leftInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var rightInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var topInset: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }
    @IBInspectable public var centerText: Bool = true {
        didSet { setNeedsDisplay() }
    }
    
    // MARK: - Superclass Properties
    
    open override var text: String! {
        didSet {
            self.layer.borderWidth = self.isActive ? self.borderWidthActive : self.borderWidth
            self.layer.borderColor = self.isActive ? self.borderActiveColor.cgColor : self.borderColor.cgColor
            self.layer.shadowColor = UIColor(red: 13/255.0, green: 21/255.0, blue: 38/255.0, alpha: 0.2).cgColor
            self.layer.shadowOffset = CGSize(width: 0, height: self.isActive ? 5.0 : 0)
            self.layer.shadowOpacity = self.isActive ? 1.0 : 0
            self.layer.cornerRadius = self.cornerRadius
            self.tintColor = self.borderActiveColor
            setNeedsDisplay()
        }
    }
    
    override open var attributedText: NSAttributedString! { didSet { setNeedsDisplay() } }
    
    override open var bounds: CGRect { didSet { setNeedsDisplay() } }
    
    override open var contentInset: UIEdgeInsets { didSet { setNeedsDisplay() } }
    
    override open var font: UIFont? {
        didSet {
            if let placeholder = placeholder as String? {
                attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
            }
        }
    }
    
    override open var textAlignment: NSTextAlignment {
        didSet {
            if let placeholder = placeholder as String? {
                attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
            }
        }
    }
    
    override open var textContainerInset: UIEdgeInsets { didSet { setNeedsDisplay() } }
    
    override open var typingAttributes: [String : Any] {
        didSet {
            if let placeholder = placeholder as String? {
                attributedPlaceholder = NSAttributedString(string: placeholder, attributes: placeholderAttributes)
            }
        }
    }
    
    // MARK: - Object Lifecycle
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UITextViewTextDidChange, object: self)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInitializer()
    }
    
    override public init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        commonInitializer()
    }
    
    // MARK: - Superclass API
    
    override open func caretRect(for position: UITextPosition) -> CGRect {
        guard text.isEmpty == true, let attributedPlaceholder = attributedPlaceholder else {
            return super.caretRect(for: position)
        }
        if placeholderTextContainer.layoutManager == nil {
            placeholderLayoutManager.addTextContainer(placeholderTextContainer)
        }
        
        let placeholderTextStorage = NSTextStorage(attributedString: attributedPlaceholder)
        placeholderTextStorage.addLayoutManager(placeholderLayoutManager)
        
        placeholderTextContainer.lineFragmentPadding = textContainer.lineFragmentPadding
        placeholderTextContainer.size = textContainer.size
        
        placeholderLayoutManager.ensureLayout(for: placeholderTextContainer)
        
        var caretRect = super.caretRect(for: position)
        
        caretRect.origin.x = placeholderLayoutManager.usedRect(for: placeholderTextContainer).origin.x + placeholderInsets.left
        
        return caretRect
    }
    
    override open func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard isEmpty else {
            return
        }
        guard let attributedPlaceholder = attributedPlaceholder else {
            return
        }
        
        let placeholderRect = UIEdgeInsetsInsetRect(rect, placeholderInsets)
        attributedPlaceholder.draw(in: placeholderRect)
        
        self.layer.borderWidth = self.isActive ? self.borderWidthActive : self.borderWidth
        self.layer.borderColor = self.isActive ? self.borderActiveColor.cgColor : self.borderColor.cgColor
        self.layer.shadowColor = UIColor(red: 13/255.0, green: 21/255.0, blue: 38/255.0, alpha: 0.2).cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: self.isActive ? 5.0 : 0)
        self.layer.shadowOpacity = self.isActive ? 1.0 : 0
        self.layer.cornerRadius = self.cornerRadius
        self.tintColor = self.borderActiveColor
    }
    
    // MARK: - Helper Methods
    
    private func commonInitializer() {
        contentMode = .topLeft
        NotificationCenter.default.addObserver(self, selector: #selector(RSKPlaceholderTextView.handleTextViewTextDidChangeNotification(_:)), name: NSNotification.Name.UITextViewTextDidChange, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(RSKPlaceholderTextView.handleTextViewTextDidBeginEditingNotification(_:)), name: NSNotification.Name.UITextViewTextDidBeginEditing, object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(RSKPlaceholderTextView.handleTextViewTextDidEndEditingNotification(_:)), name: NSNotification.Name.UITextViewTextDidEndEditing, object: self)
    }
    
    open func clearTextView() {
        self.text = ""
        setNeedsDisplay()
    }
    
    internal func handleTextViewTextDidChangeNotification(_ notification: Notification) {
        guard let object = notification.object as? RSKPlaceholderTextView, object === self else {
            return
        }
        setNeedsDisplay()
    }
    
    internal func handleTextViewTextDidBeginEditingNotification(_ notification: Notification) {
        guard let object = notification.object as? RSKPlaceholderTextView, object === self else {
            return
        }
        self.isActive = true
        setNeedsDisplay()
    }
    
    internal func handleTextViewTextDidEndEditingNotification(_ notification: Notification) {
        guard let object = notification.object as? RSKPlaceholderTextView, object === self else {
            return
        }
        self.isActive = false
        if trimWhiteSpaceWhenEndEditing {
            text = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        setNeedsDisplay()
    }
}
