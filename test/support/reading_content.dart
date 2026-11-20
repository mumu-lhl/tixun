class ReadingPassage {
  const ReadingPassage(this.id, this.title, this.paragraphs, this.items);

  final String id, title;
  final List<String> paragraphs;
  final List<ReadingItem> items;
}

class ReadingItem {
  const ReadingItem.choice(
    this.question,
    this.options,
    String answer,
    this.evidence,
    this.explanation,
  ) : answers = const [],
      choice = answer;

  const ReadingItem.fill(
    this.question,
    this.answers,
    this.evidence,
    this.explanation,
  ) : options = const {},
      choice = null;

  final String question, explanation;
  final Map<String, String> options;
  final String? choice;
  final List<String> answers;
  final int evidence;

  List<String> get acceptedAnswers => choice == null ? answers : [choice!];

  String get answerText =>
      choice == null ? answers.join(" / ") : options[choice]!;
}

const readingPassages = [
  ReadingPassage(
    "seed-library",
    "A Library for Seeds",
    [
      "When the local library began lending seeds, the idea was simple: take a few seeds in spring, grow them, and return some of the seeds from your plants in autumn. Unlike ordinary books, there is no deadline or fine. If your plants fail, the library asks for nothing back.",
      "Last year, a dry summer reduced the number of seeds that people returned. Rather than buy packets to fill the shelves, the organizers asked experienced growers to show newcomers how to save seeds from the healthiest plants. By the following spring, more people were bringing seeds in than taking them out.",
      "For the organizers, that change mattered more than stocking every kind of vegetable. They wanted neighbors to share what they knew about growing food in this particular town, where the weather and soil can make advice from a book hard to follow.",
    ],
    [
      ReadingItem.choice(
        "What happens when a borrower cannot grow any plants?",
        {
          "A": "They pay a fine.",
          "B": "They return nothing.",
          "C": "They buy replacement seeds.",
        },
        "B",
        0,
        "The last sentence sets out the exception. The library asks for seeds only when borrowers have some to return.",
      ),
      ReadingItem.choice(
        "Why did the organizers ask experienced growers to help?",
        {
          "A": "To teach newcomers how to save seeds.",
          "B": "To sell more packets.",
          "C": "To find a new library building.",
        },
        "A",
        1,
        "“Rather than” contrasts buying replacement seeds with teaching borrowers how to save them.",
      ),
      ReadingItem.choice(
        "What did the organizers value most?",
        {
          "A": "A complete collection of seeds.",
          "B": "The number of books borrowed.",
          "C": "Sharing useful local knowledge.",
        },
        "C",
        2,
        "The final paragraph contrasts the size of the collection with the value of sharing knowledge that fits local conditions.",
      ),
    ],
  ),
  ReadingPassage(
    "repair-cafe",
    "A Place to Repair Things",
    [
      "At first, Mina thought the monthly repair café worked like a shop. She planned to leave her lamp on a table and collect it later. Instead, a volunteer invited her to sit down, watch how he checked the switch, and try the next step herself.",
      "Not every broken object can be fixed there. However, the volunteers always explain what they found. Sometimes a repair needs a part they do not have; other times an object is unsafe to open. Either way, visitors leave with a clearer idea of what to do next.",
    ],
    [
      ReadingItem.choice(
        "What surprised Mina about the café?",
        {
          "A": "She was invited to take part in the repair.",
          "B": "She could not collect her lamp.",
          "C": "The café only opened on weekends.",
        },
        "A",
        0,
        "“Instead” marks the contrast between dropping off a lamp and working alongside the volunteer.",
      ),
      ReadingItem.choice(
        "What does the café offer even when it cannot finish a repair?",
        {
          "A": "A replacement object.",
          "B": "Money to buy spare parts.",
          "C": "Information about the problem and what to do next.",
        },
        "C",
        1,
        "The second paragraph says the volunteers always explain what they found.",
      ),
    ],
  ),
];
