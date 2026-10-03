# KitkayDungeon 素材盤點與交接

日期：2026-10-03。場景美術保存的交接資料；本輪只做盤點，未修改房間、主場景、來源素材／.import 或共享 Godot 快取，未 commit／push。

## 收尾狀態

- 使用者要求先收尾時，185 個 GLB 已完成實際 Godot 載入、完整變換 AABB／材質量測及全部 10 頁視覺核對；沒有為交接補跑新模型。
- 185／185 載入成功，失敗 0；全部材質存在，未發現需要外部圖片的模型；動畫、Skeleton3D 與 CollisionObject3D 全部為 0。
- 已檢視全部 185 件原造型，未找到人物、完整人形雕像或藏有角色的合集。寶箱中的小骷髏及寶箱怪尖牙是裝飾／箱體，不能認定為人物或六種食材。
- 主要候選鐵門、木桶、空武器架及書架已辨識。人物來源仍待使用者／總監確認，未加入挑戰房或遊戲隊列。
- 未完成：新素材所屬房間選擇、人物來源與角色用途、可重用子場景／碰撞／擺放、玻璃材質調整及新素材整合後的主鏡頭驗證。這些需要總監下一次範圍指示。
- 本 session 的暫存匯入、量測及 GPU 截圖程序均已正常退出。沒有仍在執行的本輪驗證程序；使用者 Godot 未關閉。

## 分類總覽

| 類別 | 模型數 |
|---|---:|
| 武器與裝備 | 28 |
| 寶箱與財寶 | 17 |
| 照明框架與掛飾 | 3 |
| 儲物與容器 | 10 |
| 家具與書籍 | 23 |
| 地面、樓梯與柱體 | 19 |
| 建築牆體與門 | 26 |
| 陶器與餐具 | 11 |
| 煉金與魔法用品 | 10 |
| 木造平台與樓梯 | 34 |
| 陷阱 | 4 |

以上分類由逐件外觀與場景結構核對；檔名只用來識別來源，沒有以檔名推定食材種族或玩法能力。

## 缺件可補與仍缺

| 原需求 | 本批實際內容 | 結論 |
|---|---|---|
| 鐵門 | door_gate、wall_gate、wall_gateDoor、wallSingle_windowGate 等 | 已有門片、柵牆及鐵窗；可補件，但門片不是完整柵牆，且無開門動畫 |
| 武器架 | weaponRack 為空木架，另有劍／斧／槌／盾／弩／法杖 | 可補；武器需另行實例化，架子本身沒有武器 |
| 木桶 | barrel、barrelDark | 可補，一般木桶與暗色版本 |
| 照護棚架 | 空／附書／寬版 bookcase 家族 | 可作木架候選，需總監確認；附書架不能直接宣稱是照護用品 |
| 鎖鏈 | 全部模型未見獨立鎖鏈 | 仍缺 |
| 吊燈／燈籠 | 只有 torch、torchWall 的握柄及托架 | 仍缺；火把模型也沒有火焰或 Light3D |
| 封閉暖爐 | 未見壁爐、暖爐或火盆模型 | 仍缺；不能把木桶／地刺箱當暖爐 |
| 稻草／軟墊／毯子 | 僅有束口袋、木板覆片及垂掛旗 | 仍缺；這些不是可直接使用的巢內鋪墊 |
| 育幼巢／龍紋裝飾 | 未見巢穴或龍紋物件 | 仍缺 |
| 人物／六種食材 | 本批全部模型未見人物 | 未找到；來源與種族對應待確認 |

## 主要候選尺寸與原點注意

尺寸為 Godot 單位，X × Y × Z，包含全部後代模型變換；min 為根節點局部外框最小點。

| 候選 | 尺寸 | min | 接入注意 |
|---|---|---|---|
| door_gate | (2, 2.54, 0.2727) | (0, -1.0816, -0.1) | 門片由 X≈0 向 +X 延伸，原點不在底部中心；擺放須做中心／落地校正 |
| wall_gate | (4, 4, 1.5) | (-2, 0, -0.75) | 完整 4 高柵牆，厚 1.5；不能沿用舊薄牆碰撞 |
| weaponRack | (1.1554, 0.7818, 0.6538) | (-0.5755, -0.0018, -0.4469) | 小型空木架，底面有約 −0.0018 偏移；需另配武器 |
| barrel／barrelDark | (0.9415, 1, 0.9684) | (-0.4707, -0.4, -0.4842) | 原點在桶身內，底面 −0.4；原樣放 Y=0 會埋地 |
| wall | (4, 4, 1.5) | (-2, 0, -0.75) | 4 × 4 模組，但厚 1.5，會改變房間內淨寬 |
| wallSingle | (4, 4, 0.75) | (-2, 0, 0) | 厚 0.75；Z 範圍 0～0.75，非 Z 置中 |
| tileBrickA_large | (6.05, 1.06, 6.05) | (-3.025, 0, -3.025) | 6.05 寬、厚約 1.06；與舊 4 寬薄地板不相容，須另訂縮放與上表面高度 |
| banner | (1.3974, 2.6149, 0.1675) | (-0.6987, -2.5303, 0) | 原點近旗桿上方，旗面向 −Y 下垂；不是地面軟墊 |

建議下一階段先由總監決定 kitkayDungeon 用於哪一類房間，再統一模組比例與材質語言。已定案兩類房間將使用不同素材，但本批所屬尚未定案。先補木桶、鐵門與空武器架比直接整套替換外殼更容易審查；這只是建議，沒有實作或替使用者定案。

## 材質、動畫與朝向

- 所有模型均使用來源 StandardMaterial3D 的純色材質，沒有 albedo 貼圖或法線貼圖，不是貼圖遺失；20 種材質名稱與 RGB 數值已實際讀取。
- 所有模型根 basis 都是 identity、position 為零。全表 AABB 已合併後代 MeshInstance3D 的完整變換，不能只以源 JSON accessor 的局部尺寸替代。
- 全部模型無動畫、無骨架、無內建碰撞。門片、箱蓋與陷阱是分離靜態模型，不代表已有開閉／觸發接口。
- 全表朝向表示可核對的幾何平面或長軸。無人物，不存在已確認的角色 forward；多向轉角、圓形器物與不對稱雜物須以索引外觀決定擺放角度。
- 藥瓶 red／green／blue 內部確有相應 Red／Green／Blue 材質，但實際 Forward Plus 外觀主要呈白色瓶身。Glass 的 alpha=1、transparency=4，外瓶遮擋內液體色；若日後以顏色辨識，須在 wrapper 調整玻璃呈現並驗證。盤點未改材質。
- torch／torchWall 材質沒有 emission，模型也沒有火焰；要用作光源需另配置火焰及燈光，不能記為現成暖爐或吊燈。

