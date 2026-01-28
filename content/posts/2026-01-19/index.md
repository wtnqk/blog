---
title: "webassemblyで画像フィルタをつくる"
date: 2026-01-19
description: "zigでwebassembly"
tags:
  - webassembly
  - zig
---

この記事は以前企業ブログに寄稿したものとなります

## [リンク](https://tec.tecotec.co.jp/entry/2025/12/03/000000)

# 1. WebAssemblyとは何か

── WASMがなぜ使われるのか、どこが嬉しいのか

WebAssembly（WASM）はもう珍しい技術ではなく、すでに**普段使用している主要Webサービスの裏側で動いています**

- **Google Meet**：背景ぼかし・ノイズ除去
- **Google Earth Web**：3D処理のコア

「JavaScriptじゃ重い画像処理や数学処理を軽くするための技術」…  
として広く紹介されていますが、個人的には**設計の自由度が上がること**にあると考えています

<!-- more -->

MDNはWebAssemblyを次のように説明しています：

> **“WebAssembly（Wasm）は、ネイティブに近いパフォーマンスで実行されるコンパクトなバイナリフォーマット”**  
> — <https://developer.mozilla.org/ja/docs/WebAssembly>

> **“WebAssembly コードは安全な、サンドボックス化された実行環境で実行される”**  
> — <https://developer.mozilla.org/ja/docs/WebAssembly/Concepts>

公式仕様書では、以下のように定義されています：

> **“WebAssembly defines a portable, efficient and safe low-level bytecode.”**  
> — <https://webassembly.github.io/spec/core/intro/introduction.html>

また、内部実行モデルについて：

> **“The execution semantics of WebAssembly are defined using a stack machine.”**  
> — <https://webassembly.github.io/spec/core/exec/instructions.html>

つまりWebAssemblyは、

- ブラウザで直接実行される
- スタックマシンベースの **仮想命令セット（virtual ISA）**
- 安全なサンドボックス上で動く
- コンパクトで高速なバイトコード形式

といった特徴を備えた実行環境です

---

# 2. WASMで画像フィルタ

JS→WASM→JSの流れでCanvasに反映します

```
HTML (UI)
  ↓
JavaScript (画像読込・Canvas)
  ↓
WebAssembly (ピクセル処理)
  ↓
JavaScript (結果描画)
```

JavaScriptはUI/Canvasのみ担当し、  
**ピクセル処理はWASMが行う**という責務分離が実現します

[f:id:teco_wata:20251127100525g:plain]

---

# 3. WASM側の主要ソースコード

以下は**画像フィルタを行うロジックのみ抜粋したzigプログラム**です

今回zigを採用した理由は**ツールチェーンがシンプル**、**言語仕様が簡単**というのが大きな理由となります

### グレースケール処理

今回、グレースケール関数は**整数近似版**で作成しております

#### 整数近似版

[tex: Y \approx \frac{30\,R + 59\,G + 11\,B}{100}]

### ソースコード

```zig
const std = @import("std");

// =======================================================
// 256 MiB の作業バッファをWebAssembly線形メモリ上に確保
// JS側はUint8Array(memory.buffer, ptr, len) として参照できる
// =======================================================
var image_buffer: [256 * 1024 * 1024]u8 = undefined;

// バッファ先頭アドレスを JS に渡す
export fn get_buffer_ptr() [*]u8 {
    return &image_buffer;
}

// 総バイト数を返す
export fn get_buffer_len() usize {
    return image_buffer.len;
}

// =======================================================
// グレースケール処理
// 1ピクセル = RGBA の 4バイト
// R,G,B を輝度 Y(0.30R+0.59G+0.11B) で置き換える
// =======================================================
export fn apply_grayscale(ptr: [*]u8, len: usize) void {
    ensure_capacity(len) catch return;

    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r = ptr[i + 0];
        const g = ptr[i + 1];
        const b = ptr[i + 2];

        const y: u8 = @intCast(u8,
            (@as(u16, r) * 30 +
             @as(u16, g) * 59 +
             @as(u16, b) * 11) / 100,
        );

        ptr[i + 0] = y;
        ptr[i + 1] = y;
        ptr[i + 2] = y;
    }
}
```

