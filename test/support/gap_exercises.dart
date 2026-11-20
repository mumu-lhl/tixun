import "reading_content.dart";

const _gardenChoices = {
  "A": "The plants under the stairs soon produced more tomatoes.",
  "B": "The children kept a simple record of what they saw.",
  "C": "The garden also gave people a reason to stop and talk.",
  "D": "That first plan overlooked a basic problem.",
  "E": "They shared those findings at the next neighborhood meeting.",
  "F": "A neighbor suggested moving the boxes to the sunny wall.",
  "G": "Everyone had to pay to enter the garden.",
};

const sentenceInsertionPassages = [
  ReadingPassage(
    "courtyard-garden",
    "A Garden for the Courtyard",
    [
      "The residents of an apartment building wanted to grow vegetables in their shared courtyard. They put their first boxes under the stairs, where there was plenty of room. [1] The stairs blocked the light, and the young plants stayed small.",
      "The residents were about to give up. [2] To find out whether the move helped, they left one box under the stairs and moved the others.",
      "[3] Each Friday they measured the plants in both places and drew a picture of any new leaves. After three weeks, their notes showed that the plants by the wall were growing faster.",
      "[4] The residents agreed to keep the boxes by the wall. They used the notes to choose places for two more boxes, too.",
      "By the end of summer, there were enough tomatoes for several families. [5] Neighbors who had never met were now trading recipes while they watered the plants.",
    ],
    [
      ReadingItem.choice(
        "Which sentence fits [1]?",
        _gardenChoices,
        "D",
        0,
        "The boxes under the stairs were the first plan. The next sentence identifies its problem: too little light.",
      ),
      ReadingItem.choice(
        "Which sentence fits [2]?",
        _gardenChoices,
        "F",
        1,
        "“The move” refers to the neighbor’s suggestion to move the boxes to the sunny wall.",
      ),
      ReadingItem.choice(
        "Which sentence fits [3]?",
        _gardenChoices,
        "B",
        2,
        "The weekly measurements and drawings explain how the children kept their record.",
      ),
      ReadingItem.choice(
        "Which sentence fits [4]?",
        _gardenChoices,
        "E",
        3,
        "“Those findings” refers to the growth measurements. The agreement that follows is the outcome of the meeting.",
      ),
      ReadingItem.choice(
        "Which sentence fits [5]?",
        _gardenChoices,
        "C",
        4,
        "The final sentence gives an example of the garden bringing neighbors together: they trade recipes while watering.",
      ),
    ],
  ),
];

const clozePassages = [
  ReadingPassage(
    "morning-bread",
    "Bread Before School",
    [
      "Leo usually passed the bakery without stopping. One cold morning, he noticed a woman outside holding a broken shopping bag. Apples rolled across the pavement. He stopped to [1] them before they reached the road.",
      "The woman thanked him. She still had a long walk home, so Leo went into the bakery to ask for a [2] bag. The baker gave him a strong paper one.",
      "The woman wanted to [3] him for his help, but Leo said he was glad to help and hurried to school.",
      "The next day, the baker put a shelf by the door for [4] bags. Anyone could leave a clean bag or take one when they needed it.",
      "The shelf began with only two bags. By Friday it was [5], and the baker had to put out a bigger box.",
    ],
    [
      ReadingItem.choice(
        "Choose the word for [1].",
        {"A": "count", "B": "collect", "C": "sell", "D": "drop"},
        "B",
        0,
        "Leo stops the apples from rolling into the road by picking them up. “Collect” describes that action.",
      ),
      ReadingItem.choice(
        "Choose the word for [2].",
        {"A": "heavier", "B": "smaller", "C": "broken", "D": "replacement"},
        "D",
        1,
        "The original bag is broken, so the woman needs another bag in its place.",
      ),
      ReadingItem.choice(
        "Choose the word for [3].",
        {"A": "pay", "B": "blame", "C": "warn", "D": "test"},
        "A",
        2,
        "“Pay someone for their help” fits the offer and Leo’s response that he was glad to help.",
      ),
      ReadingItem.choice(
        "Choose the word for [4].",
        {"A": "expensive", "B": "wet", "C": "spare", "D": "sealed"},
        "C",
        3,
        "People leave bags they can do without so others can use them. These are spare bags.",
      ),
      ReadingItem.choice(
        "Choose the word for [5].",
        {"A": "empty", "B": "full", "C": "hidden", "D": "broken"},
        "B",
        4,
        "The baker needed a bigger container because the shelf had filled up.",
      ),
    ],
  ),
];

const grammarGapPassages = [
  ReadingPassage(
    "station-map",
    "Finding the Way",
    [
      "Yesterday I [1] (visit) a town I did not know. At the station, I found a map [2] the wall, but the street names were too small for me to read.",
      "A clerk offered [3] (print) a larger map. Before printing it, she asked [4] I wanted a copy in English or would prefer a different language.",
      "The paper map was much [5] (easy) to read than the one at the station. With its help, I walked straight to the museum.",
    ],
    [
      ReadingItem.fill(
        "Complete [1] with the correct form of “visit”.",
        ["visited"],
        0,
        "“Yesterday” sets the visit in the past, so the simple past form is “visited”.",
      ),
      ReadingItem.fill(
        "Complete [2] with a preposition.",
        ["on"],
        0,
        "Use “on” to describe something attached to the surface of a wall.",
      ),
      ReadingItem.fill(
        "Complete [3] with the correct form of “print”.",
        ["to print"],
        1,
        "“Offer” takes a to-infinitive when followed by the action offered.",
      ),
      ReadingItem.fill(
        "Complete [4] with a conjunction.",
        ["whether", "if"],
        1,
        "Both “whether” and “if” can introduce this indirect question about a preference.",
      ),
      ReadingItem.fill(
        "Complete [5] with the correct form of “easy”.",
        ["easier"],
        2,
        "“Than” introduces the second part of a comparison. The comparative of “easy” is “easier”.",
      ),
    ],
  ),
];
