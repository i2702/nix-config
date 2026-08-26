---
name: typescript-react-standards
description: >-
  TypeScript または React のコードを読む・書く・修正する・レビューするときに必ず使う
  対象ファイルが .ts / .tsx / .jsx であるとき、package.json に typescript や react が含まれるプロジェクトであるとき、
  コンポーネント・hooks・props・型定義・状態管理・Next.js・Vite などに言及されたときは、
  ユーザーが明示的に指示しなくても必ずこのスキルを参照すること。
  小さな修正やリファクタリング、コードレビュー、新規ファイル作成のいずれにも適用する。
---

# TypeScript / React コーディング標準

TypeScript / React のコードに触れるすべての作業で、以下のルールに従う。
既存コードがこのルールに反している場合、依頼されたタスクの範囲内では従い、範囲外の書き換えは提案に留める。

## パッケージ

- package.jsonからリポジトリ中で使うべき技術スタックを把握する
- 管理はpnpmで行う

## 作業手順

- 最初にテストの存否を確認し、不在や不足があれば作成する。ユーザーのレビューを要請する
- 開発する。CLAUDE.mdにあるコーディングの原則を遵守する
- 作業の終了前にlint, formatを行いエラーがなくなるようにする

## TypeScript

- 明示的な指示がない場合はclassの利用を避ける。classでしか表現しえないものがあればユーザーに提案をする
- default exportは行わない。lazy loadなど不可避な場合は使ってよい
- barrel exportは行わない
- neverthrowに従い、nullableとundefinedableを原則使わない

## React

以下のディレクトリ構成でコードを分類する
(パッケージルート)/src以下に以下のサブディレクトリを作る

- component/ : コンポーネント。3行以下ですむ単純なフックは書いてもよいが、原則的にはhook/にフックは移譲する
- hook/ : カスタムフック。stateを意味がある単位でまとめたり、useEffectと相互作用するフックをまとめる
- store/ : カスタムフックではない状態管理をまとめる。機能ないで複数のコンポーネントにわたっていて、かつ更新が複雑な場合はカスタムフックではなくJotaiで状態管理をする
- util/ : 純粋関数や定数値をまとめる

ただし、機能を横断するコード以外は、機能単位でコードをまとめる
(パッケージルート)/src/feature/(機能ごとの名前)/(componentなど再帰的にサブディレクトリ)

## Jotai

- Jotaiを利用しているパッケージでは、機能を横断する状態についてはJotaiで管理する
- ひとつのatomで状態を記述するのではなく、プリミティブなatomを複数個作り、derrived atomを作って対応する
- 読み書きには制約をもうける。read-only atom, write-only atomで設計する
- API実行をともなうときはtanskackjotai-tanstack-queryを使い、React Query & Jotaiで実装する
- 複雑な状態遷移を行うときはXStateを併用する

## 命名・ファイル構成

- コンポーネントファイル: <!-- 例: PascalCase.tsx、1ファイル1コンポーネント -->
- hooks: `use` プレフィックス、`hooks/` ディレクトリに置く

## テスト

- テストファイルは元のソースと同じ階層に、同じ名前で作成する（FooBarButton.tsx -> FooBarButton.test.tsx）
- テストフレームワーク: Vitest, React Testing Library を使う
- 主要な画面についてはVitestでVRTを作成する
- コンポーネントのテストは実装詳細ではなく振る舞いをテストする（`getByRole` を優先）
- コールバックや状態遷移などの振るまいについてはhook層で行う
    - Jotaiを利用している場合はそちらの遷移の確認も行う

