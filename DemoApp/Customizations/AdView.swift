//
// Copyright © 2025 Stream.io Inc. All rights reserved.
//

import StreamChat
import StreamChatUI
import UIKit

class AdView: UIView {

    var content: ChatMessageLinkAttachment? {
        didSet {
            if let content {
                label.text = content.title
                if content.originalURL.host == "www.textnow.com" {
                    self.removeFromSuperview()
                }
            }
        }
    }

    lazy var adViewItself: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "not a link"
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        adViewItself.backgroundColor = .green
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        adViewItself.backgroundColor = .red
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        addSubview(adViewItself)
        adViewItself.addSubview(label)
        NSLayoutConstraint.activate([
            adViewItself.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            adViewItself.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            adViewItself.topAnchor.constraint(equalTo: self.topAnchor),
            adViewItself.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            adViewItself.heightAnchor.constraint(equalToConstant: 55.0),

            label.centerYAnchor.constraint(equalTo: adViewItself.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: adViewItself.leadingAnchor, constant: 8.0),
            label.trailingAnchor.constraint(equalTo: adViewItself.trailingAnchor, constant: -8.0),
        ])
    }
}

class AdViewInjector: AttachmentViewInjector {
    lazy var adView: AdView = {
        let adView = AdView()
        adView.translatesAutoresizingMaskIntoConstraints = false
        return adView
    }()

    override func contentViewDidLayout(options: ChatMessageLayoutOptions) {
        contentView.bubbleContentContainer.removeAllArrangedSubviews()
        contentView.bubbleContentContainer.insertArrangedSubview(adView, at: 0, respectsLayoutMargins: true)

        let constraint = adView.widthAnchor.constraint(equalTo: contentView.widthAnchor)
        constraint.priority = .defaultLow
        constraint.isActive = true
    }

    override func contentViewDidUpdateContent() {
        adView.content = attachments(payloadType: LinkAttachmentPayload.self).first
    }
}

class MyAttachmentViewCatalog: AttachmentViewCatalog {
    override class func attachmentViewInjectorClassFor(
        message: ChatMessage,
        components: Components
    ) -> AttachmentViewInjector.Type? {
        if !message.allAttachments.isEmpty {
            return AdViewInjector.self
        }

        return super.attachmentViewInjectorClassFor(message: message, components: components)
    }
}
