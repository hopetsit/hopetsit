// v569 — clés du lot « supprimer une conversation » (9 langues).
// Geste moderne (glisser vers la gauche / appui long) + feuille du bas de
// confirmation + bannières de résultat, communes aux 3 rôles.
//
// Le texte dit la VÉRITÉ du serveur (cf. services/conversationDeleteService.js) :
// la suppression masque la conversation pour MOI seul, sur tous MES appareils ;
// l'autre garde sa copie, et si elle m'écrit de nouveau la conversation revient
// avec son historique.
//
// Placeholder du nom : `{name}` → `.tr.replaceAll('{name}', …)`.
// Ce lot n'édite QUE ce fichier ; le branchement dans v565_i18n.dart est fait
// par Daniel. Règle : la MÊME clé dans les 9 langues.
const Map<String, Map<String, String>> chatdel569I18n = <String, Map<String, String>>{
  'en': <String, String>{
    'chatdel569_sheet_title': 'Delete this conversation?',
    'chatdel569_sheet_body':
        'It disappears from your list on all your devices. {name} keeps their copy. If {name} writes to you again, the conversation comes back with its history.',
    'chatdel569_sheet_body_generic':
        'It disappears from your list on all your devices. The other person keeps their copy. If they write to you again, the conversation comes back with its history.',
    'chatdel569_confirm': 'Delete',
    'chatdel569_deleted_title': 'Conversation deleted',
    'chatdel569_deleted_body': 'It no longer appears in your list.',
    'chatdel569_failed_title': 'Delete failed',
    'chatdel569_failed_body': 'Check your connection and try again.',
  },
  'fr': <String, String>{
    'chatdel569_sheet_title': 'Supprimer cette conversation ?',
    'chatdel569_sheet_body':
        'Elle disparaît de ta liste sur tous tes appareils. {name} garde sa copie. Si {name} t\'écrit à nouveau, la conversation revient avec son historique.',
    'chatdel569_sheet_body_generic':
        'Elle disparaît de ta liste sur tous tes appareils. L\'autre personne garde sa copie. Si elle t\'écrit à nouveau, la conversation revient avec son historique.',
    'chatdel569_confirm': 'Supprimer',
    'chatdel569_deleted_title': 'Conversation supprimée',
    'chatdel569_deleted_body': 'Elle n\'apparaît plus dans ta liste.',
    'chatdel569_failed_title': 'Suppression impossible',
    'chatdel569_failed_body': 'Vérifie ta connexion puis réessaie.',
  },
  'es': <String, String>{
    'chatdel569_sheet_title': '¿Eliminar esta conversación?',
    'chatdel569_sheet_body':
        'Desaparece de tu lista en todos tus dispositivos. {name} conserva su copia. Si {name} vuelve a escribirte, la conversación reaparece con su historial.',
    'chatdel569_sheet_body_generic':
        'Desaparece de tu lista en todos tus dispositivos. La otra persona conserva su copia. Si vuelve a escribirte, la conversación reaparece con su historial.',
    'chatdel569_confirm': 'Eliminar',
    'chatdel569_deleted_title': 'Conversación eliminada',
    'chatdel569_deleted_body': 'Ya no aparece en tu lista.',
    'chatdel569_failed_title': 'No se pudo eliminar',
    'chatdel569_failed_body': 'Comprueba tu conexión e inténtalo de nuevo.',
  },
  'de': <String, String>{
    'chatdel569_sheet_title': 'Diese Unterhaltung löschen?',
    'chatdel569_sheet_body':
        'Sie verschwindet auf allen deinen Geräten aus deiner Liste. {name} behält die eigene Kopie. Wenn {name} dir wieder schreibt, kommt die Unterhaltung mit ihrem Verlauf zurück.',
    'chatdel569_sheet_body_generic':
        'Sie verschwindet auf allen deinen Geräten aus deiner Liste. Die andere Person behält ihre Kopie. Wenn sie dir wieder schreibt, kommt die Unterhaltung mit ihrem Verlauf zurück.',
    'chatdel569_confirm': 'Löschen',
    'chatdel569_deleted_title': 'Unterhaltung gelöscht',
    'chatdel569_deleted_body': 'Sie erscheint nicht mehr in deiner Liste.',
    'chatdel569_failed_title': 'Löschen fehlgeschlagen',
    'chatdel569_failed_body': 'Prüfe deine Verbindung und versuche es erneut.',
  },
  'it': <String, String>{
    'chatdel569_sheet_title': 'Eliminare questa conversazione?',
    'chatdel569_sheet_body':
        'Sparisce dal tuo elenco su tutti i tuoi dispositivi. {name} conserva la sua copia. Se {name} ti scrive di nuovo, la conversazione torna con la sua cronologia.',
    'chatdel569_sheet_body_generic':
        'Sparisce dal tuo elenco su tutti i tuoi dispositivi. L\'altra persona conserva la sua copia. Se ti scrive di nuovo, la conversazione torna con la sua cronologia.',
    'chatdel569_confirm': 'Elimina',
    'chatdel569_deleted_title': 'Conversazione eliminata',
    'chatdel569_deleted_body': 'Non compare più nel tuo elenco.',
    'chatdel569_failed_title': 'Eliminazione non riuscita',
    'chatdel569_failed_body': 'Controlla la connessione e riprova.',
  },
  'pt': <String, String>{
    'chatdel569_sheet_title': 'Apagar esta conversa?',
    'chatdel569_sheet_body':
        'Ela desaparece da tua lista em todos os teus aparelhos. {name} fica com a cópia dele(a). Se {name} te escrever outra vez, a conversa volta com o histórico.',
    'chatdel569_sheet_body_generic':
        'Ela desaparece da tua lista em todos os teus aparelhos. A outra pessoa fica com a cópia dela. Se te escrever outra vez, a conversa volta com o histórico.',
    'chatdel569_confirm': 'Apagar',
    'chatdel569_deleted_title': 'Conversa apagada',
    'chatdel569_deleted_body': 'Já não aparece na tua lista.',
    'chatdel569_failed_title': 'Não foi possível apagar',
    'chatdel569_failed_body': 'Verifica a tua ligação e tenta de novo.',
  },
  'ko': <String, String>{
    'chatdel569_sheet_title': '이 대화를 삭제할까요?',
    'chatdel569_sheet_body':
        '내 모든 기기의 목록에서 사라져요. {name}님은 자기 대화를 그대로 갖고 있어요. {name}님이 다시 메시지를 보내면 대화가 기록과 함께 다시 나타나요.',
    'chatdel569_sheet_body_generic':
        '내 모든 기기의 목록에서 사라져요. 상대방은 자기 대화를 그대로 갖고 있어요. 상대방이 다시 메시지를 보내면 대화가 기록과 함께 다시 나타나요.',
    'chatdel569_confirm': '삭제',
    'chatdel569_deleted_title': '대화를 삭제했어요',
    'chatdel569_deleted_body': '이제 목록에 보이지 않아요.',
    'chatdel569_failed_title': '삭제하지 못했어요',
    'chatdel569_failed_body': '연결을 확인한 뒤 다시 시도해 주세요.',
  },
  'ja': <String, String>{
    'chatdel569_sheet_title': 'この会話を削除しますか？',
    'chatdel569_sheet_body':
        'あなたのすべての端末のリストから消えます。{name}さんの側には残ります。{name}さんがまたメッセージを送ると、会話は履歴付きで戻ってきます。',
    'chatdel569_sheet_body_generic':
        'あなたのすべての端末のリストから消えます。相手の側には残ります。相手がまたメッセージを送ると、会話は履歴付きで戻ってきます。',
    'chatdel569_confirm': '削除',
    'chatdel569_deleted_title': '会話を削除しました',
    'chatdel569_deleted_body': 'リストには表示されなくなりました。',
    'chatdel569_failed_title': '削除できませんでした',
    'chatdel569_failed_body': '接続を確認してからもう一度お試しください。',
  },
  'pl': <String, String>{
    'chatdel569_sheet_title': 'Usunąć tę rozmowę?',
    'chatdel569_sheet_body':
        'Zniknie z Twojej listy na wszystkich Twoich urządzeniach. {name} zachowuje swoją kopię. Jeśli {name} napisze do Ciebie ponownie, rozmowa wróci wraz z historią.',
    'chatdel569_sheet_body_generic':
        'Zniknie z Twojej listy na wszystkich Twoich urządzeniach. Druga osoba zachowuje swoją kopię. Jeśli napisze do Ciebie ponownie, rozmowa wróci wraz z historią.',
    'chatdel569_confirm': 'Usuń',
    'chatdel569_deleted_title': 'Rozmowa usunięta',
    'chatdel569_deleted_body': 'Nie pojawia się już na Twojej liście.',
    'chatdel569_failed_title': 'Nie udało się usunąć',
    'chatdel569_failed_body': 'Sprawdź połączenie i spróbuj ponownie.',
  },
};
