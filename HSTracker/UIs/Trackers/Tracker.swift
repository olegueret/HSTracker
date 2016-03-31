/*
* This file is part of the HSTracker package.
* (c) Benjamin Michotte <bmichotte@gmail.com>
*
* For the full copyright and license information, please view the LICENSE
* file that was distributed with this source code.
*
* Created on 15/02/16.
*/

import Cocoa

enum HandCountPosition: Int {
    case Tracker,
    Window
}

class Tracker: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, CardCellHover {
    @IBOutlet weak var scrollView: NSScrollView!
    
    @IBOutlet weak var table: NSTableView!
    
    @IBOutlet weak var cardCounter: CardCounter!
    @IBOutlet weak var playerDrawChance: PlayerDrawChance!
    @IBOutlet weak var opponentDrawChance: OpponentDrawChance!
    
    var heroCard: Card?
    var animatedCards = [CardCellView]()
    var player: Player?
    var playerType: PlayerType?
    private var cellsCache = [String: NSView]()
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        let center = NSNotificationCenter.defaultCenter()
        let observers = [
            "hearthstone_running": #selector(Tracker.hearthstoneRunning(_:)),
            "hearthstone_active": #selector(Tracker.hearthstoneActive(_:)),
            "tracker_opacity": #selector(Tracker.opacityChange(_:)),
            "card_size": #selector(Tracker.cardSizeChange(_:)),
            "window_locked": #selector(Tracker.windowLockedChange(_:)),
        ]
        
        for (name, selector) in observers {
            center.addObserver(self,
                               selector: selector,
                               name: name,
                               object: nil)
        }
        
        let options = ["show_opponent_draw", "show_opponent_mulligan", "show_opponent_play",
            "show_player_draw", "show_player_mulligan", "show_player_play", "rarity_colors",
            "remove_cards_from_deck", "highlight_last_drawn", "highlight_cards_in_hand",
            "highlight_discarded", "show_player_get"]
        for option in options {
            center.addObserver(self,
                               selector: #selector(Tracker.trackerOptionsChange(_:)),
                               name: option,
                               object: nil)
        }
        
        let frames = [ "player_draw_chance", "player_card_count", "opponent_card_count", "opponent_draw_chance"]
        for name in frames {
            center.addObserver(self,
                               selector: #selector(Tracker.frameOptionsChange(_:)),
                               name: name,
                               object: nil)
        }
        
        self.window!.opaque = false
        self.window!.hasShadow = false
        
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.backgroundColor = NSColor.clearColor()
        table.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
        
        setWindowSizes()
        _setOpacity()
        _windowLockedChange()
        _hearthstoneRunning(true)
        _frameOptionsChange()
        
        table.reloadData()
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - NSWindowDelegate
    func windowDidResize(notification: NSNotification) {
        _frameOptionsChange()
    }
    
    // MARK: - Notifications
    func windowLockedChange(notification: NSNotification) {
        _windowLockedChange()
    }
    private func _windowLockedChange() {
        let locked = Settings.instance.windowsLocked
        if locked {
            self.window!.styleMask = NSBorderlessWindowMask
        } else {
            self.window!.styleMask = NSTitledWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSBorderlessWindowMask
        }
        self.window!.ignoresMouseEvents = locked
    }
    
