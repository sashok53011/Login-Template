/* AI Providers list — https://app.devhorizon.online/ai-providers/
 *
 * Served by PocketBase itself, so everything is same-origin: the page talks to
 * /api/collections/users/* for auth and to /api/ai-config for the shared
 * per-user provider list. No build step, no dependencies.
 *
 * API keys are intentionally absent: they live only on the phone
 * (flutter_secure_storage) and never reach this page or the server file.
 *
 * All copy is localised (ru / en / de) through STR / t(); the language and
 * theme switchers live in /ui.js and are shared with the landing page.
 */

const TOKEN_KEY = "ai_token";
const USER_KEY = "ai_user";

const STR = {
  ru: {
    pageTitle: "AI-провайдеры — app.devhorizon.online",
    appTitle: "Список AI-провайдеров",
    logout: "Выйти",
    tabLogin: "Вход",
    tabRegister: "Регистрация",
    email: "Email",
    password: "Пароль",
    adminLogin: "Вход администратора (superuser)",
    loginSubmit: "Войти",
    userName: "Имя пользователя",
    passwordRepeat: "Повтор пароля",
    registerSubmit: "Зарегистрироваться",
    addBtn: "+ Добавить провайдера",
    reloadBtn: "Обновить",
    trashBtn: "Корзина",
    emptyNote: "Список пуст. Нажмите «Добавить провайдера».",
    footerAdmin: "Панель администратора",
    editorTitle: "Провайдер",
    editorTitleNew: "Новый провайдер",
    fieldName: "Название *",
    fieldEnabled: "Включён",
    fieldUrl: "URL *",
    fieldModel: "Model *",
    fieldPriority: "Приоритет (fallback) *",
    fieldStatus: "Статус",
    statusActive: "Работает",
    statusDead: "Не работает — убрать у пользователей",
    fieldLoginUrl: "Страница логина (URL)",
    fieldGetKey: "Получить API-ключ (URL)",
    fieldLogoUrl: "Логотип: ссылка (logoUrl)",
    fieldLogoAsset: "Логотип: готовый (logoAsset)",
    logoNone: "— не выбран —",
    fieldOrigin: "Видят",
    originAdmin: "Все пользователи",
    originUser: "Только автор",
    cancel: "Отмена",
    save: "Сохранить",
    trashTitle: "Корзина",
    trashNote:
      "Удалённые провайдеры хранятся здесь (последние 200) вместе с тем, кто их удалил. Восстановление возвращает провайдера под тем же id, а значит и ключи, которые пользователи уже ввели на устройствах.",
    trashEmpty: "Корзина пуста.",
    trashPurgeAll: "Очистить корзину",
    trashClose: "Закрыть",
    whoAdmin: " (админ)",
    statsTitle: "Статистика проверок",
    savedAt: "Сохранено: {when}",
    neverSaved: "Изменений ещё не было",
    saving: "Сохранение…",
    notSaved: "Не сохранено",
    badgeMine: "ваш",
    badgeFrom: "от {name}",
    badgeFromUser: "от пользователя",
    badgeDead: "не работает",
    badgeDisabledForAll: "отключён админом",
    disabledForAllHint:
      "Администратор отключил этого провайдера для всех. Выключите его, чтобы убрать из списка.",
    turnOff: "Выключить",
    statusDisabled: "Отключён для всех — убрать у всех",
    rowPriority: "Приоритет",
    linkLogin: "Страница логина",
    linkGetKey: "Получить API-ключ",
    toggleTitle: "Включён",
    edit: "Редактировать",
    remove: "Удалить",
    confirmDelete: "Удалить провайдера «{name}»?",
    badgeProposal: "предложение",
    badgeCatalogue: "каталог",
    trashDeleted: "Удалён {when}",
    trashDeletedBy: "Удалён {when} — {name}",
    restore: "Восстановить",
    purgeOne: "Удалить навсегда",
    confirmRestore: "Вернуть провайдера «{name}» в каталог?",
    restoreFailed: "Не удалось восстановить.",
    restoreFailedMsg: "Не удалось восстановить: {message}",
    confirmPurgeOne:
      "Удалить «{name}» из корзины навсегда? Восстановить будет нельзя.",
    purgeFailedMsg: "Не удалось удалить: {message}",
    confirmPurgeAll:
      "Очистить корзину полностью? Восстановить будет нельзя.",
    purgeAllFailedMsg: "Не удалось очистить корзину: {message}",
    trashOpenFailed: "Не удалось открыть корзину: {message}",
    saveFailedMsg: "Не удалось сохранить: {message}",
    loadFailedMsg: "Не удалось загрузить список: {message}",
    noteAdmin:
      "Вы вошли как <strong>администратор</strong>: здесь задаётся каталог " +
      "провайдеров для всех пользователей. Помеченные «не работает» " +
      "убираются из списков пользователей. <strong>API-ключи</strong> здесь " +
      "не хранятся — их вводят в приложении. Статистика проверок " +
      "обновляется автоматически.",
    noteUser:
      "Каталог провайдеров ведёт администратор. Здесь можно " +
      "<strong>включить</strong> нужных провайдеров — они появятся в " +
      "Android-приложении. <strong>API-ключи</strong> на сервере не " +
      "хранятся: их вводят только в приложении, они остаются на устройстве. " +
      "Статистика проверок обновляется автоматически.",
    errSession: "Нужно войти заново: сессия истекла.",
    errAuth: "Неверный email или пароль.",
    errEmailTaken: "Такой email уже занят. Если это ваш аккаунт — войдите.",
    errRequest: "Запрос не удался (HTTP {status}).",
    fieldTaken: "занято",
    fieldEmail: "некорректный email",
    fieldRequired: "обязательное поле",
    fieldMin8: "минимум 8 символов",
    fieldMismatch: "пароли не совпадают",
    fieldUrlBad: "некорректная ссылка",
  },
  en: {
    pageTitle: "AI providers — app.devhorizon.online",
    appTitle: "AI providers list",
    logout: "Sign out",
    tabLogin: "Sign in",
    tabRegister: "Register",
    email: "Email",
    password: "Password",
    adminLogin: "Administrator sign-in (superuser)",
    loginSubmit: "Sign in",
    userName: "Username",
    passwordRepeat: "Repeat password",
    registerSubmit: "Register",
    addBtn: "+ Add provider",
    reloadBtn: "Reload",
    trashBtn: "Bin",
    emptyNote: "The list is empty. Press “Add provider”.",
    footerAdmin: "Admin panel",
    editorTitle: "Provider",
    editorTitleNew: "New provider",
    fieldName: "Name *",
    fieldEnabled: "Enabled",
    fieldUrl: "URL *",
    fieldModel: "Model *",
    fieldPriority: "Priority (fallback) *",
    fieldStatus: "Status",
    statusActive: "Working",
    statusDead: "Not working — hide from users",
    fieldLoginUrl: "Login page (URL)",
    fieldGetKey: "Get API key (URL)",
    fieldLogoUrl: "Logo: link (logoUrl)",
    fieldLogoAsset: "Logo: built-in (logoAsset)",
    logoNone: "— none —",
    fieldOrigin: "Visible to",
    originAdmin: "All users",
    originUser: "Author only",
    cancel: "Cancel",
    save: "Save",
    trashTitle: "Bin",
    trashNote:
      "Deleted providers are kept here (the last 200) together with who " +
      "deleted them. Restoring brings the provider back under the same id, " +
      "and therefore the keys users have already entered on their devices.",
    trashEmpty: "The bin is empty.",
    trashPurgeAll: "Empty the bin",
    trashClose: "Close",
    whoAdmin: " (admin)",
    statsTitle: "Check statistics",
    savedAt: "Saved: {when}",
    neverSaved: "No changes yet",
    saving: "Saving…",
    notSaved: "Not saved",
    badgeMine: "yours",
    badgeFrom: "from {name}",
    badgeFromUser: "from a user",
    badgeDead: "not working",
    badgeDisabledForAll: "switched off by admin",
    disabledForAllHint:
      "The administrator switched this provider off for everybody. Turn it off to remove it from your list.",
    turnOff: "Turn off",
    statusDisabled: "Switched off for everybody - remove for all",
    rowPriority: "Priority",
    linkLogin: "Login page",
    linkGetKey: "Get API key",
    toggleTitle: "Enabled",
    edit: "Edit",
    remove: "Delete",
    confirmDelete: "Delete the provider “{name}”?",
    badgeProposal: "proposal",
    badgeCatalogue: "catalogue",
    trashDeleted: "Deleted {when}",
    trashDeletedBy: "Deleted {when} — {name}",
    restore: "Restore",
    purgeOne: "Delete permanently",
    confirmRestore: "Restore the provider “{name}” to the catalogue?",
    restoreFailed: "Could not restore.",
    restoreFailedMsg: "Could not restore: {message}",
    confirmPurgeOne:
      "Delete “{name}” from the bin permanently? It cannot be restored.",
    purgeFailedMsg: "Could not delete: {message}",
    confirmPurgeAll: "Empty the bin completely? It cannot be undone.",
    purgeAllFailedMsg: "Could not empty the bin: {message}",
    trashOpenFailed: "Could not open the bin: {message}",
    saveFailedMsg: "Could not save: {message}",
    loadFailedMsg: "Could not load the list: {message}",
    noteAdmin:
      "You are signed in as an <strong>administrator</strong>: the provider " +
      "catalogue for all users is configured here. Entries marked “not " +
      "working” are removed from users' lists. <strong>API keys</strong> are " +
      "not stored here — they are entered in the app. Check statistics " +
      "refresh automatically.",
    noteUser:
      "The provider catalogue is maintained by an administrator. Here you " +
      "can <strong>enable</strong> the providers you need — they will appear " +
      "in the Android app. <strong>API keys</strong> are not stored on the " +
      "server: they are entered only in the app and stay on the device. " +
      "Check statistics refresh automatically.",
    errSession: "Please sign in again: the session has expired.",
    errAuth: "Wrong email or password.",
    errEmailTaken: "This email is already taken. If it is your account, sign in.",
    errRequest: "Request failed (HTTP {status}).",
    fieldTaken: "taken",
    fieldEmail: "invalid email",
    fieldRequired: "required field",
    fieldMin8: "at least 8 characters",
    fieldMismatch: "passwords do not match",
    fieldUrlBad: "invalid link",
  },
  de: {
    pageTitle: "KI-Anbieter — app.devhorizon.online",
    appTitle: "Liste der KI-Anbieter",
    logout: "Abmelden",
    tabLogin: "Anmeldung",
    tabRegister: "Registrierung",
    email: "E-Mail",
    password: "Passwort",
    adminLogin: "Administrator-Anmeldung (Superuser)",
    loginSubmit: "Anmelden",
    userName: "Benutzername",
    passwordRepeat: "Passwort wiederholen",
    registerSubmit: "Registrieren",
    addBtn: "+ Anbieter hinzufügen",
    reloadBtn: "Aktualisieren",
    trashBtn: "Papierkorb",
    emptyNote: "Die Liste ist leer. Klicken Sie auf „Anbieter hinzufügen“.",
    footerAdmin: "Admin-Panel",
    editorTitle: "Anbieter",
    editorTitleNew: "Neuer Anbieter",
    fieldName: "Name *",
    fieldEnabled: "Aktiviert",
    fieldUrl: "URL *",
    fieldModel: "Model *",
    fieldPriority: "Priorität (Fallback) *",
    fieldStatus: "Status",
    statusActive: "Funktioniert",
    statusDead: "Funktioniert nicht — für Benutzer ausblenden",
    fieldLoginUrl: "Anmeldeseite (URL)",
    fieldGetKey: "API-Schlüssel erhalten (URL)",
    fieldLogoUrl: "Logo: Link (logoUrl)",
    fieldLogoAsset: "Logo: integriert (logoAsset)",
    logoNone: "— nicht ausgewählt —",
    fieldOrigin: "Sichtbar für",
    originAdmin: "Alle Benutzer",
    originUser: "Nur Autor",
    cancel: "Abbrechen",
    save: "Speichern",
    trashTitle: "Papierkorb",
    trashNote:
      "Gelöschte Anbieter werden hier aufbewahrt (die letzten 200) zusammen " +
      "mit der Person, die sie gelöscht hat. Eine Wiederherstellung bringt " +
      "den Anbieter unter derselben id zurück, also auch die Schlüssel, die " +
      "Benutzer bereits auf ihren Geräten eingegeben haben.",
    trashEmpty: "Der Papierkorb ist leer.",
    trashPurgeAll: "Papierkorb leeren",
    trashClose: "Schließen",
    whoAdmin: " (Admin)",
    statsTitle: "Prüfstatistik",
    savedAt: "Gespeichert: {when}",
    neverSaved: "Noch keine Änderungen",
    saving: "Speichern…",
    notSaved: "Nicht gespeichert",
    badgeMine: "Ihres",
    badgeFrom: "von {name}",
    badgeFromUser: "von einem Benutzer",
    badgeDead: "funktioniert nicht",
    badgeDisabledForAll: "vom Admin abgeschaltet",
    disabledForAllHint:
      "Der Administrator hat diesen Anbieter für alle abgeschaltet. Schalten Sie ihn aus, um ihn aus der Liste zu entfernen.",
    turnOff: "Ausschalten",
    statusDisabled: "Für alle abgeschaltet - überall entfernen",
    rowPriority: "Priorität",
    linkLogin: "Anmeldeseite",
    linkGetKey: "API-Schlüssel erhalten",
    toggleTitle: "Aktiviert",
    edit: "Bearbeiten",
    remove: "Löschen",
    confirmDelete: "Anbieter „{name}“ löschen?",
    badgeProposal: "Vorschlag",
    badgeCatalogue: "Katalog",
    trashDeleted: "Gelöscht {when}",
    trashDeletedBy: "Gelöscht {when} — {name}",
    restore: "Wiederherstellen",
    purgeOne: "Endgültig löschen",
    confirmRestore: "Anbieter „{name}“ in den Katalog zurückholen?",
    restoreFailed: "Wiederherstellung fehlgeschlagen.",
    restoreFailedMsg: "Wiederherstellung fehlgeschlagen: {message}",
    confirmPurgeOne:
      "„{name}“ endgültig aus dem Papierkorb löschen? Eine Wiederherstellung ist dann nicht möglich.",
    purgeFailedMsg: "Löschen fehlgeschlagen: {message}",
    confirmPurgeAll:
      "Papierkorb vollständig leeren? Eine Wiederherstellung ist dann nicht möglich.",
    purgeAllFailedMsg: "Papierkorb konnte nicht geleert werden: {message}",
    trashOpenFailed: "Papierkorb konnte nicht geöffnet werden: {message}",
    saveFailedMsg: "Speichern fehlgeschlagen: {message}",
    loadFailedMsg: "Liste konnte nicht geladen werden: {message}",
    noteAdmin:
      "Sie sind als <strong>Administrator</strong> angemeldet: hier wird " +
      "der Anbieter-Katalog für alle Benutzer verwaltet. Mit „funktioniert " +
      "nicht“ markierte Einträge werden aus den Listen der Benutzer entfernt. " +
      "<strong>API-Schlüssel</strong> werden hier nicht gespeichert — sie " +
      "werden in der App eingegeben. Die Prüfstatistik wird automatisch " +
      "aktualisiert.",
    noteUser:
      "Der Anbieter-Katalog wird von einem Administrator gepflegt. Hier " +
      "können Sie die gewünschten Anbieter <strong>aktivieren</strong> — sie " +
      "erscheinen dann in der Android-App. <strong>API-Schlüssel</strong> " +
      "werden nicht auf dem Server gespeichert: sie werden nur in der App " +
      "eingegeben und bleiben auf dem Gerät. Die Prüfstatistik wird " +
      "automatisch aktualisiert.",
    errSession: "Bitte erneut anmelden: die Sitzung ist abgelaufen.",
    errAuth: "Falsche E-Mail oder falsches Passwort.",
    errEmailTaken:
      "Diese E-Mail ist bereits vergeben. Wenn es Ihr Konto ist, melden Sie sich an.",
    errRequest: "Anfrage fehlgeschlagen (HTTP {status}).",
    fieldTaken: "vergeben",
    fieldEmail: "ungültige E-Mail",
    fieldRequired: "Pflichtfeld",
    fieldMin8: "mindestens 8 Zeichen",
    fieldMismatch: "Passwörter stimmen nicht überein",
    fieldUrlBad: "ungültiger Link",
  },
};

