"use client";

// v565 (point 29) — route « thème » `payout_*`, `withdrawal_*`,
// `wallet_credited`. Le wallet (retrait IBAN) vit dans l'app ; sur le web,
// le tableau de bord et les factures.

import { AppRoutePage } from "@/components/AppRoutePage";

export default function WalletRoutePage() {
  return <AppRoutePage appPath="wallet" webHref="/dashboard" />;
}
