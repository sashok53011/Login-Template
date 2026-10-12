/* AI Providers list — https://app.devhorizon.online/ai-providers/
 *
 * Served by PocketBase itself, so everything is same-origin: the page talks to
 * /api/collections/users/* for auth and to /api/ai-config for the shared
 * per-user provider list. No build step, no dependencies.
 *
 * API keys are intentionally absent: they live only on the phone
 * (flutter_secure_storage) and never reach this page or the server file.
 */

const TOKEN_KEY = "ai_token";
const USER_KEY = "ai_user";

const state = {
  token: localStorage.getItem(TOKEN_KEY) || null,
  user: safeParse(localStorage.getItem(USER_KEY)),
  config: null,
  stats: {},
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
    return "Нужно войти заново: сессия истекла.";
  }

  const raw = data && typeof data === "object" ? String(data.message || "") : "";
  const lower = raw.toLowerCase();

  if (lower.includes("failed to authenticate")) {
    return "Неверный email или пароль.";
  }
  if (lower.includes("already exists") || lower.includes("must be unique")) {
    return "Такой email уже занят. Если это ваш аккаунт — войдите.";
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
  return raw || "Запрос не удался (HTTP " + status + ").";
}

function localizeField(message) {
  const m = message.toLowerCase();
  if (m.includes("already exists") || m.includes("must be unique")) {
    return "занято";
  }
  if (m.includes("valid email")) {
    return "некорректный email";
  }
  if (m.includes("required")) {
    return "обязательное поле";
  }
  if (m.includes("at least 8")) {
    return "минимум 8 символов";
  }
  if (m.includes("do not match")) {
    return "пароли не совпадают";
  }
  if (m.includes("valid url")) {
    return "некорректная ссылка";
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
  title.textContent = "Статистика проверок";
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
    ? "Сохранено: " + updated.replace("T", " ").replace("Z", " UTC")
    : "Изменений ещё не было";
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
      (state.user.isAdmin ? " (админ)" : "");
  }

  if (loggedIn) {
    // Adding, editing and deleting is reserved for the superuser.
    el.addBtn.hidden = !state.canEdit;
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
    ? "Вы вошли как <strong>администратор</strong>: здесь задаётся каталог " +
      "провайдеров для всех пользователей. Помеченные «не работает» " +
      "убираются из списков пользователей. <strong>API-ключи</strong> здесь " +
      "не хранятся — их вводят в приложении. Статистика проверок " +
      "обновляется автоматически."
    : "Каталог провайдеров ведёт администратор. Здесь можно " +
      "<strong>включить</strong> нужных провайдеров — они появятся в " +
      "Android-приложении. <strong>API-ключи</strong> на сервере не " +
      "хранятся: их вводят только в приложении, они остаются на устройстве. " +
      "Статистика проверок обновляется автоматически.";

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
  if (provider.status === "dead") {
    const badge = document.createElement("span");
    badge.className = "badge";
    badge.textContent = "не работает";
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

  addRow(dl, "Приоритет", String(provider.fallbackPriority));
  body.appendChild(dl);

  const block = statsBlock(provider);
  if (block) {
    body.appendChild(block);
  }

  const links = document.createElement("div");
  links.className = "links";
  if (provider.loginUrl) {
    links.appendChild(extLink(provider.loginUrl, "Страница логина"));
  }
  if (provider.getApiKeyUrl) {
    links.appendChild(extLink(provider.getApiKeyUrl, "Получить API-ключ"));
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
  toggle.title = "Включён";
  toggle.addEventListener("change", function () {
    provider.enabled = toggle.checked;
    card.classList.toggle("is-off", !provider.enabled);
    persist();
  });
  actions.appendChild(toggle);

  // Only the superuser may change the catalogue.
  if (state.canEdit) {
    actions.appendChild(
      miniButton("Редактировать", function () {
        openEditor(provider.id);
      }),
    );
    actions.appendChild(
      miniButton("Удалить", function () {
        if (!confirm("Удалить провайдера «" + provider.name + "»?")) {
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
  el.editorTitle.textContent = provider ? "Провайдер" : "Новый провайдер";

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

/* --------------------------------------------------------------- wiring */

let pending = false;

async function persist() {
  if (pending) {
    return;
  }
  pending = true;
  el.syncStatus.textContent = "Сохранение…";
  try {
    await saveConfig();
    setError("");
  } catch (err) {
    setError("Не удалось сохранить: " + err.message);
    el.syncStatus.textContent = "Не сохранено";
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
    setError("Не удалось загрузить список: " + err.message);
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

el.host.textContent = location.host;
showAuth();