| 材質 | 原始 RGB | metallic / roughness |
|---|---|---|
| Beige | (0.8559, 0.6838, 0.4922) | 0.0 / 0.5 |
| Black | (0.1508, 0.1967, 0.2133) | 0.0 / 0.5 |
| Blue | (0.3913, 0.7077, 1) | 0.0 / 0.2 |
| BlueDark | (0.397, 0.5397, 0.6714) | 0.0 / 0.5 |
| BlueLight | (0.6345, 0.754, 0.8643) | 0.0 / 0.5 |
| Brown | (0.7845, 0.5205, 0.374) | 0.0 / 0.5 |
| BrownDark | (0.6071, 0.3517, 0.27) | 0.0 / 0.4 |
| Glass | (0.9059, 0.9059, 0.9059) | 0.114 / 0.0 |
| Gold | (0.7333, 0.6133, 0.3589) | 0.409 / 0.234 |
| Green | (0.2835, 0.7357, 0.5523) | 0.0 / 0.4 |
| GreenDark | (0.1577, 0.5443, 0.5533) | 0.0 / 0.4 |
| Metal | (0.6661, 0.721, 0.7467) | 0.2 / 0.3 |
| Mud | (0.5929, 0.5624, 0.5262) | 0.0 / 0.5 |
| Purple | (0.5466, 0.2529, 0.7857) | 0.0 / 0.2 |
| PurpleDark | (0.2824, 0.2667, 0.4431) | 0.0 / 0.4 |
| Red | (1, 0.172, 0.3781) | 0.0 / 0.2 |
| Stone | (0.4758, 0.515, 0.5333) | 0.0 / 0.5 |
| StoneDark | (0.3507, 0.3784, 0.3928) | 0.0 / 0.5 |
| White | (0.9059, 0.9059, 0.9059) | 0.0 / 0.5 |
| WoodDark | (0.4286, 0.3758, 0.359) | 0.0 / 0.5 |

## 視覺索引

全部模型由 Godot 4.7.2 Forward Plus／D3D12 實際渲染，原模型不旋轉，相機位於 +X、+Y、+Z 三分之四視角。每格只為索引等比置中，**各格不是同比例**；實際尺寸看下表。標號依 GLB 檔名區分大小寫排序，與逐件清單一致。

- [第 01 頁：001～020](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_01.png)
- [第 02 頁：021～040](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_02.png)
- [第 03 頁：041～060](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_03.png)
- [第 04 頁：061～080](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_04.png)
- [第 05 頁：081～100](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_05.png)
- [第 06 頁：101～120](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_06.png)
- [第 07 頁：121～140](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_07.png)
- [第 08 頁：141～160](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_08.png)
- [第 09 頁：161～180](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_09.png)
- [第 10 頁：181～185](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_all_10.png)

[主要候選集中索引](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_candidates_01.png) 的標號為候選頁自身排序，請以檔名辨識，不與全量 001～185 混用。此頁可直接核對門片、柵牆、木桶、空武器架、書架、旗幟、火把架、束口袋、木覆片與寶箱怪；沒有暖爐或鋪墊候選可確認。

## 185 件逐件清單

全數 Godot 實際載入與視覺核對完成；動畫欄「無」均由 GLB JSON 與 Godot AnimationPlayer 兩者檢查。碰撞均無，材質欄為實際 surface 使用的名稱；原點以 min 表達，max = min + size。

