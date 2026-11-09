import {
  MusicPicker,
  musicCollection,
  musicPickerMarkup,
  avatarArtwork,
} from "./music.js";
import type {
  MusicTrack,
  AppState,
  PublicUser,
  Participant,
  LiveSnapshot,
  ApiRoutes,
  Memory,
} from "./types.js";
function $<T extends Element = HTMLElement>(
  selector: string,
  parent: ParentNode = document,
): T {
  const element = parent.querySelector<T>(selector);
  if (!element) throw new Error(`Missing element: ${selector}`);
  return element;
}
const $$ = <T extends Element = HTMLElement>(
  selector: string,
  parent: ParentNode = document,
): T[] => [...parent.querySelectorAll<T>(selector)];
const icon = (name: string) =>
  `<svg aria-hidden="true"><use href="#i-${name}"/></svg>`;
const escape = (value: unknown) =>
  String(value ?? "").replace(
    /[&<>"']/g,
    (char) =>
      (
        ({
          "&": "&amp;",
          "<": "&lt;",
          ">": "&gt;",
          '"': "&quot;",
          "'": "&#39;",
        }) as Record<string, string>
      )[char],
  );
const colors = ["pink", "blue", "purple", "orange"];
const colorOf = (value: unknown): string =>
  colors.includes(String(value)) ? String(value) : "pink";
const avatar = (
  user: Pick<PublicUser, "name" | "color" | "music">,
  size = "",
) =>
  `<span class="avatar ${colorOf(user.color)} ${size}">${avatarArtwork(user.music)}<span class="avatar-fallback">${escape(user.name?.slice(0, 1) || "♪")}</span></span>`;
const state: AppState = {
  user: null,
  events: [],
  eventId: "feswave-2026",
  page: "live",
  participants: [],
  memories: [],
  filter: "all",
  connected: false,
  taps: 0,
  level: 0,
  windowEnds: 0,
  loading: true,
  demo: true,
};
let stream: EventSource | undefined;
let musicPicker: MusicPicker | undefined;
let pendingJoin = false;
let demoWindow = Math.floor(Date.now() / 5000);
let toastTimer: ReturnType<typeof setTimeout> | undefined;
const demoPeople: Participant[] = [
  {
    id: "demo-1",
    name: "haru",
    artist: "YOASOBI",
    song: "群青",
    color: "pink",
    level: 3,
  },
  {
    id: "demo-2",
    name: "minami",
    artist: "Mrs. GREEN APPLE",
    song: "青と夏",
    color: "orange",
    level: 2,
  },
  {
    id: "demo-3",
    name: "ren",
    artist: "Vaundy",
    song: "怪獣の花唄",
    color: "blue",
    level: 1,
  },
  {
    id: "demo-4",
    name: "yui",
    artist: "あいみょん",
    song: "マリーゴールド",
    color: "purple",
    level: 3,
  },
  {
    id: "demo-5",
    name: "kaito",
    artist: "King Gnu",
    song: "白日",
    color: "blue",
    level: 2,
  },
  {
    id: "demo-6",
    name: "sora",
    artist: "サカナクション",
    song: "新宝島",
    color: "pink",
    level: 1,
  },
];
async function api<K extends keyof ApiRoutes>(
  path: K,
  options?: RequestInit,
): Promise<ApiRoutes[K]>;
async function api(
  path: `music/search?${string}`,
  options?: RequestInit,
): Promise<{ results: MusicTrack[] }>;
async function api(
  path: `memories/${string}`,
  options?: RequestInit,
): Promise<Memory>;
async function api(path: string, options: RequestInit = {}): Promise<unknown> {
  const response = await fetch(`/api/${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...options.headers },
  });
  const result = await response.json();
  if (!response.ok) throw new Error(result.error || "接続できませんでした");
  return result;
}
function toast(text: string) {
  clearTimeout(toastTimer);
  $("#toast").textContent = text;
  $("#toast").classList.add("show");
  toastTimer = setTimeout(() => $("#toast").classList.remove("show"), 4200);
}
function openModal(html: string) {
  $<HTMLDialogElement>("#modal").classList.remove("profile-editor-dialog");
  musicPicker?.destroy();
  musicPicker = undefined;
  $("#modal-content").innerHTML = html;
  if (!$<HTMLDialogElement>("#modal").open)
    $<HTMLDialogElement>("#modal").showModal();
}
function closeModal() {
  musicPicker?.destroy();
  musicPicker = undefined;
  $<HTMLDialogElement>("#modal").close();
}
const closeButton = `<button class="modal-close" data-action="close" aria-label="閉じる">${icon("close")}</button>`;
function currentEvent() {
  return state.events.find((e) => e.id === state.eventId);
}

function navigate(page: string) {
  if (!["live", "memory", "profile"].includes(page)) return;
  state.page = page as AppState["page"];
  $$(".page").forEach((el) =>
    el.classList.toggle("active", el.id === `page-${page}`),
  );
  $$("[data-page]").forEach((el) =>
    el.classList.toggle("active", el.dataset.page === page),
  );
  $("#breadcrumb").textContent = {
    live: "Live",
    memory: "Memory",
    profile: "Profile",
  }[page as AppState["page"]];
  if (page === "memory") refreshMemories();
  if (page === "profile") renderProfile();
  window.scrollTo({ top: 0, behavior: "instant" });
}
function renderIdentity() {
  $("#side-name").textContent = state.user?.name || "Guest";
  $("#side-status").textContent = state.user?.name
    ? "YOUR MUSIC, YOUR WAVE"
    : "音楽でつながろう";
  $("#side-avatar").className = `avatar small ${colorOf(state.user?.color)}`;
  $("#side-avatar").innerHTML =
    `${avatarArtwork(state.user?.music)}<span class="avatar-fallback">${escape(state.user?.name?.slice(0, 1) || "♪")}</span>`;
  $("#orb .orb-inner").innerHTML =
    `${avatarArtwork(state.user?.music)}${icon("music")}`;
  $("#join-label").textContent = state.demo
    ? "ライブに参加する"
    : "参加中 · イベントを見る";
  $("#event-kicker").textContent = state.demo
    ? "TODAY'S PICK"
    : "YOU ARE IN THIS WAVE";
}
function renderEvent() {
  const event = currentEvent();
  if (!event) return;
  $("#event-name").textContent = event.name;
  if (event.id === "feswave-2026")
    $("#event-name").insertAdjacentHTML("beforeend", "<span>2026</span>");
  $("#event-subtitle").textContent = event.subtitle;
  $("#event-venue").textContent = event.venue;
  $("#event-date").textContent = event.date;
  renderIdentity();
}
function setConnection(status: string) {
  state.connected = status === "online";
  const node = $("#connection");
  node.classList.toggle("online", state.connected);
  node.innerHTML = `<i></i> ${status === "demo" ? "DEMO MODE" : status === "online" ? "CONNECTED" : "RECONNECTING"}`;
}
function connect() {
  if (stream) stream.close();
  setConnection("connecting");
  stream = new EventSource("/api/stream");
  stream.onmessage = (event) => {
    const data: LiveSnapshot = JSON.parse(event.data);
    setConnection("online");
    if (data.eventId !== state.eventId) {
      state.eventId = data.eventId;
      if (state.user) state.user.eventId = data.eventId;
      renderEvent();
    }
    state.participants = data.participants;
    const me = data.participants.find((p) => p.id === state.user?.id);
    state.taps = me?.taps || 0;
    state.level = me?.level || 0;
    state.windowEnds = (Math.floor(data.serverTime / 5000) + 1) * 5000;
    renderBubbles();
    renderMeter();
  };
  stream.onerror = () => setConnection("connecting");
}
const positions = [
  [30, 22],
  [70, 25],
  [23, 49],
  [78, 51],
  [35, 73],
  [65, 73],
  [11, 29],
  [88, 28],
  [12, 70],
  [88, 74],
];
function renderBubbles() {
  const users = state.demo
    ? demoPeople
    : state.participants.filter((p) => p.id !== state.user?.id);
  $("#participant-count").textContent = state.demo
    ? "6"
    : String(state.participants.length);
  $("#participant-unit").textContent = state.demo ? "DEMO" : "ONLINE";
  $("#bubbles").innerHTML = users
    .slice(0, 10)
    .map(
      (u, i) =>
        `<button class="bubble level-${u.level} ${u.level ? "" : "no-reaction"} view-profile" data-person="${escape(u.id)}" style="left:${positions[i][0]}%;top:${positions[i][1]}%" aria-label="${escape(u.name)}の公開プロフィール">${avatar(u)}<small>${escape(u.name)}${state.demo ? " · demo" : ""}</small></button>`,
    )
    .join("");
  if (users.length > 10)
    $("#bubbles").insertAdjacentHTML(
      "beforeend",
      `<span class="more-people">+ ${users.length - 10} 人が参加中</span>`,
    );
  const shared = users.filter(
    (u) => u.level && state.level && Math.abs(u.level - state.level) <= 1,
  ).length;
  $("#stage-note").innerHTML =
    `<span></span> ${state.demo ? (state.taps ? "デモ体験中 · 履歴には保存されません" : "同じ音楽で、つながっている。") : !users.length ? "参加者を待っています。別のブラウザから参加できます。" : shared ? `${shared}人と同じ盛り上がり！ 集計終了を待とう` : "気持ちが動いた瞬間に、タップしよう。"}`;
}
function renderMeter() {
  $("#your-level").textContent = `LEVEL ${state.level}`;
  $("#your-level").dataset.level = String(state.level);
  $("#orb").dataset.level = String(state.level);
  const messages = [
    "",
    "いい感じ！",
    "気持ちが重なる",
    "盛り上がってきた！",
    "最高の瞬間！",
    "最高潮！",
  ];
  $("#tap-count").textContent = state.taps
    ? `${state.taps} taps · ${messages[state.level] ?? ""}`
    : "タップして、盛り上がりをシェア";
  $$(".level-bars i").forEach((el, i) =>
    el.classList.toggle("lit", i < state.level),
  );
}
let lastTap = 0;
async function react() {
  if (Date.now() - lastTap < 85) return;
  lastTap = Date.now();
  const orb = $("#orb");
  orb.classList.remove("pulse");
  void orb.offsetWidth;
  orb.classList.add("pulse");
  if (state.demo) {
    state.taps++;
    state.level = Math.min(5, Math.ceil(state.taps / 5));
    state.windowEnds = (Math.floor(Date.now() / 5000) + 1) * 5000;
    renderMeter();
    renderBubbles();
    if (state.taps === 1)
      toast("デモリアクション！「ライブに参加する」から共有を始めよう");
    return;
  }
  if (!state.connected) {
    toast("再接続中です。接続後にもう一度タップしてください");
    return;
  }
  try {
    const result = await api("react", { method: "POST", body: "{}" });
    Object.assign(state, result);
    renderMeter();
  } catch (e) {
    toast(e instanceof Error ? e.message : "接続に問題が発生しました");
  }
}
function profileForm(joinAfter = false) {
  pendingJoin = joinAfter;
  const user = state.user || { name: '', artist: '', song: '', color: 'pink', visible: false };
  const editing = !!user.name;
  openModal(`<form id="profile-form" class="editor-form">
    <header class="editor-header"><button type="button" data-action="close" class="editor-cancel">キャンセル</button><h2>${editing ? 'プロフィール編集' : 'プロフィールを作成'}</h2><span class="editor-header-spacer" aria-hidden="true"></span></header>
    <div class="editor-body">
      <section class="editor-basics" aria-label="名前とアイコン"><div class="editor-preview"><span id="editor-avatar" class="avatar editor-avatar pink"></span><div><strong id="editor-preview-name">${escape(user.name || 'あなたの名前')}</strong><p id="editor-icon-caption">好きな曲のジャケットをアイコンに</p></div></div><label class="form-field"><span>ニックネーム <small>必須・20文字まで</small></span><input name="name" autocomplete="nickname" placeholder="ライブで呼ばれたい名前" required maxlength="20" value="${escape(user.name)}"></label></section>
      <section class="editor-section" aria-label="好きな曲の編集"><div class="editor-section-heading"><h3>好きな曲とアイコン</h3><span>任意</span></div>${musicPickerMarkup()}<details id="manual-music" class="manual-music" ${editing && !state.user?.tracks?.length && !state.user?.music && (user.artist || user.song) ? 'open' : ''}><summary>検索せずに曲名を入力する</summary><p id="music-manual-note" class="music-manual-note"></p><label class="form-field"><span>アーティスト名</span><input name="artist" placeholder="例：YOASOBI" maxlength="60" value="${escape(editing ? user.artist : '')}"></label><label class="form-field"><span>曲名</span><input name="song" placeholder="例：群青" maxlength="60" value="${escape(editing ? user.song : '')}"></label></details></section>
      <section class="editor-options" aria-label="公開設定"><label class="editor-sharing"><span class="sharing-copy"><strong>好きな曲とアイコンを公開</strong><small>オンにするとライブの参加者に表示され、共感した記録を残せます。</small></span><input class="sharing-input" type="checkbox" role="switch" name="visible" ${user.visible ? 'checked' : ''}><span class="sharing-toggle" aria-hidden="true"></span></label><input type="hidden" name="color" value="${colorOf(user.color)}"></section>
    </div>
    <footer class="editor-actions"><div class="form-error" id="form-error" role="alert"></div><p>保存するまで変更は反映されません</p><button class="primary-btn full-width" type="submit">${editing ? '変更を保存する' : joinAfter ? '登録して次へ' : 'プロフィールを登録'} ${icon('check')}</button></footer>
  </form>`);
  $<HTMLDialogElement>('#modal').classList.add('profile-editor-dialog');
  musicPicker = new MusicPicker($<HTMLFormElement>('#profile-form'), state.user?.tracks?.length ? state.user.tracks : state.user?.music ? [state.user.music] : [], state.user?.favoriteTrackId ?? state.user?.music?.trackId ?? null, async (term, signal) => {
    const result = await api(`music/search?term=${encodeURIComponent(term)}`, { signal }); return result.results;
  });
}
async function saveProfile(form: HTMLFormElement) {
  const button = $<HTMLButtonElement>('button[type="submit"]', form); button.disabled = true;
  const buttonContent = button.innerHTML;
  button.textContent = '保存しています…';
  button.setAttribute('aria-busy', 'true');
  const fields = new FormData(form);
  try {
    state.user = await api('profile', { method: 'PUT', body: JSON.stringify({ name: fields.get('name'), artist: fields.get('artist'), song: fields.get('song'), color: colorOf(state.user?.color), visible: fields.get('visible') === 'on', trackIds: musicPicker?.tracks.map(track => track.trackId) ?? [], favoriteTrackId: musicPicker?.favoriteTrackId ?? null }) });
    renderIdentity(); renderProfile();
    if (pendingJoin) showReady(); else { closeModal(); toast('プロフィールを保存しました'); }
  } catch (e) { $('#form-error').textContent = e instanceof Error ? e.message : '保存できませんでした'; button.disabled = false; button.innerHTML = buttonContent; button.removeAttribute('aria-busy'); }
}
function showReady() {
  openModal(
    `<div class="modal-inner success-modal">${closeButton}<div class="stepper"><span>01 PROFILE</span><i></i><span class="active">02 READY</span><i></i><span>03 LIVE</span></div><div class="success-orb">${icon("check")}</div><div class="eyebrow">YOU'RE READY TO CONNECT.</div><h2>あなたのWAVEを、<br>会場へ届けよう。</h2><p class="modal-description">プロフィールの登録が完了しました。<br>同じ音楽に、心が動く瞬間を。</p><div class="profile-summary">${state.user ? avatar(state.user) : ""}<div><strong>${escape(state.user?.name)}</strong><small>${escape(state.user?.artist)} / ${escape(state.user?.song)}</small></div></div><button class="primary-btn full-width" data-action="enter-live">ライブへ進む ${icon("arrow")}</button></div>`,
  );
}
async function joinEvent() {
  if (!state.user?.name) return profileForm(true);
  const buttons = $$<HTMLButtonElement>(
    '[data-action="enter-live"], [data-action="join"]',
  );
  buttons.forEach((b) => (b.disabled = true));
  try {
    await api("join", {
      method: "POST",
      body: JSON.stringify({ eventId: state.eventId }),
    });
    if (state.user) state.user.eventId = state.eventId;
    state.demo = false;
    state.taps = 0;
    state.level = 0;
    state.participants = [];
    closeModal();
    renderEvent();
    renderBubbles();
    renderMeter();
    connect();
    navigate("live");
    toast("接続しました。同じ瞬間を楽しもう！");
  } catch (e) {
    toast(e instanceof Error ? e.message : "接続に問題が発生しました");
    buttons.forEach((b) => (b.disabled = false));
  }
}
async function refreshMemories() {
  if (state.user) {
    try {
      state.memories = await api("memories");
    } catch (e) {
      if (state.page === "memory")
        toast(e instanceof Error ? e.message : "接続に問題が発生しました");
    }
  }
  $("#nav-memory-count").textContent = String(state.memories.length);
  renderMemories();
}
function renderMemories() {
  $("#memory-total").innerHTML =
    `${state.memories.length}<span>MEMORIES</span>`;
  const list = state.memories.filter(
    (m) => state.filter !== "favorite" || m.favorite,
  );
  if (!list.length) {
    $("#memory-list").innerHTML =
      `<div class="empty-state">${icon("heart")}<h3>${state.filter === "favorite" ? "大切なメモリを、お気に入りに。" : "最初の「同じ！」を見つけよう。"}</h3><p>${state.filter === "favorite" ? "メモリのハートを押すと、ここに残せます。" : "同じイベントで、同じ5秒間にリアクション。<br>近い盛り上がりの参加者と、思い出が生まれます。<br>双方がプロフィールの公開を許可すると記録されます。"}</p><button class="primary-btn" data-page="live">ライブに戻る ${icon("arrow")}</button></div>`;
    return;
  }
  $("#memory-list").innerHTML = list
    .map((m) => {
      const event = state.events.find((e) => e.id === m.eventId);
      const at = new Date(m.at).toLocaleString("ja-JP", {
        month: "short",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      });
      return `<article class="memory-card">${avatar(m.person)}<div><h3>${escape(m.person.name)}</h3><p>${escape(m.person.artist)}${m.person.song ? ` / ${escape(m.person.song)}` : ""}</p><small>${escape(event?.name || m.eventId)} · ${escape(at)}</small></div><span class="memory-level">LEVEL ${m.level} ${icon("wave")}</span><button class="favorite-btn ${m.favorite ? "selected" : ""}" data-favorite="${escape(m.id)}" aria-label="${m.favorite ? "お気に入りを解除" : "お気に入りに追加"}" aria-pressed="${m.favorite}">${icon("heart")}</button></article>`;
    })
    .join("");
}
function renderProfile() {
  const user = state.user;
  if (!user?.name) {
    $("#profile-content").innerHTML =
      `<div class="empty-state guest-profile">${icon("user")}<h3>あなたの音楽を、教えてください。</h3><p>ニックネームと好きな曲を登録して、<br>同じライブを楽しむ誰かとつながろう。</p><button class="primary-btn" data-action="register">プロフィールを作成 ${icon("arrow")}</button></div>`;
    return;
  }
  const partners = new Set(state.memories.map((m) => m.person.id)).size;
  $("#profile-content").innerHTML =
    `<div class="profile-grid"><section class="panel profile-main"><span class="section-kicker">THIS IS YOUR WAVE.</span>${avatar(user, "large")}<h2>${escape(user.name)}</h2><p>音楽でつながる、もっと近くに。</p><button class="subtle-btn" data-action="edit-profile">${icon("settings")} プロフィールを編集</button><div class="profile-stats"><div><strong>${state.memories.length}</strong><small>共感メモリ</small></div><div><strong>${partners}</strong><small>つながった人</small></div></div></section><div class="profile-details"><section class="panel profile-detail"><div class="section-kicker">${icon("music")} FAVORITE ARTIST</div><h3>${escape(user.artist || "まだ登録されていません")}</h3><p>心が動く、あなたのアーティスト。</p></section><section class="panel profile-detail"><div class="section-kicker">${icon("heart")} FAVORITE TRACKS</div>${user.music ? musicCollection(user.tracks, user.music) : `<h3>${escape(user.song || "まだ登録されていません")}</h3><p>何度でも聴きたくなる、あの一曲。</p>`}</section><section class="panel profile-detail"><span class="section-kicker">PRIVACY & SHARING</span><div class="privacy-status">${icon(user.visible ? "check" : "user")} ${user.visible ? "プロフィール共有：オン" : "プロフィール共有：オフ"}</div><p>${user.visible ? "共感した相手に、好きな音楽とニックネームを共有します。" : "共感メモリには記録されません。参加中はニックネームと反応のみ表示されます。"}<br>連絡先・正確な位置情報は収集しません。</p></section></div></div>`;
}
function personProfile(id: string) {
  const person = (state.demo ? demoPeople : state.participants).find(
    (p) => p.id === id,
  );
  if (!person) return;
  // Only the server's public participant projection is available here.
  openModal(
    `<div class="modal-inner success-modal">${closeButton}<div class="eyebrow">${state.demo ? "DEMO PARTICIPANT" : "ON THE SAME WAVE"}</div><div class="profile-person">${avatar(person, "large")}</div><h2>${escape(person.name)}</h2><p class="modal-description">${state.demo ? "デモ参加者のサンプルプロフィールです。" : person.artist || person.song ? "同じライブを楽しんでいる参加者です。" : "この参加者はプロフィールを公開していません。"}</p>${person.artist ? `<div class="profile-summary">${icon("music")}<div><strong>${escape(person.artist)}</strong><small>${escape(person.song)}</small></div></div>` : ""}${musicCollection(person.tracks, person.music)}<button class="subtle-btn full-width" style="margin-top:20px;justify-content:center" data-action="close">ライブに戻る</button></div>`,
  );
}
function about() {
  openModal(
    `<div class="modal-inner">${closeButton}<svg class="modal-logo"><use href="#i-wave"/></svg><div class="eyebrow">FEEL THE SAME WAVE.</div><h2>音楽でつながる、<br>もっと近くに。</h2><div class="about-text"><p>FESWAVEは、ライブの感動を言葉を使わずに共有するアプリです。<strong>その瞬間の気持ちをタップ</strong>して届けましょう。</p><p>5秒間に1〜5タップでLevel 1、6〜10タップでLevel 2、11〜15タップでLevel 3、16〜20タップでLevel 4、21タップ以上でLevel 5。同じイベント・同じ時間帯でレベル差が1以内なら共感候補になります。</p><p>双方がプロフィールの共有を許可すると、5秒の集計後にメモリが保存されます。共有をオフにすると、相手の履歴からあなたの記録も削除されます。</p><p>デモ参加者はサンプル表示です。実際の参加者はイベント参加後に表示されます。</p><p>v0.2 ローカルMVP · Bluetooth、Spotify、位置推定、アカウント認証は未実装です。サーバー側に履歴を保存し、Cookieで端末を識別します。</p></div><button class="primary-btn full-width" data-action="close">LET'S FEEL THE WAVE ${icon("arrow")}</button></div>`,
  );
}
document.addEventListener("click", async (event) => {
  const target =
    event.target instanceof Element ? event.target.closest("button") : null;
  if (!target) return;
  if (target.dataset.page) return navigate(target.dataset.page);
  if (target.dataset.person) return personProfile(target.dataset.person);
  if (target.dataset.filter) {
    state.filter = target.dataset.filter === "favorite" ? "favorite" : "all";
    $$("[data-filter]").forEach((b) =>
      b.classList.toggle("active", b.dataset.filter === state.filter),
    );
    renderMemories();
    return;
  }
  if (target.dataset.favorite) {
    const memory = state.memories.find((m) => m.id === target.dataset.favorite);
    if (!memory) return;
    target.disabled = true;
    try {
      const updated = await api(`memories/${memory.id}`, {
        method: "PATCH",
        body: JSON.stringify({ favorite: !memory.favorite }),
      });
      Object.assign(memory, updated);
      renderMemories();
    } catch (e) {
      target.disabled = false;
      toast(e instanceof Error ? e.message : "接続に問題が発生しました");
    }
    return;
  }
  switch (target.dataset.action) {
    case "close":
      closeModal();
      break;
    case "join":
      if (state.loading) toast("接続を準備しています");
      else if (state.demo) joinEvent();
      break;
    case "enter-live":
      joinEvent();
      break;
    case "edit-profile":
    case "register":
      profileForm(false);
      break;
    case "about":
      about();
      break;
  }
});
$("#tap-button").addEventListener("click", react);
$("#orb").addEventListener("click", react);
document.addEventListener("submit", (event) => {
  if (
    event.target instanceof HTMLFormElement &&
    event.target.id === "profile-form"
  ) {
    event.preventDefault();
    saveProfile(event.target);
  }
});
document.addEventListener("keydown", (event) => {
  if (
    event.code === "Space" &&
    state.page === "live" &&
    !$<HTMLDialogElement>("#modal").open &&
    !["INPUT", "TEXTAREA", "SELECT", "BUTTON", "A"].includes(
      document.activeElement?.tagName || "",
    )
  ) {
    event.preventDefault();
    if (!event.repeat) react();
  }
});
$<HTMLDialogElement>("#modal").addEventListener("close", () => {
  // A queued close event from an earlier dialog must not dispose a newly opened editor.
  if (!$<HTMLDialogElement>("#modal").open) {
    musicPicker?.destroy();
    musicPicker = undefined;
  }
});
$<HTMLDialogElement>("#modal").addEventListener("click", (event) => {
  if (event.target === $<HTMLDialogElement>("#modal")) {
    const r = $<HTMLDialogElement>("#modal").getBoundingClientRect();
    if (
      event.clientX < r.left ||
      event.clientX > r.right ||
      event.clientY < r.top ||
      event.clientY > r.bottom
    )
      closeModal();
  }
});
$("#crowd").innerHTML = Array.from(
  { length: 42 },
  (_, i) =>
    `<i class="crowd-person" style="left:${i * 2.5}%;height:${22 + ((i * 17) % 26)}px;transform:scale(${0.65 + (i % 4) * 0.16}) rotate(${(i % 5) * 4 - 8}deg)"></i>`,
).join("");
$(".today").textContent = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "2-digit",
  year: "numeric",
  timeZone: "Asia/Tokyo",
})
  .format(new Date())
  .toUpperCase();
setInterval(() => {
  const now = Date.now();
  if (state.demo && Math.floor(now / 5000) !== demoWindow) {
    demoWindow = Math.floor(now / 5000);
    state.taps = 0;
    state.level = 0;
    renderMeter();
    renderBubbles();
  }
  $("#window-count").textContent =
    state.windowEnds > now
      ? `${Math.ceil((state.windowEnds - now) / 1000)} SEC`
      : "5 SEC";
}, 200);
setInterval(() => {
  if (!state.demo) {
    refreshMemories().then(() => {
      if (state.page === "profile") renderProfile();
    });
  }
}, 5000);
document.addEventListener("visibilitychange", () => {
  if (!document.hidden && !state.demo) refreshMemories();
});
renderMeter();
renderBubbles();
renderProfile();
renderMemories();
try {
  const data = await api("session");
  state.user = data.user;
  state.events = data.events;
  state.loading = false;
  if (state.user.eventId && state.user.name) {
    state.eventId = state.user.eventId;
    state.demo = false;
    connect();
  }
  renderEvent();
  renderBubbles();
  renderProfile();
  await refreshMemories();
} catch (e) {
  state.loading = false;
  toast("サーバーに接続できません。npm start で起動してください。");
}