function t(key, vars) {
  const pack = STR[UI.lang] || STR.ru;
  let text = pack[key] !== undefined ? pack[key] : STR.ru[key];
  if (text === undefined) {
    text = key;
  }
  if (vars) {
    text = text.replace(/\{(\w+)\}/g, function (match, name) {
      return vars[name] !== undefined ? vars[name] : match;
    });
  }
  return text;
}

/* Fills every [data-i18n] placeholder in the static markup. */
function applyI18n() {
  document.querySelectorAll("[data-i18n]").forEach(function (node) {
    node.textContent = t(node.getAttribute("data-i18n"));
  });
}

const state = {
  token: localStorage.getItem(TOKEN_KEY) || null,
  user: safeParse(localStorage.getItem(USER_KEY)),
  config: null,
  stats: {},
  trash: [],
  canEdit: false,
  editingId: null,
};

let pollTimer = null;

const el = {
  authView: document.getElementById("auth-view"),
  providersView: document.getElementById("providers-view"),
  topbarActions: document.getElementById("topbar-actions"),
  who: document.getElementById("who"),
  host: document.getElementById("host-label"),
  loginForm: document.getElementById("login-form"),
  registerForm: document.getElementById("register-form"),
  authNote: document.getElementById("auth-note"),
  providers: document.getElementById("providers"),
  providersNote: document.getElementById("providers-note"),
  emptyNote: document.getElementById("empty-note"),
  syncStatus: document.getElementById("sync-status"),
  errorNote: document.getElementById("error-note"),
  editor: document.getElementById("editor"),
  editorForm: document.getElementById("editor-form"),
  editorTitle: document.getElementById("editor-title"),
  addBtn: document.getElementById("add-btn"),
  reloadBtn: document.getElementById("reload-btn"),
  logoutBtn: document.getElementById("logout-btn"),
  editorCancel: document.getElementById("editor-cancel"),
  adminLogin: document.getElementById("admin-login"),
  trashBtn: document.getElementById("trash-btn"),
  trash: document.getElementById("trash"),
  trashList: document.getElementById("trash-list"),
  trashEmpty: document.getElementById("trash-empty"),
  trashClose: document.getElementById("trash-close"),
  trashPurgeAll: document.getElementById("trash-purge-all"),
};

