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
  return `<section class="music-picker" aria-label="iTunesで好きな曲を検索"><label class="form-field" for="music-query"><span>好きな曲を追加 <small>任意 · 最大20曲</small></span></label><div class="music-search-row"><input type="search" id="music-query" name="musicQuery" placeholder="曲・アーティスト・アルバム名" maxlength="100" autocomplete="off"><button type="button" id="music-search" class="subtle-btn">検索</button></div><p class="music-search-hint">複数の曲を追加できます。★の曲のジャケットがあなたのアイコンになります。</p><p id="music-status" class="music-status" role="status" aria-live="polite"></p><div id="music-results" class="music-results"></div><div id="music-selected"></div></section>`;
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
        status.textContent = '曲を削除しました。下の登録ボタンで保存できます。'; return;
      }
      if (target.dataset.trackFavorite) {
        const track = this.tracks.find(track => track.trackId === Number(target.dataset.trackFavorite));
        if (track) { this.favoriteTrackId = track.trackId; this.syncFields(); this.renderSelected(); status.textContent = `「${track.trackName}」を一番のお気に入りにしました。保存するとアイコンが変わります。`; }
        return;
      }
      const track = this.results.find(t => t.trackId === Number(target.dataset.trackSelect));
      if (track) {
        if (this.tracks.some(item => item.trackId === track.trackId)) { status.textContent = 'この曲は追加済みです。'; return; }
        if (this.tracks.length >= 20) { status.textContent = '好きな曲は20曲まで登録できます。'; return; }
        this.tracks.push(track);
        if (this.favoriteTrackId === null) this.favoriteTrackId = track.trackId;
        this.syncFields();
        status.textContent = `${this.tracks.length}曲を追加済みです。下の一覧で★の曲を選べます。`;
        this.renderSelected();
      }
    }, { signal });
    this.syncFields();
    this.renderSelected();
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
    if (note) note.textContent = track ? '★の曲から自動入力しています。曲一覧で一番のお気に入りを変更できます。' : '検索を使わない場合は、下の欄へ手入力できます。';
  }
  private renderSelected(): void {
    const primary = this.selected;
    this.form.querySelector('#music-selected')!.innerHTML = this.tracks.length ? `<div class="selected-track"><span class="section-kicker">YOUR FAVORITE TRACKS · ${this.tracks.length}/20</span><div class="primary-icon-preview"><span class="avatar pink">${avatarArtwork(primary)}<span class="avatar-fallback">♪</span></span><span><strong>あなたのアイコン</strong><small>${escape(primary?.trackName)}</small><small>★の曲のジャケットを表示</small></span></div><div class="selected-tracks-list">${this.tracks.map(track => `<article class="selected-track-row">${musicCard(track)}<div class="track-controls"><button type="button" class="primary-track-button ${track.trackId === this.favoriteTrackId ? 'selected' : ''}" data-track-favorite="${track.trackId}" aria-pressed="${track.trackId === this.favoriteTrackId}">${track.trackId === this.favoriteTrackId ? '★ 一番のお気に入り' : '☆ 一番にする'}</button><button type="button" class="remove-track-button" data-track-remove="${track.trackId}" aria-label="${escape(track.trackName)}を削除">削除</button></div></article>`).join('')}</div></div>` : '';
    this.updateResultButtons();
  }
  private updateResultButtons(): void {
    this.form.querySelectorAll<HTMLButtonElement>('[data-track-select]').forEach(button => {
      const added = this.tracks.some(track => track.trackId === Number(button.dataset.trackSelect));
      button.disabled = added || this.tracks.length >= 20;
      const mark = button.querySelector('.music-select-mark');
      if (mark) mark.textContent = added ? '✓' : '＋';
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
      list.innerHTML = results.map(track => `<article class="music-result"><button class="music-result-select" type="button" data-track-select="${track.trackId}" aria-label="${escape(track.trackName)} / ${escape(track.artistName)}を選択">${cover(track,'compact')}<span><strong>${escape(track.trackName)}</strong><small>${escape(track.artistName)}</small><small>${escape(track.collectionName)}</small></span><span class="music-select-mark" aria-hidden="true">＋</span></button><div class="result-store-link">${storeLink(track)}</div></article>`).join('');
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
