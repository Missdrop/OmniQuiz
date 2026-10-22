// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get gatewayTitle => '通过 CLIProxyAPI 使用 ChatGPT 等账号';

  @override
  String get gatewayHelp =>
      '先在你自己的 CLIProxyAPI 网关中登录服务商账号。在下方填写网关兼容 OpenAI 的接口地址和客户端密钥，获取可用模型，再测试并保存。请使用网关客户端密钥，不是 ChatGPT 密码、OAuth 令牌或网关管理密钥。可用模型和用量限制取决于所连接的账号。生成题目时，所选资料片段会经过该网关。';

  @override
  String get gatewayAddressHelp =>
      '本机电脑：http://127.0.0.1:8317/v1\n手机：填写手机可访问的 HTTPS 网关地址，以 /v1 结尾。手机上的 localhost 指手机自身，不是你的电脑。使用时需保持网关运行。独立使用请选上方实验性 ChatGPT 登录。';

  @override
  String get loadModels => '获取可用模型';

  @override
  String get chooseModel => '选择模型';

  @override
  String get searchModels => '搜索模型';

  @override
  String get loadModelsError => '无法获取模型。请检查接口地址和密钥，或手动填写模型名称。';

  @override
  String get noModelsError => '没有可用模型。请先在网关中登录服务商账号，或手动填写模型名称。';

  @override
  String get library => '资料库';

  @override
  String get practice => '练习';

  @override
  String get review => '错题复习';

  @override
  String get settings => '设置';

  @override
  String get tagline => '把知识变成自己的。';

  @override
  String get localByDesign => '数据保存在本地';

  @override
  String get libraryEyebrow => '你的学习空间';

  @override
  String get libraryTitle => '每天练一点，进步看得见。';

  @override
  String get librarySubtitle => '导入学习资料，通过一道道练习加深理解。';

  @override
  String get documents => '资料';

  @override
  String get questionsReady => '待答题目';

  @override
  String get answersGiven => '已答题目';

  @override
  String get toRevisit => '待复习';

  @override
  String get importFiles => '导入文件';

  @override
  String get importFolder => '导入文件夹';

  @override
  String get goToPractice => '开始练习';

  @override
  String get supportedFiles => '支持 TXT、Markdown 和文本型 PDF · 每个文件不超过 20 MB';

  @override
  String get libraryEmptyTitle => '从你的第一份资料开始';

  @override
  String get libraryEmptyBody =>
      '导入资料，将知识转化为练习题。\n只有在你开始生成题目时，相关资料片段才会发送给 AI 服务商。';

  @override
  String get trySample => '体验示例资料';

  @override
  String get close => '关闭';

  @override
  String get removeDocument => '移除资料';

  @override
  String get removeDocumentTitle => '移除这份资料？';

  @override
  String get removeDocumentBody => '相关题目将从练习和复习队列中移除，历史答题记录会保留。';

  @override
  String get cancel => '取消';

  @override
  String get remove => '移除';

  @override
  String get reviewPracticeEyebrow => '让知识记得更牢';

  @override
  String get practiceEyebrow => '每次练好一道题';

  @override
  String get reviewPracticeTitle => '温故，知新。';

  @override
  String get practiceTitle => '进入学习状态。';

  @override
  String get reviewPracticeSubtitle => '先回忆答案，再查看解析。';

  @override
  String get practiceSubtitle => '根据你的资料提前生成题目，让练习顺畅进行。';

  @override
  String get practiceScope => '练习范围';

  @override
  String get allMaterials => '全部资料';

  @override
  String get pauseGeneration => '暂停生成';

  @override
  String get generateTitle => '开始生成练习题？';

  @override
  String get generateBody =>
      '相关资料片段将发送至所选 AI 连接，并消耗订阅或 API 额度。练习期间会自动补充题目，最多缓存 20 道，你可以随时暂停。';

  @override
  String get start => '开始';

  @override
  String get generateQuestions => '生成题目';

  @override
  String get backToFresh => '返回新题练习';

  @override
  String get reviewCaughtUp => '本轮复习已完成';

  @override
  String get firstQuestion => '准备开始第一道题了吗？';

  @override
  String get reviewCaughtUpBody => '下次复习到期时再来，或到错题复习中选择其他题目。';

  @override
  String get firstQuestionBody => '导入资料、配置 AI 服务商，然后开始生成题目。\n已保存的题目也可以离线练习。';

  @override
  String get openLibrary => '打开资料库';

  @override
  String get reviewQueue => '复习队列';

  @override
  String get setUpAi => '配置 AI';

  @override
  String get singleChoice => '单选题';

  @override
  String get saving => '正在保存…';

  @override
  String get nextQuestion => '下一题';

  @override
  String get checkAnswer => '提交答案';

  @override
  String get hideQuestionTitle => '隐藏这道题？';

  @override
  String get hideQuestionBody => '如果题目存在错误或歧义，可以将其从练习和复习中移除。这条反馈只保存在本机。';

  @override
  String get hideQuestion => '隐藏题目';

  @override
  String get reportProblem => '反馈问题';

  @override
  String get correctAnswer => '回答正确！';

  @override
  String get wrongAnswer => '这次错题，就是下次进步的起点。';

  @override
  String get fullSource => '查看完整资料片段';

  @override
  String get aiDisclaimer => '题目由 AI 生成。如果答案有疑问，请核对原文。';

  @override
  String get reviewEyebrow => '从错题中进步';

  @override
  String get reviewTitle => '值得再练一次。';

  @override
  String get reviewSubtitle => '答错的题目会进入这里，连续复习答对三次后移出队列。';

  @override
  String get reviewEmptyTitle => '还没有待复习的错题';

  @override
  String get reviewEmptyBody => '答错的题目会出现在这里。继续练习，发现还需要巩固的知识。';

  @override
  String get dueNow => '现在复习';

  @override
  String get reviewEarly => '提前复习';

  @override
  String get reviewNow => '开始复习';

  @override
  String get settingsEyebrow => '按你的习惯设置';

  @override
  String get settingsTitle => '你的 AI，由你选择。';

  @override
  String get settingsSubtitle =>
      '使用 ChatGPT 订阅或兼容 OpenAI 的 API，无需 OmniQuiz 账号或服务器。';

  @override
  String get aiProvider => 'AI 服务商';

  @override
  String get apiBaseUrl => 'API 基础地址';

  @override
  String get apiBaseUrlHelp => '按服务商要求包含 /v1，不要添加 /chat/completions。';

  @override
  String get modelId => '模型名称';

  @override
  String get modelHint => '填写服务商提供的模型名称';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get pasteKey => '粘贴 API 密钥';

  @override
  String get keepKey => '留空以保留已保存的密钥';

  @override
  String get hideKey => '隐藏密钥';

  @override
  String get showKey => '显示密钥';

  @override
  String get noKey => '此接口无需密钥';

  @override
  String get jsonMode => 'JSON 响应模式';

  @override
  String get jsonModeHelp => '仅在服务商支持 response_format: json_object 时开启。';

  @override
  String get questionLanguage => '出题语言';

  @override
  String get saveSettings => '保存设置';

  @override
  String get testConnection => '测试连接';

  @override
  String get privacyNotice =>
      '生成题目会将选中的资料片段发送至所选 AI 连接。连接测试会使用少量订阅或 API 额度。凭据存放在系统安全存储中，资料和学习进度保存在本地。';

  @override
  String get licenses => '开源许可证';

  @override
  String get appLanguage => '界面语言';

  @override
  String get systemLanguage => '跟随系统';

  @override
  String get appLanguageHelp => '立即生效并保存在本机。出题语言可在下方单独设置。';

  @override
  String get questionLanguageHelp => '用于新生成的题目与解析，已有题目保留原语言。';

  @override
  String get languageSaveError => '无法保存界面语言，请重试。';

  @override
  String get startupError => 'OmniQuiz 无法打开本地存储，请检查磁盘剩余空间和应用权限后重新启动。';

  @override
  String readyCount(int count) {
    return '$count 道待答';
  }

  @override
  String documentDetails(int count, String date) {
    return '$count 个资料片段 · 导入于 $date';
  }

  @override
  String reviewProgress(int streak, int mistakes) {
    return '已连续答对 $streak/3 次 · 累计答错 $mistakes 次';
  }

  @override
  String dueDate(String date) {
    return '下次复习：$date';
  }

  @override
  String sourceName(String name) {
    return '来源 · $name';
  }

  @override
  String importSummary(int count, int unchanged) {
    return '已导入 $count 份 · $unchanged 份无变化';
  }

  @override
  String bufferReady(int count) {
    return '已有 $count 道题可练习';
  }

  @override
  String retryGeneration(int attempt) {
    return '正在重试生成（$attempt/3）…';
  }

  @override
  String httpError(int code) {
    return '服务商返回 HTTP $code，请检查基础地址、模型和 JSON 模式。';
  }

  @override
  String fileTooLarge(String name) {
    return '$name 超过 20 MB 文件大小限制。';
  }

  @override
  String textLocation(String start, String end) {
    return '正文 · 第 $start–$end 个字符';
  }

  @override
  String pageLocation(String page, String start, String end) {
    return '第 $page 页 · 第 $start–$end 个字符';
  }

  @override
  String get invalidQuestion => '服务商返回的题目格式不正确。';

  @override
  String get invalidProfile => '请输入 HTTPS API 基础地址和模型名称。仅本机地址允许使用 HTTP。';

  @override
  String get loadLibraryError => '无法加载资料库。';

  @override
  String get importError => '导入失败，请检查文件权限后重试。';

  @override
  String get removeError => '无法移除这份资料。';

  @override
  String get loadQuestionsError => '无法加载题目。';

  @override
  String get saveAnswerError => '无法保存答案，请重试。';

  @override
  String get loadReviewError => '无法加载复习队列。';

  @override
  String get loadSettingsError => '无法加载服务商设置。';

  @override
  String get settingsSaved => '设置已保存，密钥已安全存储在本机。';

  @override
  String get saveSettingsError => '无法保存设置。';

  @override
  String get testKeyRequired => '请先输入此接口的 API 密钥，再测试连接。';

  @override
  String get connectionSuccess => '连接成功，模型已返回有效的 JSON。';

  @override
  String get connectionError => '连接测试失败，请检查系统安全存储和网络连接。';

  @override
  String get readyStatus => '准备好后就可以开始';

  @override
  String get pausedStatus => '已暂停生成 · 缓存题目仍可练习';

  @override
  String get configureFirst => '请先在设置中配置 AI 服务商。';

  @override
  String get importFirst => '请先导入学习资料。';

  @override
  String get generatingStatus => '正在为你生成下一批题目…';

  @override
  String get changedStatus => '资料或设置已变更，请重新开始生成。';

  @override
  String get savedQuestionsStatus => '新题目已保存';

  @override
  String get generateError => '无法生成或保存题目，请重试。';

  @override
  String get fileLimit => '文件超过 20 MB。';

  @override
  String get textLimit => '提取的正文超过 100 万个字符，请拆分文件。';

  @override
  String get noText => '未找到可读取的正文。';

  @override
  String get readError => '无法读取这个文件。';

  @override
  String get keyRequired => '请输入 API 密钥，或明确选择“此接口无需密钥”。';

  @override
  String get newKeyRequired => '请为新接口输入密钥，或明确选择无需密钥。';

  @override
  String get secureSaveError => '系统安全存储不可用，API 密钥未保存。';

  @override
  String get encodingError => '文本文件必须使用 UTF-8 编码。';

  @override
  String get documentLimit => '资料过大，请拆分为较小的文件。';

  @override
  String get scanError => '未找到正文。扫描版 PDF 需要先进行 OCR 文字识别。';

  @override
  String get formatError => '支持的格式：TXT、Markdown 和文本型 PDF。';

  @override
  String get authError => 'API 授权失败，请检查密钥和模型访问权限。';

  @override
  String get quotaError => '已达到服务商的速率或额度限制，请稍后重试。';

  @override
  String get providerUnavailable => 'AI 服务商暂时不可用。';

  @override
  String get responseLimit => '服务商返回的内容超过大小限制。';

  @override
  String get outputTruncated => '模型输出被截断，请尝试输出长度限制更大的模型。';

  @override
  String get timeoutError => '生成超时，重试可能再次消耗 API 额度。';

  @override
  String get invalidJson => '服务商返回了无效的 JSON。';

  @override
  String get incompatibleResponse => '服务商的响应不兼容 Chat Completions 格式。';

  @override
  String get networkError => '无法连接服务商，请检查网络和 API 地址。';

  @override
  String get probeJsonError => '模型已响应，但未通过 JSON 格式测试，请尝试其他模型。';

  @override
  String get modelJsonError => '模型未返回有效 JSON，请尝试开启 JSON 模式或更换模型。';

  @override
  String get secureReadError => '无法访问系统安全存储，请解锁设备后重试。';

  @override
  String get missingCredentials => '缺少 API 凭据，请在设置中保存密钥。';

  @override
  String get noQuestions => '服务商未返回题目列表。';

  @override
  String get staleQuestion => '这道题已失效，请选择其他题目。';

  @override
  String get invalidAnswer => '提交的答案无效。';

  @override
  String get noNewQuestions => '未生成新的有效题目，请尝试其他资料或模型。';

  @override
  String get invalidBatch => '没有返回新的有效题目，请尝试其他模型或添加更多资料。';

  @override
  String get fileReadError => '无法读取所选文件，请先将文件复制到本机。';

  @override
  String get useFiles => '请在此设备上使用“导入文件”。';

  @override
  String get folderLimit => '单次最多导入 100 个文件、总计 100 MB，请选择更小的文件夹。';

  @override
  String get currentLibrary => '当前资料库';

  @override
  String get createLibrary => '创建资料库';

  @override
  String get libraryName => '资料库名称';

  @override
  String get useExistingFolder => '使用现有目录';

  @override
  String get chooseFolder => '选择目录';

  @override
  String get folderIncludesSubfolders => '请选择目录，包含子目录中的资料。';

  @override
  String get managedFolderDescription => '在应用管理的目录中创建。导入的文件会复制到此目录。';

  @override
  String get mobileLibraryDescription => '此设备使用应用内目录，可通过导入文件添加资料。';

  @override
  String get libraryNameRequired => '请输入名称并选择目录。';

  @override
  String get createLibraryError => '无法创建资料库。请检查目录权限，且各资料库的目录不能重叠。';

  @override
  String get create => '创建';

  @override
  String get scanFolder => '扫描目录';

  @override
  String get libraryIsolationDescription =>
      '题目、错题和进度仅属于当前库。启动、切换及返回应用时扫描；也可手动扫描。';

  @override
  String get openLibraryError => '无法打开资料库，请重试。';

  @override
  String get scanFolderError => '无法扫描资料库目录。请检查目录是否已连接，并重新授权目录访问。';

  @override
  String get folderUnavailable => '资料库目录不可用，请重新连接后扫描。';

  @override
  String get copyLibraryFileError => '无法将文件复制到资料库目录。';

  @override
  String get grantFolderAccess => '重新授权目录';

  @override
  String get grantFolderError => '请选择当前资料库的同一目录以恢复授权。';

  @override
  String get removeIndexedDocumentBody =>
      '这会移除已导入资料并停用相关题目，同时将原文件加入扫描排除列表。原文件不会删除，可在“已排除文件”中恢复导入。';

  @override
  String get importZip => '导入 ZIP';

  @override
  String get zipSupportedFiles =>
      'TXT、Markdown、文字型 PDF · 每文件 20 MB · ZIP：压缩及解压后各限 100 MB，最多 1000 个条目';

  @override
  String get zipReadError => '无法读取此 ZIP。请使用未加密、采用标准压缩方式的 ZIP。';

  @override
  String get zipSelectedReadError => '无法读取所选 ZIP 文件。';

  @override
  String get zipArchiveLimit => 'ZIP 文件超过 100 MB 上限。';

  @override
  String get zipEntryLimit => 'ZIP 条目过多或目录元数据过大，请拆分为较小的压缩包（最多 1000 个条目）。';

  @override
  String get zipUnsafePaths => 'ZIP 包含不安全的路径或链接，未导入任何文件。';

  @override
  String get zipInvalidSizes => 'ZIP 中的文件大小信息无效。';

  @override
  String get zipExpandedLimit => 'ZIP 解压后超过 100 MB 上限。';

  @override
  String get zipDuplicatePaths => 'ZIP 包含不安全或重复的文件路径。';

  @override
  String get zipMaterialLimit => 'ZIP 中的某个资料文件超过 20 MB 上限。';

  @override
  String get zipNoMaterials => 'ZIP 中没有支持的资料。请包含 TXT、Markdown 或文字型 PDF。';

  @override
  String get zipDamaged => 'ZIP 已损坏，未导入任何文件。';

  @override
  String get zipImportError => '无法导入 ZIP，请检查存储空间和文件权限。';

  @override
  String get backupTitle => '资料库备份';

  @override
  String get backupHelp => '备份全部资料库、资料、题目和进度，不包含 AI 配置和 API 密钥。备份文件包含你的私人学习资料。';

  @override
  String get exportBackup => '导出备份';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restoreBackupHelp => '将 OmniQuiz 备份恢复为新的资料库，保留现有资料库和 AI 配置。';

  @override
  String get backupSaved => '备份已保存。';

  @override
  String get backupFailed => '备份失败，请检查存储空间和目录权限。';

  @override
  String backupRestored(int count) {
    return '已恢复 $count 个资料库，请切换资料库查看。';
  }

  @override
  String backupMissingOriginals(int count) {
    return '备份已保存。有 $count 份原文件不可用，已保留其提取文本和学习记录。';
  }

  @override
  String get backupTooLarge => '备份超过大小限制。';

  @override
  String get backupSourceError => '某份资料无法备份，请检查文件大小及读取权限。';

  @override
  String get backupReadError => '无法读取备份文件。';

  @override
  String get backupRestoreError => '备份无效或无法恢复，现有资料库已保留。';

  @override
  String get maintenanceBusy => '请先等待当前操作完成，再备份或恢复。';

  @override
  String get fullScan => '完整扫描';

  @override
  String get cancelScan => '停止扫描';

  @override
  String get scanCancelled => '扫描已停止，已完成的导入已保留。';

  @override
  String get sourceMissing => '原文件暂不可用，已保留导入内容和学习进度。';

  @override
  String get restoreImport => '恢复导入';

  @override
  String get restoreExcludedError => '无法恢复此文件的导入，请重试。';

  @override
  String excludedFiles(int count) {
    return '已排除文件（$count）';
  }

  @override
  String scanProgress(int count, String name) {
    return '已检查 $count 个文件 · $name';
  }

  @override
  String scanSourceSummary(int excluded, int missing) {
    return '$excluded 个已排除 · $missing 个原文件暂不可用';
  }

  @override
  String get chatGptTitle => 'ChatGPT 订阅 · 实验性功能';

  @override
  String get chatGptHelp =>
      '在本设备登录并授权使用符合条件的 ChatGPT 订阅，无需 API 密钥、电脑或网关。在浏览器完成授权后返回这里。手机登录属于实验性功能，仍需实机验证。';

  @override
  String get chatGptActive => '当前出题连接';

  @override
  String get chatGptAccount => 'ChatGPT 账号';

  @override
  String get continueChatGpt => '继续使用 ChatGPT';

  @override
  String get chatGptAddAccount => '添加其他账号';

  @override
  String get chatGptSignOut => '退出登录';

  @override
  String get chatGptUseModel => '测试并使用此模型';

  @override
  String get chatGptTestHelp => '测试会发送少量请求并使用订阅额度。仅登录不会切换当前的出题连接。';

  @override
  String get chatGptUsage => '管理 ChatGPT 用量';

  @override
  String get chatGptRequestError => 'ChatGPT 请求失败。请重新登录或检查订阅授权。';

  @override
  String get chatGptIdentityError => '无法验证 ChatGPT 身份。请重新登录。';

  @override
  String get chatGptLoginCancelled => 'ChatGPT 登录已取消或超时。请重试。';

  @override
  String get chatGptLoginBusy => 'ChatGPT 登录正在进行中。';

  @override
  String get chatGptScopeError => '尚未授权使用 ChatGPT 订阅。请在登录时启用此权限。';

  @override
  String get chatGptSignInFirst => '请先在设置中登录 ChatGPT。';

  @override
  String get chatGptInterrupted => 'ChatGPT 请求被中断。请重试。';

  @override
  String get chatGptIncomplete => 'ChatGPT 未能完成回复。请检查订阅用量后重试。';

  @override
  String get chatGptReady => 'ChatGPT 已就绪。新题目将使用所选账号生成。';

  @override
  String get chatGptSignedOut => '已退出 ChatGPT。';

  @override
  String get chatGptRevocationUnconfirmed =>
      '已在本地退出。请在 ChatGPT 设置中断开 OmniQuiz，以确认撤销授权。';
}
