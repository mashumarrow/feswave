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
export function musicPickerMarkup(): string {
  return `<section class="music-picker" aria-label="iTunesで好きな曲を検索"><label class="form-field" for="music-query"><span>ジャケット付きで好きな曲を登録 <small>任意</small></span></label><div class="music-search-row"><input type="search" id="music-query" name="musicQuery" placeholder="曲・アーティスト・アルバム名" maxlength="100" autocomplete="off"><button type="button" id="music-search" class="subtle-btn">検索</button></div><p class="music-search-hint">iTunesの曲から選べます。下の欄へ手入力もできます。</p><p id="music-status" class="music-status" role="status" aria-live="polite"></p><div id="music-results" class="music-results"></div><div id="music-selected"></div></section>`;
}

export class MusicPicker {
  selected: MusicTrack | null;
  private results: MusicTrack[] = [];
  private controller?: AbortController;
  private generation = 0;
  private destroyed = false;
  private listeners = new AbortController();
  constructor(private form: HTMLFormElement, initial: MusicTrack | null, private search: (term: string, signal: AbortSignal) => Promise<MusicTrack[]>) {
    this.selected = initial;
    const signal = this.listeners.signal;
    form.querySelector('#music-search')!.addEventListener('click', () => this.runSearch(), { signal });
    form.querySelector('#music-query')!.addEventListener('keydown', event => {
      if ((event as KeyboardEvent).key === 'Enter') { event.preventDefault(); this.runSearch(); }
    }, { signal });
    form.addEventListener('click', event => {
      const target = event.target instanceof Element ? event.target.closest<HTMLButtonElement>('[data-track-select], [data-track-clear]') : null;
      if (!target) return;
      if (target.hasAttribute('data-track-clear')) { this.selected = null; this.renderSelected(); return; }
      const track = this.results.find(t => t.trackId === Number(target.dataset.trackSelect));
      if (track) {
        this.selected = track;
        this.form.querySelector<HTMLInputElement>('[name="artist"]')!.value = track.artistName.slice(0,60);
        this.form.querySelector<HTMLInputElement>('[name="song"]')!.value = track.trackName.slice(0,60);
        this.form.querySelector('#music-results')!.innerHTML = '';
        this.form.querySelector('#music-status')!.textContent = '曲を選択しました。下の登録ボタンで保存できます。';
        this.renderSelected();
      }
    }, { signal });
    for (const input of form.querySelectorAll('[name="artist"], [name="song"]')) input.addEventListener('input', () => {
      if (this.selected) { this.selected = null; this.renderSelected(); this.form.querySelector('#music-status')!.textContent = '手入力に切り替えました。ジャケットを付けるには曲を選び直してください。'; }
    }, { signal });
    this.renderSelected();
  }
  private renderSelected(): void {
    this.form.querySelector('#music-selected')!.innerHTML = this.selected ? `<div class="selected-track"><span class="section-kicker">SELECTED TRACK</span>${musicCard(this.selected)}<button type="button" class="text-link clear-track" data-track-clear>ジャケットの選択を解除</button></div>` : '';
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
  if (image instanceof HTMLImageElement && image.classList.contains('cover-image')) { image.remove(); }
}, true);
