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
-- === アプリケーションに応じたホットキーの有効/無効化 ===
-- =============================================================================
-- iTerm2のような特定のアプリケーションでは、これらのカスタムホットキーが
-- 本来持つ意味で使われるため、無効化します。

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

-- 最前面のアプリケーションに応じてホットキーを有効/無効にするためのウォッチャー
local function handleGlobalAppEvent(appName, eventType, appObject)
	if eventType == hs.application.watcher.activated then
		if
			appName == "iTerm2"
			or appName == "WezTerm"
			or appName == "kitty"
			or appName == "Alacritty"
			or appName == "Hyper"
			or appName == "Terminal"
		then
			disableManagedHotkeys()
		else
			enableManagedHotkeys()
		end
	end
end

local appWatcher = hs.application.watcher.new(handleGlobalAppEvent)
appWatcher:start()

-- =============================================================================
-- === Emacs風キーリマップ設定 ===
-- =============================================================================

-- カーソル移動
createManagedHotkey({ "ctrl" }, "f", keyCode("right")) -- Forward:  カーソルを右へ
createManagedHotkey({ "ctrl" }, "b", keyCode("left")) -- Backward: カーソルを左へ
createManagedHotkey({ "ctrl" }, "p", keyCode("up")) -- Previous: カーソルを上へ
createManagedHotkey({ "ctrl" }, "n", keyCode("down")) -- Next:     カーソルを下へ
createManagedHotkey({ "ctrl" }, "a", keyCode("left", { "cmd" })) -- Ahead:    行頭へ移動
createManagedHotkey({ "ctrl" }, "e", keyCode("right", { "cmd" })) -- End:      行末へ移動

-- テキスト削除
createManagedHotkey({ "ctrl" }, "h", keyCode("delete")) -- Backspace: カーソル前の文字を削除
createManagedHotkey({ "ctrl" }, "d", keyCode("forwarddelete")) -- Delete: カーソル後の文字を削除

-- "kill line" (カーソル位置から行末まで削除) のための特別関数
local function killLine()
	-- 1. Shift+Cmd+Right で行末までを選択
	hs.eventtap.event.newKeyEvent({ "shift", "cmd" }, "right", true):post()
	hs.timer.usleep(1000)
	hs.eventtap.event.newKeyEvent({ "shift", "cmd" }, "right", false):post()
	hs.timer.usleep(1000)
	-- 2. Deleteキーで選択範囲を削除 (クリップボードには残らない)
	hs.eventtap.event.newKeyEvent({}, "delete", true):post()
	hs.timer.usleep(1000)
	hs.eventtap.event.newKeyEvent({}, "delete", false):post()
end
createManagedHotkey({ "ctrl" }, "k", killLine)

-- =============================================================================
-- === 初期状態の設定 ===
-- =============================================================================
-- Hammerspoonの起動時またはリロード時に、現在アクティブなアプリの状態をチェックする
local function setInitialState()
    local currentApp = hs.application.frontmostApplication()
    if currentApp then
        handleGlobalAppEvent(currentApp:name(), hs.application.watcher.activated, currentApp)
    end
end

setInitialState()

-- 設定がリロードされたことを通知
hs.alert.show("Hammerspoon: Emacsキーバインドが読み込まれました")
