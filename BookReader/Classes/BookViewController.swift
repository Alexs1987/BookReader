//
//  BookViewController.swift
//  BookReader
//
//  Created by Kishikawa Katsumi on 2017/07/03.
//  Copyright © 2017 Kishikawa Katsumi. All rights reserved.
//

import UIKit
import PDFKit
import MessageUI
import UIKit.UIGestureRecognizerSubclass

public class BookViewController: UIViewController, UIPopoverPresentationControllerDelegate, PDFViewDelegate, ActionMenuViewControllerDelegate, SearchViewControllerDelegate, ThumbnailGridViewControllerDelegate, OutlineViewControllerDelegate, BookmarkViewControllerDelegate, MFMailComposeViewControllerDelegate {
    @objc public var pdfDocument: PDFDocument?

    @IBOutlet weak var pdfView: PDFView!
    @IBOutlet weak var pdfThumbnailViewContainer: UIView!
    @IBOutlet weak var pdfThumbnailView: PDFThumbnailView!
    @IBOutlet private weak var pdfThumbnailViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var titleLabelContainer: UIView!
    @IBOutlet weak var pageNumberLabel: UILabel!
    @IBOutlet weak var pageNumberLabelContainer: UIView!
        
    var tableOfContentsToggleSegmentedControl: UISegmentedControl!
    @IBOutlet weak var thumbnailGridViewConainer: UIView!
    @IBOutlet weak var outlineViewConainer: UIView!
    @IBOutlet weak var bookmarkViewConainer: UIView!

    var bookmarkButton: UIBarButtonItem?

    var searchNavigationController: UINavigationController?

    let barHideOnTapGestureRecognizer = UITapGestureRecognizer()
    let pdfViewGestureRecognizer = PDFViewGestureRecognizer()
    
    var bundle: Bundle!
    
    var bookmarksProvider: BookmarksProviderProtocol!
    
