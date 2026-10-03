# UI 與背景美術：生圖提示詞

遊戲 Logo（`scenes/ui/game_logo.png`）的風格是寫實奇幻插畫：昏暗的山洞、火把與火焰的暖光、戴廚師帽的紅龍。
下面三張圖目前放的是**暫時版**（由 Logo 加工或程式繪製），請用 AI 生圖工具照提示詞產生正式版，**用同樣的檔名覆蓋**即可，不需要改程式。

生圖時把 Logo 當作風格參考圖一起提供（多數工具有「參考圖」或「image prompt」功能），風格會比較一致。

| 圖 | 檔案（覆蓋這個檔案） | 尺寸 | 用在 |
|---|---|---|---|
| 遊戲結束背景 | `scenes/ui/result_background.png` | 1920×1080 | 遊戲結束介面的背景 |
| 遊戲結束資訊面板 | `scenes/ui/result_panel.png` | 384×384，透明背景 | 遊戲結束介面中央的面板（九宮格拉伸） |
| 龍洞穴背景（**已完成**） | `scenes/backdrop/cave_backdrop.png` | 1920×1080 | 遊戲中 3D 場景最後面的背景 |

---

## 1. 遊戲結束背景

**構圖**：和 Logo 同一個山洞，但沒有標題文字。畫面中央要留給資訊面板，所以中央偏暗、細節少；四周是岩壁、火把、散落的骨頭。整體昏暗，像餐後的寧靜。

**提示詞（英文）**

```
Dark fantasy cave interior, cinematic wide shot, same style as the reference image,
rough rocky cave walls with stalactites, burning wall torches casting warm orange light,
scattered bones and skulls on the floor, faint smoke and embers in the air,
the center of the image is dark and empty with soft blur to leave room for a UI panel,
moody low-key lighting, deep shadows, semi-realistic digital painting,
no text, no logo, no characters, 16:9, 1920x1080
```

**中文說明（給中文生圖工具）**

```
暗黑奇幻風格的山洞內部，電影感廣角，風格與參考圖相同。粗糙的岩壁與鐘乳石，牆上火把散發橘色暖光，
地面散落骨頭與頭骨，空氣中有淡淡的煙與火星。畫面中央昏暗、留白並帶柔和模糊，用來放介面面板。
低調光、陰影深，半寫實數位繪畫。不要文字、不要 Logo、不要角色，16:9，1920x1080。
```

---

## 2. 遊戲結束資訊面板

**用途**：遊戲結束時放成績與按鍵的面板。Godot 用「九宮格」拉伸：四個角維持原樣，四條邊與中央拉長，所以**邊框的花紋要四邊一致**，中央要是**平整、偏暗的石板**，好放文字。

**規格**
- 正方形，建議 384×384（或 512×512、768×768，等比例放大都可以）。
- 背景透明（PNG）。工具不支援透明時，請用純黑背景生成，再用去背工具去掉。
- 邊框寬度約為圖寬的 1/7（384 的圖約 56 像素）。邊框寬度不同時，要調整 `scenes/ui/result_screen.tscn` 裡 `StyleBoxTexture_panel` 的 `texture_margin_*`（四邊）。

**提示詞（英文）**

```
Game UI panel frame, front view, perfectly square and symmetrical,
carved dark stone tablet with a glowing fiery molten-lava border, ember glow along the edges,
the four edges have the same uniform pattern so it can be 9-slice stretched,
the inner area is a flat, plain, dark smooth stone surface with no decoration for text,
fantasy dragon cave style matching the reference image, semi-realistic,
isolated on transparent background, no text, no icons, centered, 1:1
```

**中文說明**

```
遊戲介面面板框，正面視角，正方形、上下左右對稱。深色雕刻石板，邊框是發光的火焰熔岩，邊緣有火星光暈。
四條邊的花紋一致，方便九宮格拉伸。中央是平整、無裝飾的深色光滑石面，用來放文字。
風格與參考圖的龍洞穴一致，半寫實。透明背景，不要文字、不要圖示，置中，1:1。
```

---

## 3. 龍洞穴背景（遊戲中）

> 已換成正式美術（`FGJ2026TeamE_GameSceneBG.png`，左三層隧道、中間龍穴與龍巢、右三個料理洞窟）。以下提示詞留作重新生成時的參考。

**用途**：放在 3D 遊戲場景最後面的背景圖（會自動蓋滿畫面）。前面還有 3D 的平台、食材、龍與鍋子，所以背景要**偏暗、對比低**，不要搶走焦點。

**構圖**：山體內部的巨大龍穴，空間非常高大。

- **兩側**：巨大的岩壁與懸崖，往畫面中央層層後退，越遠越朦朧，營造深度。
- **天頂**：像火山口的開口，一道柔和的光柱照進洞穴，空氣中有塵埃與火星。
- **底部中央**：龍巢（樹枝與骨頭堆成，裡面有幾顆彩色龍蛋），旁邊有一堆寶藏金幣，地面散落骨頭，透出熔岩般的暖光。
- 畫面中段（龍上下飛的區域）留得比較空，不要放顯眼的物件。

**提示詞（英文）**

```
A colossal dragon's lair inside a mountain, dark fantasy, same style as the reference image, 16:9, 1920x1080.
Enormous vertical cavern, towering rock cliffs on both sides receding into the distance in hazy layers,
a crater-like opening in the ceiling with a soft beam of light falling into the cave, dust and floating embers,
at the bottom center a huge nest of twigs and bones holding several colorful dragon eggs,
a pile of gold treasure coins beside it, scattered bones, warm lava-like glow from below,
the middle of the image is open and uncluttered,
overall low contrast and darker than the reference so foreground 3D objects stand out, semi-realistic digital painting,
no characters, no dragon, no text
```

**中文說明**

```
山體內部的巨大龍穴，暗黑奇幻風格，與參考圖相同，16:9，1920x1080。
非常高大的垂直洞穴，兩側是高聳的岩壁懸崖，往遠處層層後退、越遠越朦朧；
天頂有像火山口的開口，一道柔和的光柱照進洞穴，空氣中有塵埃與飄浮的火星；
底部中央是樹枝與骨頭堆成的大龍巢，裡面有幾顆彩色龍蛋，旁邊有一堆寶藏金幣，地面散落骨頭，下方透出熔岩般的暖光；
畫面中段保持空曠。整體對比低、比參考圖更暗，讓前景的 3D 物件突出。半寫實數位繪畫。不要角色、不要龍、不要文字。
```

---

## 替換後的確認

1. 用同樣的檔名覆蓋上表的檔案。
2. 回到 Godot 編輯器，等它自動重新匯入圖片。
3. 開啟 `scenes/game/game.tscn` 按 `Cmd + R`：
   - 遊戲中看背景是否太亮、搶走前景。太亮的話用修圖工具調暗，或在生圖提示詞加上「darker」。
   - 按住 `Ctrl + Shift` 的測試快捷鍵只在 `scenes/ui/ui_test.tscn` 有效；要看結束畫面，可以在 `ui_test.tscn` 按 `Ctrl + Shift + W`（成功）或 `L`（失敗）。
4. 面板邊框如果被拉伸變形，調整 `result_screen.tscn` 的 `texture_margin_*`，讓四個數字等於新圖的邊框寬度。