function safeParse(raw) {
  try {
    return raw ? JSON.parse(raw) : null;
  } catch (err) {
    return null;
  }
}

/* ------------------------------------------------------------------ api */

async function api(path, options) {
  const opts = options || {};
  const headers = {};
  if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
  }
  if (opts.auth !== false && state.token) {
    headers["Authorization"] = state.token;
  }

  const res = await fetch(path, {
    method: opts.method || "GET",
    headers: headers,
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });

  const text = await res.text();
  let data = null;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch (err) {
      data = text;
    }
  }

  if (!res.ok) {
    const error = new Error(humanError(data, res.status));
    error.status = res.status;
    error.payload = data;
    throw error;
  }

  return data;
}

function humanError(data, status) {
  if (status === 401) {
    return t("errSession");
  }

  const raw = data && typeof data === "object" ? String(data.message || "") : "";
  const lower = raw.toLowerCase();

  if (lower.includes("failed to authenticate")) {
    return t("errAuth");
  }
  if (lower.includes("already exists") || lower.includes("must be unique")) {
    return t("errEmailTaken");
  }

  const details = [];
  if (data && typeof data === "object" && data.data) {
    Object.keys(data.data).forEach(function (field) {
      const item = data.data[field];
      const message =
        item && typeof item === "object" ? item.message : String(item);
      details.push(field + ": " + localizeField(String(message)));
    });
  }

  if (details.length) {
    return (raw ? raw + " " : "") + details.join("\n");
  }
  return raw || t("errRequest", { status: status });
}

