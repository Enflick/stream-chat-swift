//
// Copyright © 2025 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChat
import StreamChatUI
import UIKit
import UserNotifications

final class StreamChatWrapper {
    static var shared = StreamChatWrapper(apiKeyString: apiKeyString)

    static func replaceSharedInstance(apiKeyString: String) {
        StreamChatWrapper.shared = StreamChatWrapper(apiKeyString: apiKeyString)
    }

    /// How many times the token has been refreshed. This is mostly used
    /// to fake token refresh fails.
    var numberOfRefreshTokens = 0

    // This closure is called once the SDK is ready to register for remote push notifications
    static var onRemotePushRegistration: (() -> Void)?

    // Chat client
    var client: ChatClient?

    // ChatClient config
    var config: ChatClientConfig {
        didSet {
            client = ChatClient(config: config)
        }
    }

    init(apiKeyString: String) {
        config = ChatClientConfig(apiKeyString: apiKeyString)
        config.shouldShowShadowedMessages = true
        config.applicationGroupIdentifier = applicationGroupIdentifier
        config.urlSessionConfiguration.httpAdditionalHeaders = ["Custom": "Example"]

        let apiKey = DemoApiKeys(rawValue: apiKeyString)
        if let baseURL = apiKey.customBaseURL {
            config.baseURL = .init(url: baseURL)
        }
        // Uncomment this to test model transformers
        // config.modelsTransformer = CustomStreamModelsTransformer()
        configureUI()
    }
}

extension StreamChatWrapper {
    // Client not instantiated
    private func logClientNotInstantiated() {
        guard client != nil else {
            print("⚠️ Chat client is not instantiated")
            return
        }
    }
}

// MARK: User Authentication

extension StreamChatWrapper {
    func connect(user: DemoUserType, completion: @escaping (Error?) -> Void) {
        switch user {
        case let .credentials(userCredentials):
            connectUser(credentials: userCredentials, completion: completion)
        case let .custom(userCredentials):
            connectUser(credentials: userCredentials, completion: completion)
        case let .guest(userId):
            client?.connectGuestUser(userInfo: .init(id: userId), completion: completion)
        case .anonymous:
            client?.connectAnonymousUser(completion: completion)
        }
    }

    func connectUser(credentials: UserCredentials?, completion: @escaping (Error?) -> Void) {
        guard let userCredentials = credentials else {
            log.error("User credentials are missing")
            return
        }

        var privacySettings: UserPrivacySettings?

        if UserConfig.shared.readReceiptsEnabled != nil || UserConfig.shared.typingIndicatorsEnabled != nil {
            privacySettings = .init()
        }
        if let readReceiptsEnabled = UserConfig.shared.readReceiptsEnabled {
            privacySettings?.readReceipts = .init(enabled: readReceiptsEnabled)
        }
        if let typingIndicatorsEnabled = UserConfig.shared.typingIndicatorsEnabled {
            privacySettings?.typingIndicators = .init(enabled: typingIndicatorsEnabled)
        }

        let userInfo = UserInfo(
            id: userCredentials.userInfo.id,
            name: userCredentials.userInfo.name,
            imageURL: userCredentials.userInfo.imageURL,
            isInvisible: UserConfig.shared.isInvisible,
            language: UserConfig.shared.language,
            privacySettings: privacySettings,
            extraData: userCredentials.userInfo.extraData
        )

        if let tokenRefreshDetails = AppConfig.shared.demoAppConfig.tokenRefreshDetails {
            client?.connectUser(
                userInfo: userInfo,
                tokenProvider: refreshingTokenProvider(
                    initialToken: userCredentials.token,
                    refreshDetails: tokenRefreshDetails
                ),
                completion: completion
            )
            return
        }

        client?.connectUser(
            userInfo: userInfo,
            token: userCredentials.token,
            completion: completion
        )
    }

    func logIn(as user: DemoUserType, completion: @escaping (Error?) -> Void) {
        // Setup Stream Chat
        setUpChat()

        // Reset number of refresh tokens
        numberOfRefreshTokens = 0

        connect(user: user) { error in
            if let error = error {
                log.warning(error.localizedDescription)
            } else {
                StreamChatWrapper.onRemotePushRegistration?()
            }

            DispatchQueue.main.async {
                completion(error)
            }
        }
    }

    func logOut(completion: @escaping () -> Void) {
        guard let client = self.client else {
            logClientNotInstantiated()
            return
        }

        client.logout(completion: completion)
    }
}

// MARK: Controllers

extension StreamChatWrapper {
    func channelController(for channelId: ChannelId?) -> ChatChannelController? {
        guard let client = self.client else {
            logClientNotInstantiated()
            return nil
        }
        return channelId.map { client.channelController(for: $0) }
    }

    func channelListController(query: ChannelListQuery) -> ChatChannelListController? {
        client?.channelListController(query: query)
    }

    func messageController(cid: ChannelId, messageId: MessageId) -> ChatMessageController? {
        client?.messageController(cid: cid, messageId: messageId)
    }
}

// MARK: - Push Notifications

extension StreamChatWrapper {
    func registerForPushNotifications(with deviceToken: Data) {
        client?.currentUserController().addDevice(.apn(token: deviceToken, providerName: Bundle.pushProviderName)) {
            if let error = $0 {
                log.error("adding a device failed with an error \(error)")
            }
        }
    }

    func notificationInfo(for response: UNNotificationResponse) -> ChatPushNotificationInfo? {
        try? ChatPushNotificationInfo(content: response.notification.request.content)
    }
}

// MARK: - Stream Models Transformer

// An object to test the Stream Models transformer.
// By default it is not used. To use it, set it to the `modelsTransformer` property of the `ChatClientConfig`.

class CustomStreamModelsTransformer: StreamModelsTransformer {
    func transform(channel: ChatChannel) -> ChatChannel {
        channel.replacing(
            name: "Custom Name",
            imageURL: channel.imageURL,
            extraData: channel.extraData
        )
    }

    func transform(message: ChatMessage) -> ChatMessage {
        message.replacing(
            text: "Hey!",
            extraData: message.extraData,
            attachments: message.allAttachments
        )
    }

    func transform(newMessageInfo: NewMessageTransformableInfo) -> NewMessageTransformableInfo {
        newMessageInfo.replacing(
            text: "Changed!",
            attachments: newMessageInfo.attachments,
            extraData: newMessageInfo.extraData
        )
    }

    func transform(member: ChatChannelMember) -> ChatChannelMember {
        member.replacing(
            name: "Changed Name",
            imageURL: member.imageURL,
            userExtraData: member.extraData,
            memberExtraData: member.memberExtraData
        )
    }
}