### ポイント

- `export fn ...`
  - `export`が付いた関数だけがWebAssemblyモジュールの「外から呼べるAPI」になります
  - 今回は`get_buffer_ptr`/`get_buffer_len`/`apply_grayscale`がJS 側から呼び出せる関数です

- `image_buffer: [256 * 1024 * 1024]u8`
  - 256MiB分のバイト配列を**WASMの線形メモリ上に確保**しています
  - JSから見えるのは`WebAssembly.Memory`という「1本の巨大な ArrayBuffer」なので、  
    その中の一部を「画像用バッファ」として使っているイメージです
  - 画像のRGBAはすべてここに書き込み／読み出しします

- `get_buffer_ptr`/`get_buffer_len`
  - JS側が「どこから」「どこまで」を触ればいいかを知るためのgetterです
  - `ptr`は線形メモリ内の先頭オフセット、`len`はその長さ（バイト数）です
  - JSでは`new Uint8Array(memory.buffer, bufferPtr, bufferLen)`のようにしてアクセスします

- `apply_grayscale(ptr, len)`
  - `ptr`には「WASM線形メモリ内の開始位置」が入っていて、`len`はそのバイト数です
  - `while (i + 3 < len) : (i += 4)`で 4バイトずつ進みながらRGBAを1ピクセル単位で処理します
  - R/G/Bを整数近似した輝度`Y`に置き換え、A（アルファ）は変更しません
  - **ここが「JSから切り出したいロジックの本体」**であり、後から別のフィルタを追加する場合もこの関数を増やしていくだけで済みます

### WASMモジュールのコンパイル方法（Zig）

今回のZigソースは次のようにコンパイルして、ブラウザから読み込める`image_filter.wasm`を生成しています

```bash
◎ zig build-exe src/root.zig \
          -target wasm32-freestanding \
          -OReleaseSmall \
          -fno-entry \
          -fstrip \
          -rdynamic \
          -femit-bin=image_filter.wasm
```

各オプションの意味は以下の通りです：

- `build-exe`
  - Zigのソースから「実行可能なバイナリ（今回はWASM）」を作るモードです
- `-target wasm32-freestanding`
  - ターゲットを「OSなしの32bitWASM」に指定します
  - ブラウザで動くWebAssemblyはこのターゲットになります
- `-O ReleaseSmall`
  - 最適化レベル
  - WASMのサイズを小さくしつつリリース用に最適化します
- `-fno-entry`
  - main関数を持たない「ライブラリ的なモジュール」としてビルドする指定です
  - 今回はJSから`export fn`を呼ぶだけなので、エントリポイントは不要です
- `-fstrip`
  - デバッグ情報のような情報を削って、バイナリサイズを小さくします
- `-rdynamic`
  - エクスポートのシンボル名を残しておくためのオプションです
  - `export fn apply_grayscale`などの関数を JS から参照できるようにします
- `-femit-bin=image_filter.wasm`
  - 出力ファイル名を明示的に`image_filter.wasm`にしています
  - こうして生成したファイルをフロント側で`fetch("image_filter.wasm")`します

---

# 4. HTML/JS側：WASM 呼び出し部分の抜粋

### a. ソースコード

```html
<script>
  async function initWasm() {
    // WASM読み込み
    const bytes = await fetch("image_filter.wasm").then((r) => r.arrayBuffer());
    const { instance } = await WebAssembly.instantiate(bytes, {});
    const wasm = instance.exports;

    // 線形メモリにアクセス
    const memory = wasm.memory;
    const bufferPtr = wasm.get_buffer_ptr();
    const bufferLen = wasm.get_buffer_len();

    // Uint8Array(memory.buffer, offset, length)で
    // WASM側のimage_bufferを直接操作できる
  }
</script>
```