function localizeField(message) {
  const m = message.toLowerCase();
  if (m.includes("already exists") || m.includes("must be unique")) {
    return t("fieldTaken");
  }
  if (m.includes("valid email")) {
    return t("fieldEmail");
  }
  if (m.includes("required")) {
    return t("fieldRequired");
  }
  if (m.includes("at least 8")) {
    return t("fieldMin8");
  }
  if (m.includes("do not match")) {
    return t("fieldMismatch");
  }
  if (m.includes("valid url")) {
    return t("fieldUrlBad");
  }
  return message;
}

/* ----------------------------------------------------------------- auth */

async function doLogin(identity, password, isAdmin) {
  // PocketBase keeps superusers in a separate collection.
  const collectionName = isAdmin ? "_superusers" : "users";

  const data = await api(
    "/api/collections/" + collectionName + "/auth-with-password",
    {
      method: "POST",
      auth: false,
      body: { identity: identity, password: password },
    },
  );

  const record = data.record || {};
  state.token = data.token;
  state.user = {
    name: record.name || record.email || "superuser",
    email: record.email || "",
    isAdmin: !!isAdmin,
  };

  localStorage.setItem(TOKEN_KEY, data.token);
  localStorage.setItem(USER_KEY, JSON.stringify(state.user));
}

