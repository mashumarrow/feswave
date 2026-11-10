export type Color = 'pink' | 'blue' | 'purple' | 'orange';
export type Page = 'live' | 'memory' | 'profile';
export interface MusicTrack { trackId: number; artistName: string; trackName: string; collectionName: string; artworkUrl: string | null; trackUrl: string }
export interface PublicUser { id: string; name: string; artist: string; song: string; color: Color; music?: MusicTrack | null; tracks?: MusicTrack[] }
export interface User extends PublicUser { visible: boolean; eventId: string | null; favoriteTrackId: number | null }
export interface Participant extends PublicUser { taps?: number; level: number }
export interface LiveEvent { id: string; name: string; subtitle: string; date: string; venue: string; artist: string; song: string; time: string; color: Color }
export interface Memory { id: string; userId: string; eventId: string; at: number; level: number; person: PublicUser; favorite: boolean }
export interface LiveSnapshot { eventId: string; serverTime: number; participants: Participant[]; count: number }
export interface ReactionResult { taps: number; level: number; windowEnds: number }
export interface Session { user: User; events: LiveEvent[]; account: { google: boolean }; google: import('./auth.js').GoogleConfig | null }
export interface AppState { user: User | null; events: LiveEvent[]; eventId: string; page: Page; participants: Participant[]; memories: Memory[]; filter: 'all' | 'favorite'; connected: boolean; taps: number; level: number; windowEnds: number; loading: boolean; demo: boolean }
export interface ApiRoutes { session: Session; profile: User; join: { eventId: string }; react: ReactionResult; memories: Memory[]; 'auth/google': { user: User }; 'auth/challenge': { nonce: string }; 'auth/logout': { ok: boolean } }
