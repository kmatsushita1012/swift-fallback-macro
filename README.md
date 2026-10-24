# swift-fallback-macro

`@Fallback` は、指定した Optional の KeyPath またはクロージャを優先して読み取り、参照先が `nil` のときだけローカル値を返す Swift マクロです。書き込みはローカル値だけを更新します。

## 要件

- Swift 6.4 以降
- iOS 16、macOS 13、tvOS 16、watchOS 9 以降

## Swift Package Manager

依存関係に追加します。

```swift
dependencies: [
    .package(url: "https://github.com/kmatsushita1012/swift-fallback-macro", from: "0.1.0")
]
```

利用するターゲットに `Fallback` を追加します。

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Fallback", package: "swift-fallback-macro")
    ]
)
```

## 使い方

```swift
import Fallback

struct Parent {
    var child: Child?
}

struct State {
    let parent: Parent

    @Fallback(\State.parent.child)
    var child: Child

    init(parent: Parent, initialChild: Child) {
        self.parent = parent
        self._child = initialChild
    }
}
```

KeyPath のRoot型は明記してください。仕様書の `@Fallback(\.parent.child)` は現行SwiftではRoot型を推論できず、マクロ引数としてコンパイルできないため、`@Fallback(\State.parent.child)` の形を使います。KeyPath末尾の型はプロパティ型の Optional である必要があり、型の整合性はSwiftコンパイラが検査します。

クロージャで選択する場合は、`select:` 引数を使い、Root型を引数に注釈します。

```swift
@Fallback(select: { (state: State) in state.parent.child })
var child: Child
```

クロージャの戻り値もプロパティ型の Optional である必要があります。クロージャは読み取りごとに呼び出されます。

参照先が非 `nil` なら参照先を返します。参照先が `nil` ならローカルのfallback値を返します。`state.child = value` はローカル値だけを更新します。ローカル値は `self._child` として初期化してください。

## `@Shared` とTCA

`@Shared` の値は読み取りごとに評価されるため、共有値の更新が次回の読み取りに反映されます。TCA の `@ObservableState` で使う場合は、同じプロパティに `@ObservationStateIgnored` を付けてください。マクロは生成アクセサーにTCAのObservation通知を組み込みます。

```swift
@Reducer
struct Feature {
    @ObservableState
    struct State {
        @Shared var parent: Parent

        @Fallback(\Feature.State.parent.child)
        @ObservationStateIgnored
        var child: Child

        init(parent: Shared<Parent>, initialChild: Child) {
            self._parent = parent
            self._child = initialChild
        }
    }
}
```

TCA と swift-sharing はライブラリの実行時依存ではなく、このパッケージ内の連携テストでのみ使用します。利用側がこれらを使う場合は、利用側自身のターゲットに追加してください。

通常のテストとマクロ展開テストは `swift test` で実行できます。TCA / swift-sharing 連携テストは独立したテスト用パッケージで実行します。

```sh
swift test --package-path Tests/Integration
```

## 制約

- `struct` 内の、明示的な型を持つ単一の `var` Stored Property に適用します。
- KeyPathまたは`select:`クロージャはOptional値を返す必要があります。
- `let`、計算プロパティ、複数宣言を含むプロパティには適用できません。
- fallbackストレージは `_<propertyName>` として生成されます。型のinitializerから初期化してください。
- 既存プロパティとfallbackストレージ名が重複すると、Swiftコンパイラの再宣言エラーになります。

## ライセンス

MIT
