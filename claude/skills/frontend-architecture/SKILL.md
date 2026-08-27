---
name: frontend-architecture
description: TypeScript x React の設計判断を行うときに使う。コンポーネント分割、状態管理の置き場所、型設計、ディレクトリ構成、データ取得層の設計、再利用可能な UI の抽象化などを決める場面が対象。新規の React 画面/機能を設計するとき、既存コンポーネントをリファクタリングするとき、props や state の持ち方に迷ったとき、`.tsx` / `.ts` の React コードを新しく書き始める前に読む。手動では /frontend-architecture で呼び出す。
---

# Frontend Architecture (TypeScript x React)

WEBフロントエンドの設計を行うとき、以下の構成を使う

## 適用範囲

- 対象: TypeScript x Reactのアプリケーション
- 対象外: バックエンドTypeScript, React以外のフレームワークを使ったフロントエンド

## 判断基準

### 技術スタック

- Vite+
- pnpm
- TypeScript
- Jotai
- tailwind
- TanStack Router
- Tanstack Query(jotai-tanstack-query)
- neverthrow


### コンポーネント分割

propsに対して決定的なコンポーネントに切り出すようにする

### 状態管理

Jotaiを利用する
write-only atomやread-only atomで可視範囲の制御をする
derrived atomを使い、プリミティブなatomの数を最小化する

### 型設計

nullable, undefinedableな型を作らない
API通信や外部サービスの値は検査して型を確定する

### ディレクトリ構成

以下の構成を基本とする。まずこれらをsrc/以下に配置する

- component / JSXコンポーネント
- hook / Reactカスタムフック
- service / API通信や外部サービスとのやりとり
- store / 状態管理のコード。主にJotai
- constant / 定数
- helper / 上記以外に分類される純粋関数

そして、src/以下にfeature/ディレクトリを作成し、機能ごとにサブディレクトリを作成する
機能ディレクトリ以下には上記のcomponent, hook, ....ディレクトリを作成する

## やらないこと

ユーザーの許可なく上記以外のパッケージのインストールや、ディレクトリ配置の変更を行わない

