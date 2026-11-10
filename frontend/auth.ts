export interface GoogleConfig { clientId: string }
interface CredentialResponse { credential: string }
interface GoogleIdentity {
  initialize(config: { client_id: string; nonce: string; callback(response: CredentialResponse): void; auto_select: boolean }): void;
  renderButton(container: HTMLElement, options: { type: string; theme: string; size: string; text: string; shape: string; width: number; locale: string }): void;
  disableAutoSelect(): void;
}
declare global {
  interface Window { google?: { accounts: { id: GoogleIdentity } } }
}

let scriptLoading: Promise<GoogleIdentity> | undefined;
function loadGoogle(): Promise<GoogleIdentity> {
  if (window.google?.accounts.id) return Promise.resolve(window.google.accounts.id);
  return scriptLoading ??= new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    const timer = setTimeout(() => reject(new Error("Googleに接続できません。通信環境を確認して再読み込みしてください。")), 15000);
    script.onload = () => {
      clearTimeout(timer);
      if (window.google?.accounts.id) resolve(window.google.accounts.id);
      else reject(new Error("Googleログインを読み込めませんでした。"));
    };
    script.onerror = () => {
      clearTimeout(timer);
      reject(new Error("Googleに接続できません。通信環境を確認して再読み込みしてください。"));
    };
    document.head.append(script);
  });
}

export async function prepareGoogle(config: GoogleConfig, nonce: string, onCredential: (token: string) => Promise<void>) {
  const identity = await loadGoogle();
  identity.initialize({ client_id: config.clientId, nonce, auto_select: false,
    callback: (response) => { if (response.credential) void onCredential(response.credential); },
  });
  return {
    render(container: HTMLElement) {
      // Google's official button supports popup/FedCM behavior.
      identity.renderButton(container, { type: "standard", theme: "outline", size: "large", text: "signin_with", shape: "pill", width: Math.max(200, Math.min(340, container.clientWidth || 200)), locale: "ja" });
    },
  };
}

export function disableGoogleAutoSelect() {
  window.google?.accounts.id.disableAutoSelect();
}

export function loginError(error: unknown): string {
  return error instanceof Error ? error.message : "Googleログインに失敗しました。もう一度お試しください。";
}
