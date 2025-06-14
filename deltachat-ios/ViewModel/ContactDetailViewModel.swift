import UIKit
import DcCore

class ContactDetailViewModel {

    let context: DcContext

    enum ProfileSections {
        case chatOptions
        case statusArea
        case sharedChats
        case chatActions
    }

    enum ChatOption {
        case verifiedBy
        case allMedia
        case locations
        case ephemeralMessages
        case shareContact
        case startChat
    }

    enum ChatAction {
        case addToHomescreen
     //   case archiveChat
        case showEncrInfo
        case blockContact
        case clearChat
        case deleteChat
    }

    var contactId: Int

    // TODO: check if that is too inefficient (each bit read from contact, results in a database-query)
    var contact: DcContact {
        return context.getContact(id: contactId)
    }

    let chatId: Int
    let isSavedMessages: Bool
    let isDeviceTalk: Bool
    let isBot: Bool
    let greenCheckmark: Bool
    var lastSeen: Int64
    private var sharedChats: DcChatlist
    private var sections: [ProfileSections] = []
    private var chatActions: [ChatAction] = []
    private var chatOptions: [ChatOption] = []

    init(dcContext: DcContext, contactId: Int) {
        self.context = dcContext
        self.contactId = contactId
        self.chatId = dcContext.getChatIdByContactId(contactId: contactId)
        let dcContact = context.getContact(id: contactId)
        if chatId != 0 {
            let dcChat = dcContext.getChat(chatId: chatId)
            isSavedMessages = dcChat.isSelfTalk
            isDeviceTalk = dcChat.isDeviceTalk
            greenCheckmark = dcChat.isProtected
        } else {
            isSavedMessages = false
            isDeviceTalk = false
            greenCheckmark = dcContact.isVerified
        }
        self.isBot = dcContact.isBot
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)

        sections.append(.chatOptions)

        self.lastSeen = dcContact.lastSeen

        if self.isSavedMessages || !dcContact.status.isEmpty {
            sections.append(.statusArea)
        }

        if sharedChats.length > 0 && !isSavedMessages && !isDeviceTalk {
            sections.append(.sharedChats)
        }
        sections.append(.chatActions)

        chatOptions = []
        if dcContact.getVerifierId() != 0 {
            chatOptions.append(.verifiedBy)
        }

        var chatActions: [ChatAction]
        let chatExists = chatId != 0
        if chatExists {
            chatOptions.append(.allMedia)
            if UserDefaults.standard.bool(forKey: "location_streaming") {
                chatOptions.append(.locations)
            }

            if !isDeviceTalk {
                chatOptions.append(.ephemeralMessages)
            }

            if !isSavedMessages && !isDeviceTalk {
                chatOptions.append(.startChat)
                chatOptions.append(.shareContact)
            }

            chatActions = []
            if #available(iOS 17, *) {
                chatActions.append(.addToHomescreen)
            }
            if !isDeviceTalk && !isSavedMessages {
                chatActions.append(.showEncrInfo)
                chatActions.append(.blockContact)
            }
            chatActions.append(.clearChat)
            chatActions.append(.deleteChat)
        } else {
            chatOptions.append(.startChat)
            chatOptions.append(.shareContact)
            chatActions = [.showEncrInfo, .blockContact]
        }

        self.chatActions = chatActions
    }

    func typeFor(section: Int) -> ContactDetailViewModel.ProfileSections {
        return sections[section]
    }

    func chatActionFor(row: Int) -> ContactDetailViewModel.ChatAction {
        return chatActions[row]
    }

    func chatOptionFor(row: Int) -> ContactDetailViewModel.ChatOption {
        return chatOptions[row]
    }

    var chatIsArchived: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).isArchived
    }

    var chatCanSend: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).canSend
    }

    var chatIsMuted: Bool {
        return chatId != 0 && context.getChat(chatId: chatId).isMuted
    }

    var chatIsEphemeral: Bool {
        return chatId != 0 && context.getChatEphemeralTimer(chatId: chatId) > 0
    }

    var numberOfSections: Int {
        return sections.count
    }

    func numberOfRowsInSection(_ section: Int) -> Int {
        switch sections[section] {
        case .chatOptions: return chatOptions.count
        case .statusArea: return 1
        case .sharedChats: return sharedChats.length
        case .chatActions: return chatActions.count
        }
    }

    func getSharedChatIdAt(indexPath: IndexPath) -> Int {
        let index = indexPath.row
        return sharedChats.getChatId(index: index)
    }

    func getSharedChatIds() -> [Int] {
        let max = sharedChats.length
        var chatIds: [Int] = []
        for n in 0..<max {
            chatIds.append(sharedChats.getChatId(index: n))
        }
        return chatIds
    }

    func updateSharedChats() {
        self.sharedChats = context.getChatlist(flags: 0, queryString: nil, queryId: contactId)
    }

    func update(sharedChatCell cell: ContactCell, row index: Int) {
        let chatId = sharedChats.getChatId(index: index)
        let summary = sharedChats.getSummary(index: index)
        let unreadMessages = context.getUnreadMessages(chatId: chatId)
        let cellData = ChatCellData(chatId: chatId, highlightMsgId: nil, summary: summary, unreadMessages: unreadMessages)
        let cellViewModel = ChatCellViewModel(dcContext: context, chatData: cellData)
        cell.updateCell(cellViewModel: cellViewModel)
    }

    func titleFor(section: Int) -> String? {
        switch sections[section] {
        case .statusArea: return (isSavedMessages || isDeviceTalk) ? nil : String.localized("pref_default_status_label")
        case .sharedChats: return String.localized("profile_shared_chats")
        case .chatOptions, .chatActions: return nil
        }
    }

    func footerFor(section: Int) -> String? {
        switch sections[section] {
        case .chatOptions:
            if isSavedMessages || isDeviceTalk {
                return nil
            } else if lastSeen == 0 {
                return String.localized("last_seen_unknown")
            } else {
                return String.localizedStringWithFormat(String.localized("last_seen_at"), DateUtils.getExtendedAbsTimeSpanString(timeStamp: Double(lastSeen)))
            }
        case .statusArea, .sharedChats, .chatActions: return nil
        }
    }

    // returns true if chat is archived after action
//    func toggleArchiveChat() -> Bool {
//        if chatId == 0 {
//            safe_fatalError("there is no chatId - you are probably are calling this from ContactDetail - this should be only called from ChatDetail")
//            return false
//        }
//        let isArchivedBefore = chatIsArchived
//        if !isArchivedBefore {
//            NotificationManager.removeNotificationsForChat(dcContext: context, chatId: chatId)
//        }
//        context.archiveChat(chatId: chatId, archive: !isArchivedBefore)
//        return chatIsArchived
//    }

    public func blockContact() {
        context.blockContact(id: contact.id)
    }

    public func unblockContact() {
        context.unblockContact(id: contact.id)
    }

    @available(iOS 17, *)
    func toggleChatInHomescreenWidget() -> Bool {
        guard let userDefaults = UserDefaults.shared else { return false }
        let allHomescreenChatsIds: [Int] = userDefaults
            .getChatWidgetEntries()
            .compactMap { entry in
                switch entry.type {
                case .app: return nil
                case .chat(let chatId): return chatId
                }
            }

        if allHomescreenChatsIds.contains(chatId) {
            userDefaults.removeChatFromHomescreenWidget(accountId: context.id, chatId: chatId)
            return false
        } else {
            userDefaults.addChatToHomescreenWidget(accountId: context.id, chatId: chatId)
            return true
        }
    }
}
