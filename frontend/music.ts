import type { MusicTrack } from './types.js';

const escape = (value: unknown): string => String(value ?? '').replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' } as Record<string,string>)[char]);
function safeUrl(value: string | null | undefined, artwork = false): string | null {
  try {
    const url = new URL(value || '');
    if (url.protocol !== 'https:' || url.username || url.password || url.port) return null;
    return (artwork ? url.hostname.endsWith('.mzstatic.com') : ['music.apple.com','itunes.apple.com'].includes(url.hostname)) ? url.href : null;
  } catch { return null; }
}
function cover(track: MusicTrack, size = ''): string {
  const src = safeUrl(track.artworkUrl, true);
  return `<span class="music-cover ${size}">${src ? `<img class="cover-image" src="${escape(src)}" alt="${escape(track.collectionName || track.trackName)}のジャケット" width="100" height="100" loading="lazy" referrerpolicy="no-referrer">` : ''}<span class="cover-placeholder" aria-hidden="true">♫</span></span>`;
}
function storeLink(track: MusicTrack): string {
  const href = safeUrl(track.trackUrl);
  if (!href) return '';
  const url = new URL(href); url.searchParams.set('app','itunes');
  return `<a class="itunes-link" href="${escape(url.href)}" target="_blank" rel="noopener noreferrer" aria-label="${escape(track.trackName)}をiTunes Storeで見る（新しいタブ）"><img src="/itunes-badge.svg" alt="iTunes Storeで入手" width="108" height="36"></a>`;
}
export function musicCard(track: MusicTrack | null | undefined): string {
  if (!track) return '';
  return `<div class="favorite-music">${cover(track)}<div class="music-meta"><h3>${escape(track.trackName)}</h3><p>${escape(track.artistName)}</p><p class="music-album">${escape(track.collectionName)}</p>${storeLink(track)}</div></div>`;
}
export function avatarArtwork(track: MusicTrack | null | undefined): string {
  const src = safeUrl(track?.artworkUrl, true);
  return src ? `<img class="avatar-art" src="${escape(src)}" alt="" width="100" height="100" referrerpolicy="no-referrer">` : '';
}
export function musicCollection(tracks: MusicTrack[] | undefined, primary: MusicTrack | null | undefined): string {
  const list = tracks?.length ? tracks : primary ? [primary] : [];
  return list.map(track => `<article class="profile-track">${track.trackId === primary?.trackId ? '<span class="primary-track-tag">★ 一番のお気に入り · アイコン</span>' : ''}${musicCard(track)}</article>`).join('');
}
export function musicPickerMarkup(): string {
  return `<section class="music-picker" aria-label="好きな曲とアイコン"><div id="music-selected"></div><button type="button" id="music-add-toggle" class="add-music-button">＋ 曲を追加する</button><section id="music-search-panel" class="music-search-panel" hidden><div class="music-search-heading"><strong>追加したい曲を検索</strong><button type="button" id="music-search-done">完了</button></div><label for="music-query" class="music-search-hint">曲名・アーティスト名・アルバム名</label><div class="music-search-row"><input type="search" id="music-query" name="musicQuery" placeholder="例：YOASOBI 群青" maxlength="100" autocomplete="off"><button type="button" id="music-search" class="subtle-btn">検索</button></div><p class="music-search-hint">検索結果の「追加」を押してください。複数選べます。</p><div id="music-results" class="music-results"></div><button type="button" class="search-finish-button" data-music-done hidden>曲の追加を終える</button></section><p id="music-status" class="music-status" role="status" aria-live="polite"></p></section>`;
}

