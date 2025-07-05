-- =============================================================================
-- === ユーティリティ関数 ===
-- =============================================================================

-- キー押下イベントをシミュレートする関数を生成する
local function keyCode(key, modifiers)
	modifiers = modifiers or {}
	return function()
		hs.eventtap.event.newKeyEvent(modifiers, string.lower(key), true):post()
		hs.timer.usleep(1000)
		hs.eventtap.event.newKeyEvent(modifiers, string.lower(key), false):post()
	end
end

-- =============================================================================
-- === ホットキー管理 ===
-- =============================================================================
-- このスクリプトで作成したホットキーのみを管理するためのテーブル
local managedHotkeys = {}

-- ホットキーを作成し、管理テーブルに追加するヘルパー関数
local function createManagedHotkey(modifiers, key, callback)
    local hotkey = hs.hotkey.bind(modifiers, key, callback, nil, callback)
    table.insert(managedHotkeys, hotkey)
end

-- =============================================================================
-- === アプリケーションに応じたホットキーの有効/無効化 (改善版) ===
-- =============================================================================

-- ホットキーを無効化したいアプリケーションのバンドルIDリスト
local blacklistedBundleIDs = {
  ["com.googlecode.iterm2"] = true,
  ["com.github.wez.wezterm"] = true,
  ["net.kovidgoyal.kitty"] = true,
  ["io.alacritty"] = true,
  ["co.zeit.hyper"] = true,
  ["com.apple.Terminal"] = true,
}

local function disableManagedHotkeys()
	for _, hotkey in ipairs(managedHotkeys) do
		hotkey:disable()
	end
end

local function enableManagedHotkeys()
	for _, hotkey in ipairs(managedHotkeys) do
		hotkey:enable()
	end
end

-- --- ★★★ 変更点：デバウンス処理の導入 ★★★ ---
-- アプリケーション切り替えのイベントが連続で発生しても、最後のものだけを処理するためのタイマー
local appSwitchTimer = hs.timer.new(0.2, function()
    local app = hs.application.frontmostApplication()
    if app then
        local bundleID = app:bundleID()
        if blacklistedBundleIDs[bundleID] then
            disableManagedHotkeys()
        else
            enableManagedHotkeys()
        end
    end
end)

-- 最前面のアプリケーションが変更されたときに呼び出されるウォッチャー
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        -- イベントが発生するたびにタイマーをリセットして再開する（デバウンス）
        appSwitchTimer:start()
    end
end)
appWatcher:start()


-- =============================================================================
-- === Emacs風キーリマップ設定 ===
-- =============================================================================

-- カーソル移動
createManagedHotkey({ "ctrl" }, "f", keyCode("right"))
createManagedHotkey({ "ctrl" }, "b", keyCode("left"))
createManagedHotkey({ "ctrl" }, "p", keyCode("up"))
createManagedHotkey({ "ctrl" }, "n", keyCode("down"))
createManagedHotkey({ "ctrl" }, "a", keyCode("left", { "cmd" }))
createManagedHotkey({ "ctrl" }, "e", keyCode("right", { "cmd" }))

-- テキスト削除
createManagedHotkey({ "ctrl" }, "h", keyCode("delete"))
createManagedHotkey({ "ctrl" }, "d", keyCode("forwarddelete"))

-- "kill line"
local function killLine()
	hs.eventtap.event.newKeyEvent({ "shift", "cmd" }, "right", true):post()
	hs.timer.usleep(1000)
	hs.eventtap.event.newKeyEvent({ "shift", "cmd" }, "right", false):post()
	hs.timer.usleep(1000)
	hs.eventtap.event.newKeyEvent({}, "delete", true):post()
	hs.timer.usleep(1000)
	hs.eventtap.event.newKeyEvent({}, "delete", false):post()
end
createManagedHotkey({ "ctrl" }, "k", killLine)

-- =============================================================================
-- === 初期状態の設定 ===
-- =============================================================================
-- Hammerspoonの起動時またはリロード時に、現在の状態を正しく反映させる
local function setInitialState()
    -- タイマーを一度トリガーして現在の状態をチェックさせる
    appSwitchTimer:start()
end

setInitialState()

-- 設定がリロードされたことを通知
hs.alert.show("Hammerspoon: Emacsキーバインドが読み込まれました (安定版)")
