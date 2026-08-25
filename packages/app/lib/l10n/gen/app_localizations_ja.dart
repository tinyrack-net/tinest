// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonSave => '保存';

  @override
  String get commonSaving => '保存中';

  @override
  String get commonCreate => '作成';

  @override
  String get commonCreating => '作成中…';

  @override
  String get commonConfirm => 'OK';

  @override
  String get commonDelete => '削除';

  @override
  String get commonRetry => '再試行';

  @override
  String get selectSearchPlaceholder => '選択肢を検索';

  @override
  String get selectNoResults => '一致する選択肢がありません。';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonCopy => 'コピー';

  @override
  String get commonStop => '停止';

  @override
  String get commonName => '名前';

  @override
  String get commonKind => '種類';

  @override
  String get commonDescription => '説明';

  @override
  String get commonRunning => '実行中';

  @override
  String get commonDone => '完了';

  @override
  String get commonDetails => '詳細';

  @override
  String get commonSaved => '保存しました。';

  @override
  String get commonDeleted => '削除しました。';

  @override
  String get commonCopied => 'クリップボードにコピーしました。';

  @override
  String get commonActionFailed => '問題が発生しました。';

  @override
  String get toastRegionLabel => '通知';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsLoading => '設定を読み込み中';

  @override
  String settingsRefreshFailed(String error) {
    return '設定を再読み込みできませんでした: $error';
  }

  @override
  String get settingsSectionApp => 'アプリ';

  @override
  String get settingsSectionDaemon => 'デーモン';

  @override
  String get settingsDaemonSelectLabel => 'デーモン';

  @override
  String get settingsDaemonSelectEmpty => 'デーモンなし';

  @override
  String settingsDaemonOffline(String label) {
    return '$label に接続していません。';
  }

  @override
  String get settingsCategoryGeneral => '一般';

  @override
  String get settingsCategoryProjects => 'プロジェクト';

  @override
  String get settingsCategoryAgent => 'エージェント';

  @override
  String get settingsCategoryProvider => 'プロバイダー';

  @override
  String get settingsCategoryModel => 'モデル';

  @override
  String get settingsCategoryPermission => '権限';

  @override
  String get settingsCategoryDaemon => 'デーモン';

  @override
  String get settingsCategoryAdvanced => '詳細設定';

  @override
  String get advancedResetTitle => 'すべてのデータをリセット';

  @override
  String get advancedResetDescription =>
      '内蔵デーモンのデータベース、認証情報、MCP とエージェントの設定、スキル、添付ファイルを削除し、すべてのアプリ設定と保存済みのリモートデーモントークンを消去します。worktrees フォルダー内の Git チェックアウトはディスクに残ります。';

  @override
  String get advancedResetDescriptionAppOnly =>
      'このデバイスのすべてのアプリ設定と保存済みのリモートデーモントークンを消去します。リモートデーモン側のデータはそのまま残ります。';

  @override
  String get advancedResetRunning => 'リセット中…';

  @override
  String get advancedResetConfirmTitle => 'すべてのデータをリセットしますか？';

  @override
  String get advancedResetConfirmBody =>
      '内蔵デーモンのセッション、ワークスペース登録、プロバイダー接続、エージェント、スキル、MCP サーバーがすべて削除され、あわせてすべてのアプリ設定とリモートデーモンのプロファイルおよびトークンも削除されます。デーモンは既定のポートに戻ります。Git チェックアウトはディスクに残りますが、追加し直す必要があります。この操作は取り消せません。';

  @override
  String get advancedResetConfirmAccept => 'リセット';

  @override
  String get advancedResetDone => '初期設定に戻しました。';

  @override
  String get advancedResetFailedTitle => 'リセットに失敗しました';

  @override
  String advancedResetFailedDaemonRunning(String appDisplayName) {
    return '別の $appDisplayName デーモンがデータディレクトリを使用しています。終了してからもう一度お試しください。削除されたものはありません。';
  }

  @override
  String advancedResetFailedFilesystem(String error) {
    return '一部のデーモンファイルを削除できませんでした: $error';
  }

  @override
  String advancedResetFailedIncomplete(String appDisplayName) {
    return 'デーモンのデータは削除しましたが、アプリ設定を消去できませんでした。$appDisplayName を再起動してください。';
  }

  @override
  String get settingsRequiresOnlineDaemon => '先にオンラインのデーモンに接続してください。';

  @override
  String get generalAppearanceLabel => 'テーマ';

  @override
  String get generalAppearanceSystem => 'システムに合わせる';

  @override
  String get generalAppearanceLight => 'ライト';

  @override
  String get generalAppearanceDark => 'ダーク';

  @override
  String get generalLanguageLabel => '表示言語';

  @override
  String get generalLanguageSystem => 'システムに合わせる';

  @override
  String get generalStartupSection => '起動';

  @override
  String get generalStartupAtBootLabel => 'ログイン時に起動';

  @override
  String get generalStartupMinimizedLabel => '最小化した状態で起動';

  @override
  String get generalAppearanceFailed => 'テーマを変更できませんでした。';

  @override
  String get generalLanguageFailed => '言語を変更できませんでした。';

  @override
  String get generalStartupFailed => '起動設定を変更できませんでした。';

  @override
  String generalStartupCloseNotice(String appDisplayName) {
    return 'ウィンドウを閉じても $appDisplayName はトレイで動き続けます。';
  }

  @override
  String trayTooltip(String appDisplayName) {
    return '$appDisplayName';
  }

  @override
  String get trayShowWindow => 'ウィンドウを表示';

  @override
  String get trayHideWindow => 'ウィンドウを隠す';

  @override
  String get trayOpenSettings => '設定';

  @override
  String get trayQuit => '終了';

  @override
  String get desktopMenuFile => 'ファイル';

  @override
  String get desktopMenuView => '表示';

  @override
  String get desktopMenuHelp => 'ヘルプ';

  @override
  String desktopMenuAbout(String appDisplayName) {
    return '$appDisplayName について';
  }

  @override
  String get desktopWindowMinimize => '最小化';

  @override
  String get desktopWindowMaximize => '最大化';

  @override
  String get desktopWindowRestore => '元のサイズに戻す';

  @override
  String get desktopWindowClose => 'トレイにしまう';

  @override
  String get workspacesTitle => 'ワークスペース';

  @override
  String get workspaceSidebarExpand => 'サイドバーを表示';

  @override
  String get workspaceSidebarCollapse => 'サイドバーを隠す';

  @override
  String get workspaceNewSession => '新しいセッション';

  @override
  String get sessionDefaultTitle => 'コーディングセッション';

  @override
  String get workspaceNewTab => '新しいタブ';

  @override
  String get workspaceNewTerminal => '新しいターミナル';

  @override
  String terminalTabTitle(int number) {
    return 'ターミナル $number';
  }

  @override
  String get workspaceLoading => 'ワークスペースを読み込み中';

  @override
  String get workspaceCatalogLoading => 'ワークスペース一覧を読み込み中';

  @override
  String get workspaceCatalogRefreshing => 'ワークスペース一覧を更新中…';

  @override
  String get workspaceCatalogFailed => 'ワークスペース一覧を読み込めませんでした';

  @override
  String get workspaceBranchesLoading => 'ブランチを読み込み中';

  @override
  String get workspaceBranchesFailed => 'ブランチを読み込めませんでした';

  @override
  String get workspaceRegisteringProject => 'プロジェクトを追加中…';

  @override
  String get workspaceArchiveChecking => 'ワークツリーを確認中…';

  @override
  String get workspaceCreatingWorktree => 'ワークツリーを作成中…';

  @override
  String get workspaceStartingSession => 'セッションを開始中…';

  @override
  String get workspaceTerminalStarting => 'ターミナルを起動中';

  @override
  String workspaceTerminalStartFailed(String error) {
    return 'ターミナルを起動できませんでした: $error';
  }

  @override
  String get terminalCloseTitle => 'ターミナルを終了しますか？';

  @override
  String get terminalCloseConfirm => 'このタブを閉じると、シェルと子プロセスが終了します。';

  @override
  String get terminalTerminate => '終了';

  @override
  String get terminalConnectionFailed => 'ターミナルに接続できませんでした';

  @override
  String get terminalConnecting => 'ターミナルに接続中';

  @override
  String get conversationLoading => '会話を読み込み中';

  @override
  String get conversationLoadingOlder => '以前のメッセージを読み込み中';

  @override
  String get conversationLoadOlderFailed => '以前のメッセージを読み込めませんでした';

  @override
  String get conversationLoadOlderRetry => '再試行';

  @override
  String get directoryBrowserLoading => 'ディレクトリを読み込み中';

  @override
  String get terminalCreationFailed => 'ターミナルを作成できませんでした';

  @override
  String get terminalWorktreeUnavailable =>
      'このワークツリーは利用できなくなりました。別のワークツリーを選択してください。';

  @override
  String get terminalShellStartFailed =>
      '設定されたターミナルシェルを起動できませんでした。ターミナル設定を確認して、もう一度お試しください。';

  @override
  String get terminalMenuCopy => 'コピー';

  @override
  String get terminalMenuPaste => '貼り付け';

  @override
  String get terminalMenuSelectAll => 'すべて選択';

  @override
  String get terminalMenuClearSelection => '選択を解除';

  @override
  String get terminalMenuClearScreen => '画面を消去';

  @override
  String get projectSettingsHookHeading => 'ワークツリーのライフサイクルフック';

  @override
  String get projectSettingsShellHeading => 'プロジェクトのターミナルシェル';

  @override
  String get projectSettingsShellHelp =>
      'このプロジェクトで開くターミナルについて、デーモンホストのシェルを上書きします。実行ファイルを空のままにすると、ホストの既定値を使います。';

  @override
  String get projectSettingsShellExecutable => 'シェルの実行ファイル';

  @override
  String get projectSettingsShellArguments => 'シェルの引数（1 行に 1 つ）';

  @override
  String get projectSettingsHostShellHeading => 'デーモンホストの既定シェル';

  @override
  String get projectSettingsHostShellHelp =>
      'プロジェクト側で上書きしないかぎり、このデーモンホストのすべてのプロジェクトで使われます。実行ファイルを空のままにすると、OS の既定値を使います。';

  @override
  String get workspaceAllSessions => 'すべてのセッション';

  @override
  String get workspaceSplitRight => '右に分割';

  @override
  String get workspaceSplitDown => '下に分割';

  @override
  String get workspaceResizePanes => 'ペインのサイズを変更';

  @override
  String get workspaceMoveTabToPane => 'アクティブなタブを別のペインに移動';

  @override
  String get workspaceCloseTab => 'タブを閉じる';

  @override
  String get workspaceNewWorkspace => '新しいワークスペース';

  @override
  String get workspaceWorktreeMenu => 'ワークツリーメニュー';

  @override
  String get workspaceProjectMenu => 'プロジェクトメニュー';

  @override
  String get workspaceUnregister => 'プロジェクトを削除';

  @override
  String workspaceUnregisterTitle(String name) {
    return '$name を削除しますか？';
  }

  @override
  String workspaceUnregisterBody(String appName) {
    return '$appName の一覧からは消えますが、リポジトリとファイルはディスクに残ります。';
  }

  @override
  String get workspaceArchive => 'アーカイブ';

  @override
  String get workspaceArchiveBlockedTitle => 'アーカイブできません';

  @override
  String workspaceArchiveBlockedBody(int count) {
    return '実行中のセッション $count 件を先に停止してください。';
  }

  @override
  String workspaceArchiveTitle(String name) {
    return '$name をアーカイブしますか？';
  }

  @override
  String get workspaceArchiveDirty => 'コミットしていない変更があります。\n';

  @override
  String workspaceArchiveUnpushed(int count) {
    return 'プッシュしていないコミットが $count 件あります。\n';
  }

  @override
  String get workspaceArchiveRemovesDirectory => 'チェックアウトディレクトリは削除されます。';

  @override
  String get workspaceArchiveRisky => 'リスクを確認してアーカイブ';

  @override
  String get workspaceNoDaemons => 'デーモンが設定されていません。';

  @override
  String get workspaceNoConnectedDaemons => '接続中のデーモンがありません。';

  @override
  String get workspaceNoWorkspaces => 'ワークスペースがまだありません。';

  @override
  String get workspaceNoProjectSessions => 'プロジェクトなし';

  @override
  String get workspaceNoProjectOption => 'プロジェクトなし（ホームフォルダー）';

  @override
  String get workspaceProjectChip => 'プロジェクト';

  @override
  String get workspaceProjectChipTooltip => 'プロジェクトを選択';

  @override
  String get workspaceProjectAdd => '追加';

  @override
  String get workspaceWorktreeNew => '新しいワークツリー';

  @override
  String get workspaceWorktreeLocal => 'ローカル';

  @override
  String get workspaceWorktreeChipTooltip => 'ワークツリーを選択';

  @override
  String get workspaceBaseBranchChip => 'ベースブランチ';

  @override
  String get workspaceBaseBranchChipTooltip => 'ベースブランチを選択';

  @override
  String get workspaceAddProjectFirst => '先にプロジェクトを追加してください。';

  @override
  String get workspaceSelectProject => 'プロジェクトを選択してください。';

  @override
  String get workspaceCheckoutMissing => 'プロジェクトのチェックアウトが見つかりませんでした。';

  @override
  String get workspaceDaemonRequired => 'デーモンへの接続が必要です。';

  @override
  String get workspaceOpenDaemonSettings => 'デーモン設定';

  @override
  String get workspaceStartFailedTitle => 'セッションを開始できませんでした';

  @override
  String get composerSelectProviderModel => '使用するProviderとモデルを先に選択してください。';

  @override
  String get errorBranchAlreadyExists => '同じ名前のブランチが既に存在します。別の名前を指定してください。';

  @override
  String get errorWorktreePathInUse => '別のチェックアウトが既にそのフォルダーを使用しています。';

  @override
  String get errorInvalidBranchName => 'その名前はGitブランチとして使用できません。';

  @override
  String get errorGitCommandFailed => 'Gitコマンドが失敗しました。以下はGitの出力そのものです。';

  @override
  String get errorWorkspaceNotFound => 'そのプロジェクトはDaemonに登録されていません。';

  @override
  String get errorWorkspaceNotGit => 'そのプロジェクトはGitリポジトリではないためworktreeを作成できません。';

  @override
  String get errorWorkspaceProtected => 'Daemonが直接管理しているフォルダーです。';

  @override
  String get errorWorktreeNotFound => 'そのチェックアウトはDaemonに登録されていません。';

  @override
  String get errorWorktreeArchiveBlocked => '現在このチェックアウトはアーカイブできません。';

  @override
  String get errorAgentDefinitionNotFound => 'そのAgentは存在しません。別のAgentを選択してください。';

  @override
  String get errorAgentDefinitionUnusable =>
      'そのAgentではセッションを開始できません。別のAgentを選択してください。';

  @override
  String get errorProtocolMismatch =>
      'アプリとDaemonのプロトコルバージョンが異なります。両方を同じリリースに更新してください。';

  @override
  String get errorInvalidProjectSettings =>
      'プロジェクトの.tinest/config.jsonを読み込めませんでした。ファイルを修正して再試行してください。';

  @override
  String get errorRequestTimeout => 'Daemonが時間内に応答しませんでした。もう一度お試しください。';

  @override
  String get errorInternalDaemon =>
      'Daemonで予期しない問題が発生しました。報告する際は以下の内容をコピーしてください。';

  @override
  String get errorPluginUiRejected => 'プラグインインターフェースのリクエストが拒否されました。';

  @override
  String get errorPluginRevisionUnavailable =>
      'この agentはまだプラグインを有効化していません。メッセージを送ると開始されます。';

  @override
  String get errorSessionTurnActive =>
      'この sessionは turnを実行中です。完了を待つか停止してから設定を変更してください。';

  @override
  String get errorSessionSettingFailed => 'Session設定を変更できませんでした。';

  @override
  String get hostStatusOnline => 'オンライン';

  @override
  String get hostStatusConnecting => '接続中';

  @override
  String get hostStatusReconnecting => '再接続中';

  @override
  String get hostStatusOffline => 'オフライン';

  @override
  String get hostStatusError => 'エラー';

  @override
  String get hostStatusConflict => 'デーモンの重複';

  @override
  String get hostStatusIdle => '自動接続オフ';

  @override
  String get hostStatusPending => '待機中';

  @override
  String get embeddedDaemonName => '内蔵デーモン';

  @override
  String get hostErrorMissingToken => 'ベアラートークンを入力してください。';

  @override
  String get hostErrorNoToken => 'ベアラートークンが保存されていません。';

  @override
  String get hostErrorDuplicate => 'そのデーモンはすでに登録されています。';

  @override
  String get hostErrorUnauthorized => 'デーモンがベアラートークンを拒否しました。';

  @override
  String get hostErrorEmbeddedPortInUse => '選択したポートはすでに使用中です。';

  @override
  String hostErrorEmbeddedAlreadyRunning(String appName) {
    return 'このコンピューターではすでに $appName が動作していて、ローカルデーモンを使用しています。システムトレイから実行中のウィンドウを開くか、終了してからもう一度お試しください。';
  }

  @override
  String get hostErrorLocalNetworkUnreachable =>
      'デーモンに接続できませんでした。デーモンが動作しているか、このサイトにローカルネットワークへのアクセスを許可しているかを確認してください。';

  @override
  String get hostErrorRelayPairingUnavailable =>
      'このプラットフォームではリレーのペアリングを利用できません。';

  @override
  String get hostErrorServerIdentityMismatch =>
      'このアドレスは、ここに保存されているものとは別のデーモンにつながっています。';

  @override
  String get hostErrorCredentialMismatch => '保存されている認証情報は、この接続経路と一致しません。';

  @override
  String get appSettingsTitle => 'アプリ設定';

  @override
  String get appSettingsLocalSection => 'ローカル実行';

  @override
  String get appSettingsEmbeddedSubtitle =>
      'アプリと一緒に起動し、終了すると停止します。起動に失敗してもアプリは使えます。';

  @override
  String get appSettingsExposure => 'ネットワークアクセスを許可';

  @override
  String get appSettingsExposureSubtitle =>
      'オフではこのマシンからのみ、オンではすべての IPv4 インターフェースから接続を受け付けます。';

  @override
  String get appSettingsEmbeddedPort => 'ポート';

  @override
  String get appSettingsEmbeddedPortHelp =>
      '1〜65535 のポートを選んでください。適用すると、動作中の内蔵デーモンは再起動します。';

  @override
  String get appSettingsEmbeddedPortInvalid => '1〜65535 の整数を入力してください。';

  @override
  String get appSettingsEmbeddedPortApply => '適用';

  @override
  String get appSettingsEmbeddedFailureTitle => '内蔵デーモンを起動できませんでした';

  @override
  String appSettingsEmbeddedPortConflict(int port) {
    return 'ポート $port は別のプロセスが使用中です。別のポートを指定して適用するか、ポートが空いてからもう一度お試しください。';
  }

  @override
  String get appSettingsRemoteSection => 'リモートデーモン';

  @override
  String get appSettingsAddRemote => 'リモートデーモンを追加';

  @override
  String get relayPairTitle => 'デバイスを接続';

  @override
  String get relayPairDeviceDescription =>
      'QRコードをスキャンするかリンクをコピーして、他のデバイスをこのDaemonに接続します。';

  @override
  String get relayPairDialogDescription =>
      '他のデバイスでこのQRコードをスキャンするか、下の接続リンクをコピーしてください。';

  @override
  String get relayConnectDaemonTitle => 'Daemonに接続';

  @override
  String get relayConnectDaemonDescription =>
      'Daemonへの接続方法を選択します。リレー経由でも通信はエンドツーエンドで暗号化されます。';

  @override
  String get relayConnectScanDescription => 'Daemonに表示された一回限りのQRコードをスキャンします。';

  @override
  String get relayConnectPasteTitle => '接続リンクを貼り付け';

  @override
  String get relayConnectPasteDescription => 'Daemonに表示された一回限りのリンクを貼り付けます。';

  @override
  String get relayConnectDirectDescription =>
      'WebSocketアドレスとBearer tokenで接続します。';

  @override
  String get relayConfirmTitle => 'Daemon接続を確認';

  @override
  String get relayConfirmDescription => 'このデバイスを登録する前にDaemonとリレーを確認してください。';

  @override
  String get relayConfirmDaemon => 'デーモン ID';

  @override
  String get relayConfirmRelay => 'リレーサーバー';

  @override
  String get relayConfirmExpires => 'リンクの有効期限';

  @override
  String get relayShare => '共有';

  @override
  String get relayRefreshLink => '新しいリンクを作成';

  @override
  String get relayEnableTitle => 'このDaemonをリレー経由で接続';

  @override
  String get relayEnableDescription =>
      '他のデバイスから接続できるように、Daemonが別のTinyrackリレーサーバーへ暗号化されたアウトバウンド接続を開きます。';

  @override
  String get relayEnableAction => 'リレー接続を有効化';

  @override
  String get settingsCategoryConnection => '接続';

  @override
  String get relayPairDescription =>
      'daemon に表示されたワンタイムリンクを貼り付けてください。コードとファイルは relay 経由でもエンドツーエンドで暗号化されます。';

  @override
  String get relayPairLink => '接続リンク';

  @override
  String get relayPairDeviceName => 'このデバイスの名前';

  @override
  String get relayPairAction => '接続';

  @override
  String get relayPairScan => 'QR コードをスキャン';

  @override
  String get relayPairCameraUnavailable =>
      'QRスキャンはAndroidとiOSで利用できます。このデバイスでは接続リンクを貼り付けてください。';

  @override
  String relayPairCameraError(String appDisplayName) {
    return '$appDisplayNameでカメラを開けませんでした。システム設定でカメラへのアクセスを許可してから再試行してください。';
  }

  @override
  String get relayPairCameraRetry => 'カメラを再試行';

  @override
  String get relayPairQrSemantics => 'ワンタイムデバイス接続リンクの QR コード';

  @override
  String relayPairInvalid(String appDisplayName) {
    return '有効な $appDisplayName 接続リンクを入力してください。';
  }

  @override
  String get relayPairExpired => 'このリンクは期限切れか使用済みです。daemon で新しいリンクを作成してください。';

  @override
  String get relayPairFailed =>
      'このDaemonに接続できませんでした。Daemonで新しいリンクを作成して再試行してください。';

  @override
  String get relayAdvancedDirect => '直接接続';

  @override
  String get relayAdvancedRelayEndpoint => 'リレーサーバーアドレス';

  @override
  String get relayAdvancedRelayEndpointChange => 'リレーサーバーアドレスを変更';

  @override
  String get relayAdvancedRelayEndpointHelp =>
      'デフォルトで公式リレーを使用するか、self-hosted WebSocket endpointを入力します。';

  @override
  String get relayDevicesTitle => '接続済みデバイス';

  @override
  String get relayDevicesDescription => '新しいデバイス用の10分間リンクを作成するか、不要なデバイスを解除します。';

  @override
  String get relayCreateLink => '接続リンクを作成';

  @override
  String relayLinkExpires(String expiresAt) {
    return '$expiresAtに期限切れ';
  }

  @override
  String get relayNoDevices => '承認済みデバイスはありません。';

  @override
  String get relayRevoke => '解除';

  @override
  String relayRevokeTitle(String name) {
    return '$name を解除しますか？';
  }

  @override
  String get relayRevokeBody => 'デバイスの現在の relay 接続は直ちに終了します。再接続には新しいリンクが必要です。';

  @override
  String get relayPathDirect => '直接';

  @override
  String get relayPathRelay => 'リレー';

  @override
  String get relayConnectionDetails => '接続の詳細';

  @override
  String get relayApprovedDevices => 'デバイス';

  @override
  String get appSettingsNoRemotes => '保存されたリモートデーモンはありません。';

  @override
  String get appSettingsStopEmbeddedTitle => '内蔵デーモンを停止しますか？';

  @override
  String get appSettingsStopEmbeddedBody =>
      'このアプリが持つデーモンとその接続だけを停止します。リモートデーモンや単独起動のデーモンには影響しません。';

  @override
  String get appSettingsEditConnection => '接続を編集';

  @override
  String get appSettingsAutoConnect => 'アプリ起動時に接続';

  @override
  String get appSettingsReconnect => '再接続';

  @override
  String get appSettingsProviderSettings => 'プロバイダー設定';

  @override
  String get appSettingsAddRemoteTitle => 'リモートデーモンを追加';

  @override
  String get appSettingsEditRemoteTitle => 'リモートデーモンを編集';

  @override
  String get appSettingsAddress => 'WebSocket アドレス';

  @override
  String get appSettingsLabelPlaceholder => '本番デーモン';

  @override
  String get appSettingsNewToken => '新しいベアラートークン（変更するときのみ）';

  @override
  String get appSettingsBearerToken => 'ベアラートークン';

  @override
  String get appSettingsRemoteDetails => 'デーモン';

  @override
  String get appSettingsConnectionBehaviour => '接続';

  @override
  String get appSettingsConnectionFailed => '接続を保存できませんでした';

  @override
  String appSettingsDeleteTitle(String label) {
    return '$label を削除しますか？';
  }

  @override
  String get appSettingsDeleteBody => 'この端末に保存された接続情報とベアラートークンも削除されます。';

  @override
  String get projectSettingsHeading => 'プロジェクト';

  @override
  String get projectSettingsNoProjects => '登録されたプロジェクトがありません。';

  @override
  String get projectSettingsSelectProject => 'プロジェクトを選択してください。';

  @override
  String get projectSettingsProjectList => 'プロジェクト一覧';

  @override
  String projectSettingsCount(int count) {
    return '$count 件のプロジェクト';
  }

  @override
  String get projectSettingsCopyPath => 'ファイルの場所をコピー';

  @override
  String get projectSettingsHookHelp =>
      '1 行に 1 つコマンドを書くと、デーモンホストのシェルで上から順に実行されます。環境変数 CODER_WORKTREE_PATH、CODER_PROJECT_PATH、CODER_BRANCH が使えます。';

  @override
  String get projectSettingsSetup => 'セットアップ（ワークツリーの作成後）';

  @override
  String get projectSettingsTeardown => '後処理（ワークツリーの削除前）';

  @override
  String get agentSettingsHeading => 'エージェント';

  @override
  String get agentSettingsSelectAgent => 'エージェントを選択してください。';

  @override
  String get agentSettingsEmpty => '設定されたエージェントはありません。';

  @override
  String agentSettingsCount(int count) {
    return '$count 件の定義';
  }

  @override
  String agentSettingsModeStale(String mode) {
    return '$mode · 解析エラー';
  }

  @override
  String get agentSettingsAdd => 'エージェントを追加';

  @override
  String get agentSettingsAddTitle => 'エージェントを追加';

  @override
  String get agentSettingsList => 'エージェント一覧';

  @override
  String get agentSettingsCopyPath => 'ファイルの場所をコピー';

  @override
  String get agentSettingsReset => '既定値に戻す';

  @override
  String get agentSettingsCustomPrompt => 'カスタムシステムプロンプトを使う';

  @override
  String get agentSettingsUseModel => 'このエージェントにモデルを指定';

  @override
  String get agentSettingsUseModelDescription => 'オフの場合はデーモンの既定モデルを使います。';

  @override
  String get agentSettingsDefinitionHeading => '定義';

  @override
  String get agentSettingsPromptHeading => 'システムプロンプト';

  @override
  String get agentSettingsSystemPrompt => 'システムプロンプト（Markdown）';

  @override
  String get agentSettingsModelHeading => 'モデル';

  @override
  String get agentSettingsSessionModel => 'セッションのモデルを使用';

  @override
  String get agentSettingsPinnedModel => 'モデルを固定';

  @override
  String get agentSettingsProviderConnectionId => 'プロバイダー接続 ID';

  @override
  String get agentSettingsModelId => 'モデル ID';

  @override
  String get agentSettingsHarnessHeading => 'エージェントハーネス';

  @override
  String get agentSettingsHarnessDescription =>
      'エージェントが 1 つのドライバー、順序付き拡張、モデルに公開するツールを所有します。';

  @override
  String get agentSettingsDriver => 'ドライバー';

  @override
  String get agentSettingsNoDrivers => 'プラグインドライバーがインストールされていません。';

  @override
  String get agentSettingsExtensions => '順序付き拡張';

  @override
  String get agentSettingsExtensionsDescription => '拡張はこの順序で直列実行されます。';

  @override
  String get agentSettingsMoveUp => '前へ移動';

  @override
  String get agentSettingsMoveDown => '後ろへ移動';

  @override
  String get agentSettingsPluginTools => 'プラグインツール';

  @override
  String get agentSettingsPluginToolsDescription =>
      'モデルに公開するすべてのツールを、このエージェントで個別に切り替えられます。';

  @override
  String get agentSettingsPluginSettings => 'プラグイン設定';

  @override
  String get agentSettingsPluginSettingsDescription =>
      '設定はこのエージェント定義に JSON オブジェクトとして保存されます。';

  @override
  String get agentSettingsPluginSettingsRemove =>
      '既存の設定エントリーを削除するには、フィールドを空にします。';

  @override
  String agentSettingsPluginSettingsLabel(String plugin) {
    return '$plugin 設定 (JSON)';
  }

  @override
  String get agentSettingsCapabilities => 'プラグイン機能';

  @override
  String get agentSettingsCapabilitiesDescription =>
      '許可は編集可能なエージェントファイルではなく、このエージェントの daemon state に保存されます。';

  @override
  String get agentSettingsNoCapabilities => '選択したプラグインが要求する機能はありません。';

  @override
  String get agentSettingsHarnessDiagnostics => 'ハーネス診断';

  @override
  String agentSettingsHarnessMissing(String kind, String id) {
    return '設定された $kind は利用できません: $id';
  }

  @override
  String get agentSettingsHarnessKindDriver => 'ドライバー';

  @override
  String get agentSettingsHarnessKindExtension => '拡張';

  @override
  String get agentSettingsHarnessKindTool => 'ツール';

  @override
  String get agentSettingsHarnessKindPlugin => 'プラグイン';

  @override
  String get agentSettingsHarnessKindDependency => '依存関係';

  @override
  String get agentSettingsHarnessKindModel => 'モデル';

  @override
  String agentSettingsHarnessModelMismatch(String capability) {
    return '選択したモデルはドライバー機能を満たしません: $capability';
  }

  @override
  String agentSettingsHarnessInvalidSettings(String plugin) {
    return '$plugin 設定は有効な JSON オブジェクトである必要があります。';
  }

  @override
  String get agentSettingsPluginsLoading => 'プラグイン contribution を読み込み中…';

  @override
  String get agentSettingsBehaviourHeading => '動作';

  @override
  String get agentSettingsReasoning => '推論の深さ';

  @override
  String get agentSettingsPermission => '権限モード';

  @override
  String get agentSettingsBuiltinTools => '組み込みツール';

  @override
  String get agentSettingsToolGroupFilesystem => 'ファイル';

  @override
  String get agentSettingsToolGroupEditing => '編集';

  @override
  String get agentSettingsToolGroupExecution => 'コマンド実行';

  @override
  String get agentSettingsToolGroupAttachments => '添付ファイル';

  @override
  String get agentSettingsToolGroupMcp => 'MCP';

  @override
  String get agentSettingsToolGroupCollaboration => 'コラボレーション';

  @override
  String get agentSettingsToolGroupSession => 'セッション';

  @override
  String agentSettingsToolGroupSummary(int enabled, int total) {
    return '$total 個中 $enabled 個オン';
  }

  @override
  String get agentSettingsSubagents => '呼び出せるサブエージェント';

  @override
  String get agentSettingsNoSubagents => '登録されたサブエージェントがありません。';

  @override
  String agentSettingsArchiveTitle(String name) {
    return '$name をアーカイブしますか？';
  }

  @override
  String get agentSettingsArchiveBody =>
      'このエージェントをすでに使っているセッションはそのまま動き続けます。新しいセッションで選べなくなるだけです。';

  @override
  String agentSettingsResetTitle(String name) {
    return '$name を既定値に戻しますか？';
  }

  @override
  String get agentSettingsResetBody => 'この組み込みエージェントに加えた変更はすべて破棄され、元に戻せません。';

  @override
  String get agentSettingsArchiveFailed => 'エージェントをアーカイブできませんでした。';

  @override
  String get agentSettingsResetFailed => '組み込みエージェントを元に戻せませんでした。';

  @override
  String get agentSettingsArchived => 'アーカイブしました。';

  @override
  String get agentSettingsResetDone => '組み込みエージェントに戻しました。';

  @override
  String get agentSettingsSaveFailedTitle => 'エージェントを保存できませんでした';

  @override
  String get agentSettingsReload => '再読み込み';

  @override
  String get agentSettingsOverwrite => '上書き';

  @override
  String get agentSettingsIdInvalid => '半角小文字、数字、-、_ のみ使えます。';

  @override
  String get agentSettingsIdTaken => 'そのエージェント ID はすでに存在します。';

  @override
  String get agentSettingsIdLabel => 'ID（ファイル名）';

  @override
  String get agentSettingsNameRequired => '名前を入力してください。';

  @override
  String get providerSettingsTitle => 'プロバイダー';

  @override
  String get providerSettingsRequiresDaemon => '先にデーモンに接続してください。';

  @override
  String get providerSettingsRefreshCatalog => 'カタログを更新';

  @override
  String get providerSettingsCatalogStatus => 'カタログメタデータ';

  @override
  String get providerSettingsCatalogBundled => '同梱スナップショット';

  @override
  String get providerSettingsCatalogCached => '最終正常キャッシュ';

  @override
  String get providerSettingsCatalogFresh => '更新済み';

  @override
  String get providerSettingsCatalogStale => '更新期限切れ。ローカルデータを使用できます';

  @override
  String get modelSettingsSection => 'デーモンの既定モデル';

  @override
  String get modelSettingsSectionDescription =>
      'チャットとエージェントのどちらもモデルを指定していない場合に、新しいチャットが使うモデルです。';

  @override
  String get modelSettingsUnavailableTitle => '保存済みモデルは利用できません';

  @override
  String modelSettingsUnavailableDescription(String modelId) {
    return '$modelId は実行できません。チャットを開始する前に別のモデルを選んでください。';
  }

  @override
  String get modelSettingsSaveFailed => 'デーモンの既定モデルを変更できませんでした';

  @override
  String providerSettingsAuthTitle(String name) {
    return '$name の接続';
  }

  @override
  String get providerSettingsExperimental => '実験的';

  @override
  String get providerSettingsDisconnectTitle => 'プロバイダーの接続を解除';

  @override
  String providerSettingsDisconnectBody(String name) {
    return '$name の接続を解除しますか？これまでのエージェント履歴は残ります。';
  }

  @override
  String get providerSettingsDisconnect => '接続を解除';

  @override
  String get providerSettingsDeleteCustomTitle => 'カスタムプロバイダーを削除';

  @override
  String providerSettingsDeleteCustomBody(String name) {
    return '$name と保存された認証情報を削除しますか？これまでのセッション履歴は残ります。';
  }

  @override
  String get providerSettingsConnected => '接続済み';

  @override
  String get providerSettingsNoConnections => '接続中のプロバイダーはありません。';

  @override
  String get providerSettingsSelectConnection => '管理するProviderを選択してください。';

  @override
  String get providerSettingsRequiredFields => '名前とBase URLを入力してください。';

  @override
  String get providerSettingsApiKeyRequired => 'API keyを入力してください。';

  @override
  String get providerSettingsEditAdvanced => '詳細設定を編集';

  @override
  String get providerSettingsActions => '接続の操作';

  @override
  String get providerSettingsAdd => 'プロバイダーを追加';

  @override
  String get providerSettingsNoPresets => '追加できるプリセットはもうありません。';

  @override
  String get providerSettingsCustomSubtitle => '上級者向け: 独自のエンドポイントに接続';

  @override
  String get providerSettingsCustomName => 'カスタムプロバイダー';

  @override
  String get providerSettingsRefreshFailed => 'カタログを更新できませんでした';

  @override
  String get providerSettingsOAuthPending => 'サインインを待っています';

  @override
  String get providerSettingsOpenBrowser => 'ブラウザーを開く';

  @override
  String get providerSettingsReconnect => '再接続';

  @override
  String get providerSettingsModelPrefix => 'モデルプレフィックス';

  @override
  String get providerSettingsModelPrefixHelp =>
      'openai/gpt-5.6-col のようなモデル ID に使用されます。';

  @override
  String get providerSettingsModelPrefixInvalid =>
      '小文字、数字、ハイフン、アンダースコアを1〜64文字で入力してください。';

  @override
  String get providerSettingsModelPrefixConflict =>
      'そのモデルプレフィックスはすでに使用されています。更新された候補をお試しください。';

  @override
  String get providerSettingsConnectionHeading => '接続状態';

  @override
  String providerSettingsConnectTitle(String name) {
    return '$name に接続';
  }

  @override
  String get providerSettingsConnect => '接続';

  @override
  String get providerSettingsApiKey => 'API キー';

  @override
  String get providerSettingsBaseUrl => 'ベース URL';

  @override
  String get providerSettingsConnectionFailed => 'プロバイダーへの接続に失敗しました。';

  @override
  String get providerSettingsAuthUrlFailed => '認証ページを開けませんでした。';

  @override
  String get providerSettingsCustomTitle => 'カスタムプロバイダー詳細設定';

  @override
  String get providerSettingsApiFormat => 'API 形式';

  @override
  String get providerSettingsRequiresApiKey => 'API キーが必要';

  @override
  String get providerSettingsManualModelId => 'モデル ID';

  @override
  String get providerSettingsManualModelAdd => 'モデルを追加';

  @override
  String get providerSettingsManualModelRemove => 'モデルを削除';

  @override
  String providerSettingsControlValues(String control) {
    return '$control の値';
  }

  @override
  String get providerSettingsControlValuesHelp =>
      '値を入力して選ぶと追加されます。どの値を受け付けるかは、この endpoint を運用する人だけが知っています。';

  @override
  String get providerSettingsControlValuesPlaceholder => '値を入力';

  @override
  String providerSettingsControlValuesRequired(String control) {
    return '$control に値を 1 つ以上追加するか、オフにしてください。';
  }

  @override
  String get providerSettingsModelLookupFailedTitle => 'モデルを一覧できませんでした';

  @override
  String get providerSettingsModelLookupFailedBody =>
      'プロバイダーがモデル一覧を返しませんでした。使用するモデル ID を入力してください。';

  @override
  String get providerSettingsLater => 'あとで';

  @override
  String get providerStatusConnecting => '接続中';

  @override
  String get providerStatusConnected => '接続済み';

  @override
  String get providerStatusDegraded => '接続が制限されています';

  @override
  String get providerStatusError => 'エラー';

  @override
  String get providerStatusReauthRequired => '再サインインが必要';

  @override
  String get providerStatusDisconnected => '未接続';

  @override
  String get providerAuthStored => '保存済みの認証情報';

  @override
  String get providerAuthOAuth => 'OAuth';

  @override
  String get providerAuthNone => '認証情報なし';

  @override
  String get modelPickerTitle => 'モデルを選択';

  @override
  String get modelPickerSearch => 'モデルを検索';

  @override
  String get modelPickerNoResults => '該当するものがありません。';

  @override
  String get composerSelectAgent => 'エージェントを選択';

  @override
  String get composerAgent => 'Agent';

  @override
  String get composerAgentLocked => 'セッションの開始後はエージェントを変更できません。';

  @override
  String get composerModel => 'モデル';

  @override
  String get composerSelectModel => 'モデルを選択';

  @override
  String get composerStartHint => 'コーディングの依頼を書いて新しいセッションを始めましょう。';

  @override
  String get composerNoPrimaryAgent => '利用できるprimary Agentがありません。';

  @override
  String get composerConnectProviderFirst => '先にプロバイダーに接続してください。';

  @override
  String get composerInputHint => 'コーディングの依頼を入力…';

  @override
  String get composerReasoningEffort => '推論';

  @override
  String get composerSelectReasoningEffort => '推論の深さを選択';

  @override
  String get composerInheritReasoningEffort => 'エージェントの既定値';

  @override
  String get composerPermissionMode => '権限';

  @override
  String get composerSelectPermissionMode => '権限を選択';

  @override
  String get composerPermissionReadOnly => '読み取り専用';

  @override
  String get composerPermissionAsk => '変更前に確認';

  @override
  String get composerPermissionWorkspaceWrite => 'ワークスペースへの書き込み';

  @override
  String get composerPermissionFullAccess => 'フルアクセス';

  @override
  String get permissionPickerDescription => 'エージェントが確認なしで行える操作を選んでください。';

  @override
  String get permissionDescriptionReadOnly =>
      'ファイルの読み取りができます。ファイルの変更、コマンド実行、書き込み可能な外部ツールはブロックします。';

  @override
  String get permissionDescriptionAsk =>
      '読み取りは確認なしで行います。ファイルの変更、コマンド実行、書き込み可能な外部ツールは事前に確認します。';

  @override
  String get permissionDescriptionWorkspaceWrite =>
      'ワークスペースのファイルは読み書きできます。コマンド実行と書き込み可能な外部ツールは事前に確認します。';

  @override
  String get permissionDescriptionFullAccess =>
      'ファイルの変更、コマンド実行、外部ツールを確認なしで実行します。信頼できる作業でのみ使ってください。';

  @override
  String get permissionSettingsTitle => '権限';

  @override
  String get permissionSettingsSection => '既定の権限';

  @override
  String get permissionSettingsSectionDescription =>
      '独自の権限を選んでいないエージェントは、このデーモンの既定値を引き継ぎます。';

  @override
  String get permissionSettingsChange => '既定の権限を変更';

  @override
  String get permissionSettingsSaveFailed => '既定の権限を変更できませんでした';

  @override
  String get permissionChangeFailed => '権限を変更できませんでした';

  @override
  String get permissionSettingsDaemonDefault => 'デーモンの既定値';

  @override
  String get composerFastMode => '高速';

  @override
  String get composerFastModeTooltip => 'クレジットを多く使う代わりに応答が速くなります';

  @override
  String get composerFastModeOnTooltip => '高速モードがオンです。タップすると標準に戻ります';

  @override
  String get composerSettingLocked => '設定を変更できるのはターンの合間だけです';

  @override
  String get composerSendLabel => 'メッセージを送信';

  @override
  String get composerQueueLabel => 'メッセージを順番待ちに入れる';

  @override
  String get composerQueueTooltip => '現在のターンが終わったら送信します';

  @override
  String get composerQueuedEdit => '順番待ちのメッセージを編集';

  @override
  String get composerQueuedSendNow => '順番待ちのメッセージをすぐ送信';

  @override
  String composerQueuedAttachments(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ファイル $countString 件',
    );
    return '$_temp0';
  }

  @override
  String composerQueuedFailed(String reason) {
    return '未送信 · $reason';
  }

  @override
  String get composerAttachLabel => 'ファイルを添付';

  @override
  String composerRemoveAttachment(String name) {
    return '$name を削除';
  }

  @override
  String composerAttachmentTooLarge(int limit) {
    return '添付ファイルは 1 つあたり $limit MB 未満にしてください。';
  }

  @override
  String composerAttachmentTooMany(int limit) {
    return '1 ターンに添付できるファイルは最大 $limit 件です。';
  }

  @override
  String get composerMoreSettings => 'その他の設定';

  @override
  String get composerUseDefault => 'デフォルトを使用';

  @override
  String get composerEnabled => '有効';

  @override
  String get chatEmptyTitle => 'コーディングの依頼を入力してください。';

  @override
  String get chatEmptyExample => '例）テストを実行して、失敗した原因を直して';

  @override
  String get chatNoticeCancelled => '停止しました';

  @override
  String chatNoticeFailed(String message) {
    return '失敗 · $message';
  }

  @override
  String get chatCopyResponse => '応答をコピー';

  @override
  String chatMoreLines(int count) {
    return '… 他 $count 行';
  }

  @override
  String chatApprovalRequired(String tool) {
    return '承認が必要 · $tool';
  }

  @override
  String get chatApprovalDeny => '拒否';

  @override
  String get chatApprovalAllow => '許可';

  @override
  String usageInput(int tokens) {
    return '入力 $tokens';
  }

  @override
  String usageInputCached(int tokens, int cached) {
    return '入力 $tokens（キャッシュ $cached）';
  }

  @override
  String usageOutput(int tokens) {
    return '出力 $tokens';
  }

  @override
  String usageOutputReasoning(int tokens, int reasoning) {
    return '出力 $tokens（推論 $reasoning）';
  }

  @override
  String usageTotal(int tokens) {
    return '合計 $tokens';
  }

  @override
  String usageThroughput(double rate) {
    final intl.NumberFormat rateNumberFormat = intl.NumberFormat.decimalPattern(
      localeName,
    );
    final String rateString = rateNumberFormat.format(rate);

    return '$rateString tok/s';
  }

  @override
  String chatAnswerTyped(String answer) {
    return '$answer（自由入力）';
  }

  @override
  String get chatSleepWaiting => '待機中';

  @override
  String chatSleepRemaining(int seconds) {
    return '残り $seconds 秒';
  }

  @override
  String chatSleepDone(int seconds) {
    return '$seconds 秒待機しました';
  }

  @override
  String get subagentApprovalSection => 'サブエージェントの承認';

  @override
  String get subagentTabAwaitingApproval => 'サブエージェントが承認を待っています';

  @override
  String get statusPending => '待機中';

  @override
  String get statusRunning => '実行中';

  @override
  String get statusBlocked => '承認待ち';

  @override
  String get statusPaused => '中断';

  @override
  String get statusDone => '完了';

  @override
  String get statusFailed => '失敗';

  @override
  String get chatToolSubagentQueued => '順番待ちに追加しました';

  @override
  String chatToolSubagentCount(int count) {
    return 'エージェント $count 個';
  }

  @override
  String chatDeferredTools(int count) {
    return '検索して使えるツールが $count 個あります';
  }

  @override
  String get chatQuestionSubmit => '回答';

  @override
  String get chatQuestionNext => '次へ';

  @override
  String get chatQuestionNavigation => '質問';

  @override
  String get chatQuestionSubmitting => '回答を送信しています';

  @override
  String get chatQuestionOther => '自由入力';

  @override
  String get chatQuestionOtherPlaceholder => '回答を入力してください';

  @override
  String get toolRejected => '拒否されました';

  @override
  String get toolFailed => '失敗';

  @override
  String get directoryBrowserTitle => 'デーモン上のフォルダーを選択';

  @override
  String get directoryBrowserPath => 'デーモンのパス';

  @override
  String get directoryBrowserEmpty => 'サブフォルダーがありません。';

  @override
  String get directoryBrowserSelect => 'このフォルダーを選択';

  @override
  String get directoryBrowserHostTitle => 'フォルダーを追加するデーモン';

  @override
  String hookFailureMessage(String phase, int exitCode, String command) {
    return '$phase が失敗しました（終了コード $exitCode）: $command';
  }

  @override
  String hookFailureTitle(String phase) {
    return '$phase フックが失敗しました';
  }

  @override
  String get hookFailureNoOutput => '(出力なし)';

  @override
  String get settingsCategorySkill => 'スキル';

  @override
  String get skillSettingsHeading => 'スキル';

  @override
  String get skillSettingsScope => 'スキルの範囲';

  @override
  String get skillSettingsScopeGlobal => 'グローバル';

  @override
  String get skillSettingsScopeHint => '選択した範囲で定義され、実際に有効なスキルのみ表示します。';

  @override
  String skillSettingsGlobalCount(int count) {
    return 'グローバルスキル $count 件';
  }

  @override
  String skillSettingsProjectCount(int count) {
    return 'プロジェクトスキル $count 件';
  }

  @override
  String get skillSettingsGlobalEmpty => '利用可能なグローバルスキルはありません。';

  @override
  String get skillSettingsProjectEmpty => 'このプロジェクトで利用可能なスキルはありません。';

  @override
  String get skillSettingsProjectSearch => 'プロジェクトを検索';

  @override
  String get skillSettingsProjectNoMatch => '一致するプロジェクトがありません';

  @override
  String get settingsCategoryMcp => 'MCP';

  @override
  String get mcpSettingsHeading => 'MCP サーバー';

  @override
  String get mcpSettingsAdd => 'MCP サーバーを追加';

  @override
  String get mcpSettingsEmpty => '設定された MCP サーバーがありません。';

  @override
  String get mcpSettingsSelectServer => '編集するサーバーを選択してください。';

  @override
  String get mcpSettingsScopeUser => '自分の設定';

  @override
  String get mcpSettingsScopeProject => 'このプロジェクト';

  @override
  String mcpSettingsProjectReadOnly(String appName) {
    return 'このリポジトリが定義しているサーバーのため、$appName は編集しません。';
  }

  @override
  String get mcpSettingsShadowed => '同じ名前の自分のサーバーに隠れています';

  @override
  String mcpSettingsSource(String path) {
    return '$path で定義';
  }

  @override
  String get mcpSettingsServerId => 'ID';

  @override
  String get mcpSettingsServerIdInvalid => '半角小文字、数字、-、_ を使ってください。';

  @override
  String get mcpSettingsTransport => '接続方式';

  @override
  String get mcpSettingsTransportStdio => 'コマンド';

  @override
  String get mcpSettingsTransportHttp => 'HTTP';

  @override
  String get mcpSettingsCommand => 'コマンド';

  @override
  String get mcpSettingsArgs => '引数（1 行に 1 つ）';

  @override
  String get mcpSettingsWorkingDirectory => '作業ディレクトリ（任意）';

  @override
  String get mcpSettingsUrl => 'URL';

  @override
  String get mcpSettingsEnvironment => '環境変数（KEY=value、1 行に 1 つ）';

  @override
  String get mcpSettingsHeaders => 'ヘッダー（Name: value、1 行に 1 つ）';

  @override
  String get mcpSettingsConnectionHeading => '接続';

  @override
  String get mcpSettingsStateHeading => '利用可否';

  @override
  String get mcpSettingsEnabled => '有効';

  @override
  String get mcpSettingsSecretHint =>
      'ここに秘密情報を直接貼り付けないでください。保存済みのシークレットか環境変数を参照してください:';

  @override
  String get mcpSettingsTest => '接続をテスト';

  @override
  String mcpSettingsTestSucceeded(int count) {
    return '接続できました。ツールを $count 個見つけました。';
  }

  @override
  String mcpSettingsTestFailed(String error) {
    return '接続できませんでした: $error';
  }

  @override
  String get terminalTerminateFailed => 'ターミナルを終了できませんでした。';

  @override
  String get relayRevokeFailed => 'デバイスを失効させられませんでした。';

  @override
  String get appSettingsDaemonChangeFailed => 'デーモンの設定を変更できませんでした。';

  @override
  String get appSettingsDeleteFailed => 'デーモンを削除できませんでした。';

  @override
  String get appSettingsReconnectFailed => '再接続できませんでした。';

  @override
  String get providerSettingsDisconnectFailed => 'プロバイダーの接続を解除できませんでした。';

  @override
  String get providerSettingsDeleteFailed => 'プロバイダーを削除できませんでした。';

  @override
  String get providerSettingsDisconnected => '接続を解除しました。';

  @override
  String get workspaceArchiveFailed => 'ワークツリーをアーカイブできませんでした。';

  @override
  String get workspaceUnregisterFailed => 'プロジェクトを削除できませんでした。';

  @override
  String get projectSettingsSaveFailed => 'プロジェクト設定を保存できませんでした。';

  @override
  String get mcpSettingsSaveFailed => 'サーバーを保存できませんでした。';

  @override
  String get mcpSettingsDeleteFailed => 'サーバーを削除できませんでした。';

  @override
  String get mcpSettingsSecretFailed => 'シークレットを保存できませんでした。';

  @override
  String get mcpSettingsDelete => 'サーバーを削除';

  @override
  String mcpSettingsDeleteConfirm(String name) {
    return '$name を削除しますか？このサーバーのツールを使っているエージェントは使えなくなります。';
  }

  @override
  String get mcpSettingsStatusDisabled => '無効';

  @override
  String get mcpSettingsStatusConnecting => '接続中';

  @override
  String get mcpSettingsConnecting => 'MCP サーバーに接続中';

  @override
  String get mcpSettingsStatusReady => '準備完了';

  @override
  String get mcpSettingsStatusFailed => '失敗';

  @override
  String get mcpSettingsDiscoveredResources => 'リソース';

  @override
  String get mcpSettingsResources => '公開中のリソース';

  @override
  String get mcpSettingsNoResources => 'このサーバーはリソースを公開していません。';

  @override
  String get mcpSettingsResourceTemplates => 'リソーステンプレート';

  @override
  String get mcpSettingsNoResourceTemplates => 'このサーバーはリソーステンプレートを公開していません。';

  @override
  String get mcpSettingsDiscoveredTools => 'ツール';

  @override
  String get mcpSettingsNoTools => 'このサーバーはツールを公開していません。';

  @override
  String get mcpSettingsDiagnostics => 'サーバー出力';

  @override
  String get mcpSettingsSecretSet => 'シークレットを保存';

  @override
  String get mcpSettingsSecretKey => '参照名';

  @override
  String get mcpSettingsSecretValue => '値';

  @override
  String get sessionContextMeter => 'コンテキスト';

  @override
  String sessionContextMeterValue(int percent) {
    return 'コンテキストウィンドウの $percent% を使用';
  }

  @override
  String get sessionContextDetailsTitle => 'コンテキスト使用量';

  @override
  String sessionContextPercent(int percent) {
    return '$percent% 使用';
  }

  @override
  String sessionContextTokens(String used, String max) {
    return '$used / $max トークン';
  }

  @override
  String sessionContextCost(String cost) {
    return 'セッション料金 $cost';
  }

  @override
  String get sessionQuotaLoading => 'プロバイダー使用量を読み込み中';

  @override
  String get sessionQuotaError => 'プロバイダー使用量を一時的に取得できません。';

  @override
  String sessionQuotaProviderPlan(String provider, String plan) {
    return '$provider · $plan';
  }

  @override
  String sessionQuotaPercent(int percent) {
    return '$percent% 使用';
  }

  @override
  String sessionQuotaResets(String time) {
    return '$time にリセット';
  }

  @override
  String sessionQuotaCredits(String amount) {
    return 'クレジット $amount';
  }

  @override
  String get sessionQuotaWindowSession => 'セッション上限';

  @override
  String get sessionQuotaWindowWeekly => '週間上限';

  @override
  String get sessionQuotaWindowCodeReview => 'コードレビュー上限';

  @override
  String get composerCommandNoAttachments => 'コマンドを実行するには添付ファイルを外してください。';

  @override
  String get composerCommandsEmpty => 'コマンドなし';

  @override
  String get composerFilesEmpty => 'ファイルなし';

  @override
  String get composerFilesSearching => 'ワークスペースを検索中';

  @override
  String get composerCommandsError => 'コマンドを読み込めませんでした';

  @override
  String get composerFilesError => 'ファイルを検索できませんでした';

  @override
  String get composerCommandSourceClient => 'アプリ';

  @override
  String get composerCommandSourceAgent => 'コマンド';

  @override
  String get composerCommandSourceSkill => 'スキル';

  @override
  String get composerCommandClearLabel => 'clear';

  @override
  String get composerCommandClearDescription => 'コンポーザーを空にします。';

  @override
  String get composerCommandNewLabel => 'new';

  @override
  String get composerCommandNewDescription => '新しいセッションを始めます。';

  @override
  String get composerCommandAgentsLabel => 'agents';

  @override
  String get composerCommandAgentsDescription => 'エージェント設定を開きます。';

  @override
  String get composerCommandSkillsLabel => 'skills';

  @override
  String get composerCommandSkillsDescription => 'スキル設定を開きます。';

  @override
  String get composerCommandHelpLabel => 'help';

  @override
  String get composerCommandHelpDescription => '使えるコマンドを一覧します。';

  @override
  String get composerSuggestionsLabel => '候補';

  @override
  String get composerDropFilesHere => 'ここにファイルをドロップ';

  @override
  String get chatToolActionRead => 'ファイルを読む';

  @override
  String get chatToolActionList => 'ファイル一覧を見る';

  @override
  String get chatToolActionSearch => '検索';

  @override
  String get chatToolActionEdit => 'ファイルを編集';

  @override
  String get chatToolActionRun => 'コマンドを実行';

  @override
  String get chatToolActionDelegate => 'エージェントを調整';

  @override
  String get chatToolActionAsk => '質問する';

  @override
  String get chatToolActionResource => 'リソースを使用';

  @override
  String get chatToolActionTools => 'ツールを探す';

  @override
  String get chatToolActionClock => '待機';

  @override
  String get chatToolActionContext => 'コンテキストを管理';

  @override
  String get chatToolActionImage => '画像を見る';

  @override
  String get chatToolActionGeneric => 'ツールを使用';

  @override
  String get chatReasoningThinking => '思考中…';

  @override
  String get chatReasoningThought => '思考済み';

  @override
  String get chatReasoningWaiting => '思考内容を待っています…';

  @override
  String get chatToolStatusFailed => '失敗';

  @override
  String get chatToolStatusDenied => '拒否';

  @override
  String get chatToolDetailsTool => 'ツール';

  @override
  String get chatToolDetailsRequest => 'リクエスト';

  @override
  String get chatToolDetailsResult => '結果';

  @override
  String get settingsCategoryPlugin => 'プラグイン';

  @override
  String get pluginSettingsHeading => 'プラグイン';

  @override
  String pluginSettingsCount(int count) {
    return '$count個のプラグイン';
  }

  @override
  String get pluginSettingsSelect => 'プラグインを選択してください。';

  @override
  String get pluginSettingsAdd => 'プラグインを作成';

  @override
  String get pluginSettingsAddTitle => 'プラグインスターターを作成';

  @override
  String get pluginSettingsEmpty => 'インストール済みのプラグインはありません。';

  @override
  String get pluginSettingsSource => 'ソース';

  @override
  String get pluginSettingsSourceBuiltIn => '組み込み';

  @override
  String get pluginSettingsSourceUser => 'ユーザー';

  @override
  String get pluginSettingsSourcePath => 'ソースパス';

  @override
  String get pluginSettingsApi => 'プラグインAPI';

  @override
  String pluginSettingsApiValue(int api) {
    return 'API $api';
  }

  @override
  String get pluginSettingsRevision => '有効なリビジョン';

  @override
  String get pluginSettingsRevisionMissing => '有効なリビジョンなし';

  @override
  String get pluginSettingsStale => '最後に正常だったリビジョンを使用中';

  @override
  String get pluginSettingsAuthoring => 'Lua 開発環境';

  @override
  String get pluginSettingsAuthoringStatus => '開発環境の状態';

  @override
  String get pluginSettingsAuthoringSynchronized => '同期済み';

  @override
  String get pluginSettingsAuthoringNeedsSync => '同期が必要';

  @override
  String get pluginSettingsSdkAbi => 'SDK ABI';

  @override
  String get pluginSettingsLuaRuntime => 'Lua ランタイム';

  @override
  String get pluginSettingsLuaLs => 'Lua 言語サーバー';

  @override
  String get pluginSettingsLuaConfig => 'LuaLS 設定';

  @override
  String get pluginSettingsSdkSync => 'SDK を同期';

  @override
  String get pluginSettingsCapabilities => '要求された機能';

  @override
  String get pluginSettingsCapabilitiesNone => 'ホスト機能は要求されていません。';

  @override
  String get pluginSettingsAgents => '参照しているエージェント';

  @override
  String get pluginSettingsAgentsNone => 'このプラグインを参照するエージェントはありません。';

  @override
  String get pluginSettingsContributions => 'コントリビューション';

  @override
  String get pluginSettingsDiagnostics => '診断';

  @override
  String get pluginSettingsDiagnosticsNone => '診断はありません。';

  @override
  String get pluginSettingsValidate => '検証';

  @override
  String get pluginSettingsReload => '再読み込み';

  @override
  String get pluginSettingsOpenPath => 'プラグインフォルダーを開く';

  @override
  String get pluginSettingsFork => 'フォーク';

  @override
  String pluginSettingsForkTitle(String plugin) {
    return '$plugin をフォーク';
  }

  @override
  String get pluginSettingsForkDescription =>
      '検証済みリビジョンを新しいアプリデータプラグインへコピーします。Agent には自動で有効化されません。';

  @override
  String get pluginSettingsReloadAgent => '再読み込みに使用するエージェント権限';

  @override
  String get pluginSettingsReloadNeedsAgent =>
      '再読み込みする前にエージェントからこのプラグインを参照してください。';

  @override
  String get pluginSettingsId => 'プラグインID';

  @override
  String get pluginSettingsName => '名前';

  @override
  String get pluginSettingsIdInvalid =>
      'example.toolsのような小文字のドット区切り名前空間を使用してください。';

  @override
  String get pluginSettingsIdTaken => 'そのプラグインIDは既に存在します。';

  @override
  String get pluginSettingsUi => 'プラグインインターフェース';

  @override
  String get pluginUiLoading => 'プラグインインターフェースを読み込み中';

  @override
  String get pluginUiLoadFailed => 'プラグインインターフェースを読み込めませんでした。';

  @override
  String get pluginUiInvalidTitle => '未対応のプラグインインターフェース';

  @override
  String pluginUiInvalidDescription(String appName) {
    return 'ドキュメントが無効なため、$appNameはソースを読み取り専用の開閉領域に表示しました。';
  }

  @override
  String pluginUiSemanticLabel(String plugin) {
    return '$pluginプラグインインターフェース';
  }

  @override
  String get pluginSessionControlLoading => 'セッションコントロールを読み込み中';

  @override
  String get pluginSessionControlLoadFailed => 'プラグインのセッションコントロールを読み込めませんでした。';

  @override
  String get pluginSessionControlUnsupported => 'サポートされていないプラグインセッションコントロール';

  @override
  String get pluginSessionControlSaveFailed => 'プラグインのセッションコントロールを保存できませんでした。';

  @override
  String get pluginContributionDriver => 'ドライバー';

  @override
  String get pluginContributionExtension => '拡張';

  @override
  String get pluginContributionTool => 'ツール';

  @override
  String get pluginContributionSessionControl => 'セッションコントロール';

  @override
  String get pluginContributionUi => 'インターフェース';

  @override
  String get pluginSettingsActionFailed => 'プラグイン操作に失敗しました';
}
