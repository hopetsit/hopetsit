// v568 — clés de traduction du lot « carte bancaire enregistrée » (9 langues) :
// écran Mes cartes (carte par défaut, remplacement, carte expirée) et libellé
// « Payer avec •••• 4242 » sur l'écran de paiement.
//
// Format identique à friends_i18n.dart : la MÊME clé dans les 9 langues
// (en fr es de it pt ko ja pl). NON branché dans v565_i18n.dart — Daniel
// l'ajoute lui-même au registre.
//
// Rappel produit qui explique le vocabulaire : Airwallex ne permet PAS de
// modifier le numéro d'une carte enregistrée. « Modifier » = enregistrer la
// nouvelle carte, la passer par défaut, puis retirer l'ancienne.
const Map<String, Map<String, String>> cards568I18n = <String, Map<String, String>>{
  'en': <String, String>{
    'cards568_default_badge': 'Default',
    'cards568_set_default': 'Use by default',
    'cards568_set_default_done': 'Default card updated',
    'cards568_expired': 'Expired',
    'cards568_expired_hint': 'This card has expired. Replace it to keep paying.',
    'cards568_manage': 'Manage',
    'cards568_actions_title': 'This card',
    'cards568_replace': 'Replace this card',
    'cards568_replace_title': 'Replace this card?',
    'cards568_replace_message':
        'A card number cannot be edited. We add your new card, make it the default one, then remove the old card. Your new card is verified with a €0.50 charge that is refunded straight away.',
    'cards568_replace_confirm': 'Add the new card',
    'cards568_replace_done': 'Card replaced',
    'cards568_replace_old_kept':
        'Your new card is saved. The old one could not be removed — delete it from the list.',
    'cards568_delete': 'Delete this card',
    'cards568_paying_with': 'Paying with @card',
    'cards568_security_note':
        'Your card is stored by Airwallex, our payment provider. HoPetSit never sees your card number.',
    'cards568_add_explain':
        'Add your card securely on the Airwallex page: €0.50 is charged to check the card, then refunded straight away.',
    'cards568_add_open': 'Open My cards',
  },
  'fr': <String, String>{
    'cards568_default_badge': 'Par défaut',
    'cards568_set_default': 'Utiliser par défaut',
    'cards568_set_default_done': 'Carte par défaut mise à jour',
    'cards568_expired': 'Expirée',
    'cards568_expired_hint': 'Cette carte est expirée. Remplace-la pour continuer à payer.',
    'cards568_manage': 'Gérer',
    'cards568_actions_title': 'Cette carte',
    'cards568_replace': 'Remplacer cette carte',
    'cards568_replace_title': 'Remplacer cette carte ?',
    'cards568_replace_message':
        'Un numéro de carte ne se modifie pas. On enregistre ta nouvelle carte, on la met par défaut, puis on retire l\'ancienne. La nouvelle carte est vérifiée par un débit de 0,50 € remboursé aussitôt.',
    'cards568_replace_confirm': 'Ajouter la nouvelle carte',
    'cards568_replace_done': 'Carte remplacée',
    'cards568_replace_old_kept':
        'Ta nouvelle carte est enregistrée. L\'ancienne n\'a pas pu être retirée — supprime-la dans la liste.',
    'cards568_delete': 'Supprimer cette carte',
    'cards568_paying_with': 'Paiement avec @card',
    'cards568_security_note':
        'Ta carte est conservée par Airwallex, notre prestataire de paiement. HoPetSit ne voit jamais ton numéro.',
    'cards568_add_explain':
        'Ajoute ta carte en sécurité sur la page Airwallex : 0,50 € sont débités pour vérifier la carte, puis remboursés aussitôt.',
    'cards568_add_open': 'Ouvrir Mes cartes',
  },
  'es': <String, String>{
    'cards568_default_badge': 'Predeterminada',
    'cards568_set_default': 'Usar por defecto',
    'cards568_set_default_done': 'Tarjeta predeterminada actualizada',
    'cards568_expired': 'Caducada',
    'cards568_expired_hint': 'Esta tarjeta ha caducado. Sustitúyela para seguir pagando.',
    'cards568_manage': 'Gestionar',
    'cards568_actions_title': 'Esta tarjeta',
    'cards568_replace': 'Sustituir esta tarjeta',
    'cards568_replace_title': '¿Sustituir esta tarjeta?',
    'cards568_replace_message':
        'El número de una tarjeta no se puede modificar. Guardamos tu nueva tarjeta, la ponemos como predeterminada y luego retiramos la antigua. La nueva se verifica con un cargo de 0,50 € que se devuelve enseguida.',
    'cards568_replace_confirm': 'Añadir la nueva tarjeta',
    'cards568_replace_done': 'Tarjeta sustituida',
    'cards568_replace_old_kept':
        'Tu nueva tarjeta está guardada. No se pudo retirar la antigua: elimínala desde la lista.',
    'cards568_delete': 'Eliminar esta tarjeta',
    'cards568_paying_with': 'Pago con @card',
    'cards568_security_note':
        'Airwallex, nuestro proveedor de pagos, guarda tu tarjeta. HoPetSit nunca ve tu número.',
    'cards568_add_explain':
        'Añade tu tarjeta de forma segura en la página de Airwallex: se cobran 0,50 € para comprobarla y se devuelven enseguida.',
    'cards568_add_open': 'Abrir Mis tarjetas',
  },
  'de': <String, String>{
    'cards568_default_badge': 'Standard',
    'cards568_set_default': 'Als Standard verwenden',
    'cards568_set_default_done': 'Standardkarte aktualisiert',
    'cards568_expired': 'Abgelaufen',
    'cards568_expired_hint': 'Diese Karte ist abgelaufen. Ersetze sie, um weiter zu bezahlen.',
    'cards568_manage': 'Verwalten',
    'cards568_actions_title': 'Diese Karte',
    'cards568_replace': 'Diese Karte ersetzen',
    'cards568_replace_title': 'Diese Karte ersetzen?',
    'cards568_replace_message':
        'Eine Kartennummer lässt sich nicht ändern. Wir speichern deine neue Karte, machen sie zum Standard und entfernen dann die alte. Die neue Karte wird mit einer Belastung von 0,50 € geprüft, die sofort erstattet wird.',
    'cards568_replace_confirm': 'Neue Karte hinzufügen',
    'cards568_replace_done': 'Karte ersetzt',
    'cards568_replace_old_kept':
        'Deine neue Karte ist gespeichert. Die alte konnte nicht entfernt werden – lösche sie in der Liste.',
    'cards568_delete': 'Diese Karte löschen',
    'cards568_paying_with': 'Zahlung mit @card',
    'cards568_security_note':
        'Deine Karte liegt bei Airwallex, unserem Zahlungsdienstleister. HoPetSit sieht deine Kartennummer nie.',
    'cards568_add_explain':
        'Füge deine Karte sicher auf der Airwallex-Seite hinzu: 0,50 € werden zur Prüfung belastet und sofort erstattet.',
    'cards568_add_open': 'Meine Karten öffnen',
  },
  'it': <String, String>{
    'cards568_default_badge': 'Predefinita',
    'cards568_set_default': 'Usa come predefinita',
    'cards568_set_default_done': 'Carta predefinita aggiornata',
    'cards568_expired': 'Scaduta',
    'cards568_expired_hint': 'Questa carta è scaduta. Sostituiscila per continuare a pagare.',
    'cards568_manage': 'Gestisci',
    'cards568_actions_title': 'Questa carta',
    'cards568_replace': 'Sostituisci questa carta',
    'cards568_replace_title': 'Sostituire questa carta?',
    'cards568_replace_message':
        'Il numero di una carta non si può modificare. Salviamo la nuova carta, la impostiamo come predefinita e poi rimuoviamo la vecchia. La nuova carta è verificata con un addebito di 0,50 € rimborsato subito.',
    'cards568_replace_confirm': 'Aggiungi la nuova carta',
    'cards568_replace_done': 'Carta sostituita',
    'cards568_replace_old_kept':
        'La nuova carta è salvata. La vecchia non è stata rimossa: eliminala dalla lista.',
    'cards568_delete': 'Elimina questa carta',
    'cards568_paying_with': 'Pagamento con @card',
    'cards568_security_note':
        'La tua carta è conservata da Airwallex, il nostro fornitore di pagamenti. HoPetSit non vede mai il tuo numero.',
    'cards568_add_explain':
        'Aggiungi la carta in sicurezza sulla pagina Airwallex: 0,50 € vengono addebitati per la verifica e rimborsati subito.',
    'cards568_add_open': 'Apri Le mie carte',
  },
  'pt': <String, String>{
    'cards568_default_badge': 'Predefinida',
    'cards568_set_default': 'Usar por predefinição',
    'cards568_set_default_done': 'Cartão predefinido atualizado',
    'cards568_expired': 'Expirado',
    'cards568_expired_hint': 'Este cartão expirou. Substitui-o para continuares a pagar.',
    'cards568_manage': 'Gerir',
    'cards568_actions_title': 'Este cartão',
    'cards568_replace': 'Substituir este cartão',
    'cards568_replace_title': 'Substituir este cartão?',
    'cards568_replace_message':
        'O número de um cartão não pode ser alterado. Guardamos o teu novo cartão, tornamo-lo predefinido e depois retiramos o antigo. O novo cartão é verificado com um débito de 0,50 € devolvido de imediato.',
    'cards568_replace_confirm': 'Adicionar o novo cartão',
    'cards568_replace_done': 'Cartão substituído',
    'cards568_replace_old_kept':
        'O teu novo cartão está guardado. O antigo não pôde ser retirado — elimina-o na lista.',
    'cards568_delete': 'Eliminar este cartão',
    'cards568_paying_with': 'Pagamento com @card',
    'cards568_security_note':
        'O teu cartão é guardado pela Airwallex, o nosso fornecedor de pagamentos. A HoPetSit nunca vê o teu número.',
    'cards568_add_explain':
        'Adiciona o teu cartão em segurança na página Airwallex: 0,50 € são debitados para verificar e devolvidos logo a seguir.',
    'cards568_add_open': 'Abrir Os meus cartões',
  },
  'ko': <String, String>{
    'cards568_default_badge': '기본',
    'cards568_set_default': '기본 카드로 사용',
    'cards568_set_default_done': '기본 카드가 변경되었습니다',
    'cards568_expired': '만료됨',
    'cards568_expired_hint': '이 카드는 만료되었습니다. 계속 결제하려면 교체하세요.',
    'cards568_manage': '관리',
    'cards568_actions_title': '이 카드',
    'cards568_replace': '이 카드 교체',
    'cards568_replace_title': '이 카드를 교체할까요?',
    'cards568_replace_message':
        '카드 번호는 수정할 수 없습니다. 새 카드를 저장하고 기본 카드로 지정한 뒤 이전 카드를 삭제합니다. 새 카드는 0.50유로 결제로 확인하며 바로 환불됩니다.',
    'cards568_replace_confirm': '새 카드 추가',
    'cards568_replace_done': '카드를 교체했습니다',
    'cards568_replace_old_kept':
        '새 카드가 저장되었습니다. 이전 카드는 삭제되지 않았습니다 — 목록에서 삭제하세요.',
    'cards568_delete': '이 카드 삭제',
    'cards568_paying_with': '@card 로 결제',
    'cards568_security_note':
        '카드는 결제사 Airwallex가 보관합니다. HoPetSit은 카드 번호를 절대 보지 않습니다.',
    'cards568_add_explain':
        'Airwallex 페이지에서 안전하게 카드를 추가하세요. 확인을 위해 0.50유로가 결제된 뒤 바로 환불됩니다.',
    'cards568_add_open': '내 카드 열기',
  },
  'ja': <String, String>{
    'cards568_default_badge': '既定',
    'cards568_set_default': '既定のカードにする',
    'cards568_set_default_done': '既定のカードを更新しました',
    'cards568_expired': '有効期限切れ',
    'cards568_expired_hint': 'このカードは有効期限が切れています。支払いを続けるには交換してください。',
    'cards568_manage': '管理',
    'cards568_actions_title': 'このカード',
    'cards568_replace': 'このカードを交換',
    'cards568_replace_title': 'このカードを交換しますか？',
    'cards568_replace_message':
        'カード番号は変更できません。新しいカードを登録して既定に設定し、その後で古いカードを削除します。新しいカードは0.50ユーロの決済で確認し、すぐに返金します。',
    'cards568_replace_confirm': '新しいカードを追加',
    'cards568_replace_done': 'カードを交換しました',
    'cards568_replace_old_kept':
        '新しいカードを登録しました。古いカードは削除できませんでした — 一覧から削除してください。',
    'cards568_delete': 'このカードを削除',
    'cards568_paying_with': '@card で支払い',
    'cards568_security_note':
        'カード情報は決済事業者Airwallexが保管します。HoPetSitがカード番号を見ることはありません。',
    'cards568_add_explain':
        'Airwallexのページで安全にカードを追加できます。確認のため0.50ユーロを決済し、すぐに返金します。',
    'cards568_add_open': 'マイカードを開く',
  },
  'pl': <String, String>{
    'cards568_default_badge': 'Domyślna',
    'cards568_set_default': 'Ustaw jako domyślną',
    'cards568_set_default_done': 'Zaktualizowano domyślną kartę',
    'cards568_expired': 'Wygasła',
    'cards568_expired_hint': 'Ta karta wygasła. Wymień ją, aby dalej płacić.',
    'cards568_manage': 'Zarządzaj',
    'cards568_actions_title': 'Ta karta',
    'cards568_replace': 'Wymień tę kartę',
    'cards568_replace_title': 'Wymienić tę kartę?',
    'cards568_replace_message':
        'Numeru karty nie da się zmienić. Zapisujemy nową kartę, ustawiamy ją jako domyślną, a potem usuwamy starą. Nowa karta jest sprawdzana obciążeniem 0,50 €, które od razu zwracamy.',
    'cards568_replace_confirm': 'Dodaj nową kartę',
    'cards568_replace_done': 'Karta wymieniona',
    'cards568_replace_old_kept':
        'Nowa karta jest zapisana. Starej nie udało się usunąć — usuń ją z listy.',
    'cards568_delete': 'Usuń tę kartę',
    'cards568_paying_with': 'Płatność kartą @card',
    'cards568_security_note':
        'Twoją kartę przechowuje Airwallex, nasz dostawca płatności. HoPetSit nigdy nie widzi numeru karty.',
    'cards568_add_explain':
        'Dodaj kartę bezpiecznie na stronie Airwallex: pobieramy 0,50 € na weryfikację i od razu zwracamy.',
    'cards568_add_open': 'Otwórz Moje karty',
  },
};