export class MusicPicker {
  tracks: MusicTrack[];
  favoriteTrackId: number | null;
  get selected(): MusicTrack | null { return this.tracks.find(track => track.trackId === this.favoriteTrackId) || null; }
  private results: MusicTrack[] = [];
  private controller?: AbortController;
  private generation = 0;
  private destroyed = false;
  private listeners = new AbortController();
  constructor(private form: HTMLFormElement, initial: MusicTrack[], favoriteId: number | null, private search: (term: string, signal: AbortSignal) => Promise<MusicTrack[]>) {
    this.tracks = [...initial];
    this.favoriteTrackId = initial.some(track => track.trackId === favoriteId) ? favoriteId : initial[0]?.trackId ?? null;
    const signal = this.listeners.signal;
    form.querySelector('#music-add-toggle')!.addEventListener('click', () => this.setSearchOpen(true), { signal });
    form.querySelector('#music-search-done')!.addEventListener('click', () => this.setSearchOpen(false), { signal });
    form.querySelector('[data-music-done]')!.addEventListener('click', () => this.setSearchOpen(false), { signal });
    form.querySelector('#music-search')!.addEventListener('click', () => this.runSearch(), { signal });
    form.querySelector('#music-query')!.addEventListener('keydown', event => {
      if ((event as KeyboardEvent).key === 'Enter') { event.preventDefault(); this.runSearch(); }
    }, { signal });
    form.addEventListener('click', event => {
      const target = event.target instanceof Element ? event.target.closest<HTMLButtonElement>('[data-track-select], [data-track-remove], [data-track-favorite]') : null;
      if (!target) return;
      const status = this.form.querySelector('#music-status')!;
      if (target.dataset.trackRemove) {
        const id = Number(target.dataset.trackRemove);
        this.tracks = this.tracks.filter(track => track.trackId !== id);
        if (this.favoriteTrackId === id) this.favoriteTrackId = this.tracks[0]?.trackId ?? null;
        this.syncFields(true); this.renderSelected();
        status.textContent = this.tracks.length ? '曲を削除しました。変更は保存すると反映されます。' : '登録した曲をすべて削除しました。文字アイコンに戻ります。'; return;
      }
      if (target.dataset.trackFavorite) {
        const track = this.tracks.find(track => track.trackId === Number(target.dataset.trackFavorite));
        if (track) { this.favoriteTrackId = track.trackId; this.syncFields(); this.renderSelected(); status.textContent = `保存すると「${track.trackName}」のジャケットがアイコンになります。`; }
        return;
      }
      const track = this.results.find(t => t.trackId === Number(target.dataset.trackSelect));
      if (track) {
        if (this.tracks.some(item => item.trackId === track.trackId)) { status.textContent = 'この曲は追加済みです。'; return; }
        if (this.tracks.length >= 20) { status.textContent = '好きな曲は20曲まで登録できます。'; return; }
        this.tracks.push(track);
        if (this.favoriteTrackId === null) this.favoriteTrackId = track.trackId;
        this.syncFields();
        status.textContent = `「${track.trackName}」を追加しました。登録した曲：${this.tracks.length}曲`;
        this.renderSelected();
      }
    }, { signal });
    form.querySelector('[name="name"]')!.addEventListener('input', () => this.renderPreview(), { signal });
    form.querySelectorAll('[data-color]').forEach(button => button.addEventListener('click', () => {
      // The form's existing color handler updates its hidden field later in the click event.
      queueMicrotask(() => { if (!this.destroyed) this.renderPreview(); });
    }, { signal }));
    this.syncFields();
    this.renderSelected();
  }
  private setSearchOpen(open: boolean): void {
    this.form.querySelector<HTMLElement>('#music-search-panel')!.hidden = !open;
    this.form.querySelector<HTMLElement>('#music-selected')!.hidden = open;
    this.form.querySelector<HTMLElement>('#music-add-toggle')!.hidden = open;
    if (open) this.form.querySelector<HTMLInputElement>('#music-query')!.focus();
    else {
      this.controller?.abort(); this.generation++;
      this.form.querySelector<HTMLButtonElement>('#music-search')!.disabled = false;
      this.form.querySelector('#music-results')!.removeAttribute('aria-busy');
      this.form.querySelector('#music-status')!.textContent = this.tracks.length ? 'アイコンに使う曲を選び、最後に保存してください。' : '';
      this.form.querySelector<HTMLElement>('[data-track-favorite], #music-add-toggle')!.focus({preventScroll:true});
      this.form.querySelector('#music-selected')!.scrollIntoView({block:'start'});
    }
  }
  private renderPreview(): void {
    const preview = this.form.querySelector('#editor-avatar');
    if (!preview) return;
    const name = this.form.querySelector<HTMLInputElement>('[name="name"]')!.value.trim();
    const color = this.form.querySelector<HTMLInputElement>('[name="color"]')!.value;
    preview.className = `avatar editor-avatar ${['pink','blue','purple','orange'].includes(color) ? color : 'pink'}`;
    preview.innerHTML = `${avatarArtwork(this.selected)}<span class="avatar-fallback">${escape(name.slice(0,1) || '♪')}</span>`;
    this.form.querySelector('#editor-preview-name')!.textContent = name || 'あなたの名前';
    this.form.querySelector('#editor-icon-caption')!.textContent = this.selected ? '選んだ曲のジャケットがアイコンになります' : '曲を選ぶと、ジャケットをアイコンにできます';
  }
  private syncFields(clearEmpty = false): void {
    const track = this.selected;
    for (const field of ['artist','song'] as const) {
      const input = this.form.querySelector<HTMLInputElement>(`[name="${field}"]`)!;
      input.readOnly = !!track;
      input.setAttribute('aria-describedby','music-manual-note');
      if (track) input.value = (field === 'artist' ? track.artistName : track.trackName).slice(0,60);
      else if (clearEmpty) input.value = '';
    }
    const note = this.form.querySelector('#music-manual-note');
    if (note) note.textContent = '検索で見つからない場合は、曲名を直接入力できます。手入力では文字アイコンになります。';
    const manual = this.form.querySelector<HTMLElement>('#manual-music');
    if (manual) manual.hidden = !!track;
    this.renderPreview();
  }
  private renderSelected(): void {
    const primary = this.selected;
    this.form.querySelector('#music-selected')!.innerHTML = this.tracks.length ? `<div class="selected-track"><div class="primary-icon-preview"><span class="avatar pink">${avatarArtwork(primary)}<span class="avatar-fallback">♪</span></span><span><strong>アイコンに使う曲</strong><small class="primary-song-name">${escape(primary?.trackName)}</small><small>${escape(primary?.artistName)}</small></span></div><div class="registered-tracks-heading"><strong>登録した曲</strong><span>${this.tracks.length} / 20曲</span></div><p class="music-search-hint">一番のお気に入りを「アイコンにする」で選べます。</p><div class="selected-tracks-list">${this.tracks.map(track => `<article class="selected-track-row ${track.trackId === this.favoriteTrackId ? 'is-primary' : ''}"><div class="track-row-main"><button type="button" class="primary-track-button ${track.trackId === this.favoriteTrackId ? 'selected' : ''}" data-track-favorite="${track.trackId}" aria-pressed="${track.trackId === this.favoriteTrackId}" aria-label="${escape(track.trackName)}をアイコンにする">${cover(track,'compact')}<span class="track-row-copy"><strong>${escape(track.trackName)}</strong><small>${escape(track.artistName)}</small><span class="icon-choice-label">${track.trackId === this.favoriteTrackId ? '✓ アイコンに設定中' : 'アイコンにする'}</span></span></button><button type="button" class="remove-track-button" data-track-remove="${track.trackId}" aria-label="${escape(track.trackName)}を削除">×</button></div><div class="compact-track-link">${storeLink(track)}</div></article>`).join('')}</div></div>` : '<div class="music-empty-editor"><span aria-hidden="true">♫</span><strong>好きな曲を追加しましょう</strong><p>追加した曲の中から、アイコンに使う1曲を選べます。</p></div>';
    this.updateResultButtons();
  }
  private updateResultButtons(): void {
    this.form.querySelectorAll<HTMLButtonElement>('[data-track-select]').forEach(button => {
      const added = this.tracks.some(track => track.trackId === Number(button.dataset.trackSelect));
      button.disabled = added || this.tracks.length >= 20;
      const mark = button.querySelector('.music-select-mark');
      if (mark) mark.textContent = added ? '追加済み' : '＋ 追加';
    });
  }
  private async runSearch(): Promise<void> {
    const query = this.form.querySelector<HTMLInputElement>('#music-query')!;
    const status = this.form.querySelector<HTMLElement>('#music-status')!;
    const list = this.form.querySelector<HTMLElement>('#music-results')!;
    const button = this.form.querySelector<HTMLButtonElement>('#music-search')!;
    const term = query.value.trim();
    this.controller?.abort();
    const generation = ++this.generation;
    button.disabled = false; list.removeAttribute('aria-busy');
    if (!term) { status.textContent = '曲名・アーティスト名・アルバム名を入力してください。'; list.innerHTML = ''; return; }
    this.controller = new AbortController();
    button.disabled = true; list.innerHTML = ''; list.setAttribute('aria-busy','true'); status.textContent = 'iTunesで検索しています…';
    try {
      const results = await this.search(term, this.controller.signal);
      if (this.destroyed || generation !== this.generation) return;
      this.results = results;
      status.textContent = results.length ? `${results.length}件の曲が見つかりました。好きな曲を選んでください。` : '見つかりませんでした。別のキーワードを試すか、手入力してください。';
      list.innerHTML = results.map(track => `<article class="music-result"><button class="music-result-select" type="button" data-track-select="${track.trackId}" aria-label="${escape(track.trackName)} / ${escape(track.artistName)}を追加">${cover(track,'compact')}<span><strong>${escape(track.trackName)}</strong><small>${escape(track.artistName)}</small><small>${escape(track.collectionName)}</small></span><span class="music-select-mark" aria-hidden="true">＋ 追加</span></button><div class="result-store-link">${storeLink(track)}</div></article>`).join('');
      this.form.querySelector<HTMLButtonElement>('[data-music-done]')!.hidden = results.length === 0;
      this.updateResultButtons();
    } catch (error) {
      if (!this.destroyed && generation === this.generation && !(error instanceof DOMException && error.name === 'AbortError')) status.textContent = error instanceof Error ? error.message : '検索できませんでした。手入力でも登録できます。';
    } finally {
      if (!this.destroyed && generation === this.generation) { button.disabled = false; list.removeAttribute('aria-busy'); }
    }
  }
  destroy(): void { this.destroyed = true; this.generation++; this.controller?.abort(); this.listeners.abort(); }
}

document.addEventListener('error', event => {
  const image = event.target;
  if (image instanceof HTMLImageElement && (image.classList.contains('cover-image') || image.classList.contains('avatar-art'))) { image.remove(); }
}, true);
