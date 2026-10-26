"use client";

// 26/10/2026 (LEO — retour de FLO, ordre de BOB) : « Mot de passe oublié » sur le site. Les
// propriétaires venus de la pub n'ont jamais choisi de mot de passe (compte ouvert par e-mail) et
// la page /posts/confirmer leur dit d'utiliser « Mot de passe oublié » — le lien n'existait pas.
// Mêmes routes que l'app : POST /auth/forgot-password { email } → code à 6 chiffres par e-mail,
// POST /auth/verify-password-reset-otp { email, code }, POST /auth/reset-password
// { email, newPassword }, puis connexion et retour à la page demandée (?redirect=…).
// Page privée (noindex via middleware). Hooks en tête, aucun retour anticipé avant.

import Link from "@/components/SiteLink";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useT } from "@/lib/i18n/LanguageProvider";
import type { Lang } from "@/lib/i18n/langs";
import { API_BASE, ApiError, login } from "@/lib/api";

type Txt = Record<string, string>;
const TXT: Record<Lang, Txt> = {
  fr: { title: "Mot de passe oublié", sub: "Indique ton e-mail : on t'envoie un code pour choisir un nouveau mot de passe.", email: "E-mail", send: "Recevoir mon code", sending: "Envoi…", code: "Code reçu par e-mail (6 chiffres)", pwd: "Nouveau mot de passe (8 caractères minimum)", save: "Enregistrer et me connecter", saving: "Enregistrement…", sent: "Code envoyé à {email}. Regarde aussi tes spams.", resend: "Renvoyer le code", unknown: "Aucun compte avec cet e-mail.", bad: "Code incorrect.", expired: "Code expiré : demande un nouveau code.", short: "Le mot de passe doit faire au moins 8 caractères.", generic: "Ça n'a pas marché. Réessaie dans un instant.", back: "Retour à la connexion" },
  en: { title: "Forgot password", sub: "Enter your email: we'll send you a code to choose a new password.", email: "Email", send: "Get my code", sending: "Sending…", code: "Code received by email (6 digits)", pwd: "New password (at least 8 characters)", save: "Save and sign in", saving: "Saving…", sent: "Code sent to {email}. Check your spam folder too.", resend: "Send the code again", unknown: "No account with this email.", bad: "Wrong code.", expired: "Code expired: ask for a new one.", short: "The password must be at least 8 characters.", generic: "That didn't work. Please try again in a moment.", back: "Back to sign in" },
  es: { title: "Contraseña olvidada", sub: "Indica tu e-mail: te enviamos un código para elegir una nueva contraseña.", email: "E-mail", send: "Recibir mi código", sending: "Enviando…", code: "Código recibido por e-mail (6 cifras)", pwd: "Nueva contraseña (mínimo 8 caracteres)", save: "Guardar e iniciar sesión", saving: "Guardando…", sent: "Código enviado a {email}. Revisa también el spam.", resend: "Reenviar el código", unknown: "No hay ninguna cuenta con este e-mail.", bad: "Código incorrecto.", expired: "Código caducado: pide uno nuevo.", short: "La contraseña debe tener al menos 8 caracteres.", generic: "No ha funcionado. Inténtalo de nuevo en un momento.", back: "Volver al inicio de sesión" },
  de: { title: "Passwort vergessen", sub: "Gib deine E-Mail an: Wir schicken dir einen Code für ein neues Passwort.", email: "E-Mail", send: "Code erhalten", sending: "Wird gesendet…", code: "Code aus der E-Mail (6 Ziffern)", pwd: "Neues Passwort (mindestens 8 Zeichen)", save: "Speichern und anmelden", saving: "Wird gespeichert…", sent: "Code an {email} gesendet. Schau auch im Spam nach.", resend: "Code erneut senden", unknown: "Kein Konto mit dieser E-Mail.", bad: "Falscher Code.", expired: "Code abgelaufen: Fordere einen neuen an.", short: "Das Passwort muss mindestens 8 Zeichen haben.", generic: "Das hat nicht geklappt. Versuch es gleich noch einmal.", back: "Zurück zur Anmeldung" },
  it: { title: "Password dimenticata", sub: "Indica la tua e-mail: ti inviamo un codice per scegliere una nuova password.", email: "E-mail", send: "Ricevi il codice", sending: "Invio…", code: "Codice ricevuto via e-mail (6 cifre)", pwd: "Nuova password (almeno 8 caratteri)", save: "Salva e accedi", saving: "Salvataggio…", sent: "Codice inviato a {email}. Controlla anche lo spam.", resend: "Invia di nuovo il codice", unknown: "Nessun account con questa e-mail.", bad: "Codice errato.", expired: "Codice scaduto: chiedine uno nuovo.", short: "La password deve avere almeno 8 caratteri.", generic: "Non ha funzionato. Riprova tra un attimo.", back: "Torna all'accesso" },
  pt: { title: "Esqueci-me da palavra-passe", sub: "Indica o teu e-mail: enviamos-te um código para escolher uma nova palavra-passe.", email: "E-mail", send: "Receber o código", sending: "A enviar…", code: "Código recebido por e-mail (6 dígitos)", pwd: "Nova palavra-passe (mínimo 8 caracteres)", save: "Guardar e entrar", saving: "A guardar…", sent: "Código enviado para {email}. Vê também o spam.", resend: "Reenviar o código", unknown: "Não existe conta com este e-mail.", bad: "Código incorreto.", expired: "Código expirado: pede um novo.", short: "A palavra-passe deve ter pelo menos 8 caracteres.", generic: "Não funcionou. Tenta novamente daqui a pouco.", back: "Voltar ao início de sessão" },
  ko: { title: "비밀번호 찾기", sub: "이메일을 입력하면 새 비밀번호를 정할 수 있는 코드를 보내드려요.", email: "이메일", send: "코드 받기", sending: "보내는 중…", code: "이메일로 받은 코드(6자리)", pwd: "새 비밀번호(8자 이상)", save: "저장하고 로그인", saving: "저장 중…", sent: "{email}(으)로 코드를 보냈어요. 스팸함도 확인해 주세요.", resend: "코드 다시 보내기", unknown: "이 이메일로 가입된 계정이 없어요.", bad: "코드가 올바르지 않아요.", expired: "코드가 만료됐어요. 새 코드를 요청해 주세요.", short: "비밀번호는 8자 이상이어야 해요.", generic: "처리하지 못했어요. 잠시 후 다시 시도해 주세요.", back: "로그인으로 돌아가기" },
  ja: { title: "パスワードをお忘れの方", sub: "メールアドレスを入力すると、新しいパスワードを設定するためのコードをお送りします。", email: "メールアドレス", send: "コードを受け取る", sending: "送信中…", code: "メールで届いたコード（6桁）", pwd: "新しいパスワード（8文字以上）", save: "保存してログイン", saving: "保存中…", sent: "{email} にコードを送りました。迷惑メールフォルダもご確認ください。", resend: "コードを再送する", unknown: "このメールアドレスのアカウントはありません。", bad: "コードが正しくありません。", expired: "コードの有効期限が切れました。新しいコードを請求してください。", short: "パスワードは8文字以上にしてください。", generic: "うまくいきませんでした。少ししてからもう一度お試しください。", back: "ログインに戻る" },
  pl: { title: "Nie pamiętam hasła", sub: "Podaj e-mail: wyślemy kod, aby ustawić nowe hasło.", email: "E-mail", send: "Wyślij mi kod", sending: "Wysyłanie…", code: "Kod z e-maila (6 cyfr)", pwd: "Nowe hasło (min. 8 znaków)", save: "Zapisz i zaloguj", saving: "Zapisywanie…", sent: "Kod wysłany na {email}. Sprawdź też spam.", resend: "Wyślij kod ponownie", unknown: "Brak konta z tym adresem e-mail.", bad: "Nieprawidłowy kod.", expired: "Kod wygasł: poproś o nowy.", short: "Hasło musi mieć co najmniej 8 znaków.", generic: "Nie udało się. Spróbuj ponownie za chwilę.", back: "Wróć do logowania" },
};