WASMを呼び出すためにinitWasm関数の中では、次のことを行います

#### **.wasmファイルを取得してインスタンス化する**

```javascript
const bytes = await fetch("image_filter.wasm").then((r) => r.arrayBuffer());
const { instance } = await WebAssembly.instantiate(bytes, {});
const wasm = instance.exports;
```

- `fetch`でバイナリを取得し、`WebAssembly.instantiate`でモジュールをインスタンス化します
  - `instance.exports`にZig側の`export fn`や`memory`がまとまっているので、ここから取り出します

#### **線形メモリにアクセスする**

```javascript
const memory = wasm.memory;
const bufferPtr = wasm.get_buffer_ptr();
const bufferLen = wasm.get_buffer_len();
```

- `memory`はWASM側の線形メモリを表すオブジェクト（中身は`ArrayBuffer`）です
  - `bufferPtr`は`image_buffer`の先頭オフセット、`bufferLen`はそのサイズです
  - 後で `new Uint8Array(memory.buffer, bufferPtr, length)`として画像データをコピーします

#### **線形メモリを通じてRGBAを受け渡しする**

```
Canvas(ImageData)
→ JS Uint8Array
→ image_buffer
→ apply_grayscale(...)
→ JS Uint8Array
→ Canvas(ImageData)
```

- 画像は一度`canvas`に描画し、`getImageData`でRGBAの配列をJS 側で取得します
  　- その配列をWASMの`image_buffer`に書き込み、`apply_grayscale`などのフィルタ関数を呼出します
  - 処理が終わったら同じ領域からRGBAを読み戻し`putImageData`で`Canvas`に描画します

### **なぜ線形メモリを自分で確保するのか**

- WebAssemblyのメモリは「1本の大きなバイト列（ArrayBuffer）」としてしか見えていない
  配列やオブジェクトをそのまま引数で渡すことはできず、**「ポインタ（オフセット）」と「長さ」**という形で表現する必要があります
- Zig側で`image_buffer`を1つ決めておき、**「この領域はJSと共有して画像をやり取りする」**という役割を持たせています
- JS側からは毎回malloc的なことをせず、**「決まったバッファに書いて→同じバッファから読む」**だけで済むため、コードがシンプルになる

この「線形メモリにバッファを確保してJSと共有する」パターンが、WASMで画像や音声などのバイナリデータを扱うときの基本形になります

---

# 5. WASMを使うことで得られる設計上のメリット

WebAssembly（WASM）を組み込む最大の利点は、  
**UIとロジックの責務が自然に分離され、アプリ全体の構造が安定する**点にあります

フロントエンドではJavaScriptがUI/Canvas/イベント処理に専念し、  
画像処理のようなロジックはWebAssemblyが担当します

この構造には次のようなメリットがあります：

---

### UIとロジックの完全な分離

- JavaScriptはUI・Canvas・ファイル読み込みのみ担当
- ピクセル処理はWASMにまるごと任せられる
- フィルタが増えるほど分離効果が大きく、**JSが肥大化しない**

---

### 高速化余地が広い（SIMD/並列化）

WASMは常に拡張が進んでおり、画像処理とも相性が良い：

- **WebAssembly SIMD**（128-bit ベクトル演算）
- **WebAssembly Threads**（並列フィルタ）
- **WebWorker + WASM** による並列パイプライン

---

### “得意分野”をフロントに持ち込める

JavaScriptでは書きにくい/読みにくい処理を、**低レイヤ寄りの言語で記述し、安全なサンドボックス内**で動かせる

---

### トータルとして得られる “設計の自由度”

以上の要素が組み合わさることで、

- JSとWASMがそれぞれの責務に集中
- 規模が大きくなってもコードが崩れない

環境が実現します

---

# 6. まとめ

本記事では、WebAssemblyを用いてブラウザ上で動作する簡単な画像フィルタを実装しながら、WASMがどのような技術なのかを整理しました

WebAssemblyは“**JavaScriptを高速化するための仕組み**”という以上に、  
**UIとロジックを自然に分離し、フロントエンドの設計をシンプルに保つための土台**を提供してくれます