| ID | 來源模型 | 類別 | 實際內容／用途 | 尺寸 X/Y/Z | 外框 min X/Y/Z | 朝向摘要 | 材質名稱 | 動畫 |
|---:|---|---|---|---|---|---|---|---|
| 001 | `arrow.gltf.glb` | 武器與裝備 | 箭／可放武器架；不是人物 | (0.1475, 0.1314, 0.6674) | (-0.0738, -0.0462, -0.3781) | 保留原方向；見索引 | Metal, BrownDark, GreenDark | 無 |
| 002 | `artifact.gltf.glb` | 寶箱與財寶 | 金色鑲寶石杯形神器 | (0.5839, 0.8637, 0.5839) | (-0.292, -0.2, -0.292) | 保留原方向；見索引 | Gold, Red | 無 |
| 003 | `axeDouble_common.gltf.glb` | 武器與裝備 | 雙刃斧／可放武器架；不是人物 | (0.5477, 0.8903, 0.1863) | (-0.2739, -0.2001, -0.0931) | 長軸Y；握柄向−Y | Stone, WoodDark | 無 |
| 004 | `axeDouble_rare.gltf.glb` | 武器與裝備 | 雙刃斧／可放武器架；不是人物 | (0.808, 0.9504, 0.2754) | (-0.404, -0.1976, -0.1377) | 長軸Y；握柄向−Y | White, Metal, Gold, Red | 無 |
| 005 | `axeDouble_uncommon.gltf.glb` | 武器與裝備 | 雙刃斧／可放武器架；不是人物 | (0.7926, 0.9528, 0.1686) | (-0.3963, -0.2001, -0.0843) | 長軸Y；握柄向−Y | Metal, BrownDark, Stone | 無 |
| 006 | `axe_common.gltf.glb` | 武器與裝備 | 單刃斧／可放武器架；不是人物 | (0.3814, 0.8903, 0.1863) | (-0.2738, -0.2106, -0.0931) | 長軸Y；握柄向−Y | Stone, WoodDark | 無 |
| 007 | `axe_rare.gltf.glb` | 武器與裝備 | 單刃斧／可放武器架；不是人物 | (0.5417, 0.9504, 0.2754) | (-0.404, -0.2082, -0.1377) | 長軸Y；握柄向−Y | White, Metal, Gold, Red | 無 |
| 008 | `axe_uncommon.gltf.glb` | 武器與裝備 | 單刃斧／可放武器架；不是人物 | (0.4806, 0.9528, 0.1686) | (-0.3963, -0.2106, -0.0843) | 長軸Y；握柄向−Y | Metal, BrownDark, Stone | 無 |
| 009 | `banner.gltf.glb` | 照明框架與掛飾 | 藍色垂掛旗；非鋪墊 | (1.3974, 2.6149, 0.1675) | (-0.6987, -2.5303, 0) | Y立面；主要面±Z | BrownDark, BlueDark, BlueLight | 無 |
| 010 | `barrel.gltf.glb` | 儲物與容器 | 封口木桶；非暖爐或巢穴 | (0.9415, 1, 0.9684) | (-0.4707, -0.4, -0.4842) | Y直立 | BrownDark, Beige, Metal | 無 |
| 011 | `barrelDark.gltf.glb` | 儲物與容器 | 封口木桶；非暖爐或巢穴 | (0.9415, 1, 0.9684) | (-0.4707, -0.4, -0.4842) | Y直立 | WoodDark, Beige, Stone | 無 |
| 012 | `bench.gltf.glb` | 家具與書籍 | 長木凳 | (1.4466, 0.4556, 0.7531) | (-0.3737, 0, -0.3802) | 保留原方向；見索引 | BrownDark | 無 |
| 013 | `bookA.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3758, 0.4161, 0.172) | (-0.0724, -0.208, -0.086) | 保留原方向；見索引 | StoneDark, White, Metal | 無 |
| 014 | `bookB.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3758, 0.4161, 0.172) | (-0.0724, -0.208, -0.086) | 保留原方向；見索引 | PurpleDark, White, Metal | 無 |
| 015 | `bookC.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3586, 0.4161, 0.1431) | (-0.0552, -0.208, -0.0715) | 保留原方向；見索引 | Black, White | 無 |
| 016 | `bookD.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3586, 0.4161, 0.1431) | (-0.0552, -0.208, -0.0715) | 保留原方向；見索引 | WoodDark, White | 無 |
| 017 | `bookE.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3586, 0.4161, 0.1431) | (-0.0552, -0.208, -0.0715) | 保留原方向；見索引 | GreenDark, White | 無 |
| 018 | `bookF.gltf.glb` | 家具與書籍 | 閉合書本／書架或桌面陳設 | (0.3586, 0.4161, 0.1431) | (-0.0552, -0.208, -0.0715) | 保留原方向；見索引 | BlueDark, White | 無 |
| 019 | `bookOpenA.gltf.glb` | 家具與書籍 | 攤開書本／桌面陳設 | (0.7032, 0.1569, 0.4166) | (-0.3516, -0.0373, -0.2059) | 上表面+Y／XZ平放 | GreenDark, White, Metal | 無 |
| 020 | `bookOpenB.gltf.glb` | 家具與書籍 | 攤開書本／桌面陳設 | (0.7032, 0.1569, 0.4166) | (-0.3516, -0.0373, -0.2059) | 上表面+Y／XZ平放 | Brown, White, Metal | 無 |
| 021 | `bookcase.gltf.glb` | 家具與書籍 | 木書架／空架 | (0.9949, 2.0015, 0.5333) | (-0.4974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark | 無 |
| 022 | `bookcaseFilled.gltf.glb` | 家具與書籍 | 木書架／附書 | (0.9949, 2.0015, 0.5333) | (-0.4974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark, PurpleDark, White, Metal, BlueDark, GreenDark, WoodDark, Black | 無 |
| 023 | `bookcaseFilled_broken.gltf.glb` | 家具與書籍 | 木書架／附書／破損 | (0.9949, 2.0015, 0.5333) | (-0.4974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark, PurpleDark, White, Metal, BlueDark, GreenDark, WoodDark | 無 |
| 024 | `bookcaseWide.gltf.glb` | 家具與書籍 | 木書架／空架 | (1.9949, 2.0015, 0.5333) | (-0.9974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark | 無 |
| 025 | `bookcaseWideFilled.gltf.glb` | 家具與書籍 | 木書架／附書 | (1.9949, 2.0015, 0.5333) | (-0.9974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark, PurpleDark, White, Metal, BlueDark, GreenDark, WoodDark, StoneDark, Black | 無 |
| 026 | `bookcaseWideFilled_broken.gltf.glb` | 家具與書籍 | 木書架／附書／破損 | (1.9949, 2.0015, 0.5333) | (-0.9974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark, PurpleDark, White, Metal, BlueDark, GreenDark, WoodDark, Black | 無 |
| 027 | `bookcaseWide_broken.gltf.glb` | 家具與書籍 | 木書架／空架／破損 | (1.9949, 2.0015, 0.5333) | (-0.9974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark | 無 |
| 028 | `bookcase_broken.gltf.glb` | 家具與書籍 | 木書架／空架／破損 | (0.9949, 2.0015, 0.5333) | (-0.4974, -0.0024, -0.2667) | 保留原方向；見索引 | BrownDark | 無 |
| 029 | `bricks.gltf.glb` | 地面、樓梯與柱體 | 散落石磚 | (1.3646, 0.7962, 1.2761) | (-0.7646, 0, -0.6803) | 保留原方向；見索引 | Stone | 無 |
| 030 | `bucket.gltf.glb` | 儲物與容器 | 開口木水桶 | (0.8822, 0.7327, 0.8822) | (-0.4411, -0.4, -0.4411) | Y直立 | BrownDark, Metal | 無 |
| 031 | `chair.gltf.glb` | 家具與書籍 | 木椅 | (0.7466, 0.9909, 0.8697) | (-0.3737, 0, -0.381) | 保留原方向；見索引 | BrownDark | 無 |
| 032 | `chestTop_common.gltf.glb` | 寶箱與財寶 | 分離箱蓋；需配箱身 | (1.5, 0.879, 1.2808) | (-0.75, -0.1588, -0.155) | 保留原方向；見索引 | Stone, WoodDark | 無 |
| 033 | `chestTop_common_empty.gltf.glb` | 寶箱與財寶 | 分離箱蓋；需配箱身 | (1.5, 0.879, 1.2808) | (-0.75, -0.1588, -0.155) | 保留原方向；見索引 | Stone, WoodDark | 無 |
| 034 | `chestTop_rare.gltf.glb` | 寶箱與財寶 | 分離箱蓋；需配箱身 | (2.2216, 1.1382, 1.2808) | (-1.1108, -0.1588, -0.155) | 保留原方向；見索引 | Gold, White | 無 |
| 035 | `chestTop_rare_mimic.gltf.glb` | 寶箱與財寶 | 分離箱蓋／寶箱怪齒部；需配箱身 | (2.2216, 1.4057, 1.2808) | (-1.1108, -0.4264, -0.155) | 保留原方向；見索引 | Gold, White, Black | 無 |
| 036 | `chestTop_uncommon.gltf.glb` | 寶箱與財寶 | 分離箱蓋；需配箱身 | (1.9, 0.9723, 1.2808) | (-0.95, -0.1588, -0.155) | 保留原方向；見索引 | Metal, BrownDark | 無 |
| 037 | `chestTop_uncommon_mimic.gltf.glb` | 寶箱與財寶 | 分離箱蓋／寶箱怪齒部；需配箱身 | (1.9, 1.2399, 1.2808) | (-0.95, -0.4264, -0.155) | 保留原方向；見索引 | Metal, BrownDark, Black, White | 無 |
| 038 | `chest_common.gltf.glb` | 寶箱與財寶 | 開口箱身／金幣與器物 | (1.44, 0.8099, 1.1) | (-0.72, 0, -0.55) | 保留原方向；見索引 | Stone, WoodDark, Gold, Red | 無 |
| 039 | `chest_common_empty.gltf.glb` | 寶箱與財寶 | 開口箱身／少量骷髏裝飾 | (1.44, 0.9233, 1.1) | (-0.72, 0, -0.55) | 保留原方向；見索引 | Stone, WoodDark, White, Black | 無 |
| 040 | `chest_rare.gltf.glb` | 寶箱與財寶 | 開口箱身／金幣與器物 | (1.84, 0.6007, 1.1) | (-0.92, 0, -0.55) | 保留原方向；見索引 | Gold, White | 無 |
| 041 | `chest_rare_mimic.gltf.glb` | 寶箱與財寶 | 開口箱身／寶箱怪尖牙；非人物 | (1.84, 1.084, 1.1) | (-0.92, 0, -0.55) | 保留原方向；見索引 | Gold, White, Black | 無 |
| 042 | `chest_uncommon.gltf.glb` | 寶箱與財寶 | 開口箱身／金幣與器物 | (1.84, 0.8099, 1.1) | (-0.92, 0, -0.55) | 保留原方向；見索引 | Metal, BrownDark, Gold, Red | 無 |
| 043 | `chest_uncommon_mimic.gltf.glb` | 寶箱與財寶 | 開口箱身／寶箱怪尖牙；非人物 | (1.84, 1.084, 1.1) | (-0.92, 0, -0.55) | 保留原方向；見索引 | Metal, BrownDark, Black, White | 無 |
| 044 | `coin.gltf.glb` | 寶箱與財寶 | 金幣／散落寶物 | (0.8462, 0.8462, 0.32) | (-0.4231, -0.4231, -0.16) | 保留原方向；見索引 | Gold | 無 |
| 045 | `coinsLarge.gltf.glb` | 寶箱與財寶 | 金幣／散落寶物 | (1.5945, 0.9074, 1.3304) | (-0.7453, -0.0074, -0.5971) | 保留原方向；見索引 | Gold | 無 |
| 046 | `coinsMedium.gltf.glb` | 寶箱與財寶 | 金幣／散落寶物 | (1.2302, 0.5074, 0.9779) | (-0.5651, -0.0074, -0.5651) | 保留原方向；見索引 | Gold | 無 |
| 047 | `coinsSmall.gltf.glb` | 寶箱與財寶 | 金幣／散落寶物 | (0.8875, 0.288, 0.7918) | (-0.4224, -0.0074, -0.4267) | 保留原方向；見索引 | Gold | 無 |
| 048 | `crate.gltf.glb` | 儲物與容器 | 金屬包邊木箱 | (1.0521, 1.0521, 1.0521) | (-0.526, -0.526, -0.526) | 保留原方向；見索引 | BrownDark, Metal | 無 |
| 049 | `crateDark.gltf.glb` | 儲物與容器 | 金屬包邊木箱 | (1.0521, 1.0521, 1.0521) | (-0.526, -0.526, -0.526) | 保留原方向；見索引 | WoodDark, Stone | 無 |
| 050 | `cratePlatform_large.gltf.glb` | 儲物與容器 | 扁木箱平台 | (2.0521, 2.2521, 2.0521) | (-1.026, -0.026, -1.026) | 保留原方向；見索引 | WoodDark, Stone | 無 |
| 051 | `cratePlatform_medium.gltf.glb` | 儲物與容器 | 扁木箱平台 | (2.0521, 1.0521, 2.0521) | (-1.026, -0.026, -1.026) | 保留原方向；見索引 | WoodDark, Stone | 無 |
| 052 | `cratePlatform_small.gltf.glb` | 儲物與容器 | 扁木箱平台 | (2.0521, 0.6521, 2.0521) | (-1.026, -0.026, -1.026) | 保留原方向；見索引 | WoodDark, Stone | 無 |
| 053 | `crossbow_common.gltf.glb` | 武器與裝備 | 弩／可放武器架；不是人物 | (0.691, 0.1945, 0.6382) | (-0.3455, -0.1145, -0.1052) | 保留原方向；見索引 | WoodDark, Stone | 無 |
| 054 | `crossbow_rare.gltf.glb` | 武器與裝備 | 弩／可放武器架；不是人物 | (1.0445, 0.2366, 0.7409) | (-0.5222, -0.1145, -0.0904) | 保留原方向；見索引 | White, Gold | 無 |
| 055 | `crossbow_uncommon.gltf.glb` | 武器與裝備 | 弩／可放武器架；不是人物 | (1.0352, 0.2098, 0.7584) | (-0.5176, -0.1145, -0.1052) | 保留原方向；見索引 | Metal, BrownDark | 無 |
| 056 | `dagger_common.gltf.glb` | 武器與裝備 | 匕首／可放武器架；不是人物 | (0.1507, 0.8978, 0.104) | (-0.0753, -0.1021, -0.052) | 長軸Y；握柄向−Y | Stone, WoodDark, StoneDark | 無 |
| 057 | `dagger_rare.gltf.glb` | 武器與裝備 | 匕首／可放武器架；不是人物 | (0.374, 1.1535, 0.1445) | (-0.187, -0.1739, -0.0724) | 長軸Y；握柄向−Y | White, Metal, Gold, Red | 無 |
| 058 | `dagger_uncommon.gltf.glb` | 武器與裝備 | 匕首／可放武器架；不是人物 | (0.3867, 1.0307, 0.1167) | (-0.1933, -0.1511, -0.0584) | 長軸Y；握柄向−Y | Metal, BrownDark, Stone | 無 |
| 059 | `door.gltf.glb` | 建築牆體與門 | 木門；無開門動畫 | (2, 2.5, 0.4738) | (0, -0.2071, -0.2369) | Y立面；主要面±Z | BrownDark, Metal | 無 |
| 060 | `door_gate.gltf.glb` | 建築牆體與門 | 可獨立配置的鐵柵門；無開門動畫 | (2, 2.54, 0.2727) | (0, -1.0816, -0.1) | Y立面；主要面±Z | StoneDark, Black | 無 |
| 061 | `floorDecoration_shatteredBricks.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (1.5676, 0.05, 1.7076) | (-0.8316, 0, -0.8925) | 上表面+Y／XZ平放 | Stone | 無 |
| 062 | `floorDecoration_tilesLarge.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (5.8, 0.05, 5.8) | (-2.9, 0, -2.9) | 上表面+Y／XZ平放 | Stone | 無 |
| 063 | `floorDecoration_tilesSmall.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (1.8, 0.06, 1.8) | (-0.9, 0, -0.9) | 上表面+Y／XZ平放 | Stone | 無 |
| 064 | `floorDecoration_wood.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (2, 0.1, 2) | (-1, 0, -1) | 上表面+Y／XZ平放 | WoodDark | 無 |
| 065 | `floorDecoration_woodLeft.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (1.9, 0.1, 2) | (-0.9, 0, -1) | 上表面+Y／XZ平放 | WoodDark | 無 |
| 066 | `floorDecoration_woodRight.gltf.glb` | 地面、樓梯與柱體 | 薄地面覆片／碎磚或木板；非軟墊 | (1.9, 0.1, 2) | (-1, 0, -1) | 上表面+Y／XZ平放 | WoodDark | 無 |
| 067 | `hammer_common.gltf.glb` | 武器與裝備 | 戰錘／可放武器架；不是人物 | (0.5293, 0.8632, 0.3274) | (-0.264, -0.233, -0.1637) | 長軸Y；握柄向−Y | Stone, WoodDark | 無 |
| 068 | `hammer_rare.gltf.glb` | 武器與裝備 | 戰錘／可放武器架；不是人物 | (0.8443, 0.8981, 0.4477) | (-0.4222, -0.2406, -0.2238) | 長軸Y；握柄向−Y | White, Gold, Red | 無 |
| 069 | `hammer_uncommon.gltf.glb` | 武器與裝備 | 戰錘／可放武器架；不是人物 | (0.7876, 0.8701, 0.421) | (-0.3938, -0.233, -0.2105) | 長軸Y；握柄向−Y | Metal, BrownDark, Stone | 無 |
| 070 | `lootSackA.gltf.glb` | 儲物與容器 | 束口袋；非稻草／軟墊 | (0.986, 1.1304, 0.9975) | (-0.4826, -0.0052, -0.4903) | 保留原方向；見索引 | Beige, BrownDark | 無 |
| 071 | `lootSackB.gltf.glb` | 儲物與容器 | 束口袋；非稻草／軟墊 | (1, 0.933, 1) | (-0.5, -0.0052, -0.5) | 保留原方向；見索引 | Beige, BrownDark | 無 |
| 072 | `mug.gltf.glb` | 陶器與餐具 | 木製杯 | (0.4375, 0.3892, 0.3434) | (-0.1692, -0.1959, -0.1717) | Y直立 | BrownDark, Metal | 無 |
| 073 | `pillar.gltf.glb` | 地面、樓梯與柱體 | 石柱 | (1.61, 4, 1.61) | (-0.805, 0, -0.805) | Y直立 | Stone, StoneDark | 無 |
| 074 | `pillar_broken.gltf.glb` | 地面、樓梯與柱體 | 石柱／破損 | (1.6354, 3.5015, 1.6457) | (-0.8252, 0, -0.8403) | Y直立 | Stone, StoneDark | 無 |
| 075 | `plate.gltf.glb` | 陶器與餐具 | 盤子 | (0.6587, 0.0773, 0.6587) | (-0.3294, 0, -0.3294) | 上表面+Y／XZ平放 | Mud | 無 |
| 076 | `plateFull.gltf.glb` | 陶器與餐具 | 盤子／含食物形狀 | (0.6587, 0.1855, 0.6587) | (-0.3294, 0, -0.3294) | 上表面+Y／XZ平放 | Mud, Beige | 無 |
| 077 | `plateHalf.gltf.glb` | 陶器與餐具 | 盤子／含食物形狀 | (0.6587, 0.1078, 0.6587) | (-0.3294, 0, -0.3294) | 上表面+Y／XZ平放 | Mud, Beige | 無 |
| 078 | `potA.gltf.glb` | 陶器與餐具 | 陶罐；非鍋或巢 | (0.5242, 0.9821, 0.5242) | (-0.2621, 0, -0.2621) | Y直立 | Beige | 無 |
| 079 | `potA_decorated.gltf.glb` | 陶器與餐具 | 陶罐／裝飾紋；非鍋或巢 | (0.5242, 0.9821, 0.5242) | (-0.2621, 0, -0.2621) | Y直立 | Beige, Brown | 無 |
| 080 | `potB.gltf.glb` | 陶器與餐具 | 陶罐；非鍋或巢 | (0.8406, 0.9517, 0.8406) | (-0.4203, 0, -0.4203) | Y直立 | Beige | 無 |
| 081 | `potB_decorated.gltf.glb` | 陶器與餐具 | 陶罐／裝飾紋；非鍋或巢 | (0.8406, 0.9517, 0.8406) | (-0.4203, 0, -0.4203) | Y直立 | Beige, Brown | 無 |
| 082 | `potC.gltf.glb` | 陶器與餐具 | 陶罐；非鍋或巢 | (1.121, 0.911, 1.121) | (-0.5605, 0, -0.5605) | Y直立 | Beige | 無 |
| 083 | `potC_decorated.gltf.glb` | 陶器與餐具 | 陶罐／裝飾紋；非鍋或巢 | (1.121, 0.911, 1.121) | (-0.5605, 0, -0.5605) | Y直立 | Beige, Brown | 無 |
| 084 | `potionLarge_blue.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (1.0025, 1.1813, 1.0025) | (-0.5012, 0, -0.5012) | Y直立 | Glass, Beige, Blue | 無 |
| 085 | `potionLarge_green.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (1.0025, 1.1813, 1.0025) | (-0.5012, 0, -0.5012) | Y直立 | Glass, Beige, Green | 無 |
| 086 | `potionLarge_red.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (1.0025, 1.1813, 1.0025) | (-0.5012, 0, -0.5012) | Y直立 | Glass, Beige, Red | 無 |
| 087 | `potionMedium_blue.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.7978, 1.0752, 0.7978) | (-0.3989, 0, -0.3989) | Y直立 | Glass, Beige, Blue | 無 |
| 088 | `potionMedium_green.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.7978, 1.0752, 0.7978) | (-0.3989, 0, -0.3989) | Y直立 | Glass, Beige, Green | 無 |
| 089 | `potionMedium_red.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.7978, 1.0752, 0.7978) | (-0.3989, 0, -0.3989) | Y直立 | Glass, Beige, Red | 無 |
| 090 | `potionSmall_blue.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.5001, 0.8622, 0.5001) | (-0.2501, 0.0079, -0.2501) | Y直立 | Glass, Beige, Blue | 無 |
| 091 | `potionSmall_green.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.5001, 0.8622, 0.5001) | (-0.2501, 0.0079, -0.2501) | Y直立 | Glass, Beige, Green | 無 |
| 092 | `potionSmall_red.gltf.glb` | 煉金與魔法用品 | 藥瓶；外瓶遮住內液色，需確認玻璃材質 | (0.5001, 0.8622, 0.5001) | (-0.2501, 0.0079, -0.2501) | Y直立 | Glass, Beige, Red | 無 |
| 093 | `pots.gltf.glb` | 陶器與餐具 | 陶罐群組；非鍋或巢 | (1.599, 0.9821, 1.7408) | (-0.8203, 0, -0.8621) | Y直立 | Beige | 無 |
| 094 | `quiver_empty.gltf.glb` | 武器與裝備 | 箭筒／空 | (0.2481, 0.5483, 0.178) | (-0.1241, -0.3778, -0.1002) | Y直立 | BrownDark, Metal | 無 |
| 095 | `quiver_full.gltf.glb` | 武器與裝備 | 箭筒／滿箭 | (0.3592, 0.6959, 0.2039) | (-0.1797, -0.3778, -0.1261) | Y直立 | BrownDark, Metal, GreenDark | 無 |
| 096 | `quiver_half_full.gltf.glb` | 武器與裝備 | 箭筒／少量箭 | (0.3037, 0.6914, 0.178) | (-0.1797, -0.3778, -0.1002) | Y直立 | BrownDark, Metal, GreenDark | 無 |
| 097 | `scaffold_high.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 4.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 098 | `scaffold_high_cornerBoth.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 5.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 099 | `scaffold_high_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 5.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 100 | `scaffold_high_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 5.1, 4) | (-2.0006, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 101 | `scaffold_high_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 5.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 102 | `scaffold_low.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 0.2, 4) | (-2, -0.1, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 103 | `scaffold_low_cornerBoth.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 1.2, 4) | (-2, -0.1, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 104 | `scaffold_low_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 1.2, 4) | (-2, -0.1, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 105 | `scaffold_low_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 1.2, 4) | (-2.0006, -0.1, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 106 | `scaffold_low_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 1.2, 4) | (-2, -0.1, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 107 | `scaffold_medium.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 2.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 108 | `scaffold_medium_cornerBoth.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 3.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 109 | `scaffold_medium_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 3.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 110 | `scaffold_medium_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 3.1, 4) | (-2.0006, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 111 | `scaffold_medium_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 3.1, 4) | (-2, 0, -2) | 上表面+Y；見索引 | WoodDark | 無 |
| 112 | `scaffold_small_high.gltf.glb` | 木造平台與樓梯 | 木平台 | (2, 4.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 113 | `scaffold_small_high_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 5.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 114 | `scaffold_small_high_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 5.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 115 | `scaffold_small_high_long.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 4.1, 2) | (-2, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 116 | `scaffold_small_high_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 5.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 117 | `scaffold_small_high_railing_long.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 5.1, 2) | (-2, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 118 | `scaffold_small_low.gltf.glb` | 木造平台與樓梯 | 木平台 | (2, 0.2, 2) | (-1, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 119 | `scaffold_small_low_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 1.2, 2) | (-1, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 120 | `scaffold_small_low_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 1.2, 2) | (-1, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 121 | `scaffold_small_low_long.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 0.2, 2) | (-2, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 122 | `scaffold_small_low_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 1.2, 2) | (-1, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 123 | `scaffold_small_low_railing_long.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 1.2, 2) | (-2, -0.1, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 124 | `scaffold_small_medium.gltf.glb` | 木造平台與樓梯 | 木平台 | (2, 2.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 125 | `scaffold_small_medium_cornerLeft.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 3.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 126 | `scaffold_small_medium_cornerRight.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 3.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 127 | `scaffold_small_medium_long.gltf.glb` | 木造平台與樓梯 | 木平台 | (4, 2.1, 2) | (-2, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 128 | `scaffold_small_medium_railing.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (2, 3.1, 2) | (-1, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 129 | `scaffold_small_medium_railing_long.gltf.glb` | 木造平台與樓梯 | 木平台／護欄 | (4, 3.1, 2) | (-2, 0, -1) | 上表面+Y；見索引 | WoodDark | 無 |
| 130 | `scaffold_stairs.gltf.glb` | 木造平台與樓梯 | 木平台／梯子 | (2, 2.1, 2.2) | (-1, 0, -1.1) | 上表面+Y；見索引 | WoodDark | 無 |
| 131 | `shield_common.gltf.glb` | 武器與裝備 | 盾／可放武器架；不是人物 | (0.6879, 0.6879, 0.13) | (-0.3439, -0.3439, -0.0283) | 保留原方向；見索引 | BrownDark, Stone, White | 無 |
| 132 | `shield_rare.gltf.glb` | 武器與裝備 | 盾／可放武器架；不是人物 | (0.7004, 0.8742, 0.3635) | (-0.3501, -0.4945, -0.1545) | 保留原方向；見索引 | Gold, White, Red | 無 |
| 133 | `shield_uncommon.gltf.glb` | 武器與裝備 | 盾／可放武器架；不是人物 | (0.7567, 0.8359, 0.1991) | (-0.3783, -0.4592, -0.1162) | 保留原方向；見索引 | Metal, BrownDark | 無 |
| 134 | `spellBook.gltf.glb` | 煉金與魔法用品 | 攤開書本／桌面陳設 | (0.7796, 0.3222, 0.4888) | (-0.3898, -0.1816, -0.2572) | 上表面+Y／XZ平放 | BrownDark, White, Metal, Red | 無 |
| 135 | `staff_common.gltf.glb` | 武器與裝備 | 法杖／可放武器架；不是人物 | (0.2111, 0.9065, 0.2062) | (-0.1002, -0.4319, -0.106) | 長軸Y；握柄向−Y | Green, WoodDark | 無 |
| 136 | `staff_rare.gltf.glb` | 武器與裝備 | 法杖／可放武器架；不是人物 | (0.2153, 1.1622, 0.2211) | (-0.1077, -0.4488, -0.1105) | 長軸Y；握柄向−Y | White, Gold, Red | 無 |
| 137 | `staff_uncommon.gltf.glb` | 武器與裝備 | 法杖／可放武器架；不是人物 | (0.2607, 1.1224, 0.2607) | (-0.1237, -0.451, -0.137) | 長軸Y；握柄向−Y | BrownDark, Purple | 無 |
| 138 | `stairs.gltf.glb` | 地面、樓梯與柱體 | 石階模組 | (2.6, 4.7, 6) | (-1.3, 0, -3) | 上表面+Y；見索引 | Stone | 無 |
| 139 | `stairs_wide.gltf.glb` | 地面、樓梯與柱體 | 石階模組 | (4.6, 4.7, 6) | (-2.3, 0, -3) | 上表面+Y；見索引 | Stone | 無 |
| 140 | `stool.gltf.glb` | 家具與書籍 | 木凳 | (0.7466, 0.4556, 0.7531) | (-0.3737, 0, -0.3802) | 保留原方向；見索引 | BrownDark | 無 |
| 141 | `sword_common.gltf.glb` | 武器與裝備 | 劍／可放武器架；不是人物 | (0.3937, 1.2791, 0.1267) | (-0.1969, -0.1703, -0.0634) | 長軸Y；握柄向−Y | Stone, WoodDark, StoneDark | 無 |
| 142 | `sword_rare.gltf.glb` | 武器與裝備 | 劍／可放武器架；不是人物 | (0.7422, 1.8953, 0.1914) | (-0.3711, -0.2117, -0.0957) | 長軸Y；握柄向−Y | White, Metal, Gold, Red | 無 |
| 143 | `sword_uncommon.gltf.glb` | 武器與裝備 | 劍／可放武器架；不是人物 | (0.4102, 1.5126, 0.1914) | (-0.2051, -0.2038, -0.0957) | 長軸Y；握柄向−Y | Metal, BrownDark, Stone | 無 |
| 144 | `tableLarge.gltf.glb` | 家具與書籍 | 木桌／用品工作台 | (2.9977, 0.7075, 1.7151) | (-1.4995, 0, -0.8536) | 保留原方向；見索引 | BrownDark | 無 |
| 145 | `tableMedium.gltf.glb` | 家具與書籍 | 木桌／用品工作台 | (1.9977, 0.7075, 1.2) | (-0.9995, 0, -0.6) | 保留原方向；見索引 | BrownDark | 無 |
| 146 | `tableSmall.gltf.glb` | 家具與書籍 | 木桌／用品工作台 | (0.9977, 0.7074, 1.0782) | (-0.4995, 0, -0.5391) | 保留原方向；見索引 | BrownDark | 無 |
| 147 | `tileBrickA_large.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (6.05, 1.06, 6.05) | (-3.025, 0, -3.025) | 上表面+Y／XZ平放 | StoneDark, Stone | 無 |
| 148 | `tileBrickA_medium.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (4.05, 1.06, 4.05) | (-2.025, 0, -2.025) | 上表面+Y／XZ平放 | StoneDark, Stone | 無 |
| 149 | `tileBrickA_small.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (2.05, 1.06, 2.05) | (-1.025, 0, -1.025) | 上表面+Y／XZ平放 | StoneDark, Stone | 無 |
| 150 | `tileBrickB_large.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (6, 1, 6) | (-3, 0, -3) | 上表面+Y／XZ平放 | Stone | 無 |
| 151 | `tileBrickB_largeCrackedA.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (6, 1, 6) | (-3, 0, -3) | 上表面+Y／XZ平放 | Stone | 無 |
| 152 | `tileBrickB_largeCrackedB.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (6, 1.4081, 6) | (-3, 0, -3) | 上表面+Y／XZ平放 | Stone, Mud, WoodDark | 無 |
| 153 | `tileBrickB_medium.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (4, 1, 4) | (-2, 0, -2) | 上表面+Y／XZ平放 | Stone | 無 |
| 154 | `tileBrickB_small.gltf.glb` | 地面、樓梯與柱體 | 厚石磚地板模組；需上表面對齊 | (2, 1, 2) | (-1, 0, -1) | 上表面+Y／XZ平放 | Stone | 無 |
| 155 | `tileSpikes.gltf.glb` | 陷阱 | 地刺箱／陷阱裝飾；無觸發動畫 | (2, 2, 2) | (-1, -1, -1) | 保留原方向；見索引 | Stone, WoodDark, Metal | 無 |
| 156 | `tileSpikes_large.gltf.glb` | 陷阱 | 地刺箱／陷阱裝飾；無觸發動畫 | (4, 2, 4) | (-2, -1, -2) | 保留原方向；見索引 | Stone, WoodDark, Metal | 無 |
| 157 | `tileSpikes_shallow.gltf.glb` | 陷阱 | 地刺箱／陷阱裝飾；無觸發動畫 | (2, 1, 2) | (-1, 0, -1) | 保留原方向；見索引 | Stone, WoodDark, Metal | 無 |
| 158 | `torch.gltf.glb` | 照明框架與掛飾 | 火把／壁掛托架；無火焰或光源 | (0.6436, 1.3639, 0.6436) | (-0.3218, -0.6819, -0.3218) | 保留原方向；見索引 | BrownDark, Metal, WoodDark | 無 |
| 159 | `torchWall.gltf.glb` | 照明框架與掛飾 | 火把／壁掛托架；無火焰或光源 | (0.6436, 1.5674, 1.133) | (-0.3218, -0.5666, -0.1753) | Y立架；托臂伸+Z | BrownDark, Metal, WoodDark, StoneDark | 無 |
| 160 | `trapdoor.gltf.glb` | 陷阱 | 地板活門；無開啟動畫 | (1.9411, 0.2875, 1.9411) | (-0.9693, 0, -1.9691) | 保留原方向；見索引 | Stone, WoodDark | 無 |
| 161 | `wall.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 1.5) | (-2, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 162 | `wallCorner.gltf.glb` | 建築牆體與門 | 石牆模組／轉角或接合 | (2.75, 4, 2.75) | (-2, 0, -0.75) | Y立面；多向接合 | Stone, StoneDark | 無 |
| 163 | `wallDecorationA.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 2.1729) | (-2, 0, -1.0864) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 164 | `wallDecorationB.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 2) | (-2, 0, -0.9999) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 165 | `wallIntersection.gltf.glb` | 建築牆體與門 | 石牆模組／轉角或接合 | (4, 4, 4) | (-2, 0, -2) | Y立面；多向接合 | Stone, StoneDark | 無 |
| 166 | `wallSingle.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 0.75) | (-2, 0, 0) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 167 | `wallSingle_broken.gltf.glb` | 建築牆體與門 | 石牆模組／破損 | (4, 4, 0.75) | (-2, 0, 0) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 168 | `wallSingle_corner.gltf.glb` | 建築牆體與門 | 石牆模組／轉角或接合 | (2, 4, 2) | (-2, 0, 0) | Y立面；多向接合 | Stone, StoneDark | 無 |
| 169 | `wallSingle_decorationA.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 1.0865) | (-2, 0, 0) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 170 | `wallSingle_decorationB.gltf.glb` | 建築牆體與門 | 石牆模組 | (4, 4, 1.0001) | (-2, 0, 0) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 171 | `wallSingle_door.gltf.glb` | 建築牆體與門 | 石牆模組／門洞 | (6, 4, 0.7542) | (-3, 0, -0.0042) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 172 | `wallSingle_split.gltf.glb` | 建築牆體與門 | 石牆模組／轉角或接合 | (4, 4, 2) | (-2, 0, 0) | Y立面；多向接合 | Stone, StoneDark | 無 |
| 173 | `wallSingle_window.gltf.glb` | 建築牆體與門 | 石牆模組／窗洞 | (6, 4, 0.8142) | (-3, 0, -0.0642) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 174 | `wallSingle_windowGate.gltf.glb` | 建築牆體與門 | 石牆模組／鐵柵或鐵窗 | (6, 4, 0.8142) | (-3, 0, -0.0642) | Y立面；主要面±Z | Stone, StoneDark, Black | 無 |
| 175 | `wallSplit.gltf.glb` | 建築牆體與門 | 石牆模組／轉角或接合 | (4, 4, 2.75) | (-2, 0, -0.75) | Y立面；多向接合 | Stone, StoneDark | 無 |
| 176 | `wall_broken.gltf.glb` | 建築牆體與門 | 石牆模組／破損 | (4, 4, 1.5) | (-2, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 177 | `wall_door.gltf.glb` | 建築牆體與門 | 石牆模組／門洞 | (6, 4, 1.5) | (-3, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 178 | `wall_end.gltf.glb` | 建築牆體與門 | 石牆模組 | (2.2, 4, 1.5) | (0, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 179 | `wall_end_broken.gltf.glb` | 建築牆體與門 | 石牆模組／破損 | (3.0462, 4, 1.5) | (0, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 180 | `wall_gate.gltf.glb` | 建築牆體與門 | 石牆模組／鐵柵或鐵窗 | (4, 4, 1.5) | (-2, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark, Black | 無 |
| 181 | `wall_gateCorner.gltf.glb` | 建築牆體與門 | 石牆模組／鐵柵或鐵窗 | (2.75, 4, 2.75) | (-2, 0, -0.75) | Y立面；多向接合 | Stone, StoneDark, Black | 無 |
| 182 | `wall_gateDoor.gltf.glb` | 建築牆體與門 | 石牆模組／鐵柵或鐵窗 | (4, 4, 1.5) | (-2, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark, Black | 無 |
| 183 | `wall_window.gltf.glb` | 建築牆體與門 | 石牆模組／窗洞 | (6, 4, 1.5) | (-3, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark | 無 |
| 184 | `wall_windowGate.gltf.glb` | 建築牆體與門 | 石牆模組／鐵柵或鐵窗 | (6, 4, 1.5) | (-3, 0, -0.75) | Y立面；主要面±Z | Stone, StoneDark, Black | 無 |
| 185 | `weaponRack.gltf.glb` | 家具與書籍 | 空木武器架；需另放武器 | (1.1554, 0.7818, 0.6538) | (-0.5755, -0.0018, -0.4469) | 保留原方向；見索引 | BrownDark | 無 |

## 暫存與交接檔案

- 完整量測 JSON：[kitkay_inventory_raw.json](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_inventory_raw.json)。
- 原始 GLB 結構摘要：[kitkay_gltf_metadata.json](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_gltf_metadata.json)。
- 本輪來源 SHA256 快照：[kitkay_source_manifest.json](C:/Users/LeeDong/.codex/visualizations/2026/10/03/01a10081-9bc7-7c82-8c12-4295ae71f90b/kitkay_source_manifest.json)。
- 暫存專案：`C:/Users/LeeDong/AppData/Local/Temp/fgj_kitkay_inventory`；內含 `measure_inventory.gd`、`inventory_raw.json`、`gltf_metadata.json`、`source_manifest.json` 與匯入／載入／GPU 日誌。來源素材只複製到此處，沒有回寫 .import 或共享快取。
- 載入結果 `MODEL_LOAD_COUNT 185 FAILED []`，10 頁及候選頁 GPU save 全部回傳 0。工具初始化有使用者資料目錄／憑證存放區權限訊息，未造成模型載入或截圖失敗；無 script／shader 解析錯誤。

下一步：總監確認本批素材所屬房間，使用者確認人物的確切路徑；之後才指定 wrapper／子場景歸屬與配置範圍。巢穴、鋪墊及其他缺件仍照共用素材表追蹤。本文件保存本輪初始快照 185 件，不表示後續新複製的素材已盤點。