async function doRegister(email, name, password, passwordConfirm) {
  await api("/api/collections/users/records", {
    method: "POST",
    auth: false,
    body: {
      email: email,
      name: name,
      password: password,
      passwordConfirm: passwordConfirm,
    },
  });
  await doLogin(email, password, false);
}

function doLogout() {
  stopPolling();
  state.token = null;
  state.user = null;
  state.config = null;
  state.stats = {};
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(USER_KEY);
  render();
}

/* ---------------------------------------------------------------- stats */

/// The counters are refreshed on a timer, which is what makes the numbers
/// move "in real time" as other people run their tests.
function startPolling() {
  stopPolling();
  pollTimer = window.setInterval(refreshStats, 8000);
}

function stopPolling() {
  if (pollTimer) {
    window.clearInterval(pollTimer);
    pollTimer = null;
  }
}

async function refreshStats() {
  try {
    const stats = await api("/api/ai-stats");
    state.stats = stats && typeof stats === "object" ? stats : {};
    if (state.token) {
      renderProviders();
    }
  } catch (err) {
    // Statistics are secondary: never disturb the page over them.
  }
}

function formatStats(model) {
  const users =
    model.usersFail > 0
      ? model.usersOk + " (" + model.usersFail + ")"
      : String(model.usersOk);
  const when = model.last ? shortTime(model.last) : "";
  return when ? users + " · " + when : users;
}

function shortTime(value) {
  const date = new Date(value);
  if (isNaN(date.getTime())) return "";
  const two = function (n) {
    return String(n).padStart(2, "0");
  };
  return (
    two(date.getDate()) +
    "." +
    two(date.getMonth() + 1) +
    " " +
    two(date.getHours()) +
    ":" +
    two(date.getMinutes())
  );
}

/// Lists every model of the provider that has counters, with the configured
/// one highlighted.
function statsBlock(provider) {
  const providerStats = state.stats[provider.id];
  if (!providerStats || !providerStats.models) return null;

  const names = Object.keys(providerStats.models);
  if (!names.length) return null;
  names.sort();

  const wrap = document.createElement("div");
  wrap.className = "stats";

  const title = document.createElement("div");
  title.className = "stats-title";
  title.textContent = t("statsTitle");
  wrap.appendChild(title);

  names.forEach(function (name) {
    const model = providerStats.models[name];

    const row = document.createElement("div");
    row.className = "stats-row";

    const label = document.createElement("span");
    label.className = name === provider.model ? "stats-current" : "";
    label.textContent = name;

    const value = document.createElement("span");
    value.className = "stats-value" + (model.fail > 0 ? " stats-has-fail" : "");
    value.textContent = formatStats(model);

    row.appendChild(label);
    row.appendChild(value);
    wrap.appendChild(row);
  });

  return wrap;
}

/* --------------------------------------------------------------- config */

async function loadConfig() {
  state.config = await api("/api/ai-config");
  if (!Array.isArray(state.config.providers)) {
    state.config.providers = [];
  }
  // Granted only to a PocketBase superuser.
  state.canEdit = state.config.canEdit === true;
}

async function saveConfig() {
  state.config = await api("/api/ai-config", {
    method: "PUT",
    body: { version: 1, providers: state.config.providers },
  });
  stampSync();
}

function stampSync() {
  const updated = state.config && state.config.updated;
  el.syncStatus.textContent = updated
    ? t("savedAt", { when: updated.replace("T", " ").replace("Z", " UTC") })
    : t("neverSaved");
}

/* --------------------------------------------------------------- render */

function render() {
  const loggedIn = !!state.token;

  el.authView.hidden = loggedIn;
  el.providersView.hidden = !loggedIn;
  el.topbarActions.hidden = !loggedIn;

  if (state.user) {
    el.who.textContent =
      (state.user.name || state.user.email || "") +
      (state.user.isAdmin ? t("whoAdmin") : "");
  }

  if (loggedIn) {
    // Adding, editing and deleting is reserved for the superuser, and so is
    // the bin.
    el.addBtn.hidden = !state.canEdit;
    el.trashBtn.hidden = !state.canEdit;
    renderProviders();
    stampSync();
  }
}

function setAuthNote(message) {
  el.authNote.hidden = !message;
  el.authNote.textContent = message || "";
}