実際に、画像のピクセル操作のような処理はJavaScriptだけで書くと複雑化していきますが、低レイヤ寄りの言語でWASMへコンパイルすることで、ブラウザでも安全に、かつ安定した速度で実行できることが確認できました

今回紹介した画像フィルタはとても小さな例ですが、WebAssemblyの特徴である「仮想 ISA」「線形メモリ」「サンドボックス」という基本要素がすべて登場しており、WASMの仕組みを理解するための良い入口になります

- **UI**/**Canvas**/**イベント処理**：**JavaScript**
- **ピクセル処理**：**WebAssembly**

という責務の分離が自然に成立し、さらに必要に応じて**SIMDや並列化による性能向上**にも発展できる柔軟性を持ちます

「フロントエンドの中に、低レイヤ向け言語の得意分野を持ち込める」  
という体験は、WASMならではの魅力だと考えています

興味があれば、性能最適化、WASI（ブラウザ外のWASM）への応用など、さらに深いテーマにも挑戦してみてください

# おまけ

今回作成したソースコードです

### **zigバージョン**

```
◎ zig version
0.16.0-dev.1458+755a3d957
```

### **ファイルツリー**

```
└── src
    ├── image_filter.wasm <- zigのwasmコンパイルで生成
    ├── main.zig
    ├── root.zig
    ├── index.html
    └── main.js
```

### **main.zig**

```zig
const std = @import("std");
const image_filter = @import("image_filter");
const builtin = @import("builtin");

pub fn main() !void {
    var pixels = [_]u8{
        255, 128, 0, 200,
        40, 60, 80, 255,
    };

    image_filter.apply_grayscale(&pixels, pixels.len);
    image_filter.apply_invert(&pixels, pixels.len);

    if (builtin.os.tag != .freestanding) {
        const stdout = std.io.getStdOut().writer();
        try stdout.print(
            "Inverted grayscale sample: [{d},{d},{d},{d}] [{d},{d},{d},{d}]\n",
            .{ pixels[0], pixels[1], pixels[2], pixels[3], pixels[4], pixels[5], pixels[6], pixels[7] },
        );
    }
}
```

### **root.zig**

```zig
const std = @import("std");

pub const image_buffer_size: usize = 256 * 1024 * 1024;
pub export var image_buffer: [image_buffer_size]u8 = undefined;

pub export fn get_buffer_ptr() [*]u8 {
    return &image_buffer;
}

pub export fn get_buffer_len() usize {
    return image_buffer.len;
}

pub export fn ensure_capacity(len: usize) bool {
    const page = 64 * 1024;
    const current = @wasmMemorySize(0) * page;
    if (current >= len) return true;

    const extra_bytes = len - current;
    const extra_pages = std.math.divCeil(usize, extra_bytes, page) catch return false;
    const prev = @wasmMemoryGrow(0, extra_pages);
    return prev != std.math.maxInt(usize);
}

pub export fn apply_grayscale(ptr: [*]u8, len: usize) void {
    var i: usize = 0;
    while (i + 3 < len) : (i += 4) {
        const r: u8 = ptr[i + 0];
        const g: u8 = ptr[i + 1];
        const b: u8 = ptr[i + 2];

        const y: u8 = @intCast(
            (@as(u16, r) * 30 +
                @as(u16, g) * 59 +
                @as(u16, b) * 11) / 100,
        );

        ptr[i + 0] = y;
        ptr[i + 1] = y;
        ptr[i + 2] = y;
        // alpha (ptr[i+3]) is left untouched
    }
}
```

### **index.html**