async function post(path: string, body: Record<string, string>): Promise<void> {
  const r = await fetch(`${API_BASE}${path}`, { method: "POST", headers: { "Content-Type": "application/json", "X-App-Version": "web" }, body: JSON.stringify(body) });
  if (!r.ok) {
    let msg = "";
    try { msg = String((await r.json())?.error || ""); } catch { /* corps vide */ }
    throw new ApiError(msg || `HTTP ${r.status}`, r.status);
  }
}

export default function ForgotPasswordPage() {
  const { lang } = useT();
  const router = useRouter();
  const tx = TXT[lang] || TXT.fr;
  const [email, setEmail] = useState("");
  const [step, setStep] = useState<"email" | "code">("email");
  const [code, setCode] = useState("");
  const [pwd, setPwd] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState("");
  const [redirect, setRedirect] = useState("/dashboard");

  useEffect(() => {
    try {
      const q = new URLSearchParams(window.location.search);
      const r = q.get("redirect") || "";
      if (/^\/(?!\/)[^\s]*$/.test(r)) setRedirect(r);
      const e = q.get("email") || "";
      if (e) setEmail(e);
    } catch { /* URL exotique */ }
  }, []);

  async function sendCode(e?: React.FormEvent) {
    e?.preventDefault();
    setErr("");
    setBusy(true);
    try {
      await post("/auth/forgot-password", { email: email.trim().toLowerCase() });
      setStep("code");
    } catch (ex) {
      setErr(ex instanceof ApiError && ex.status === 404 ? tx.unknown : tx.generic);
    } finally {
      setBusy(false);
    }
  }

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setErr("");
    if (pwd.length < 8) { setErr(tx.short); return; }
    setBusy(true);
    const mail = email.trim().toLowerCase();
    try {
      await post("/auth/verify-password-reset-otp", { email: mail, code: code.trim() });
      await post("/auth/reset-password", { email: mail, newPassword: pwd });
      await login(mail, pwd);
      router.push(redirect);
    } catch (ex) {
      const st = ex instanceof ApiError ? ex.status : 0;
      setErr(st === 410 ? tx.expired : st === 400 ? tx.bad : tx.generic);
      setBusy(false);
    }
  }

  const input = "mt-1 w-full rounded-2xl border border-ink/10 bg-white px-4 py-3 text-[16px] text-ink focus:border-owner focus:outline-none";

  return (
    <div className="mx-auto max-w-md px-4 py-16 md:py-24" data-forgot-2610="">
      <h1 className="text-center font-display text-3xl font-extrabold tracking-tight md:text-4xl">{tx.title}</h1>
      <p className="mt-3 text-center text-sm text-ink-muted">{tx.sub}</p>

      {step === "email" ? (
        <form onSubmit={sendCode} className="mt-8 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card">
          <label className="block text-sm font-medium text-ink">
            {tx.email}
            <input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} className={input} />
          </label>
          <button disabled={busy || !email.trim()} className="min-h-[48px] w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60">
            {busy ? tx.sending : tx.send}
          </button>
          {err && <p role="alert" className="text-center text-sm font-semibold text-owner-dark">{err}</p>}
        </form>
      ) : (
        <form onSubmit={save} className="mt-8 space-y-4 rounded-3xl border border-ink/5 bg-white p-7 shadow-card">
          <p className="rounded-2xl bg-owner-light px-4 py-3 text-sm font-semibold text-owner-dark">{tx.sent.split("{email}").join(email.trim())}</p>
          <label className="block text-sm font-medium text-ink">
            {tx.code}
            <input inputMode="numeric" autoComplete="one-time-code" required value={code} onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))} className={`${input} tracking-[0.3em]`} />
          </label>
          <label className="block text-sm font-medium text-ink">
            {tx.pwd}
            <input type="password" required minLength={8} autoComplete="new-password" value={pwd} onChange={(e) => setPwd(e.target.value)} className={input} />
          </label>
          <button disabled={busy || code.length < 4} className="min-h-[48px] w-full rounded-full bg-owner py-3 text-sm font-semibold text-white shadow-cta hover:bg-owner-dark disabled:opacity-60">
            {busy ? tx.saving : tx.save}
          </button>
          {err && <p role="alert" className="text-center text-sm font-semibold text-owner-dark">{err}</p>}
          <button type="button" onClick={() => void sendCode()} disabled={busy} className="min-h-[44px] w-full text-sm font-semibold text-owner underline-offset-2 hover:underline">
            {tx.resend}
          </button>
        </form>
      )}

      <p className="mt-6 text-center text-sm">
        <Link href={`/login${redirect !== "/dashboard" ? `?redirect=${encodeURIComponent(redirect)}` : ""}`} className="font-semibold text-owner">{tx.back}</Link>
      </p>
    </div>
  );
}