    @objc public static func makeFromStoryboard() -> BookViewController
    {
        let bookViewController = UIStoryboard(name: "BookReader", bundle: Bundle.bookReader).instantiateViewController(withIdentifier: "BookViewController") as! BookViewController
        bookViewController.bookmarksProvider = BookmarksProvider()
        return bookViewController
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        bundle = Bundle.bookReader
        
        tableOfContentsToggleSegmentedControl = UISegmentedControl(items: [
            UIImage.init(named: "Grid", in: bundle, compatibleWith: nil)!,
            UIImage.init(named: "List", in: bundle, compatibleWith: nil)!,
            UIImage.init(named: "Bookmark-P", in: bundle, compatibleWith: nil)!,
            ])

        NotificationCenter.default.addObserver(self, selector: #selector(pdfViewPageChanged(_:)), name: .PDFViewPageChanged, object: nil)

        barHideOnTapGestureRecognizer.addTarget(self, action: #selector(gestureRecognizedToggleVisibility(_:)))
        view.addGestureRecognizer(barHideOnTapGestureRecognizer)

        tableOfContentsToggleSegmentedControl.selectedSegmentIndex = 0
        tableOfContentsToggleSegmentedControl.addTarget(self, action: #selector(toggleTableOfContentsView(_:)), for: .valueChanged)

        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true, withViewOptions: [UIPageViewController.OptionsKey.interPageSpacing: 20])

        pdfView.addGestureRecognizer(pdfViewGestureRecognizer)

        pdfView.document = pdfDocument

        pdfThumbnailView.layoutMode = .horizontal
        pdfThumbnailView.pdfView = pdfView

        titleLabel.text = pdfDocument?.documentAttributes?["Title"] as? String
        titleLabelContainer.layer.cornerRadius = 4
        pageNumberLabelContainer.layer.cornerRadius = 4

        resume()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if navigationController?.topViewController != self {
            presentedViewController?.dismiss(animated: false, completion: nil)
        }
    }
    
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override public func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        adjustThumbnailViewHeight()
    }

    override public func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (context) in
            self.adjustThumbnailViewHeight()
        }, completion: nil)
    }

    private func adjustThumbnailViewHeight() {
        self.pdfThumbnailViewHeightConstraint.constant = 44 + self.view.safeAreaInsets.bottom
    }
    
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? ThumbnailGridViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? OutlineViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
        } else if let viewController = segue.destination as? BookmarkViewController {
            viewController.pdfDocument = pdfDocument
            viewController.delegate = self
            viewController.bookmarksProvider = BookmarksProvider()
        }
    }

    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    public func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
           return .none
       }

    func actionMenuViewControllerShareDocument(_ actionMenuViewController: ActionMenuViewController) {
        guard MFMailComposeViewController.canSendMail() else {
            let alertController = UIAlertController(title: "Email not configured", message: "Please configure your email and try again", preferredStyle: .alert)
                   alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            let presentationBlock: () -> () = { [weak self] in
                self?.present(alertController, animated: true, completion: nil)
            }
            if presentedViewController != nil {
                presentedViewController?.dismiss(animated: true, completion: presentationBlock)
            }
            else {
                presentationBlock()
            }
            return
        }
        let mailComposeViewController = MFMailComposeViewController()
        mailComposeViewController.mailComposeDelegate = self
        if let lastPathComponent = pdfDocument?.documentURL?.lastPathComponent,
            let documentAttributes = pdfDocument?.documentAttributes,
            let attachmentData = pdfDocument?.dataRepresentation() {
            if let title = documentAttributes["Title"] as? String {
                mailComposeViewController.setSubject(title)
            }
            mailComposeViewController.addAttachmentData(attachmentData, mimeType: "application/pdf", fileName: lastPathComponent)
            let presentationBlock: () -> () = { [weak self] in
                self?.present(mailComposeViewController, animated: true, completion: nil)
            }
            if presentedViewController != nil {
                presentedViewController?.dismiss(animated: true, completion: presentationBlock)
            }
            else {
                presentationBlock()
            }
        }
    }

    func actionMenuViewControllerPrintDocument(_ actionMenuViewController: ActionMenuViewController) {
        let printInteractionController = UIPrintInteractionController.shared
        printInteractionController.printingItem = pdfDocument?.dataRepresentation()
        printInteractionController.present(animated: true, completionHandler: nil)
    }

    func searchViewController(_ searchViewController: SearchViewController, didSelectSearchResult selection: PDFSelection) {
        selection.color = .yellow
        pdfView.currentSelection = selection
        pdfView.go(to: selection)
        showBars()
    }

    func thumbnailGridViewController(_ thumbnailGridViewController: ThumbnailGridViewController, didSelectPage page: PDFPage) {
        resume()
        pdfView.go(to: page)
    }

    func outlineViewController(_ outlineViewController: OutlineViewController, didSelectOutlineAt destination: PDFDestination) {
        resume()
        pdfView.go(to: destination)
    }

    func bookmarkViewController(_ bookmarkViewController: BookmarkViewController, didSelectPage page: PDFPage) {
        resume()
        pdfView.go(to: page)
    }
    
    //MARK: MFMailComposeViewControllerDelegate
    
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }

    private func resume() {
        let backButton = UIBarButtonItem(image: UIImage.init(named: "Chevron", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(back(_:)))
        let tableOfContentsButton = UIBarButtonItem(image: UIImage.init(named: "List", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(showTableOfContents(_:)))
        let actionButton = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(showActionMenu(_:)))
        navigationItem.leftBarButtonItems = [backButton, tableOfContentsButton, actionButton]

        let brightnessButton = UIBarButtonItem(image: UIImage.init(named: "Brightness", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(showAppearanceMenu(_:)))
        let searchButton = UIBarButtonItem(image: UIImage.init(named: "Search", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(showSearchView(_:)))
        bookmarkButton = UIBarButtonItem(image: UIImage.init(named: "Bookmark-N", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(addOrRemoveBookmark(_:)))
        navigationItem.rightBarButtonItems = [bookmarkButton!, searchButton, brightnessButton]

        pdfThumbnailViewContainer.alpha = 1

        pdfView.isHidden = false
        titleLabelContainer.alpha = 1
        pageNumberLabelContainer.alpha = 1
        thumbnailGridViewConainer.isHidden = true
        outlineViewConainer.isHidden = true

        barHideOnTapGestureRecognizer.isEnabled = true

        updateBookmarkStatus()
        updatePageNumberLabel()
    }

    private func showTableOfContents() {
        view.exchangeSubview(at: 0, withSubviewAt: 1)
        view.exchangeSubview(at: 0, withSubviewAt: 2)

        let backButton = UIBarButtonItem(image: UIImage.init(named: "Chevron", in: bundle, compatibleWith: nil), style: .plain, target: self, action: #selector(back(_:)))
        let tableOfContentsToggleBarButton = UIBarButtonItem(customView: tableOfContentsToggleSegmentedControl)
        let resumeBarButton = UIBarButtonItem(title: NSLocalizedString("Resume", comment: ""), style: .plain, target: self, action: #selector(resume(_:)))
        navigationItem.leftBarButtonItems = [backButton, tableOfContentsToggleBarButton]
        navigationItem.rightBarButtonItems = [resumeBarButton]

        pdfThumbnailViewContainer.alpha = 0

        toggleTableOfContentsView(tableOfContentsToggleSegmentedControl)

        barHideOnTapGestureRecognizer.isEnabled = false
    }

    @objc func resume(_ sender: UIBarButtonItem) {
        resume()
    }

    @objc func back(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    @objc func showTableOfContents(_ sender: UIBarButtonItem) {
        showTableOfContents()
    }

    @objc func showActionMenu(_ sender: UIBarButtonItem) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: String(describing: ActionMenuViewController.self)) as? ActionMenuViewController {
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 300, height: 88)
            viewController.popoverPresentationController?.barButtonItem = sender
            viewController.popoverPresentationController?.permittedArrowDirections = .up
            viewController.popoverPresentationController?.delegate = self
            viewController.delegate = self
            present(viewController, animated: true, completion: nil)
        }
    }

    @objc func showAppearanceMenu(_ sender: UIBarButtonItem) {
        if let viewController = storyboard?.instantiateViewController(withIdentifier: String(describing: AppearanceViewController.self)) as? AppearanceViewController {
            viewController.modalPresentationStyle = .popover
            viewController.preferredContentSize = CGSize(width: 300, height: 44)
            viewController.popoverPresentationController?.barButtonItem = sender
            viewController.popoverPresentationController?.permittedArrowDirections = .up
            viewController.popoverPresentationController?.delegate = self
            present(viewController, animated: true, completion: nil)
        }
    }

    @objc func showSearchView(_ sender: UIBarButtonItem) {
        if let searchNavigationController = self.searchNavigationController {
            present(searchNavigationController, animated: true, completion: nil)
        } else if let navigationController = storyboard?.instantiateViewController(withIdentifier: String(describing: SearchViewController.self)) as? UINavigationController,
            let searchViewController = navigationController.topViewController as? SearchViewController {
            searchViewController.pdfDocument = pdfDocument
            searchViewController.delegate = self
            present(navigationController, animated: true, completion: nil)

            searchNavigationController = navigationController
        }
    }

    @objc func addOrRemoveBookmark(_ sender: UIBarButtonItem) {
        guard let url = pdfDocument?.documentURL, let currentPage = pdfView.currentPage, let pageIndex = pdfDocument?.index(for: currentPage) else {
            return
        }
        if bookmarksProvider.hasBookmark(for: url, pageIndex: pageIndex) {
            bookmarksProvider.removeBookmark(for: url, pageIndex: pageIndex)
            bookmarkButton?.image = UIImage.init(named: "Bookmark-N", in: bundle, compatibleWith: nil)
        }
        else {
            bookmarksProvider.addBookmark(for: url, pageIndex: pageIndex)
            bookmarkButton?.image = UIImage.init(named: "Bookmark-P", in: bundle, compatibleWith: nil)
        }
    }

    @objc func toggleTableOfContentsView(_ sender: UISegmentedControl) {
        pdfView.isHidden = true
        titleLabelContainer.alpha = 0
        pageNumberLabelContainer.alpha = 0

        if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 0 {
            thumbnailGridViewConainer.isHidden = false
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = true
        } else if tableOfContentsToggleSegmentedControl.selectedSegmentIndex == 1 {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = false
            bookmarkViewConainer.isHidden = true
        } else {
            thumbnailGridViewConainer.isHidden = true
            outlineViewConainer.isHidden = true
            bookmarkViewConainer.isHidden = false
        }
    }

    @objc func pdfViewPageChanged(_ notification: Notification) {
        if pdfViewGestureRecognizer.isTracking {
            hideBars()
        }
        updateBookmarkStatus()
        updatePageNumberLabel()
    }

    @objc func gestureRecognizedToggleVisibility(_ gestureRecognizer: UITapGestureRecognizer) {
        if let navigationController = navigationController {
            if navigationController.navigationBar.alpha > 0 {
                hideBars()
            } else {
                showBars()
            }
        }
    }

    private func updateBookmarkStatus() {
        guard let url = pdfDocument?.documentURL, let currentPage = pdfView.currentPage, let index = pdfDocument?.index(for: currentPage) else {
            return
        }
        bookmarkButton?.image = bookmarksProvider.hasBookmark(for: url, pageIndex: index) ? UIImage.init(named: "Bookmark-P", in: bundle, compatibleWith: nil) : UIImage.init(named: "Bookmark-N", in: bundle, compatibleWith: nil)
    }

    private func updatePageNumberLabel() {
        if let currentPage = pdfView.currentPage, let index = pdfDocument?.index(for: currentPage), let pageCount = pdfDocument?.pageCount {
            pageNumberLabel.text = String(format: "%d/%d", index + 1, pageCount)
        } else {
            pageNumberLabel.text = nil
        }
    }

    private func showBars() {
        if let navigationController = navigationController {
            UIView.animate(withDuration: CATransaction.animationDuration()) {
                navigationController.navigationBar.alpha = 1
                self.pdfThumbnailViewContainer.alpha = 1
                self.titleLabelContainer.alpha = 1
                self.pageNumberLabelContainer.alpha = 1
            }
        }
    }

    private func hideBars() {
        if let navigationController = navigationController {
            UIView.animate(withDuration: CATransaction.animationDuration()) {
                navigationController.navigationBar.alpha = 0
                self.pdfThumbnailViewContainer.alpha = 0
                self.titleLabelContainer.alpha = 0
                self.pageNumberLabelContainer.alpha = 0
            }
        }
    }
}

class PDFViewGestureRecognizer: UIGestureRecognizer {
    var isTracking = false

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = true
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        isTracking = false
    }
}