```html
<!doctype html>
<html lang="ja">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>Zig WASM Image Filter Demo</title>
    <link rel="stylesheet" href="./style.css" />
  </head>
  <body>
    <h1>Zig WASM Image Filter</h1>
    <div class="controls">
      <input type="file" id="file-input" accept="image/*" />
      <button id="btn-gray" disabled>Grayscale</button>
    </div>
    <div class="canvas-row">
      <div class="canvas-wrapper">
        <span>Original</span>
        <canvas id="canvas-src" width="0" height="0"></canvas>
      </div>
      <div class="canvas-wrapper">
        <span>Filtered</span>
        <canvas id="canvas-dst" width="0" height="0"></canvas>
      </div>
    </div>
    <script src="./main.js" defer></script>
  </body>
</html>
```

### **main.js**

```javascript
"use strict";

const wasmUrl = "image_filter.wasm";

let wasmExports;
let wasmMemory;
let bufferPtr = 0;
let bufferLen = 0;

const fileInput = document.getElementById("file-input");
const btnGray = document.getElementById("btn-gray");
const canvasSrc = document.getElementById("canvas-src");
const canvasDst = document.getElementById("canvas-dst");
const ctxSrc = canvasSrc.getContext("2d");
const ctxDst = canvasDst.getContext("2d");

let currentWidth = 0;
let currentHeight = 0;
let grayscaleApplied = false;

async function loadWasm() {
  const response = await fetch(wasmUrl);
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, {});

  wasmExports = instance.exports;
  wasmMemory = wasmExports.memory;
  bufferPtr = wasmExports.get_buffer_ptr();
  bufferLen = Number(wasmExports.get_buffer_len());
}

function setButtonsEnabled(enabled) {
  btnGray.disabled = !enabled;
}

function loadImage(file) {
  const reader = new FileReader();

  reader.onload = (event) => {
    const img = new Image();

    img.onload = () => {
      currentWidth = img.width;
      currentHeight = img.height;

      canvasSrc.width = currentWidth;
      canvasSrc.height = currentHeight;
      canvasDst.width = currentWidth;
      canvasDst.height = currentHeight;

      ctxSrc.drawImage(img, 0, 0);
      ctxDst.drawImage(img, 0, 0);

      setButtonsEnabled(true);
      grayscaleApplied = false;
    };

    img.src = event.target.result;
  };

  reader.readAsDataURL(file);
}

function copyImageToWasm(imageData) {
  const requiredBytes = imageData.data.length;

  if (requiredBytes > bufferLen) {
    throw new Error("WASM buffer too small");
  }

  const u8 = new Uint8Array(wasmMemory.buffer, bufferPtr, requiredBytes);
  u8.set(imageData.data);
  return requiredBytes;
}

function copyImageFromWasm(imageData) {
  const bytes = imageData.data.length;
  const u8 = new Uint8Array(wasmMemory.buffer, bufferPtr, bytes);
  imageData.data.set(u8);
}

function applyGrayscale() {
  if (!wasmExports || currentWidth === 0 || currentHeight === 0) return;
  if (grayscaleApplied) {
    ctxDst.drawImage(canvasSrc, 0, 0);
    grayscaleApplied = false;
    return;
  }
  const imageData = ctxSrc.getImageData(0, 0, currentWidth, currentHeight);
  const bytes = copyImageToWasm(imageData);
  wasmExports.apply_grayscale(bufferPtr, bytes);
  copyImageFromWasm(imageData);
  ctxDst.putImageData(imageData, 0, 0);
  grayscaleApplied = true;
}

function registerEvents() {
  fileInput.addEventListener("change", (event) => {
    const [file] = event.target.files;
    if (!file) return;
    setButtonsEnabled(false);
    loadImage(file);
  });
  btnGray.addEventListener("click", applyGrayscale);
}
async function init() {
  try {
    await loadWasm();
    registerEvents();
  } catch (error) {
    console.error("Failed to load WASM:", error);
  }
}
document.addEventListener("DOMContentLoaded", init);
```

### テコテックの採用活動について

テコテックでは新卒採用、中途採用共に積極的に募集をしています。  
採用サイトにて会社の雰囲気や福利厚生、募集内容をご確認いただけます。  
ご興味を持っていただけましたら是非ご覧ください。
[https://tecotec.co.jp/recruit/:embed:cite]
