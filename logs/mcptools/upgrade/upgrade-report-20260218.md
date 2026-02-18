# MCP 升級建議報告

**專案**: che-xcode-mcp
**當前版本**: 0.2.0（GitHub Release）/ 0.1.0（原始碼內版本號未更新）
**分析時間**: 2026-02-18
**語言**: Swift

---

## 📦 依賴更新

### 狀態：全部最新

| 套件 | 當前版本 | 最新版本 | 狀態 |
|------|----------|----------|------|
| swift-sdk (MCP) | 0.10.2 | 0.10.2 | ✅ 最新 |
| swift-log | 1.10.1 | 1.10.1 | ✅ 最新 |
| swift-system | 1.6.4 | 1.6.4 | ✅ 最新 |
| eventsource | 1.3.0 | 1.3.0 | ✅ 最新 |

無需更新依賴。

---

## 🏗️ 結構優化

### 版本號不一致 🔴 高優先

v0.2.0 已發布到 GitHub Release，但原始碼內多處版本號仍為 0.1.0：

| 檔案 | 當前值 | 應更新為 |
|------|--------|----------|
| `Sources/CheXcodeMCP/Version.swift:5` | `"0.1.0"` | `"0.2.0"` |
| `mcpb/manifest.json:4` | `"0.1.0"` | `"0.2.0"` |
| `README.md:72` | `0.1.0` | `0.2.0` |
| `README.md` Version History | 缺少 0.2.0 條目 | 加入 |
| `CHANGELOG.md` | 缺少 0.2.0 條目 | 加入 |

### mcpb/server/ 目錄缺失 🟡 中優先

`mcpb/server/` 目錄不存在（無 binary）。`.gitattributes` 已設定 LFS tracking，但實際目錄未建立。

- 建議：下次 deploy 時由 `/mcp-tools:mcp-deploy` 自動建立

### 已具備

| 項目 | 狀態 |
|------|------|
| LICENSE (MIT) | ✅ |
| .gitattributes (LFS) | ✅ |
| mcpb/manifest.json | ✅ |
| mcpb/PRIVACY.md | ✅ |
| CHANGELOG.md | ✅（需更新） |
| README.md | ✅（需更新） |
| Tests/ | ✅（Placeholder） |

---

## ⚠️ 程式碼品質

### `try!` 使用 🟡 中優先

`Sources/CheXcodeMCP/Auth/JWTManager.swift` 有 2 處 `try!`：

| 行號 | 程式碼 | 風險評估 |
|------|--------|----------|
| 97 | `try! JSONSerialization.data(withJSONObject: header, options: .sortedKeys)` | 低風險 — header 是硬編碼的 `[String: String]`，不可能 throw |
| 109 | `try! JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)` | 低風險 — payload 是硬編碼的 `[String: Any]`，值都是基本型別 |

**結論**：雖然是 `try!`，但輸入完全受控，實際上不會 crash。可改為 `try` + `do-catch` 更安全，但優先級低。

### 單元測試缺失 🟢 低優先

`Tests/CheXcodeMCPTests/PlaceholderTests.swift` 只有 placeholder test。目前所有測試靠手動 MCP tool 呼叫驗證（test-report-20260218-fix.md 記錄了 35+ tools 測試結果）。

---

## ✨ 功能差距分析（Missing Tools）

### 完整 Tool 盤點（16 Managers, 91 Tools）

| Manager | 工具數 | 類型分布 |
|---------|--------|----------|
| TestFlight | 10 | 6 read, 3 write, 1 delete |
| Provisioning | 8 | 6 read, 2 write |
| Metadata | 7 | 4 read, 2 write, 1 read (phased release) |
| Users | 7 | 3 read, 2 write, 2 delete |
| Subscription | 7 | 4 read, 3 write |
| IAP | 6 | 2 read, 3 write, 1 delete |
| Review | 6 | 2 read, 3 write, 1 delete |
| Xcode Cloud | 6 | 5 read, 1 write |
| App | 5 | 4 read, 1 write |
| App Clips | 5 | 4 read, 1 write |
| Analytics | 5 | 4 read, 1 write |
| Game Center | 5 | 5 read |
| Pricing | 4 | 4 read |
| Performance | 4 | 4 read |
| Finance | 3 | 3 read |
| Organizer | 3 | 3 read |

