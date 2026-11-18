class LanguageLesson {
  const LanguageLesson(
    this.id,
    this.titleEn,
    this.titleZh,
    this.examples,
    this.promptEn,
    this.promptZh,
    this.options,
    this.answer,
  );

  final String id, titleEn, titleZh, promptEn, promptZh;
  final List<({String text, String en, String zh})> examples;
  final List<String> options;
  final int answer;
}

const englishLessons = [
  LanguageLesson(
    'short-vowels',
    'Letters and short vowels',
    '字母与短元音',
    [
      (
        text: 'A, B, C',
        en: 'Letter names: ay, bee, see.',
        zh: '三个字母的名称，注意名称和词中的发音不同。',
      ),
      (
        text: 'cat, hat',
        en: 'Both have the short a sound /æ/.',
        zh: '两个词中的 a 都发短音 /æ/。',
      ),
      (
        text: 'bed, red',
        en: 'Both have the short e sound /ɛ/.',
        zh: '两个词中的 e 都发短音 /ɛ/。',
      ),
    ],
    'Which word has the same vowel sound as “cat”?',
    '哪个词的元音和 cat 相同？',
    ['bed', 'hat', 'red'],
    1,
  ),
  LanguageLesson(
    'essential-words',
    'High-frequency words',
    '高频基础词',
    [
      (text: 'water', en: 'Something to drink.', zh: '水，可以喝的液体。'),
      (text: 'help', en: 'Support when something is difficult.', zh: '帮助。'),
      (text: 'today', en: 'The current day.', zh: '今天。'),
    ],
    'Which word means the current day?',
    '哪个词表示今天？',
    ['water', 'today', 'help'],
    1,
  ),
  LanguageLesson(
    'greetings',
    'Greetings and introductions',
    '问候和自我介绍',
    [
      (
        text: 'Good morning!',
        en: 'A greeting used in the morning.',
        zh: '早上好！',
      ),
      (
        text: 'My name is Lina.',
        en: 'Use “My name is” to introduce yourself.',
        zh: '我叫 Lina。用 My name is 介绍自己。',
      ),
      (
        text: 'Nice to meet you.',
        en: 'Say this when you meet someone for the first time.',
        zh: '很高兴认识你，初次见面时使用。',
      ),
    ],
    'How do you introduce yourself?',
    '怎样介绍自己的名字？',
    ['Good night.', 'See you tomorrow.', 'My name is Lina.'],
    2,
  ),
  LanguageLesson(
    'everyday-questions',
    'Everyday questions',
    '日常问答',
    [
      (
        text: 'Where is the bus stop?',
        en: 'Ask “where” to find a place.',
        zh: '公交站在哪里？用 where 询问地点。',
      ),
      (
        text: 'It is next to the library.',
        en: '“Next to” means beside.',
        zh: '它就在图书馆旁边。',
      ),
      (
        text: 'When does it open?',
        en: 'Ask “when” to find out a time.',
        zh: '它什么时候开门？用 when 询问时间。',
      ),
    ],
    'Which reply gives a location?',
    '哪句回答给出了地点？',
    ['It is next to the library.', 'It opens at nine.', 'Yes, it does.'],
    0,
  ),
  LanguageLesson(
    'making-requests',
    'Making a request',
    '表达需求',
    [
      (
        text: 'Could I have some water, please?',
        en: 'A polite way to ask for water.',
        zh: '可以给我一点水吗？这是礼貌的请求。',
      ),
      (
        text: 'Sure. Here you are.',
        en: 'Say this when you hand something to someone.',
        zh: '当然。给你。',
      ),
      (
        text: 'Thank you for your help.',
        en: 'Thank someone who helped you.',
        zh: '谢谢你的帮助。',
      ),
    ],
    'Which sentence politely asks for something?',
    '哪一句是礼貌的请求？',
    ['I have some water.', 'Could I have some water, please?', 'Here you are.'],
    1,
  ),
  LanguageLesson(
    'first-message',
    'Read and write a short message',
    '读写一条短消息',
    [
      (
        text: 'Hi Sam, I am at the library. I will wait near the front door.',
        en: 'The message gives a location now and a plan.',
        zh: '这条消息告知当前的位置，并说明接下来的计划。',
      ),
      (
        text: 'Hi Sam, I am at the bus stop. I will wait here.',
        en: 'Try writing a new message by changing the location and plan.',
        zh: '试试换一个地点和计划，写一条自己的留言。',
      ),
    ],
    'In the first message, where will the writer wait?',
    '第一条消息的作者会在哪里等？',
    ['At the bus stop.', 'Near the front door.', 'On the train.'],
    1,
  ),
];

const japaneseLessons = [
  LanguageLesson(
    'hiragana-vowels',
    'The five hiragana vowels',
    '平假名的五个元音',
    [
      (
        text: 'あ、い、う、え、お',
        en: 'The basic vowels: a, i, u, e, o.',
        zh: '五个基本元音，依次为 a、i、u、e、o。',
      ),
      (text: 'あお', en: 'Blue (ao).', zh: '蓝色（ao）。'),
      (text: 'いえ', en: 'House (ie).', zh: '房子（ie）。'),
    ],
    'Which character represents “e”?',
    '哪个平假名对应 e？',
    ['え', 'お', 'あ'],
    0,
  ),
  LanguageLesson(
    'japanese-greetings',
    'First greetings',
    '初次问候',
    [
      (text: 'おはようございます。', en: 'Good morning (polite).', zh: '早上好（礼貌用语）。'),
      (
        text: 'はじめまして。',
        en: 'Nice to meet you (first meeting).',
        zh: '初次见面，请多关照。',
      ),
      (text: 'ありがとうございます。', en: 'Thank you (polite).', zh: '谢谢（礼貌用语）。'),
    ],
    'What do you say to greet someone for the first time?',
    '初次见面可以怎么说？',
    ['ありがとうございます。', 'はじめまして。', 'おはようございます。'],
    1,
  ),
  LanguageLesson(
    'japanese-requests',
    'Asking for something',
    '在店里提出请求',
    [
      (text: 'みず', en: 'Water (mizu).', zh: '水（mizu）。'),
      (text: 'みずをください。', en: 'Water, please.', zh: '请给我水。'),
      (text: 'これをください。', en: 'This one, please.', zh: '请给我这个。'),
    ],
    'Which sentence asks for water?',
    '哪一句是请求给水？',
    ['これをください。', 'はじめまして。', 'みずをください。'],
    2,
  ),
];
