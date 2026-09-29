// v599 (29/09/2026) — LA BALADE : fond « carte en préparation » sous la carte
// (Oppo A40 : 5 s de zone vide avant les tuiles), section « La Balade » de
// « Comprendre la PawMap » (ce que voit la personne en balade, ce que voient
// les autres, le point vert du menu). 9 langues, mêmes clés.
// Mêmes textes que ~/hopetsit-social/pawmap_599/balade_textes_9langues.json
// (repris par LEO pour la page « Comprendre la PawMap » du site).
const Map<String, Map<String, String>> balade599I18n =
    <String, Map<String, String>>{
  'fr': <String, String>{
    'pawmap599_map_preparing': 'Carte en préparation…',
    'help599_sec_balade': 'La Balade',
    'help599_ex_balade':
        'Kathy promène Rex : sur sa carte, son rond « Moi » avance et laisse un tracé violet ; à droite, un badge vert au-dessus du bouton Balade indique « 12 min » et le nombre de personnes qui la suivent. Chez ses amis, Kathy est un rond avec sa photo, un anneau violet et « en direct · maintenant ».',
    'help599_t_me': 'Toi, en balade',
    'help599_b_me':
        'Touche le bouton Balade (barre de droite). Ton rond « Moi » bouge avec toi, un tracé violet dessine ton chemin et un badge vert, juste au-dessus du bouton, montre la durée et le nombre de personnes qui te suivent. Touche à nouveau Balade pour finir : tout s\'efface aussitôt, sur tous tes téléphones.',
    'help599_t_others': 'Ce que voient les autres',
    'help599_b_others':
        'Tes amis, ta famille, et le propriétaire pendant une réservation en cours : ton rond porte ta photo, un anneau violet qui respire, la bulle « en direct · maintenant » et ton tracé. Sans signal pendant 2 min, le rond s\'éteint et affiche « Vu il y a X » ; après 10 min, il disparaît.',
    'help599_t_dot': 'Le point vert du menu',
    'help599_b_dot':
        'Sans ouvrir la carte : un petit point vert apparaît en haut à droite de la patte du menu dès qu\'un ami est en balade (le nombre s\'ils sont plusieurs). Touche la patte : la carte s\'ouvre sur lui. Le point s\'efface quand la balade s\'arrête.',
    'help599_img_caption':
        'À gauche : ce que voit la personne en balade. À droite : ce que voient les autres.',
  },
  'en': <String, String>{
    'pawmap599_map_preparing': 'Map loading…',
    'help599_sec_balade': 'The Walk',
    'help599_ex_balade':
        'Kathy is walking Rex: on her map, her “Me” circle moves and leaves a purple trail; on the right, a green badge above the Walk button shows “12 min” and how many people follow her. For her friends, Kathy is a circle with her photo, a purple ring and “live · right now”.',
    'help599_t_me': 'You, on a walk',
    'help599_b_me':
        'Tap the Walk button (right bar). Your “Me” circle moves with you, a purple trail draws your path and a green badge, just above the button, shows how long you\'ve been out and how many people follow you. Tap Walk again to finish: everything clears at once, on all your phones.',
    'help599_t_others': 'What others see',
    'help599_b_others':
        'Your friends, your family, and the owner during a booking in progress: your circle shows your photo, a breathing purple ring, the bubble “live · right now” and your trail. After 2 min without signal, the circle dims and shows “Seen X ago”; after 10 min, it disappears.',
    'help599_t_dot': 'The green dot on the menu',
    'help599_b_dot':
        'Without opening the map: a small green dot appears at the top right of the menu paw as soon as a friend is on a walk (with the number if there are several). Tap the paw: the map opens on them. The dot vanishes when the walk stops.',
    'help599_img_caption':
        'Left: what the person on a walk sees. Right: what others see.',
  },
  'es': <String, String>{
    'pawmap599_map_preparing': 'Preparando el mapa…',
    'help599_sec_balade': 'El Paseo',
    'help599_ex_balade':
        'Kathy pasea a Rex: en su mapa, su círculo «Yo» avanza y deja un trazo morado; a la derecha, una insignia verde encima del botón Paseo indica «12 min» y cuántas personas la siguen. Para sus amigos, Kathy es un círculo con su foto, un anillo morado y «en directo · ahora mismo».',
    'help599_t_me': 'Tú, de paseo',
    'help599_b_me':
        'Toca el botón Paseo (barra derecha). Tu círculo «Yo» se mueve contigo, un trazo morado dibuja tu camino y una insignia verde, justo encima del botón, muestra la duración y cuántas personas te siguen. Vuelve a tocar Paseo para terminar: todo se borra al instante, en todos tus teléfonos.',
    'help599_t_others': 'Lo que ven los demás',
    'help599_b_others':
        'Tus amigos, tu familia y el propietario durante una reserva en curso: tu círculo lleva tu foto, un anillo morado que respira, la burbuja «en directo · ahora mismo» y tu trazo. Tras 2 min sin señal, el círculo se apaga y muestra «Visto hace X»; a los 10 min desaparece.',
    'help599_t_dot': 'El punto verde del menú',
    'help599_b_dot':
        'Sin abrir el mapa: un pequeño punto verde aparece arriba a la derecha de la huella del menú en cuanto un amigo está de paseo (con el número si son varios). Toca la huella: el mapa se abre sobre él. El punto desaparece cuando el paseo termina.',
    'help599_img_caption':
        'Izquierda: lo que ve la persona de paseo. Derecha: lo que ven los demás.',
  },
  'de': <String, String>{
    'pawmap599_map_preparing': 'Karte wird vorbereitet…',
    'help599_sec_balade': 'Der Spaziergang',
    'help599_ex_balade':
        'Kathy geht mit Rex spazieren: Auf ihrer Karte bewegt sich ihr „Ich“-Kreis und hinterlässt eine violette Spur; rechts zeigt ein grünes Abzeichen über der Gassi-Taste „12 Min.“ und wie viele ihr folgen. Für ihre Freunde ist Kathy ein Kreis mit ihrem Foto, einem violetten Ring und „live · gerade eben“.',
    'help599_t_me': 'Du, unterwegs',
    'help599_b_me':
        'Tippe auf die Gassi-Taste (rechte Leiste). Dein „Ich“-Kreis bewegt sich mit dir, eine violette Spur zeichnet deinen Weg und ein grünes Abzeichen direkt über der Taste zeigt die Dauer und wie viele dir folgen. Tippe erneut auf Gassi, um zu beenden: Alles verschwindet sofort, auf allen deinen Telefonen.',
    'help599_t_others': 'Was die anderen sehen',
    'help599_b_others':
        'Deine Freunde, deine Familie und der Besitzer während einer laufenden Buchung: Dein Kreis trägt dein Foto, einen atmenden violetten Ring, die Blase „live · gerade jetzt“ und deine Spur. Nach 2 Min ohne Signal wird der Kreis dunkler und zeigt „Zuletzt vor X“; nach 10 Min verschwindet er.',
    'help599_t_dot': 'Der grüne Punkt im Menü',
    'help599_b_dot':
        'Ohne die Karte zu öffnen: Ein kleiner grüner Punkt erscheint oben rechts an der Pfote des Menüs, sobald ein Freund unterwegs ist (mit der Zahl, wenn es mehrere sind). Tippe auf die Pfote: Die Karte öffnet sich auf ihm. Der Punkt verschwindet, wenn der Spaziergang endet.',
    'help599_img_caption':
        'Links: was die Person unterwegs sieht. Rechts: was die anderen sehen.',
  },
  'it': <String, String>{
    'pawmap599_map_preparing': 'Mappa in preparazione…',
    'help599_sec_balade': 'La Passeggiata',
    'help599_ex_balade':
        'Kathy porta a spasso Rex: sulla sua mappa, il suo cerchio «Io» avanza e lascia una scia viola; a destra, un badge verde sopra il pulsante Passeggio mostra «12 min» e quante persone la seguono. Per i suoi amici, Kathy è un cerchio con la sua foto, un anello viola e «in diretta · adesso».',
    'help599_t_me': 'Tu, in passeggiata',
    'help599_b_me':
        'Tocca il pulsante Passeggio (barra destra). Il tuo cerchio «Io» si muove con te, una scia viola disegna il tuo percorso e un badge verde, proprio sopra il pulsante, mostra la durata e quante persone ti seguono. Tocca di nuovo Passeggio per finire: tutto sparisce subito, su tutti i tuoi telefoni.',
    'help599_t_others': 'Cosa vedono gli altri',
    'help599_b_others':
        'I tuoi amici, la tua famiglia e il proprietario durante una prenotazione in corso: il tuo cerchio porta la tua foto, un anello viola che respira, la bolla «in diretta · adesso» e la tua scia. Dopo 2 min senza segnale, il cerchio si spegne e mostra «Visto X fa»; dopo 10 min scompare.',
    'help599_t_dot': 'Il punto verde del menu',
    'help599_b_dot':
        'Senza aprire la mappa: un piccolo punto verde appare in alto a destra della zampa del menu appena un amico è in passeggiata (con il numero se sono più di uno). Tocca la zampa: la mappa si apre su di lui. Il punto sparisce quando la passeggiata finisce.',
    'help599_img_caption':
        'A sinistra: cosa vede chi è in passeggiata. A destra: cosa vedono gli altri.',
  },
  'pt': <String, String>{
    'pawmap599_map_preparing': 'Mapa em preparação…',
    'help599_sec_balade': 'O Passeio',
    'help599_ex_balade':
        'A Kathy passeia o Rex: no mapa dela, o círculo «Eu» avança e deixa um traço roxo; à direita, um emblema verde por cima do botão Passeio mostra «12 min» e quantas pessoas a seguem. Para os amigos, a Kathy é um círculo com a foto dela, um anel roxo e «em direto · agora mesmo».',
    'help599_t_me': 'Tu, a passear',
    'help599_b_me':
        'Toca no botão Passeio (barra da direita). O teu círculo «Eu» move-se contigo, um traço roxo desenha o teu caminho e um emblema verde, logo por cima do botão, mostra a duração e quantas pessoas te seguem. Toca de novo em Passeio para terminar: tudo se apaga de imediato, em todos os teus telemóveis.',
    'help599_t_others': 'O que os outros veem',
    'help599_b_others':
        'Os teus amigos, a tua família e o dono durante uma reserva em curso: o teu círculo mostra a tua foto, um anel roxo que respira, o balão «em direto · agora mesmo» e o teu traço. Após 2 min sem sinal, o círculo apaga-se e mostra «Visto há X»; após 10 min, desaparece.',
    'help599_t_dot': 'O ponto verde do menu',
    'help599_b_dot':
        'Sem abrir o mapa: um pequeno ponto verde aparece no canto superior direito da pata do menu assim que um amigo está a passear (com o número se forem vários). Toca na pata: o mapa abre-se sobre ele. O ponto desaparece quando o passeio termina.',
    'help599_img_caption':
        'À esquerda: o que vê quem está a passear. À direita: o que os outros veem.',
  },
  'pl': <String, String>{
    'pawmap599_map_preparing': 'Przygotowuję mapę…',
    'help599_sec_balade': 'Spacer',
    'help599_ex_balade':
        'Kathy wyprowadza Rexa: na jej mapie kółko „Ja” przesuwa się i zostawia fioletowy ślad; po prawej zielona plakietka nad przyciskiem Spacer pokazuje „12 min” i liczbę osób, które ją śledzą. U znajomych Kathy to kółko z jej zdjęciem, fioletowym pierścieniem i napisem „na żywo · teraz”.',
    'help599_t_me': 'Ty, na spacerze',
    'help599_b_me':
        'Dotknij przycisku Spacer (prawy pasek). Twoje kółko „Ja” porusza się razem z tobą, fioletowy ślad rysuje twoją drogę, a zielona plakietka tuż nad przyciskiem pokazuje czas i liczbę osób, które cię śledzą. Dotknij Spacer ponownie, aby zakończyć: wszystko znika od razu, na wszystkich twoich telefonach.',
    'help599_t_others': 'Co widzą inni',
    'help599_b_others':
        'Twoi znajomi, rodzina i właściciel podczas trwającej rezerwacji: twoje kółko ma twoje zdjęcie, pulsującą fioletową obwódkę, dymek „na żywo · teraz” i twój ślad. Po 2 min bez sygnału kółko gaśnie i pokazuje „Widziano X temu”; po 10 min znika.',
    'help599_t_dot': 'Zielona kropka w menu',
    'help599_b_dot':
        'Bez otwierania mapy: mała zielona kropka pojawia się w prawym górnym rogu łapki w menu, gdy tylko znajomy jest na spacerze (z liczbą, jeśli jest ich kilku). Dotknij łapki: mapa otworzy się na nim. Kropka znika, gdy spacer się kończy.',
    'help599_img_caption':
        'Po lewej: co widzi osoba na spacerze. Po prawej: co widzą inni.',
  },
  'ja': <String, String>{
    'pawmap599_map_preparing': '地図を準備中…',
    'help599_sec_balade': 'お散歩',
    'help599_ex_balade':
        'キャシーがレックスを散歩中：彼女の地図では「自分」の丸が動いて紫の軌跡を残し、右側の散歩ボタンのすぐ上に緑のバッジが出て「12分」とフォロー中の人数を表示します。友だちには、キャシーは写真入りの丸と紫のリング、「ライブ・今」と表示されます。',
    'help599_t_me': 'あなたがお散歩中',
    'help599_b_me':
        '右バーの散歩ボタンをタップします。「自分」の丸があなたと一緒に動き、紫の軌跡が道を描き、ボタンのすぐ上の緑のバッジが経過時間とフォロー中の人数を表示します。もう一度散歩ボタンをタップすると終了：すべてのスマホからすぐに消えます。',
    'help599_t_others': '他の人に見えるもの',
    'help599_b_others':
        '友だち、家族、そして予約中の飼い主には：あなたの丸に写真、呼吸するような紫のリング、「ライブ・たった今」の吹き出し、軌跡が表示されます。2分間信号がないと丸は暗くなり「X前に確認」と表示、10分後に消えます。',
    'help599_t_dot': 'メニューの緑の点',
    'help599_b_dot':
        '地図を開かなくても：友だちがお散歩を始めると、メニューの肉球の右上に小さな緑の点が出ます（複数なら人数も）。肉球をタップすると地図がその人の位置で開きます。お散歩が終わると点は消えます。',
    'help599_img_caption': '左：お散歩中の人に見える画面。右：他の人に見える画面。',
  },
  'ko': <String, String>{
    'pawmap599_map_preparing': '지도를 준비하는 중…',
    'help599_sec_balade': '산책',
    'help599_ex_balade':
        '캐시가 렉스를 산책시켜요: 캐시의 지도에서는 「나」 원이 움직이며 보라색 자취를 남기고, 오른쪽 산책 버튼 바로 위의 초록 배지에 「12분」과 팔로우하는 사람 수가 표시돼요. 친구들에게 캐시는 사진이 든 원, 보라색 링, 「실시간 · 지금」으로 보여요.',
    'help599_t_me': '산책 중인 나',
    'help599_b_me':
        '오른쪽 바의 산책 버튼을 누르세요. 「나」 원이 나와 함께 움직이고, 보라색 자취가 길을 그리며, 버튼 바로 위의 초록 배지가 산책 시간과 나를 팔로우하는 사람 수를 보여 줘요. 산책 버튼을 다시 누르면 끝: 모든 휴대폰에서 바로 사라져요.',
    'help599_t_others': '다른 사람에게 보이는 것',
    'help599_b_others':
        '친구, 가족, 그리고 진행 중인 예약의 반려인에게는: 내 원에 사진, 숨 쉬듯 반짝이는 보라색 링, 「라이브 · 지금」 말풍선, 그리고 자취가 보여요. 2분간 신호가 없으면 원이 어두워지며 「X 전에 확인」이 표시되고, 10분 후 사라져요.',
    'help599_t_dot': '메뉴의 초록 점',
    'help599_b_dot':
        '지도를 열지 않아도: 친구가 산책을 시작하면 메뉴 발바닥의 오른쪽 위에 작은 초록 점이 나타나요(여럿이면 숫자도 함께). 발바닥을 누르면 지도가 그 친구 위치에서 열려요. 산책이 끝나면 점은 사라져요.',
    'help599_img_caption': '왼쪽: 산책 중인 사람이 보는 화면. 오른쪽: 다른 사람이 보는 화면.',
  },
};