    func hearthstoneRunning(notification: NSNotification) {
        _hearthstoneRunning(false)
    }
    private func _hearthstoneRunning(forceActive: Bool) {
        let hs = Hearthstone.instance
        
        if hs.isHearthstoneRunning && (forceActive || hs.hearthstoneActive) {
            self.window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.ScreenSaverWindowLevelKey))
        }
        else {
            self.window!.level = Int(CGWindowLevelForKey(CGWindowLevelKey.NormalWindowLevelKey))
        }
    }
    
    func hearthstoneActive(notification: NSNotification) {
        _windowLockedChange()
        _hearthstoneRunning(false)
    }
    
    func trackerOptionsChange(notification: NSNotification) {
        self.table.reloadData()
    }
    
    func cardSizeChange(notification: NSNotification) {
        self.table.reloadData()
        setWindowSizes()
    }
    
    func setWindowSizes() {
        var width: Double
        let settings = Settings.instance
        switch settings.cardSize {
        case .Small:
            width = kSmallFrameWidth
            
        case .Medium:
            width = kMediumFrameWidth
            
        default:
            width = kFrameWidth
        }
        
        self.window!.setFrame(NSMakeRect(0, 0, CGFloat(width), 200), display: true)
        self.window!.contentMinSize = NSMakeSize(CGFloat(width), 200)
        self.window!.contentMaxSize = NSMakeSize(CGFloat(width), NSHeight(NSScreen.mainScreen()!.frame))
    }
    
    func opacityChange(notification: NSNotification) {
        _setOpacity()
    }
    private func _setOpacity() {
        self.window!.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: CGFloat(Settings.instance.trackerOpacity / 100.0))
    }
    
    func frameOptionsChange(notification: NSNotification) {
        _frameOptionsChange()
    }
    
    private func _frameOptionsChange() {
        let settings = Settings.instance
        
        guard let windowFrame = self.window?.contentView?.frame else { return }
        let width = NSWidth(windowFrame)
        
        let ratio: CGFloat
        switch Settings.instance.cardSize {
        case .Small: ratio = CGFloat(kRowHeight / kSmallRowHeight)
        case .Medium: ratio = CGFloat(kRowHeight / kMediumRowHeight)
        default: ratio = 1.0
        }
        var y: CGFloat = 0
        
        if playerType == .Opponent {
            cardCounter.hidden = !settings.showOpponentCardCount
            opponentDrawChance.hidden = !settings.showOpponentDrawChance
            playerDrawChance.hidden = true
            
            if !opponentDrawChance.hidden {
                opponentDrawChance.frame = NSMakeRect(0, 0, width, 71 / ratio)
                y += NSHeight(opponentDrawChance.frame)
            }
            if !cardCounter.hidden {
                cardCounter.frame = NSMakeRect(0, y, width, 40 / ratio)
                y += NSHeight(cardCounter.frame)
            }
        }
        else {
            cardCounter.hidden = !settings.showPlayerCardCount
            opponentDrawChance.hidden = true
            playerDrawChance.hidden = !settings.showPlayerDrawChance
            
            if !playerDrawChance.hidden {
                playerDrawChance.frame = NSMakeRect(0, 0, width, 40 / ratio)
                y += NSHeight(playerDrawChance.frame)
            }
            if !cardCounter.hidden {
                cardCounter.frame = NSMakeRect(0, y, width, 40 / ratio)
                y += NSHeight(cardCounter.frame)
            }
        }
        
        scrollView.frame = NSMakeRect(0, y, width, NSHeight(windowFrame) - y)
    }
    
    // MARK: - Game
    func update(cards: [Card], _ reset: Bool = false) {
        guard let _ = self.table else { return }
        
        if reset {
            cellsCache.removeAll()
            animatedCards.removeAll()
        }
        
        var newCards = [Card]()
        cards.forEach({ (card: Card) in
            let existing = animatedCards.firstWhere({ self.areEqualForList($0.card!, card) })
            if existing == nil {
                newCards.append(card)
            }
            else if existing!.card!.count != card.count || existing!.card!.highlightInHand != card.highlightInHand {
                let highlight = existing!.card!.count != card.count
                existing!.card!.count = card.count
                existing!.card!.highlightInHand = card.highlightInHand
                existing!.update(highlight)
            }
            else if existing!.card!.isCreated != card.isCreated {
                existing!.update(false)
            }
        })

        var toUpdate = [CardCellView]()
        animatedCards.forEach({ (c: CardCellView) in
            if !cards.any({ self.areEqualForList($0, c.card!) }) {
                toUpdate.append(c)
            }
        })
        var toRemove:[CardCellView: Bool] = [:]
        toUpdate.forEach { (card: CardCellView) in
            let newCard = newCards.firstWhere({ $0.id == card.card!.id })
            toRemove[card] = newCard == nil
            if newCard != nil {
                let newAnimated = CardCellView()
                newAnimated.playerType = self.playerType
                newAnimated.setDelegate(self)
                newAnimated.card = newCard
                
                let index = cards.indexOf(newCard!)!
                animatedCards.insert(newAnimated, atIndex: index)
                newAnimated.update(true)
                newCards.remove(newCard!)
            }
        }
        for (cardCellView, fadeOut) in toRemove {
            removeCard(cardCellView, fadeOut)
        }
        newCards.forEach({
            let newCard = CardCellView()
            newCard.playerType = self.playerType
            newCard.setDelegate(self)
            newCard.card = $0
            let index = cards.indexOf($0)!
            animatedCards.insert(newCard, atIndex: index)
            newCard.fadeIn(!reset)
        })
        
        table.beginUpdates()
        table.reloadData()
        table.endUpdates()
        
        setCardCount()
    }
    
    func setCardCount() {
        let gameStarted = !Game.instance.isInMenu && Game.instance.entities.count >= 67
        let deckCount = !gameStarted || player == nil ? 30 : player!.deckCount
        let handCount = !gameStarted || player == nil ? 0 : player!.handCount
        
        cardCounter.deckCount = deckCount
        cardCounter.handCount = handCount
        cardCounter.layer?.setNeedsDisplay()
        
        if playerType == .Opponent {
            var draw1 = 0.0, draw2 = 0.0, hand1 = 0.0, hand2 = 0.0
            if deckCount > 0 {
                draw1 = (1 * 100.0) / Double(deckCount)
                draw2 = (2 * 100.0) / Double(deckCount)
            }
            if handCount > 0 {
                hand1 = (1 * 100.0) / Double(handCount)
                hand2 = (2 * 100.0) / Double(handCount)
            }
            opponentDrawChance.drawChance1 = draw1
            opponentDrawChance.drawChance2 = draw2
            opponentDrawChance.handChance1 = hand1
            opponentDrawChance.handChance2 = hand2
            opponentDrawChance.layer?.setNeedsDisplay()
        }
        else {
            var draw1 = 0.0, draw2 = 0.0
            if deckCount > 0 {
                draw1 = (1 * 100.0) / Double(deckCount)
                draw2 = (2 * 100.0) / Double(deckCount)
            }
            
            playerDrawChance.drawChance1 = draw1
            playerDrawChance.drawChance2 = draw2
            playerDrawChance.layer?.setNeedsDisplay()
        }
    }
    
    private func removeCard(card:CardCellView, _ fadeOut: Bool) {
        if fadeOut {
            card.fadeOut(card.card!.count > 0)
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(600 * Double(NSEC_PER_MSEC)))
            let queue = dispatch_get_main_queue()
            dispatch_after(when, queue) {
                self.animatedCards.remove(card)
            }
        }
        else {
            animatedCards.remove(card)
        }
    }
    
    private func areEqualForList(c1: Card, _ c2: Card) -> Bool {
        return c1.id == c2.id && c1.jousted == c2.jousted && c1.isCreated == c2.isCreated
            && (!Settings.instance.highlightDiscarded || c1.wasDiscarded == c2.wasDiscarded)
    }
    
    // MARK: - NSTableViewDelegate / NSTableViewDataSource
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return animatedCards.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        return animatedCards[row]
    }
    
    func tableView(tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        switch Settings.instance.cardSize {
        case .Small:
            return CGFloat(kSmallRowHeight)
            
        case .Medium:
            return CGFloat(kMediumRowHeight)
            
        default:
            return CGFloat(kRowHeight)
        }
    }
    
    func selectionShouldChangeInTableView(tableView: NSTableView) -> Bool {
        return false;
    }
    
    // MARK: - CardCellHover
    func hover(card: Card) {
        // DDLogInfo("hovering \(card)")
    }
    
    func out(card: Card) {
        // DDLogInfo(@"out \(card)")
    }
}