---

### 🔴 高優先：Subscription Localizations（3 new tools）

**痛點**：上一個 session 要讀取/修改訂閱顯示名稱和說明時，必須寫 raw Python ASC API 呼叫。這是日常管理最常用的功能之一。

| 新工具 | 功能 | API Endpoint |
|--------|------|-------------|
| `subscription_list_localizations` | 列出訂閱的所有語言版本（名稱、說明） | `GET /v1/subscriptions/{id}/subscriptionLocalizations` |
| `subscription_update_localization` | 更新特定語言的名稱/說明 | `PATCH /v1/subscriptionLocalizations/{id}` |
| `subscription_create_localization` | 為訂閱新增一個語言版本 | `POST /v1/subscriptionLocalizations` |

**實作複雜度**：低 — 遵循現有 Manager 的 CRUD pattern，估計 ~150 行。

---

### 🟡 中優先：IAP Localizations（2 new tools）

**痛點**：和 Subscription Localizations 同理，IAP 的顯示名稱/說明也需要透過 localizations 端點管理。

| 新工具 | 功能 | API Endpoint |
|--------|------|-------------|
| `iap_list_localizations` | 列出 IAP 的所有語言版本 | `GET /v1/inAppPurchases/{id}/inAppPurchaseLocalizations` |
| `iap_update_localization` | 更新特定語言的名稱/說明 | `PATCH /v1/inAppPurchaseLocalizations/{id}` |

---

### 🟡 中優先：Subscription Pricing（2 new tools）

**痛點**：目前無法查看或管理訂閱在各地區的價格。

| 新工具 | 功能 | API Endpoint |
|--------|------|-------------|
| `subscription_list_prices` | 列出訂閱在各地區的價格 | `GET /v1/subscriptions/{id}/prices` |
| `subscription_list_price_points` | 列出可用的訂閱價格點 | `GET /v1/subscriptions/{id}/pricePoints` |

---

### 🟢 低優先：TestFlight What's New Localizations（已有 set_whats_new，但不完整）

目前 `testflight_set_whats_new` 只設定單一語言。可考慮：
- `testflight_list_build_localizations` — 列出 build 的所有語言版本
- 不急需，現有工具已能覆蓋基本需求

---

### 🟢 低優先：其他潛在功能

| 功能 | 說明 | 急迫性 |
|------|------|--------|
| `subscription_delete_localization` | 刪除特定語言版本 | 很少用 |
| `metadata_create_localization` | 新增 App Store 語言版本 | 少見需求 |
| App Store Screenshots | 截圖管理 | 極複雜，暫不考慮 |
| Offer Codes | 促銷碼管理 | 未來可能需要 |

---

## 🔗 Binary 一致性

| 位置 | 存在 | 備註 |
|------|------|------|
| mcpb/server/CheXcodeMCP | ❌ 不存在 | mcpb/server/ 目錄不存在 |
| ~/bin/CheXcodeMCP | ✅ | v0.2.0 binary（本 session deploy） |

- 建議：下次 deploy 時補建 mcpb/server/ 目錄

---

## 📋 建議執行計畫

### Phase A：版本號同步 ✅
1. [x] Version.swift → 0.2.0
2. [x] mcpb/manifest.json → 0.2.0
3. [x] README.md → 更新版本號 + Version History
4. [x] CHANGELOG.md → 加入 0.2.0 條目

### Phase B：新功能實作 ✅
5. [x] 加入 `subscription_list_localizations`
6. [x] 加入 `subscription_update_localization`
7. [x] 加入 `subscription_create_localization`
8. [x] 加入 `iap_list_localizations`
9. [x] 加入 `iap_update_localization`
10. [x] 加入 `subscription_list_prices`
11. [x] 加入 `subscription_list_price_points`

### Phase C：程式碼品質 ✅
12. [x] JWTManager.swift `try!` → `try` + error handling
13. [ ] 加入單元測試（暫不實作）

---

## 執行結果

- **Build**: ✅ 成功（release mode, 8.48s）
- **Binary**: 已部署到 `~/bin/CheXcodeMCP`（arm64）
- **Git**: 已 push 到 GitHub main（commit 884b978）
- **Release**: v0.2.0 release notes 已更新，binary 已上傳
- **Tool count**: 91 → 98（+7 new tools）
