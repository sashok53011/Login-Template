/// Central translation table and lookup helper.
///
/// Keys are `screen.element` (`login.title`, `ai.addProvider`,
/// `home.loggedInAs`); the service errors use the `err.*` namespace. Keys are
/// stable: `lib/services/*` and `lib/providers/*` hand them to the screens,
/// which translate them at the moment of display.
///
/// [translate] falls back to Russian and, crucially, returns the input
/// unchanged when the key is unknown. Plain text therefore keeps working and
/// no screen can ever show a raw key.
library;

const Map<String, Map<String, String>> kTranslations = <String, Map<String, String>>{
  'ru': <String, String>{
    // -------------------------------------------------------------- common
    'common.cancel': 'Отмена',
    'common.save': 'Сохранить',
    'common.close': 'Закрыть',
    'common.delete': 'Удалить',
    'common.retry': 'Повторить',
    'common.refresh': 'Обновить',
    'common.checking': 'Проверяем…',
    'common.free': 'Свободен',
    'common.taken': 'Занят',
    'common.logout': 'Выйти',
    'common.user': 'пользователь',

    // --------------------------------------------------------------- login
    'login.title': 'Вход',
    'login.password': 'Пароль',
    'login.submit': 'Войти',
    'login.noAccount': 'Ещё нет аккаунта? Зарегистрироваться',
    'login.successTitle': 'Вход выполнен',
    'login.successDesc': 'Добро пожаловать! Вы вошли в аккаунт.',
    'login.failTitle': 'Вход не выполнен',

    // ------------------------------------------------------------ register
    'register.title': 'Регистрация',
    'register.usernameHint': 'Показывается на главном экране',
    'register.password': 'Пароль',
    'register.confirmPassword': 'Повторите пароль',
    'register.submit': 'Зарегистрироваться',
    'register.haveAccount': 'Уже есть аккаунт? Войти',
    'register.successTitle': 'Регистрация прошла успешно',
    'register.successDesc': 'Аккаунт создан. Теперь войдите, чтобы продолжить.',
    'register.failTitle': 'Регистрация не выполнена',
    'register.takenDesc': 'Email или username уже заняты. '
        'Если это ваш аккаунт — войдите с помощью него.',

    // ---------------------------------------------------------------- home
    'home.title': 'Главная',
    'home.loggedInAs': 'Вы зашли как {name}',
    'home.aiProviders': 'AI-провайдеры',
    'home.settings': 'Настройки',
    'home.logoutTitle': 'Выйти?',
    'home.logoutConfirm': 'Сессия будет завершена, потребуется войти снова.',

    // --------------------------------------------------------------- splash
    'splash.loading': 'Загрузка...',

    // --------------------------------------------------------- result screen
    'result.fallbackTitle': 'Результат',
    'result.noDataTitle': 'Нет данных о результате',
    'result.noDataDesc': 'Попробуйте выполнить действие ещё раз.',
    'result.goToLogin': 'Перейти к входу',
    'result.goToLoginFallback': 'Перейти ко входу',
    'result.retry': 'Попробовать снова',
    'result.goToProfile': 'Перейти в профиль',
    'result.createAnother': 'Создать ещё один аккаунт',
    'result.createAccount': 'Создать аккаунт',

    // ------------------------------------------------------ settings screen
    'settings.title': 'Настройки',
    'settings.languageTitle': 'Язык',
    'settings.themeTitle': 'Тема',
    'language.ru': 'Русский',
    'language.en': 'English',
    'language.de': 'Deutsch',

    // --------------------------------------------------------------- themes
    'theme.day': 'Дневная',
    'theme.dayYellow': 'Дневная — жёлтая',
    'theme.dayRed': 'Дневная — красная',
    'theme.dayGreen': 'Дневная — зелёная',
    'theme.dayOrange': 'Дневная — оранжевая',
    'theme.nightRed': 'Ночная — красная',
    'theme.nightBlue': 'Ночная — голубая',
    'theme.nightYellow': 'Ночная — жёлтая',
    'theme.nightGreen': 'Ночная — зелёная',
    'theme.nightOrange': 'Ночная — оранжевая',

    // ----------------------------------------------------------- validators
    'valid.emailRequired': 'Введите email',
    'valid.emailInvalid': 'Некорректный email',
    'valid.usernameRequired': 'Введите username',
    'valid.usernameMin': 'Минимум 3 символа',
    'valid.passwordRequired': 'Введите пароль',
    'valid.passwordMin': 'Минимум {n} символов',
    'valid.confirmRequired': 'Повторите пароль',
    'valid.passwordMismatch': 'Пароли не совпадают',
    'valid.passwordsMatch': 'Пароли совпадают',
    'valid.required': 'Обязательное поле',

    // ------------------------------------------------------ AI providers UI
    'ai.requiresAuth': 'Требуется авторизация',
    'ai.title': 'AI-провайдеры',
    'ai.refresh': 'Обновить',
    'ai.addProvider': 'Добавить провайдера',
    'ai.emptyList': 'Список пуст. Каталог провайдеров заполняет администратор.',
    'ai.errorPrefix': 'Ошибка: {error}',
    'ai.testFailed': 'Проверка не удалась',
    'ai.apiKeySaved': 'API-ключ сохранён на устройстве',
    'ai.providerAdded': 'Провайдер добавлен и отправлен администратору',
    'ai.providerUpdated': 'Провайдер обновлён',
    'ai.deleteTitle': 'Удалить провайдера?',
    'ai.deleteConfirm': 'Будет удалён ваш провайдер: {name}',
    'ai.newProvider': 'Новый провайдер',
    'ai.yourProvider': 'Ваш провайдер',
    'ai.providerNewHint': 'Провайдер появится у администратора с пометкой, что '
        'его добавили вы. Остальные пользователи увидят его после того, как '
        'администратор его опубликует. API-ключ сюда не входит — он остаётся '
        'на устройстве.',
    'ai.fieldName': 'Название',
    'ai.fieldPriority': 'Приоритет',
    'ai.fieldLoginUrl': 'Страница логина (URL)',
    'ai.fieldGetApiKeyUrl': 'Получить API-ключ (URL)',
    'ai.fieldLogoUrl': 'Логотип: ссылка',
    'ai.fieldLogoAsset': 'Логотип: имя в assets/logos',
    'ai.fieldEnabled': 'Включён',
    'ai.clipboardEmpty': 'В буфере обмена нет текста',
    'ai.apiKeyHint': 'Хранится только на этом устройстве',
    'ai.show': 'Показать',
    'ai.hide': 'Скрыть',
    'ai.paste': 'Вставить из буфера',
    'ai.clear': 'Очистить',
    'ai.apiKeyNote': 'Сам провайдер и его адрес задаются администратором. '
        'Ключ можно получить по ссылке «Получить API-ключ» и вставить сюда.',
    'ai.catalogueTitle': 'Каталог провайдеров ведёт администратор',
    'ai.syncOnDesc': 'Выключенные провайдеры сверяются с каталогом: если '
        'провайдер помечен как неработающий, он убирается из списка. Включённые '
        'не трогаются.',
    'ai.syncOffDesc': 'Синхронизация выключена: показан последний сохранённый '
        'список, изменения с сервера не подхватываются.',
    'ai.catalogueUpdated': 'Каталог обновлён: {time}',
    'ai.syncNow': 'Синхронизировать сейчас',
    'ai.webVersion': 'Веб-версия',
    'ai.keysStayLocal': 'API-ключи остаются на этом устройстве и на сервер не '
        'отправляются.',
    'ai.badgeMine': 'ваш',
    'ai.badgeDead': 'не работает',
    'ai.priority': 'Приоритет: {n}',
    'ai.keyNotSet': '(не задан)',
    'ai.keyEnter': 'ввести',
    'ai.deadHint': 'Проверка недоступна: провайдер помечен администратором.',
    'ai.loginPage': 'Страница логина',
    'ai.getApiKey': 'Получить API-ключ',
    'ai.enterKey': 'Ввести ключ',
    'ai.testAndModels': 'Проверить и список моделей',
    'ai.edit': 'Изменить',
    'ai.modelsTitle': 'Модели: {name}',
    'ai.fieldAddress': 'Адрес',
    'ai.fieldConfigured': 'Настроена',
    'ai.modelInList': 'есть в списке',
    'ai.modelNotInList': 'НЕТ в списке',
    'ai.modelsFound': 'Найдено моделей: {n}',
    'ai.modelsHint': 'Рядом — сколько пользователей проверили модель успешно, '
        'в скобках — сколько с ошибкой, и время последнего отчёта.',
    'ai.noData': 'нет данных',

    // ------------------------------------------------------- service errors
    'err.noConnection': 'Нет связи с сервером. Проверьте интернет-соединение.',
    'err.cancelled': 'Запрос был отменён.',
    'err.badCert': 'Проблема с сертификатом сервера.',
    'err.authFailed': 'Неверный email или пароль.',
    'err.createFailed': 'Не удалось создать аккаунт.',
    'err.updateFailed': 'Не удалось обновить данные.',
    'err.notFound': 'Запись не найдена.',
    'err.tooMany': 'Слишком много попыток. Повторите позже.',
    'err.serverError': 'Сервер вернул ошибку. Повторите позже.',
    'err.sessionExpired': 'Сессия истекла. Войдите заново.',
    'err.registerFailed': 'Ошибка регистрации',
    'err.loginFailed': 'Ошибка входа',
    'err.noToken': 'Сервер не вернул токен авторизации',
    'err.availabilityCheck': 'Не удалось проверить доступность',
    'err.availabilityCheckReason': 'Не удалось проверить: {reason}',
    'err.taken': 'занято',
    'err.invalidEmail': 'некорректный email',
    'err.min8': 'минимум 8 символов',
    'err.mismatch': 'значения не совпадают',
    'err.requiredField': 'обязательное поле',
    'err.tooShort': 'слишком короткое значение',
    'err.invalidValue': 'недопустимое значение',
    'err.configLoad': 'Не удалось получить конфиг с сервера',
    'err.configSave': 'Не удалось сохранить конфиг на сервере',
    'err.statsLoad': 'Не удалось получить статистику',
    'err.statsSave': 'Не удалось сохранить статистику',
    'err.providerTimeout': 'Провайдер не ответил вовремя.',
    'err.providerNoConnection': 'Нет связи с провайдером. Проверьте адрес и '
        'интернет.',
    'err.providerBadCert': 'Проблема с сертификатом провайдера.',
    'err.providerCancelled': 'Запрос отменён.',
    'err.badApiKey': 'Неверный API-ключ или он не подходит этому провайдеру.',
    'err.noModelsEndpoint': 'Провайдер не отдаёт список моделей по этому адресу.',
    'err.rateLimited': 'Провайдер ограничил запросы. Попробуйте позже.',
    'err.providerUnreachable': 'Не удалось связаться с провайдером.',
    'err.providerStatus': 'Провайдер ответил ошибкой {status}.',
    'err.providerEmptyModels': 'Провайдер ответил, но список моделей пуст.',
    'err.providerDead': 'Провайдер помечен администратором как неработающий.',
    'err.enterApiKey': 'Сначала введите API-ключ.',
    'err.modelNotOffered': 'Модель {model} не предлагается',
  },
  'en': <String, String>{
    // -------------------------------------------------------------- common
    'common.cancel': 'Cancel',
    'common.save': 'Save',
    'common.close': 'Close',
    'common.delete': 'Delete',
    'common.retry': 'Retry',
    'common.refresh': 'Refresh',
    'common.checking': 'Checking…',
    'common.free': 'Available',
    'common.taken': 'Taken',
    'common.logout': 'Log out',
    'common.user': 'user',

    // --------------------------------------------------------------- login
    'login.title': 'Sign in',
    'login.password': 'Password',
    'login.submit': 'Sign in',
    'login.noAccount': "Don't have an account? Sign up",
    'login.successTitle': 'Signed in',
    'login.successDesc': 'Welcome! You are signed in.',
    'login.failTitle': 'Sign-in failed',

    // ------------------------------------------------------------ register
    'register.title': 'Sign up',
    'register.usernameHint': 'Shown on the home screen',
    'register.password': 'Password',
    'register.confirmPassword': 'Repeat the password',
    'register.submit': 'Sign up',
    'register.haveAccount': 'Already have an account? Sign in',
    'register.successTitle': 'Registration successful',
    'register.successDesc': 'The account was created. Now sign in to continue.',
    'register.failTitle': 'Registration failed',
    'register.takenDesc': 'Email or username is already taken. '
        'If this is your account, sign in with it.',

    // ---------------------------------------------------------------- home
    'home.title': 'Home',
    'home.loggedInAs': 'Signed in as {name}',
    'home.aiProviders': 'AI providers',
    'home.settings': 'Settings',
    'home.logoutTitle': 'Log out?',
    'home.logoutConfirm': 'The session will end and you will need to sign in '
        'again.',

    // --------------------------------------------------------------- splash
    'splash.loading': 'Loading...',

    // --------------------------------------------------------- result screen
    'result.fallbackTitle': 'Result',
    'result.noDataTitle': 'No result data',
    'result.noDataDesc': 'Try the action again.',
    'result.goToLogin': 'Go to sign in',
    'result.goToLoginFallback': 'Go to sign in',
    'result.retry': 'Try again',
    'result.goToProfile': 'Go to profile',
    'result.createAnother': 'Create another account',
    'result.createAccount': 'Create account',

    // ------------------------------------------------------ settings screen
    'settings.title': 'Settings',
    'settings.languageTitle': 'Language',
    'settings.themeTitle': 'Theme',
    'language.ru': 'Russian',
    'language.en': 'English',
    'language.de': 'German',

    // --------------------------------------------------------------- themes
    'theme.day': 'Light',
    'theme.dayYellow': 'Light — yellow',
    'theme.dayRed': 'Light — red',
    'theme.dayGreen': 'Light — green',
    'theme.dayOrange': 'Light — orange',
    'theme.nightRed': 'Dark — red',
    'theme.nightBlue': 'Dark — blue',
    'theme.nightYellow': 'Dark — yellow',
    'theme.nightGreen': 'Dark — green',
    'theme.nightOrange': 'Dark — orange',

    // ----------------------------------------------------------- validators
    'valid.emailRequired': 'Enter an email',
    'valid.emailInvalid': 'Invalid email',
    'valid.usernameRequired': 'Enter a username',
    'valid.usernameMin': 'At least 3 characters',
    'valid.passwordRequired': 'Enter a password',
    'valid.passwordMin': 'At least {n} characters',
    'valid.confirmRequired': 'Repeat the password',
    'valid.passwordMismatch': 'Passwords do not match',
    'valid.passwordsMatch': 'Passwords match',
    'valid.required': 'Required field',

    // ------------------------------------------------------ AI providers UI
    'ai.requiresAuth': 'Authorization required',
    'ai.title': 'AI providers',
    'ai.refresh': 'Refresh',
    'ai.addProvider': 'Add provider',
    'ai.emptyList': 'The list is empty. The provider catalogue is maintained '
        'by an administrator.',
    'ai.errorPrefix': 'Error: {error}',
    'ai.testFailed': 'The check failed',
    'ai.apiKeySaved': 'The API key was saved on this device',
    'ai.providerAdded': 'The provider was added and sent to the administrator',
    'ai.providerUpdated': 'The provider was updated',
    'ai.deleteTitle': 'Delete the provider?',
    'ai.deleteConfirm': 'Your provider will be deleted: {name}',
    'ai.newProvider': 'New provider',
    'ai.yourProvider': 'Your provider',
    'ai.providerNewHint': 'The provider will appear for the administrator '
        'marked as added by you. Other users will see it once the administrator '
        'publishes it. The API key is not part of this — it stays on the device.',
    'ai.fieldName': 'Name',
    'ai.fieldPriority': 'Priority',
    'ai.fieldLoginUrl': 'Login page (URL)',
    'ai.fieldGetApiKeyUrl': 'Get API key (URL)',
    'ai.fieldLogoUrl': 'Logo: link',
    'ai.fieldLogoAsset': 'Logo: name in assets/logos',
    'ai.fieldEnabled': 'Enabled',
    'ai.clipboardEmpty': 'There is no text in the clipboard',
    'ai.apiKeyHint': 'Stored only on this device',
    'ai.show': 'Show',
    'ai.hide': 'Hide',
    'ai.paste': 'Paste from clipboard',
    'ai.clear': 'Clear',
    'ai.apiKeyNote': 'The provider itself and its address are set by the '
        'administrator. You can get a key via the "Get API key" link and paste '
        'it here.',
    'ai.catalogueTitle': 'The provider catalogue is maintained by an '
        'administrator',
    'ai.syncOnDesc': 'Disabled providers are checked against the catalogue: a '
        'provider marked as broken is removed from the list. Enabled ones are '
        'left untouched.',
    'ai.syncOffDesc': 'Synchronization is off: the last saved list is shown '
        'and changes from the server are not picked up.',
    'ai.catalogueUpdated': 'Catalogue updated: {time}',
    'ai.syncNow': 'Sync now',
    'ai.webVersion': 'Web version',
    'ai.keysStayLocal': 'API keys stay on this device and are not sent to the '
        'server.',
    'ai.badgeMine': 'yours',
    'ai.badgeDead': 'not working',
    'ai.priority': 'Priority: {n}',
    'ai.keyNotSet': '(not set)',
    'ai.keyEnter': 'enter',
    'ai.deadHint': 'The check is unavailable: the provider was marked by an '
        'administrator.',
    'ai.loginPage': 'Login page',
    'ai.getApiKey': 'Get API key',
    'ai.enterKey': 'Enter key',
    'ai.testAndModels': 'Check and list models',
    'ai.edit': 'Edit',
    'ai.modelsTitle': 'Models: {name}',
    'ai.fieldAddress': 'Address',
    'ai.fieldConfigured': 'Configured',
    'ai.modelInList': 'in the list',
    'ai.modelNotInList': 'NOT in the list',
    'ai.modelsFound': 'Models found: {n}',
    'ai.modelsHint': 'Next to each model: how many users checked it '
        'successfully, in brackets how many failed, and the time of the last '
        'report.',
    'ai.noData': 'no data',

    // ------------------------------------------------------- service errors
    'err.noConnection': 'No connection to the server. Check your internet '
        'connection.',
    'err.cancelled': 'The request was cancelled.',
    'err.badCert': 'There is a problem with the server certificate.',
    'err.authFailed': 'Wrong email or password.',
    'err.createFailed': 'Could not create the account.',
    'err.updateFailed': 'Could not update the data.',
    'err.notFound': 'Record not found.',
    'err.tooMany': 'Too many attempts. Try again later.',
    'err.serverError': 'The server returned an error. Try again later.',
    'err.sessionExpired': 'The session has expired. Sign in again.',
    'err.registerFailed': 'Registration error',
    'err.loginFailed': 'Sign-in error',
    'err.noToken': 'The server did not return an authorization token',
    'err.availabilityCheck': 'Could not check availability',
    'err.availabilityCheckReason': 'Could not check: {reason}',
    'err.taken': 'taken',
    'err.invalidEmail': 'invalid email',
    'err.min8': 'at least 8 characters',
    'err.mismatch': 'values do not match',
    'err.requiredField': 'required field',
    'err.tooShort': 'value is too short',
    'err.invalidValue': 'invalid value',
    'err.configLoad': 'Could not load the config from the server',
    'err.configSave': 'Could not save the config on the server',
    'err.statsLoad': 'Could not load the statistics',
    'err.statsSave': 'Could not save the statistics',
    'err.providerTimeout': 'The provider did not respond in time.',
    'err.providerNoConnection': 'No connection to the provider. Check the '
        'address and the internet.',
    'err.providerBadCert': 'There is a problem with the provider certificate.',
    'err.providerCancelled': 'The request was cancelled.',
    'err.badApiKey': 'Wrong API key, or it does not belong to this provider.',
    'err.noModelsEndpoint': 'The provider does not serve a model list at this '
        'address.',
    'err.rateLimited': 'The provider rate-limited the requests. Try again '
        'later.',
    'err.providerUnreachable': 'Could not reach the provider.',
    'err.providerStatus': 'The provider answered with error {status}.',
    'err.providerEmptyModels': 'The provider answered, but the model list is '
        'empty.',
    'err.providerDead': 'The provider is marked as not working by an '
        'administrator.',
    'err.enterApiKey': 'Enter an API key first.',
    'err.modelNotOffered': 'The model {model} is not offered',
  },
  'de': <String, String>{
    // -------------------------------------------------------------- common
    'common.cancel': 'Abbrechen',
    'common.save': 'Speichern',
    'common.close': 'Schließen',
    'common.delete': 'Löschen',
    'common.retry': 'Wiederholen',
    'common.refresh': 'Aktualisieren',
    'common.checking': 'Prüfe…',
    'common.free': 'Frei',
    'common.taken': 'Belegt',
    'common.logout': 'Abmelden',
    'common.user': 'Benutzer',

    // --------------------------------------------------------------- login
    'login.title': 'Anmelden',
    'login.password': 'Passwort',
    'login.submit': 'Anmelden',
    'login.noAccount': 'Noch kein Konto? Registrieren',
    'login.successTitle': 'Anmeldung erfolgreich',
    'login.successDesc': 'Willkommen! Sie sind angemeldet.',
    'login.failTitle': 'Anmeldung fehlgeschlagen',

    // ------------------------------------------------------------ register
    'register.title': 'Registrierung',
    'register.usernameHint': 'Wird auf dem Startbildschirm angezeigt',
    'register.password': 'Passwort',
    'register.confirmPassword': 'Passwort wiederholen',
    'register.submit': 'Registrieren',
    'register.haveAccount': 'Schon ein Konto? Anmelden',
    'register.successTitle': 'Registrierung erfolgreich',
    'register.successDesc': 'Das Konto wurde erstellt. Melden Sie sich an, um '
        'fortzufahren.',
    'register.failTitle': 'Registrierung fehlgeschlagen',
    'register.takenDesc': 'E-Mail oder Benutzername sind bereits vergeben. '
        'Falls es Ihr Konto ist, melden Sie sich damit an.',

    // ---------------------------------------------------------------- home
    'home.title': 'Startseite',
    'home.loggedInAs': 'Angemeldet als {name}',
    'home.aiProviders': 'KI-Anbieter',
    'home.settings': 'Einstellungen',
    'home.logoutTitle': 'Abmelden?',
    'home.logoutConfirm': 'Die Sitzung wird beendet, Sie müssen sich erneut '
        'anmelden.',

    // --------------------------------------------------------------- splash
    'splash.loading': 'Wird geladen...',

    // --------------------------------------------------------- result screen
    'result.fallbackTitle': 'Ergebnis',
    'result.noDataTitle': 'Keine Ergebnisdaten',
    'result.noDataDesc': 'Versuchen Sie die Aktion erneut.',
    'result.goToLogin': 'Zur Anmeldung',
    'result.goToLoginFallback': 'Zur Anmeldung',
    'result.retry': 'Erneut versuchen',
    'result.goToProfile': 'Zum Profil',
    'result.createAnother': 'Weiteres Konto erstellen',
    'result.createAccount': 'Konto erstellen',

    // ------------------------------------------------------ settings screen
    'settings.title': 'Einstellungen',
    'settings.languageTitle': 'Sprache',
    'settings.themeTitle': 'Design',
    'language.ru': 'Russisch',
    'language.en': 'Englisch',
    'language.de': 'Deutsch',

    // --------------------------------------------------------------- themes
    'theme.day': 'Hell',
    'theme.dayYellow': 'Hell — gelb',
    'theme.dayRed': 'Hell — rot',
    'theme.dayGreen': 'Hell — grün',
    'theme.dayOrange': 'Hell — orange',
    'theme.nightRed': 'Dunkel — rot',
    'theme.nightBlue': 'Dunkel — blau',
    'theme.nightYellow': 'Dunkel — gelb',
    'theme.nightGreen': 'Dunkel — grün',
    'theme.nightOrange': 'Dunkel — orange',

    // ----------------------------------------------------------- validators
    'valid.emailRequired': 'E-Mail eingeben',
    'valid.emailInvalid': 'Ungültige E-Mail',
    'valid.usernameRequired': 'Benutzername eingeben',
    'valid.usernameMin': 'Mindestens 3 Zeichen',
    'valid.passwordRequired': 'Passwort eingeben',
    'valid.passwordMin': 'Mindestens {n} Zeichen',
    'valid.confirmRequired': 'Passwort wiederholen',
    'valid.passwordMismatch': 'Passwörter stimmen nicht überein',
    'valid.passwordsMatch': 'Passwörter stimmen überein',
    'valid.required': 'Pflichtfeld',

    // ------------------------------------------------------ AI providers UI
    'ai.requiresAuth': 'Anmeldung erforderlich',
    'ai.title': 'KI-Anbieter',
    'ai.refresh': 'Aktualisieren',
    'ai.addProvider': 'Anbieter hinzufügen',
    'ai.emptyList': 'Die Liste ist leer. Der Anbieterkatalog wird von einem '
        'Administrator gepflegt.',
    'ai.errorPrefix': 'Fehler: {error}',
    'ai.testFailed': 'Die Prüfung ist fehlgeschlagen',
    'ai.apiKeySaved': 'Der API-Schlüssel wurde auf diesem Gerät gespeichert',
    'ai.providerAdded': 'Der Anbieter wurde hinzugefügt und an den '
        'Administrator gesendet',
    'ai.providerUpdated': 'Der Anbieter wurde aktualisiert',
    'ai.deleteTitle': 'Anbieter löschen?',
    'ai.deleteConfirm': 'Ihr Anbieter wird gelöscht: {name}',
    'ai.newProvider': 'Neuer Anbieter',
    'ai.yourProvider': 'Ihr Anbieter',
    'ai.providerNewHint': 'Der Anbieter erscheint beim Administrator mit dem '
        'Hinweis, dass Sie ihn hinzugefügt haben. Andere Nutzer sehen ihn, '
        'sobald der Administrator ihn veröffentlicht. Der API-Schlüssel gehört '
        'nicht dazu — er bleibt auf dem Gerät.',
    'ai.fieldName': 'Name',
    'ai.fieldPriority': 'Priorität',
    'ai.fieldLoginUrl': 'Anmeldeseite (URL)',
    'ai.fieldGetApiKeyUrl': 'API-Schlüssel erhalten (URL)',
    'ai.fieldLogoUrl': 'Logo: Link',
    'ai.fieldLogoAsset': 'Logo: Name in assets/logos',
    'ai.fieldEnabled': 'Aktiviert',
    'ai.clipboardEmpty': 'Die Zwischenablage enthält keinen Text',
    'ai.apiKeyHint': 'Nur auf diesem Gerät gespeichert',
    'ai.show': 'Anzeigen',
    'ai.hide': 'Ausblenden',
    'ai.paste': 'Aus Zwischenablage einfügen',
    'ai.clear': 'Leeren',
    'ai.apiKeyNote': 'Der Anbieter selbst und seine Adresse werden vom '
        'Administrator festgelegt. Einen Schlüssel erhalten Sie über den Link '
        '„API-Schlüssel erhalten" und fügen ihn hier ein.',
    'ai.catalogueTitle': 'Der Anbieterkatalog wird von einem Administrator '
        'gepflegt',
    'ai.syncOnDesc': 'Deaktivierte Anbieter werden mit dem Katalog '
        'abgeglichen: Ein als defekt markierter Anbieter wird aus der Liste '
        'entfernt. Aktivierte bleiben unberührt.',
    'ai.syncOffDesc': 'Die Synchronisierung ist aus: Es wird die zuletzt '
        'gespeicherte Liste angezeigt, Änderungen vom Server werden nicht '
        'übernommen.',
    'ai.catalogueUpdated': 'Katalog aktualisiert: {time}',
    'ai.syncNow': 'Jetzt synchronisieren',
    'ai.webVersion': 'Webversion',
    'ai.keysStayLocal': 'API-Schlüssel bleiben auf diesem Gerät und werden '
        'nicht an den Server gesendet.',
    'ai.badgeMine': 'Ihr',
    'ai.badgeDead': 'funktioniert nicht',
    'ai.priority': 'Priorität: {n}',
    'ai.keyNotSet': '(nicht festgelegt)',
    'ai.keyEnter': 'eingeben',
    'ai.deadHint': 'Die Prüfung ist nicht verfügbar: Der Anbieter wurde von '
        'einem Administrator markiert.',
    'ai.loginPage': 'Anmeldeseite',
    'ai.getApiKey': 'API-Schlüssel erhalten',
    'ai.enterKey': 'Schlüssel eingeben',
    'ai.testAndModels': 'Prüfen und Modelle auflisten',
    'ai.edit': 'Bearbeiten',
    'ai.modelsTitle': 'Modelle: {name}',
    'ai.fieldAddress': 'Adresse',
    'ai.fieldConfigured': 'Konfiguriert',
    'ai.modelInList': 'in der Liste',
    'ai.modelNotInList': 'NICHT in der Liste',
    'ai.modelsFound': 'Gefundene Modelle: {n}',
    'ai.modelsHint': 'Daneben: wie viele Nutzer das Modell erfolgreich geprüft '
        'haben, in Klammern wie viele mit Fehler, und die Zeit des letzten '
        'Berichts.',
    'ai.noData': 'keine Daten',

    // ------------------------------------------------------- service errors
    'err.noConnection': 'Keine Verbindung zum Server. Prüfen Sie die '
        'Internetverbindung.',
    'err.cancelled': 'Die Anfrage wurde abgebrochen.',
    'err.badCert': 'Es gibt ein Problem mit dem Serverzertifikat.',
    'err.authFailed': 'Falsche E-Mail oder falsches Passwort.',
    'err.createFailed': 'Das Konto konnte nicht erstellt werden.',
    'err.updateFailed': 'Die Daten konnten nicht aktualisiert werden.',
    'err.notFound': 'Eintrag nicht gefunden.',
    'err.tooMany': 'Zu viele Versuche. Versuchen Sie es später erneut.',
    'err.serverError': 'Der Server hat einen Fehler zurückgegeben. Versuchen '
        'Sie es später erneut.',
    'err.sessionExpired': 'Die Sitzung ist abgelaufen. Melden Sie sich erneut '
        'an.',
    'err.registerFailed': 'Registrierungsfehler',
    'err.loginFailed': 'Anmeldefehler',
    'err.noToken': 'Der Server hat kein Autorisierungstoken zurückgegeben',
    'err.availabilityCheck': 'Verfügbarkeit konnte nicht geprüft werden',
    'err.availabilityCheckReason': 'Prüfung fehlgeschlagen: {reason}',
    'err.taken': 'belegt',
    'err.invalidEmail': 'ungültige E-Mail',
    'err.min8': 'mindestens 8 Zeichen',
    'err.mismatch': 'Werte stimmen nicht überein',
    'err.requiredField': 'Pflichtfeld',
    'err.tooShort': 'Wert ist zu kurz',
    'err.invalidValue': 'ungültiger Wert',
    'err.configLoad': 'Konfiguration konnte nicht vom Server geladen werden',
    'err.configSave': 'Konfiguration konnte nicht auf dem Server gespeichert '
        'werden',
    'err.statsLoad': 'Statistik konnte nicht geladen werden',
    'err.statsSave': 'Statistik konnte nicht gespeichert werden',
    'err.providerTimeout': 'Der Anbieter hat nicht rechtzeitig geantwortet.',
    'err.providerNoConnection': 'Keine Verbindung zum Anbieter. Prüfen Sie '
        'Adresse und Internet.',
    'err.providerBadCert': 'Es gibt ein Problem mit dem Anbieterzertifikat.',
    'err.providerCancelled': 'Die Anfrage wurde abgebrochen.',
    'err.badApiKey': 'Falscher API-Schlüssel oder er passt nicht zu diesem '
        'Anbieter.',
    'err.noModelsEndpoint': 'Der Anbieter liefert unter dieser Adresse keine '
        'Modellliste.',
    'err.rateLimited': 'Der Anbieter hat die Anfragen begrenzt. Versuchen Sie '
        'es später erneut.',
    'err.providerUnreachable': 'Der Anbieter konnte nicht erreicht werden.',
    'err.providerStatus': 'Der Anbieter hat mit Fehler {status} geantwortet.',
    'err.providerEmptyModels': 'Der Anbieter hat geantwortet, aber die '
        'Modellliste ist leer.',
    'err.providerDead': 'Der Anbieter wurde von einem Administrator als nicht '
        'funktionsfähig markiert.',
    'err.enterApiKey': 'Geben Sie zuerst einen API-Schlüssel ein.',
    'err.modelNotOffered': 'Das Modell {model} wird nicht angeboten',
  },
};

/// Looks up [key] in [language], falls back to Russian and finally to [key]
/// itself, so plain text (`"Just a message"`) is passed through untouched.
///
/// The `{name}` placeholders are replaced from [args].
String translate(
  String key,
  String language, {
  Map<String, String>? args,
}) {
  final table = kTranslations[language] ?? kTranslations['ru']!;
  final ru = kTranslations['ru']!;

  final direct = table[key] ?? ru[key];
  if (direct != null) return _applyArgs(direct, args);

  // Composite messages (several error keys in one line, or a key embedded in
  // a sentence) must still render as text rather than as raw keys, so every
  // key-looking token is translated as well.
  return key.replaceAllMapped(_keyToken, (Match match) {
    final token = match.group(0)!;
    final value = table[token] ?? ru[token];
    if (value == null) return token;
    return _applyArgs(value, args);
  });
}

/// `err.noConnection`, `screen.element`, `ai.addProvider`, `theme.dayYellow`.
final RegExp _keyToken = RegExp(r'[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+');

String _applyArgs(String value, Map<String, String>? args) {
  if (args == null || args.isEmpty) return value;
  var result = value;
  args.forEach((String name, String replacement) {
    result = result.replaceAll('{$name}', replacement);
  });
  return result;
}