function setError(message) {
  el.errorNote.hidden = !message;
  el.errorNote.textContent = message || "";
}

function showAuth() {
  if (state.token) {
    render();
    refresh();
  } else {
    render();
  }
}

function renderProviders() {
  const list = state.config ? state.config.providers : [];
  el.providers.textContent = "";
  el.emptyNote.hidden = list.length > 0;

  el.providersNote.innerHTML = state.canEdit
    ? t("noteAdmin")
    : t("noteUser");

  list.forEach(function (provider) {
    el.providers.appendChild(providerCard(provider));
  });
}

function providerCard(provider) {
  const card = document.createElement("article");
  card.className = "provider" + (provider.enabled ? "" : " is-off");
  card.dataset.id = provider.id;

  card.appendChild(logoNode(provider));

  const body = document.createElement("div");
  const title = document.createElement("h3");
  title.textContent = provider.name;

  if (provider.origin === "user") {
    // The administrator sees who proposed it; the author sees their own.
    const badge = document.createElement("span");
    badge.className = "badge badge-user";
    badge.textContent = provider.mine
      ? t("badgeMine")
      : provider.authorName
        ? t("badgeFrom", { name: provider.authorName })
        : t("badgeFromUser");
    title.appendChild(badge);
  }

  if (provider.status === "dead") {
    const badge = document.createElement("span");
    badge.className = "badge";
    badge.textContent = t("badgeDead");
    title.appendChild(badge);
  }

  if (provider.status === "disabled_for_all") {
    const badge = document.createElement("span");
    badge.className = "badge";
    badge.textContent = t("badgeDisabledForAll");
    title.appendChild(badge);
  }
  body.appendChild(title);

  const dl = document.createElement("dl");
  addRow(dl, "URL", provider.url);
  addRow(dl, "Model", provider.model);

  const modelStats = statsOf(provider);
  if (modelStats) {
    const dd = dl.querySelector("dd:last-of-type");
    if (dd) {
      const badge = document.createElement("span");
      badge.className =
        "stats-value" + (modelStats.fail > 0 ? " stats-has-fail" : "");
      badge.textContent = formatStats(modelStats);
      dd.appendChild(document.createTextNode(" "));
      dd.appendChild(badge);
    }
  }

  addRow(dl, t("rowPriority"), String(provider.fallbackPriority));
  body.appendChild(dl);

  // Switched off for everybody: whoever still has it on is asked to turn it
  // off, which is what finally removes it from that user's list.
  if (provider.status === "disabled_for_all") {
    const blocked = document.createElement("div");
    blocked.className = "blocked";

    const note = document.createElement("div");
    note.className = "blocked-note";
    note.textContent = t("disabledForAllHint");
    blocked.appendChild(note);

    const turnOff = document.createElement("button");
    turnOff.type = "button";
    turnOff.className = "btn btn-ghost btn-mini";
    turnOff.textContent = t("turnOff");
    turnOff.addEventListener("click", function () {
      provider.enabled = false;
      card.classList.add("is-off");
      const box = card.querySelector('input[type="checkbox"]');
      if (box) box.checked = false;
      persist();
    });
    blocked.appendChild(turnOff);

    body.appendChild(blocked);
  }

  const block = statsBlock(provider);
  if (block) {
    body.appendChild(block);
  }

  const links = document.createElement("div");
  links.className = "links";
  if (provider.loginUrl) {
    links.appendChild(extLink(provider.loginUrl, t("linkLogin")));
  }
  if (provider.getApiKeyUrl) {
    links.appendChild(extLink(provider.getApiKeyUrl, t("linkGetKey")));
  }
  if (links.childNodes.length) {
    body.appendChild(links);
  }
  card.appendChild(body);

  const actions = document.createElement("div");
  actions.className = "provider-actions";

  const toggle = document.createElement("input");
  toggle.type = "checkbox";
  toggle.checked = !!provider.enabled;
  toggle.title = t("toggleTitle");
  toggle.addEventListener("change", function () {
    provider.enabled = toggle.checked;
    card.classList.toggle("is-off", !provider.enabled);
    persist();
  });
  actions.appendChild(toggle);

  // Only the superuser may change the catalogue.
  if (state.canEdit) {
    actions.appendChild(
      miniButton(t("edit"), function () {
        openEditor(provider.id);
      }),
    );
    actions.appendChild(
      miniButton(t("remove"), function () {
        if (!confirm(t("confirmDelete", { name: provider.name }))) {
          return;
        }
        state.config.providers = state.config.providers.filter(function (p) {
          return p.id !== provider.id;
        });
        renderProviders();
        persist();
      }),
    );
  }

  card.appendChild(actions);
  return card;
}

function addRow(dl, label, value) {
  if (!value) {
    return;
  }
  const dt = document.createElement("dt");
  dt.textContent = label;
  const dd = document.createElement("dd");
  dd.textContent = value;
  dl.appendChild(dt);
  dl.appendChild(dd);
}

/// Counters of the provider's configured model, if any.
function statsOf(provider) {
  const providerStats = state.stats[provider.id];
  if (!providerStats || !providerStats.models) return null;
  return providerStats.models[provider.model] || null;
}

