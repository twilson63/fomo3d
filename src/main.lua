-- Constants
local GAME_TIME = 1000 * 60 * 15 -- 15 minutes game time in milliseconds
local TOKEN_ADDR = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc" -- Testnet cred token contract

-- Game state
local GameState = {
    Treasury = 0,  -- The balance of testnet cred in the round
    Timeout = 0,   -- The time when the game ends
    LastSender = nil, -- State of the last sender
}

-- Resets the game to its initial state
local function resetGameState(timestamp)
    GameState.Treasury = 0
    GameState.Timeout = timestamp + GAME_TIME
    GameState.LastSender = nil
    print('New game started! Timeout: ' .. GameState.Timeout)
end

-- Handles the start of the game
local function handleStart(m)
    if m.From == ao.id then
        resetGameState(m.Timestamp)
    end
end

-- Processes a buy action
local function handleBuy(m)
    if m.Timestamp >= GameState.Timeout then
        if GameState.LastSender then
            print(GameState.LastSender .. " won the game! Dispatching " .. GameState.Treasury .. " tokenz...")
            ao.send({
                Target = TOKEN_ADDR,
                Action = "Transfer",
                Recipient = GameState.LastSender,
                Quantity = GameState.Treasury
            })
        end
        resetGameState(m.Timestamp)
        return
    end

    GameState.LastSender = m.From
    GameState.Treasury = GameState.Treasury + m.Quantity
    GameState.Timeout = m.Timestamp + GAME_TIME
    local TimeRemaining = (GameState.Timeout - m.Timestamp) // 1000
    print('Game continues! Current balance: ' .. GameState.Treasury .. '. Leader: ' .. GameState.LastSender .. '. Remaining time (secs): ' .. TimeRemaining)
end

-- Checks if the game should end
local function checkGameEnd(m)
    if m.Timestamp >= GameState.Timeout and GameState.LastSender then
        print(GameState.LastSender .. " won the game! Dispatching " .. GameState.Treasury .. " tokenz...")
        ao.send({
            Target = TOKEN_ADDR,
            Action = "Transfer",
            Recipient = GameState.LastSender,
            Quantity = GameState.Treasury
        })
        resetGameState(m.Timestamp)
    else
        local TimeRemaining = (GameState.Timeout - m.Timestamp) // 1000
        print('Game continues! Current balance: ' .. GameState.Treasury .. '. Leader: ' .. GameState.LastSender .. '. Remaining time (secs): ' .. TimeRemaining)
    end
end

-- Sends game info to the requester
local function sendGameInfo(m)
    Send({
        Target = m.From,
        Data =
            "WELCOME TO THE ARENA.\n" ..
            "Send me $CRED and I will reset the timer for 15 mins.\n" ..
            "Last person to send me tokens when timer gets to zero gets all.\n"
    })
end


Handlers.add("Start", function(m) return m.From == ao.id end, handleStart)
Handlers.add("Buy", function(m) return m.From == TOKEN_ADDR and m.Action == "Credit-Notice" and tonumber(m.Quantity) > 1 end, handleBuy)
Handlers.add("what-is-it", Handlers.utils.hasMatchingTag("Action", "Info", "info", "action"), sendGameInfo)
Handlers.add("cron-handler", function(m) return m.Action == "Cron" end, checkGameEnd)