function extLink(href, label) {
  const a = document.createElement("a");
  a.href = href;
  a.target = "_blank";
  a.rel = "noopener noreferrer";
  a.textContent = label;
  return a;
}

function miniButton(label, onClick) {
  const b = document.createElement("button");
  b.type = "button";
  b.className = "btn btn-ghost btn-mini";
  b.textContent = label;
  b.addEventListener("click", onClick);
  return b;
}

function logoNode(provider) {
  const wrap = document.createElement("div");
  wrap.className = "logo";

  const fallback = function () {
    wrap.textContent = "";
    const letter = document.createElement("span");
    letter.className = "letter";
    letter.textContent = (provider.name || "?").trim().charAt(0).toUpperCase();
    wrap.appendChild(letter);
  };

  const src = provider.logoUrl
    ? provider.logoUrl
    : provider.logoAsset
      ? "logos/" + provider.logoAsset + ".svg"
      : "";

  if (!src) {
    fallback();
    return wrap;
  }

  const img = document.createElement("img");
  img.alt = "";
  img.src = src;
  img.addEventListener("error", fallback);
  wrap.appendChild(img);
  return wrap;
}

/* --------------------------------------------------------------- editor */

function openEditor(id) {
  const provider = id
    ? state.config.providers.find(function (p) {
        return p.id === id;
      })
    : null;

  state.editingId = provider ? provider.id : null;
  el.editorTitle.textContent = provider ? t("editorTitle") : t("editorTitleNew");

  const form = el.editorForm;
  form.reset();
  form.name.value = provider ? provider.name : "";
  form.enabled.checked = provider ? !!provider.enabled : true;
  form.url.value = provider ? provider.url : "";
  form.model.value = provider ? provider.model : "";
  form.fallbackPriority.value = provider
    ? provider.fallbackPriority
    : nextPriority();
  form.loginUrl.value = provider ? provider.loginUrl : "";
  form.getApiKeyUrl.value = provider ? provider.getApiKeyUrl : "";
  form.logoUrl.value = provider ? provider.logoUrl : "";
  form.logoAsset.value = provider ? provider.logoAsset : "";
  form.status.value = provider ? provider.status : "active";
  form.origin.value = provider && provider.origin === "user" ? "user" : "admin";

  el.editor.showModal();
}

function nextPriority() {
  return state.config.providers.reduce(function (max, p) {
    return Math.max(max, p.fallbackPriority || 0);
  }, 0) + 1;
}

function submitEditor(event) {
  event.preventDefault();
  const form = el.editorForm;

  const editing = state.editingId
    ? state.config.providers.find(function (p) {
        return p.id === state.editingId;
      })
    : null;

  // "user" keeps the entry to its author (a proposal); "admin" publishes it to
  // everybody. Publishing clears the author mark.
  const origin = form.origin.value === "user" ? "user" : "admin";

  const data = {
    id: state.editingId || "p" + Date.now().toString(36),
    name: form.name.value.trim(),
    enabled: form.enabled.checked,
    url: form.url.value.trim(),
    model: form.model.value.trim(),
    fallbackPriority: Math.max(0, parseInt(form.fallbackPriority.value, 10) || 0),
    loginUrl: form.loginUrl.value.trim(),
    getApiKeyUrl: form.getApiKeyUrl.value.trim(),
    logoUrl: form.logoUrl.value.trim(),
    logoAsset: form.logoAsset.value,
    status: form.status.value === "dead" ? "dead" : "active",
    origin: origin,
    authorName: origin === "user" ? (editing ? editing.authorName || "" : "") : "",
    isPredefined: false,
  };

  if (state.editingId) {
    const index = state.config.providers.findIndex(function (p) {
      return p.id === state.editingId;
    });
    data.isPredefined = index >= 0 ? !!state.config.providers[index].isPredefined : false;
    if (index >= 0) {
      state.config.providers[index] = data;
    } else {
      state.config.providers.push(data);
    }
  } else {
    state.config.providers.push(data);
  }

  state.config.providers.sort(function (a, b) {
    return a.fallbackPriority - b.fallbackPriority;
  });

  el.editor.close();
  renderProviders();
  persist();
}

/* ----------------------------------------------------------------- bin */

function showTrashError(message) {
  const node = document.getElementById("trash-error");
  node.hidden = !message;
  node.textContent = message || "";
}

async function openTrash() {
  el.trash.showModal();
  await refreshTrash();
}

async function refreshTrash() {
  el.trashList.textContent = "";
  el.trashEmpty.hidden = true;
  showTrashError("");

  try {
    const data = await api("/api/ai-trash");
    state.trash = data && Array.isArray(data.items) ? data.items : [];
  } catch (err) {
    state.trash = [];
    showTrashError(t("trashOpenFailed", { message: err.message }));
  }

  renderTrash();
}

function renderTrash() {
  el.trashList.textContent = "";
  el.trashEmpty.hidden = state.trash.length > 0;

  state.trash.forEach(function (item) {
    const provider = item.provider || {};

    const row = document.createElement("div");
    row.className = "trash-row";

    const left = document.createElement("div");

    const title = document.createElement("h3");
    title.textContent = provider.name || provider.id;
    const badge = document.createElement("span");
    badge.className =
      "badge" + (item.source === "proposal" ? " badge-user" : "");
    badge.textContent =
      item.source === "proposal" ? t("badgeProposal") : t("badgeCatalogue");
    title.appendChild(badge);
    left.appendChild(title);

    const what = document.createElement("div");
    what.className = "trash-meta";
    what.textContent = (provider.model || "") + " · " + (provider.url || "");
    left.appendChild(what);

    const when = document.createElement("div");
    when.className = "trash-meta";
    when.textContent = item.deletedByName
      ? t("trashDeletedBy", {
          when: shortTime(item.deletedAt),
          name: item.deletedByName,
        })
      : t("trashDeleted", { when: shortTime(item.deletedAt) });
    left.appendChild(when);

    row.appendChild(left);

    const actions = document.createElement("div");
    actions.className = "provider-actions";
    actions.appendChild(
      miniButton(t("restore"), function () {
        restoreFromTrash(provider.id, provider.name || provider.id);
      }),
    );
    actions.appendChild(
      miniButton(t("purgeOne"), function () {
        purgeOne(provider.id, provider.name || provider.id);
      }),
    );
    row.appendChild(actions);

    el.trashList.appendChild(row);
  });
}

async function restoreFromTrash(id, name) {
  if (!confirm(t("confirmRestore", { name: name }))) return;

  showTrashError("");
  try {
    const res = await api("/api/ai-trash/restore", {
      method: "POST",
      body: { id: id },
    });
    if (res && res.restored) {
      await loadConfig();
      render();
    } else {
      showTrashError((res && res.reason) || t("restoreFailed"));
    }
  } catch (err) {
    showTrashError(t("restoreFailedMsg", { message: err.message }));
  }

  await refreshTrash();
}

async function purgeOne(id, name) {
  if (!confirm(t("confirmPurgeOne", { name: name }))) {
    return;
  }

  showTrashError("");
  try {
    await api("/api/ai-trash/" + encodeURIComponent(id), { method: "DELETE" });
  } catch (err) {
    showTrashError(t("purgeFailedMsg", { message: err.message }));
  }

  await refreshTrash();
}

async function purgeAllTrash() {
  if (!confirm(t("confirmPurgeAll"))) {
    return;
  }

  showTrashError("");
  try {
    await api("/api/ai-trash", { method: "DELETE" });
  } catch (err) {
    showTrashError(t("purgeAllFailedMsg", { message: err.message }));
  }

  await refreshTrash();
}

/* --------------------------------------------------------------- wiring */

let pending = false;

async function persist() {
  if (pending) {
    return;
  }
  pending = true;
  el.syncStatus.textContent = t("saving");
  try {
    await saveConfig();
    setError("");
  } catch (err) {
    setError(t("saveFailedMsg", { message: err.message }));
    el.syncStatus.textContent = t("notSaved");
  } finally {
    pending = false;
  }
}

async function refresh() {
  try {
    await loadConfig();
    setError("");
    // render() also refreshes the toolbar: canEdit arrives with the config.
    render();
    await refreshStats();
    startPolling();
  } catch (err) {
    if (err.status === 401) {
      doLogout();
      setAuthNote(err.message);
      return;
    }
    setError(t("loadFailedMsg", { message: err.message }));
  }
}

document.querySelectorAll(".tab").forEach(function (tab) {
  tab.addEventListener("click", function () {
    document.querySelectorAll(".tab").forEach(function (t) {
      t.classList.toggle("is-active", t === tab);
    });
    const login = tab.dataset.tab === "login";
    el.loginForm.hidden = !login;
    el.registerForm.hidden = login;
    setAuthNote("");
  });
});

el.loginForm.addEventListener("submit", async function (event) {
  event.preventDefault();
  const form = event.target;
  setAuthNote("");
  try {
    await doLogin(
      form.identity.value.trim(),
      form.password.value,
      el.adminLogin.checked,
    );
    form.reset();
    render();
    refresh();
  } catch (err) {
    setAuthNote(err.message);
  }
});

el.registerForm.addEventListener("submit", async function (event) {
  event.preventDefault();
  const form = event.target;
  setAuthNote("");
  try {
    await doRegister(
      form.email.value.trim(),
      form.name.value.trim(),
      form.password.value,
      form.passwordConfirm.value,
    );
    form.reset();
    render();
    refresh();
  } catch (err) {
    setAuthNote(err.message);
  }
});

el.logoutBtn.addEventListener("click", doLogout);
el.addBtn.addEventListener("click", function () {
  openEditor(null);
});
el.reloadBtn.addEventListener("click", refresh);
el.editorForm.addEventListener("submit", submitEditor);
el.editorCancel.addEventListener("click", function () {
  el.editor.close();
});
el.trashBtn.addEventListener("click", openTrash);
el.trashClose.addEventListener("click", function () {
  el.trash.close();
});
el.trashPurgeAll.addEventListener("click", purgeAllTrash);

/* Switching language re-renders everything, including the provider cards,
 * the toolbar notes and the open dialogs' labels. */
UI.onChange(function () {
  applyI18n();
  document.title = t("pageTitle");
  render();
});

UI.mount();
applyI18n();
document.title = t("pageTitle");
el.host.textContent = location.host;
showAuth();
